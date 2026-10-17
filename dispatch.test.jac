"""Tests for dispatch.jac (annex). Live services off, no network. The countdown clock is moved by hand."""

import from models { Hospital, Location, Severity, UnitType }
import from data.hospital_seed { DEMO_HOSPITAL_PASSWORD }
import from agent_log { case_events }
import from hospitals { hospital_login, list_hospitals }
import from matcher { LIVE_SERVICES, match_case }

def _critical_case() -> CaseState {
    LIVE_SERVICES["on"] = False;
    LIVE_MODEL["on"] = False;
    cs = (root.shared ++> CaseState(
        description="chest pain",
        origin=Location(lat=6.93, lon=79.85),
        severity=Severity.CRITICAL,
        unit_needed=UnitType.CARDIAC
    ))[0];
    match_case(cs);
    return cs;
}

def _login_as(hospital_id: str) -> str {
    for h in [root.shared -->][?:Hospital] {
        if jid(h) == hospital_id {
            return hospital_login(h.username, DEMO_HOSPITAL_PASSWORD).token;
        }
    }
    return "";
}

test "countdown holds the requests until it ends" {
    cs = _critical_case();
    start_dispatch(cs);
    assert cs.status == CaseStatus.DISPATCHING;
    view = get_dispatch(jid(cs));
    assert view is not None;
    assert len(view.requests) == 3;
    assert view.seconds_left > 0.0;
    assert all([r.status == "PENDING" for r in view.requests]);
    assert all([r.simulated for r in view.requests]);
    kinds = [r.kind for r in view.requests];
    assert "AMBULANCE" in kinds and "POLICE" in kinds and "HOSPITAL_ALERT" in kinds;
}

test "start_dispatch twice creates requests once" {
    cs = _critical_case();
    start_dispatch(cs);
    start_dispatch(cs);
    assert len(get_dispatch(jid(cs)).requests) == 3;
}

test "requests are sent once the countdown ends" {
    cs = _critical_case();
    start_dispatch(cs);
    cs.countdown_ends_at = 0.0;
    view = get_dispatch(jid(cs));
    assert view.case_status == "DISPATCHED";
    assert all([r.status == "SENT" for r in view.requests]);
    again = get_dispatch(jid(cs));
    sent_events = [e for e in case_events(jid(cs)) if e.step.startswith("send_")];
    assert len(sent_events) == 3;
    assert len(again.requests) == 3;
}

test "cancel stops everything before the countdown ends" {
    cs = _critical_case();
    start_dispatch(cs);
    view = cancel_dispatch(jid(cs));
    assert view.case_status == "CANCELLED";
    assert all([r.status == "CANCELLED" for r in view.requests]);
    cs.countdown_ends_at = 0.0;
    assert get_dispatch(jid(cs)).case_status == "CANCELLED";
}

test "cancel after the countdown does nothing" {
    cs = _critical_case();
    start_dispatch(cs);
    cs.countdown_ends_at = 0.0;
    view = cancel_dispatch(jid(cs));
    assert view.case_status == "DISPATCHED";
}

test "hospital sees the alert and accepts it" {
    cs = _critical_case();
    start_dispatch(cs);
    cs.countdown_ends_at = 0.0;
    token = _login_as(cs.hospital_id);
    assert token != "";
    alerts = hospital_alerts(token);
    mine = [a for a in alerts if a.case_id == jid(cs)];
    assert len(mine) == 1;
    assert mine[0].status == "SENT";
    assert mine[0].severity == "CRITICAL";
    done = respond_alert(token, mine[0].request_id, True);
    assert done.status == "ACCEPTED";
    assert cs.status == CaseStatus.DISPATCHED;
    # A second answer changes nothing.
    again = respond_alert(token, mine[0].request_id, False);
    assert again.status == "ACCEPTED";
}

test "a decline hands the case to the re-plan agent" {
    cs = _critical_case();
    start_dispatch(cs);
    cs.countdown_ends_at = 0.0;
    token = _login_as(cs.hospital_id);
    mine = [a for a in hospital_alerts(token) if a.case_id == jid(cs)];
    done = respond_alert(token, mine[0].request_id, False);
    first = [h for h in list_hospitals() if h.id not in cs.excluded_hospital_ids];
    assert done.status == "DECLINED";
    assert cs.replan_count == 1;
    assert len(cs.excluded_hospital_ids) == 1;
    assert cs.status == CaseStatus.DISPATCHED;
    assert len(first) > 0;
}

test "other hospitals and bad tokens see nothing" {
    cs = _critical_case();
    start_dispatch(cs);
    cs.countdown_ends_at = 0.0;
    assert hospital_alerts("bad-token") == [];
    others = [h for h in list_hospitals() if h.id != cs.hospital_id];
    other_token = _login_as(others[0].id);
    assert len([a for a in hospital_alerts(other_token) if a.case_id == jid(cs)]) == 0;
    req = [r for r in get_dispatch(jid(cs)).requests if r.kind == "HOSPITAL_ALERT"][0];
    assert respond_alert(other_token, req.id, True) is None;
}
