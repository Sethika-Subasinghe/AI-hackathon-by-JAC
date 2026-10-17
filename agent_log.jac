"""CareRoute - agent conventions and the AgentEvent log (T09).

Every agent follows the same pattern (details in skill.md A0 and A8):

    ev = start_event(cs, "triage", "rate_urgency", "Rating urgency");
    result = triage(compact_case(cs));         # a typed `by llm()` function
    finish_event(ev, EventStatus.DONE, "Urgent, needs a cardiac unit", detail);

`case_events` is polled by the UI AgentTimeline about once a second.
Model setup lives in jac.toml under [plugins.byllm.model]; agents pass a low
`temperature` per call, for example `by llm(temperature=0.2)`.
"""

import os;
import time;
import from jaclang { JacRuntime as Jac }
import from models { CaseState, AgentEvent, CaseEvent, EventStatus }

# Set CAREROUTE_NO_COMMIT=1 to turn the mid-request saves off (used to compare behaviour).
glob COMMIT_EVENTS: bool = os.environ.get("CAREROUTE_NO_COMMIT", "") == "";

"""One timeline step as sent to the UI."""
obj EventView {
    has id: str,
        case_id: str,
        agent: str,
        step: str,
        status: str,
        title: str,
        detail: str,
        timestamp: float;
}

def find_case(case_id: str) -> CaseState | None {
    for c in [root.shared -->][?:CaseState] {
        if jid(c) == case_id {
            return c;
        }
    }
    return None;
}

def _event_view(e: AgentEvent) -> EventView {
    return EventView(
        id=jid(e),
        case_id=e.case_id,
        agent=e.agent,
        step=e.step,
        status=e.status.name,
        title=e.title,
        detail=e.detail,
        timestamp=e.timestamp
    );
}

"""Write a step with any status in one call."""
def log_event(
    cs: CaseState,
    agent: str,
    step: str,
    status: EventStatus,
    title: str,
    detail: str = ""
) -> AgentEvent {
    ev = (cs +>:CaseEvent():+> AgentEvent(
        case_id=jid(cs),
        agent=agent,
        step=step,
        status=status,
        title=title,
        detail=detail,
        timestamp=time.time()
    ))[0];
    # Save now, so the UI timeline (another request) sees this step while the case is still running.
    if COMMIT_EVENTS {
        Jac.commit();
    }
    return ev;
}

"""Write a RUNNING step before an agent runs."""
def start_event(
    cs: CaseState,
    agent: str,
    step: str,
    title: str,
    detail: str = ""
) -> AgentEvent {
    return log_event(cs, agent, step, EventStatus.RUNNING, title, detail);
}

"""Close a step: DONE, FAILED or WAITING. Empty title or detail keep the old text."""
def finish_event(
    ev: AgentEvent,
    status: EventStatus,
    title: str = "",
    detail: str = ""
) {
    ev.status = status;
    if title != "" {
        ev.title = title;
    }
    if detail != "" {
        ev.detail = detail;
    }
    ev.timestamp = time.time();
    if COMMIT_EVENTS {
        Jac.commit();
    }
}

"""Short text of the latest case facts for LLM prompts (never the whole history)."""
def compact_case(cs: CaseState) -> str {
    lines = [f"Description: {cs.description}"];
    if cs.report_summary != "" {
        lines.append(f"Report summary: {cs.report_summary}");
    }
    lines.append(f"Severity: {cs.severity.name}, unit: {cs.unit_needed.name}, confidence: {cs.confidence}");
    if len(cs.red_flags) > 0 {
        lines.append("Red flags: " + ", ".join(cs.red_flags));
    }
    lines.append(f"Status: {cs.status.name}, hospital chosen: {cs.hospital_id != ''}, re-plans: {cs.replan_count}");
    return "\n".join(lines);
}

"""All steps of a case, oldest first (the UI timeline polls this)."""
def:pub case_events(case_id: str) -> list[EventView] {
    cs = find_case(case_id);
    if cs is None {
        return [];
    }
    views = [_event_view(e) for e in [cs ->:CaseEvent:->]];
    return sorted(views, key=lambda v: EventView : v.timestamp);
}
