"""CareRoute - Emergency SOS (T33).

One tap for a real emergency: no typing and no questions. The phone shares its location,
the case is rated CRITICAL straight away, the nearest hospital with a free bed (public or
private) is chosen, and the simulated ambulance, police route clearance and hospital alert
are sent after a very short Cancel window (an accidental tap can still be stopped).

    start_sos(lat, lon)  ->  case_id        (instant)
    run_sos(case_id)                         (a few seconds: match, then dispatch)

The UI polls the same endpoints as a normal case (get_case, case_events, get_match, get_dispatch).
"""

import time;
import from models { CaseState, CaseStatus, EventStatus, Severity, UnitType, Location }
import from agent_log { log_event, find_case }
import from graph_lock { GRAPH_LOCK }
import from matcher { match_case }
import from dispatch { start_dispatch }
import from orchestrator { CaseView, _case_view }

# Cancel window after the SOS tap. Set to 0.0 to send at once with no way back.
glob SOS_CANCEL_SECONDS: float = 3.0;
glob SOS_TEXT: str = "EMERGENCY SOS: the patient pressed the emergency button. Details unknown, treat as critical.";

"""Create the SOS case from the phone's location and return its id. The UI then calls `run_sos`."""
def:pub start_sos(lat: float, lon: float, address: str = "My current location") -> str {
    with GRAPH_LOCK {
        cs = (root.shared ++> CaseState(
            description=SOS_TEXT,
            origin=Location(lat=lat, lon=lon, address=address)
        ))[0];
        cs.severity = Severity.CRITICAL;
        cs.unit_needed = UnitType.GENERAL;
        cs.red_flags = ["Emergency button pressed"];
        cs.confidence = 1.0;
        cs.status = CaseStatus.TRIAGED;
        log_event(cs, "sos", "sos_pressed", EventStatus.DONE, "Emergency button pressed", "Location shared, no questions asked. Treated as critical.");
        return jid(cs);
    }
}

"""Find the nearest hospital with a free bed, then ask for the ambulance and police. Returns the case."""
def:pub run_sos(case_id: str) -> CaseView | None {
    with GRAPH_LOCK {
        cs = find_case(case_id);
        if cs is None {
            return None;
        }
        try {
            # Template reasons only: SOS never waits for a model to word them.
            result = match_case(cs, False);
            if result.best is None {
                cs.status = CaseStatus.DONE;
                log_event(cs, "sos", "no_hospital", EventStatus.FAILED, "No hospital found. Call 1990 now.", "");
            } else {
                start_dispatch(cs, SOS_CANCEL_SECONDS, False);
            }
        } except Exception {
            cs.used_fallback = True;
            cs.status = CaseStatus.DONE;
            log_event(cs, "sos", "sos_failed", EventStatus.FAILED, "Something went wrong. Call 1990 now.", "");
        }
        return _case_view(cs);
    }
}
