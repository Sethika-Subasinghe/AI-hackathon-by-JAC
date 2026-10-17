"""CareRoute - Emergency Dispatch Agent (T17), critical cases only.

Flow (nothing runs in the background, the clock is checked on every read):

1. `start_dispatch` drafts the messages and creates three PENDING requests
   (ambulance, police route clearance, hospital pre-alert), then opens a
   10-second countdown (`CaseState.countdown_ends_at`).
2. The patient can `cancel_dispatch` until the countdown ends.
3. When it ends, the next `get_dispatch` sends all three (status SENT). Sending
   is idempotent, so nothing is ever sent twice.
4. The hospital sees the alert in `hospital_alerts` and calls `respond_alert`
   with accept or decline. A decline sets the case to REPLANNING (T20 re-plans).

Everything here is simulated and labelled `simulated=True`.
"""

import time;
import from models { CaseState, CaseStatus, CaseRequest, EventStatus, Hospital, Request, RequestKind, RequestStatus }
import from agent_log { start_event, finish_event, log_event, find_case, compact_case }
import from hospitals { my_hospital }
import from geoapify { get_route }

glob COUNTDOWN_SECONDS: float = 10.0;
# Demo speed: the ambulance covers the route this many times faster than real time.
glob DEMO_SPEEDUP: float = 30.0;
glob LIVE_MODEL: dict[str, bool] = {"on": True};

"""Messages for each recipient, short and factual, no diagnosis."""
obj DispatchPlan {
    has ambulance_message: str,
        police_message: str,
        hospital_message: str,
        priority: str = "high";
}
sem DispatchPlan.ambulance_message = "One or two factual sentences for the ambulance crew: where to go and how urgent. No diagnosis.";
sem DispatchPlan.police_message = "One or two factual sentences asking police to clear the given route. No diagnosis.";
sem DispatchPlan.hospital_message = "One or two factual sentences telling the hospital a critical patient is coming, with ETA and unit needed. No diagnosis.";
sem DispatchPlan.priority = "Always the word high.";

"""One simulated request as sent to the UI."""
obj RequestView {
    has id: str,
        kind: str,
        target: str,
        message: str,
        status: str,
        priority: str,
        simulated: bool,
        route: list[list[float]] = [];
}

"""Dispatch status for the countdown banner and the live status panel."""
obj DispatchView {
    has case_id: str,
        case_status: str,
        seconds_left: float,
        requests: list[RequestView],
        ambulance_progress: float = 0.0;
}

"""A hospital's incoming alert."""
obj AlertView {
    has request_id: str,
        case_id: str,
        status: str,
        message: str,
        severity: str,
        unit: str,
        eta_minutes: float,
        created_at: float;
}

def draft_dispatch_messages(facts: str) -> DispatchPlan by llm(temperature=0.2);
sem draft_dispatch_messages = "Write the three short dispatch messages for a critical patient. Be factual and calm. Never diagnose.";
sem draft_dispatch_messages.facts = "Compact case facts: unit needed, hospital, ETA, route length.";

def _template_plan(hospital: str, unit: str, eta: float, km: float) -> DispatchPlan {
    return DispatchPlan(
        ambulance_message=f"Critical patient, {unit.lower()} care needed. Take them to {hospital}, about {round(eta)} min away.",
        police_message=f"Please clear the route to {hospital}: about {km:.1f} km, {round(eta)} min. Ambulance is on the way.",
        hospital_message=f"Critical patient arriving in about {round(eta)} min. Unit needed: {unit.lower()}. Please get ready."
    );
}

def _requests(cs: CaseState) -> list[Request] {
    return [r for r in [cs ->:CaseRequest:->]];
}

def _view_request(r: Request) -> RequestView {
    return RequestView(
        id=jid(r),
        kind=r.kind.name,
        target=r.target,
        message=r.message,
        status=r.status.name,
        priority=r.priority,
        simulated=r.simulated,
        route=r.route
    );
}

def _new_request(
    cs: CaseState,
    kind: RequestKind,
    target: str,
    target_id: str,
    message: str,
    route: list[list[float]]
) -> Request {
    return (cs +>:CaseRequest():+> Request(
        case_id=jid(cs),
        kind=kind,
        target=target,
        target_id=target_id,
        message=message,
        route=route,
        created_at=time.time()
    ))[0];
}

"""Create the three requests and open the countdown. Safe to call twice."""
def start_dispatch(cs: CaseState) -> list[Request] {
    existing = _requests(cs);
    if len(existing) > 0 {
        return existing;
    }
    ev = start_event(cs, "dispatch", "prepare", "Preparing ambulance, police and hospital requests");
    hospital_name = "the chosen hospital";
    route_coords: list[list[float]] = [];
    km = 0.0;
    eta = cs.eta_minutes;
    for h in [root.shared -->][?:Hospital] {
        if jid(h) == cs.hospital_id {
            hospital_name = h.name;
            if LIVE_MODEL["on"] {
                route = get_route(cs.origin.lat, cs.origin.lon, h.lat, h.lon);
                route_coords = route.coordinates;
                km = route.distance_km;
                eta = route.eta_minutes;
            }
        }
    }
    unit = cs.unit_needed.name;
    plan = _template_plan(hospital_name, unit, eta, km);
    if LIVE_MODEL["on"] {
        try {
            plan = draft_dispatch_messages(
                compact_case(cs) + f"\nHospital: {hospital_name}, ETA {round(eta)} min, route {km:.1f} km"
            );
        } except Exception {
            cs.used_fallback = True;
        }
    }
    created: list[Request] = [];
    created.append(_new_request(cs, RequestKind.AMBULANCE, "Ambulance service", "", plan.ambulance_message, route_coords));
    created.append(_new_request(cs, RequestKind.POLICE, "Traffic police", "", plan.police_message, route_coords));
    created.append(_new_request(cs, RequestKind.HOSPITAL_ALERT, hospital_name, cs.hospital_id, plan.hospital_message, []));
    cs.status = CaseStatus.DISPATCHING;
    cs.countdown_ends_at = time.time() + COUNTDOWN_SECONDS;
    finish_event(ev, EventStatus.DONE, "Requests ready (simulated)", "Dispatching in 10 seconds unless you cancel");
    log_event(cs, "dispatch", "countdown", EventStatus.WAITING, "Dispatching in 10 seconds", "Tap Cancel to stop");
    return created;
}

"""Send every pending request once."""
def _send(cs: CaseState) {
    now = time.time();
    for r in _requests(cs) {
        if r.status == RequestStatus.PENDING {
            r.status = RequestStatus.SENT;
            r.sent_at = now;
            log_event(cs, "dispatch", f"send_{r.kind.name.lower()}", EventStatus.DONE, f"{r.target}: request sent (simulated)", r.message);
        }
    }
    cs.status = CaseStatus.DISPATCHED;
}

"""Move the countdown forward. Called by every read below."""
def _tick(cs: CaseState) {
    if cs.status == CaseStatus.DISPATCHING and time.time() >= cs.countdown_ends_at {
        _send(cs);
    }
}

def _ambulance_progress(cs: CaseState) -> float {
    if cs.status != CaseStatus.DISPATCHED or cs.eta_minutes <= 0.0 {
        return 0.0;
    }
    for r in _requests(cs) {
        if r.kind == RequestKind.AMBULANCE and r.sent_at > 0.0 {
            seconds = cs.eta_minutes * 60.0 / DEMO_SPEEDUP;
            return min(1.0, (time.time() - r.sent_at) / max(seconds, 1.0));
        }
    }
    return 0.0;
}

def _dispatch_view(cs: CaseState) -> DispatchView {
    left = 0.0;
    if cs.status == CaseStatus.DISPATCHING {
        left = max(0.0, cs.countdown_ends_at - time.time());
    }
    return DispatchView(
        case_id=jid(cs),
        case_status=cs.status.name,
        seconds_left=left,
        requests=[_view_request(r) for r in _requests(cs)],
        ambulance_progress=_ambulance_progress(cs)
    );
}

"""Countdown and request status for a case (poll about once a second)."""
def:pub get_dispatch(case_id: str) -> DispatchView | None {
    cs = find_case(case_id);
    if cs is None {
        return None;
    }
    _tick(cs);
    return _dispatch_view(cs);
}

"""Cancel the dispatch while the countdown is still running."""
def:pub cancel_dispatch(case_id: str) -> DispatchView | None {
    cs = find_case(case_id);
    if cs is None {
        return None;
    }
    _tick(cs);
    if cs.status == CaseStatus.DISPATCHING {
        for r in _requests(cs) {
            r.status = RequestStatus.CANCELLED;
        }
        cs.status = CaseStatus.CANCELLED;
        log_event(cs, "dispatch", "cancelled", EventStatus.DONE, "Dispatch cancelled by you", "Nothing was sent. In a real emergency call 1990.");
    }
    return _dispatch_view(cs);
}

def _alert_view(r: Request, cs: CaseState) -> AlertView {
    return AlertView(
        request_id=jid(r),
        case_id=jid(cs),
        status=r.status.name,
        message=r.message,
        severity=cs.severity.name,
        unit=cs.unit_needed.name,
        eta_minutes=cs.eta_minutes,
        created_at=r.sent_at
    );
}

"""Incoming alerts for the signed-in hospital, newest first."""
def:pub hospital_alerts(token: str) -> list[AlertView] {
    me = my_hospital(token);
    if me is None {
        return [];
    }
    alerts: list[AlertView] = [];
    for cs in [root.shared -->][?:CaseState] {
        _tick(cs);
        for r in _requests(cs) {
            if r.kind == RequestKind.HOSPITAL_ALERT and r.target_id == me.id and r.status != RequestStatus.PENDING and r.status != RequestStatus.CANCELLED {
                alerts.append(_alert_view(r, cs));
            }
        }
    }
    return sorted(alerts, key=lambda a: AlertView : -a.created_at);
}

"""A hospital accepts or declines an alert. A decline sends the case to re-planning."""
def:pub respond_alert(token: str, request_id: str, accept: bool) -> AlertView | None {
    me = my_hospital(token);
    if me is None {
        return None;
    }
    for cs in [root.shared -->][?:CaseState] {
        for r in _requests(cs) {
            if jid(r) == request_id and r.kind == RequestKind.HOSPITAL_ALERT and r.target_id == me.id {
                if r.status != RequestStatus.SENT {
                    return _alert_view(r, cs);
                }
                if accept {
                    r.status = RequestStatus.ACCEPTED;
                    log_event(cs, "dispatch", "hospital_accepted", EventStatus.DONE, f"{r.target} accepted the patient", "Ready for arrival");
                } else {
                    r.status = RequestStatus.DECLINED;
                    cs.status = CaseStatus.REPLANNING;
                    log_event(cs, "dispatch", "hospital_declined", EventStatus.FAILED, f"{r.target} declined", "Finding another hospital");
                }
                return _alert_view(r, cs);
            }
        }
    }
    return None;
}
