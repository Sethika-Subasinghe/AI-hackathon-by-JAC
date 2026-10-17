"""CareRoute - Re-plan Agent (T20).

Recovers when the plan breaks: the chosen hospital declines, runs out of free
beds, or does not answer within RESPONSE_TIMEOUT_SECONDS. Then it
1. leaves that hospital out (`excluded_hospital_ids`),
2. re-runs the Matcher,
3. re-dispatches to the next best hospital (no second countdown, the patient already agreed),
4. logs every step so the timeline shows "Hospital declined, re-matching, new hospital alerted".

At most MAX_REPLANS re-plans per case, then it stops and advises calling 1990.
`dispatch.jac` calls `replan_if_needed` on every poll and `replan_case` on a decline.
"""

import time;
import from models { CaseState, CaseStatus, CaseRequest, EventStatus, RequestKind, RequestStatus, Severity }
import from agent_log { start_event, finish_event, log_event }
import from matcher { match_case }
import from hospitals { get_hospital }
import from dispatch { dispatch_now }

glob MAX_REPLANS: int = 3;
# Demo: about 20 seconds without an answer counts as no response.
glob RESPONSE_TIMEOUT_SECONDS: float = 20.0;
glob replanning: dict[str, bool] = {};

def _free_beds(cs: CaseState) -> int {
    h = get_hospital(cs.hospital_id);
    if h is None {
        return 0;
    }
    for u in h.units {
        if u.unit_type == cs.unit_needed.name {
            return u.free;
        }
    }
    return 0;
}

"""Why the plan broke, or an empty string when it did not. Marks the hospital alert it used."""
def check_triggers(cs: CaseState) -> str {
    if cs.status != CaseStatus.DISPATCHED {
        return "";
    }
    for r in [cs ->:CaseRequest:->] {
        if r.kind == RequestKind.HOSPITAL_ALERT and r.attempt == cs.replan_count and r.status == RequestStatus.SENT {
            if time.time() - r.sent_at > RESPONSE_TIMEOUT_SECONDS {
                r.status = RequestStatus.TIMEOUT;
                return f"{r.target} did not answer in time";
            }
            if _free_beds(cs) == 0 {
                r.status = RequestStatus.CANCELLED;
                return f"{r.target} has no free {cs.unit_needed.name.lower()} beds left";
            }
        }
    }
    return "";
}

"""Re-plan now: exclude the current hospital, re-match, re-dispatch. Returns True when a new hospital was alerted."""
def replan_case(cs: CaseState) -> bool {
    key = jid(cs);
    if replanning.get(key, False) {
        return False;
    }
    replanning[key] = True;
    ok = False;
    try {
        ok = _replan(cs);
    } except Exception {
        log_event(cs, "replan", "failed", EventStatus.FAILED, "Re-planning failed, please call 1990");
        cs.status = CaseStatus.DONE;
    }
    replanning[key] = False;
    return ok;
}

def _replan(cs: CaseState) -> bool {
    if cs.replan_count >= MAX_REPLANS {
        log_event(
            cs, "replan", "limit", EventStatus.FAILED,
            f"We tried {MAX_REPLANS} other hospitals without success",
            "Please call 1990. The best remaining options are listed on screen."
        );
        cs.status = CaseStatus.DONE;
        return False;
    }
    old_id = cs.hospital_id;
    old_name = "the previous hospital";
    h = get_hospital(old_id);
    if h is not None {
        old_name = h.name;
    }
    ev = start_event(cs, "replan", "re_match", "Finding another hospital", f"Leaving out {old_name}");
    cs.status = CaseStatus.REPLANNING;
    # The ambulance and police requests for the old hospital are redirected.
    for r in [cs ->:CaseRequest:->] {
        if r.attempt == cs.replan_count and r.kind != RequestKind.HOSPITAL_ALERT {
            if r.status == RequestStatus.SENT or r.status == RequestStatus.PENDING {
                r.status = RequestStatus.CANCELLED;
            }
        }
    }
    excluded = list(cs.excluded_hospital_ids);
    if old_id != "" and old_id not in excluded {
        excluded.append(old_id);
    }
    cs.excluded_hospital_ids = excluded;
    cs.replan_count += 1;
    cs.hospital_id = "";
    result = match_case(cs);
    best = result.best;
    if best is None {
        cs.status = CaseStatus.DONE;
        finish_event(ev, EventStatus.FAILED, "No other hospital found", "Please call 1990");
        return False;
    }
    if cs.severity == Severity.CRITICAL {
        dispatch_now(cs);
    }
    finish_event(
        ev,
        EventStatus.DONE,
        f"New hospital: {best.name}",
        f"Re-plan {cs.replan_count} of {MAX_REPLANS}. {old_name} was left out."
    );
    return True;
}

"""Poll hook: re-plan if the chosen hospital is full or silent. Returns True when it re-planned."""
def replan_if_needed(cs: CaseState) -> bool {
    if replanning.get(jid(cs), False) {
        return False;
    }
    reason = check_triggers(cs);
    if reason == "" {
        return False;
    }
    log_event(cs, "replan", "trigger", EventStatus.FAILED, reason, "Finding another hospital");
    return replan_case(cs);
}
