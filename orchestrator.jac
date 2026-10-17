"""CareRoute - Orchestrator Agent (T13).

Decides the next step for a case, one step at a time (max 8):

    action = decide(cs)        # `decide_next` by llm(), or the rule planner if the model fails
    action = guard(action, cs) # deterministic rules can veto the model
    run the step, log it, repeat

The re-plan step is not built yet: `_do_replan` below is a placeholder that
T20 replaces with the real agent call.
"""

import from models { CaseState, CaseStatus, EventStatus, Severity, Location }
import from agent_log { start_event, finish_event, log_event, compact_case, find_case }
import from triage { triage_case }
import from matcher { match_case }
import from dispatch { start_dispatch }
import from documents { read_report }

enum Step { ASK_FOLLOWUP, READ_DOCUMENT, TRIAGE, MATCH, DISPATCH, REPLAN, FINISH }
sem Step.ASK_FOLLOWUP = "Ask the patient one follow-up question because the text is too vague.";
sem Step.READ_DOCUMENT = "Read the uploaded PDF report. Only valid when a report exists and has not been read.";
sem Step.TRIAGE = "Rate urgency and the unit needed. Only valid for a new case.";
sem Step.MATCH = "Find the best hospital. Only valid after triage.";
sem Step.DISPATCH = "Send ambulance, police and hospital requests. Only for CRITICAL cases with a matched hospital.";
sem Step.REPLAN = "Pick another hospital after a decline or no beds.";
sem Step.FINISH = "Stop, the case has a safe outcome.";

"""The orchestrator's choice and the reason shown in the timeline."""
obj NextAction {
    has step: Step,
        reason: str = "";
}
sem NextAction.step = "The single next step to run.";
sem NextAction.reason = "One short plain sentence explaining the choice, no diagnosis.";

"""Case facts for the UI."""
obj CaseView {
    has id: str,
        description: str,
        status: str,
        severity: str,
        unit: str,
        red_flags: list[str],
        confidence: float,
        followup_question: str,
        hospital_id: str,
        eta_minutes: float,
        replan_count: int,
        used_fallback: bool;
}

glob MAX_STEPS: int = 8;
glob MAX_REPLANS: int = 3;

def _document_pending(cs: CaseState) -> bool {
    return cs.has_pdf and cs.report_summary == "";
}

"""Steps the guard allows in the case's current state."""
def allowed_steps(cs: CaseState) -> list[Step] {
    st = cs.status;
    if st == CaseStatus.NEW {
        if _document_pending(cs) {
            return [Step.READ_DOCUMENT];
        }
        return [Step.TRIAGE];
    }
    if st == CaseStatus.NEEDS_INFO {
        return [Step.ASK_FOLLOWUP];
    }
    if st == CaseStatus.TRIAGED {
        return [Step.MATCH];
    }
    if st == CaseStatus.MATCHED {
        if cs.severity == Severity.CRITICAL and cs.hospital_id != "" {
            return [Step.DISPATCH];
        }
        return [Step.FINISH];
    }
    if st == CaseStatus.REPLANNING {
        if cs.replan_count < MAX_REPLANS {
            return [Step.REPLAN];
        }
        return [Step.FINISH];
    }
    return [Step.FINISH];
}

"""Rule planner: the first allowed step. Fallback when the model fails."""
def rule_next(cs: CaseState) -> NextAction {
    options = allowed_steps(cs);
    return NextAction(step=options[0], reason="Next step by rule");
}

"""Guard: the model's choice must be an allowed step, otherwise the rule planner decides."""
def guard(action: NextAction, cs: CaseState) -> NextAction {
    if action.step in allowed_steps(cs) {
        return action;
    }
    fixed = rule_next(cs);
    fixed.reason = f"Guard changed {action.step.name} to {fixed.step.name}: {action.reason}";
    return fixed;
}

"""Choose the next step from a compact view of the case."""
def decide_next(state: str) -> NextAction by llm(temperature=0.1);
sem decide_next = "You coordinate emergency hospital-finding agents. Pick the next step. Order: READ_DOCUMENT only if a report exists and is unread, TRIAGE for a new case, ASK_FOLLOWUP if triage needs more information, MATCH after triage, DISPATCH only if CRITICAL and a hospital is matched, REPLAN if the hospital declined, FINISH when done. Never diagnose.";
sem decide_next.state = "Compact case facts including its status.";

def _state_text(cs: CaseState) -> str {
    return compact_case(cs) + f"\nHas PDF report: {cs.has_pdf}, report read: {cs.report_summary != ''}";
}

def _do_read_document(cs: CaseState) {
    read_report(cs);
}

def _do_match(cs: CaseState) {
    result = match_case(cs);
    if result.best is None {
        cs.status = CaseStatus.DONE;
    }
}

def _do_dispatch(cs: CaseState) {
    start_dispatch(cs);
}

def _do_replan(cs: CaseState) {
    # Placeholder until T20 (Re-plan Agent) is connected.
    log_event(cs, "replan", "re_match", EventStatus.FAILED, "Re-planning is not connected yet");
    cs.status = CaseStatus.DONE;
}

"""Run the orchestrator loop for a case. Returns the number of steps taken.
Stops early when it must wait for the patient (follow-up) or the case is finished."""
def run_case(cs: CaseState) -> int {
    steps = 0;
    for _i in range(MAX_STEPS) {
        steps += 1;
        ev = start_event(cs, "orchestrator", "decide", "Choosing the next step");
        try {
            action = decide_next(_state_text(cs));
        } except Exception {
            action = rule_next(cs);
            action.reason = "Using backup logic: " + action.reason;
        }
        action = guard(action, cs);
        finish_event(ev, EventStatus.DONE, f"Next: {action.step.name}", action.reason);

        if action.step == Step.TRIAGE {
            triage_case(cs);
        } elif action.step == Step.READ_DOCUMENT {
            _do_read_document(cs);
        } elif action.step == Step.ASK_FOLLOWUP {
            log_event(cs, "orchestrator", "ask_followup", EventStatus.WAITING, cs.followup_question, "Waiting for your answer");
            return steps;
        } elif action.step == Step.MATCH {
            _do_match(cs);
        } elif action.step == Step.DISPATCH {
            _do_dispatch(cs);
        } elif action.step == Step.REPLAN {
            _do_replan(cs);
        } else {
            # Dispatching, dispatched, replanning and cancelled cases keep their status.
            if cs.status in [CaseStatus.NEW, CaseStatus.TRIAGED, CaseStatus.MATCHED] {
                cs.status = CaseStatus.DONE;
            }
            log_event(cs, "orchestrator", "finish", EventStatus.DONE, "All steps finished");
            return steps;
        }
    }
    log_event(cs, "orchestrator", "step_limit", EventStatus.DONE, "Stopped at the step limit, showing the best result so far");
    return steps;
}

def _case_view(cs: CaseState) -> CaseView {
    return CaseView(
        id=jid(cs),
        description=cs.description,
        status=cs.status.name,
        severity=cs.severity.name,
        unit=cs.unit_needed.name,
        red_flags=cs.red_flags,
        confidence=cs.confidence,
        followup_question=cs.followup_question,
        hospital_id=cs.hospital_id,
        eta_minutes=cs.eta_minutes,
        replan_count=cs.replan_count,
        used_fallback=cs.used_fallback
    );
}

"""Create a case and return its id. The UI then calls `run_case_by_id` and polls `case_events`."""
def:pub create_case(
    description: str,
    lat: float,
    lon: float,
    address: str = "",
    has_pdf: bool = False
) -> str {
    cs = (root.shared ++> CaseState(
        description=description,
        origin=Location(lat=lat, lon=lon, address=address),
        has_pdf=has_pdf
    ))[0];
    return jid(cs);
}

"""Run the orchestrator for a case. Returns the case when it stops, or None if the id is unknown."""
def:pub run_case_by_id(case_id: str) -> CaseView | None {
    cs = find_case(case_id);
    if cs is None {
        return None;
    }
    run_case(cs);
    return _case_view(cs);
}

"""Current case facts (for the result screen), or None."""
def:pub get_case(case_id: str) -> CaseView | None {
    cs = find_case(case_id);
    if cs is None {
        return None;
    }
    return _case_view(cs);
}

"""Add the patient's answer to the description and reopen the case. Call `run_case_by_id` next."""
def:pub answer_followup(case_id: str, answer: str) -> CaseView | None {
    cs = find_case(case_id);
    if cs is None {
        return None;
    }
    cs.description = cs.description + ". " + answer;
    cs.followup_question = "";
    cs.status = CaseStatus.NEW;
    return _case_view(cs);
}
