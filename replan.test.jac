"""Tests for replan.jac (annex). Live services off, no network."""

import from models { Hospital, Location, Severity, UnitType }
import from data.hospital_seed { DEMO_HOSPITAL_PASSWORD }
import from agent_log { case_events }
import from hospitals { hospital_login, list_hospitals, set_free_beds }
import from matcher { LIVE_SERVICES, match_case }
import from dispatch { LIVE_MODEL, start_dispatch, get_dispatch, hospital_alerts, respond_alert }

def _login_as(hospital_id: str) -> str {
    for h in [root.shared -->][?:Hospital] {
        if jid(h) == hospital_id {
            return hospital_login(h.username, DEMO_HOSPITAL_PASSWORD).token;
        }
    }
    return "";
}

"""A critical cardiac case that is already dispatched to its best hospital."""
def _dispatched_case() -> CaseState {
    LIVE_SERVICES["on"] = False;
    LIVE_MODEL["on"] = False;
    cs = (root.shared ++> CaseState(
        description="chest pain",
        origin=Location(lat=6.93, lon=79.85),
        severity=Severity.CRITICAL,
        unit_needed=UnitType.CARDIAC
    ))[0];
    match_case(cs);
    start_dispatch(cs);
    cs.countdown_ends_at = 0.0;
    get_dispatch(jid(cs));
    return cs;
}

def _alert_for(cs: CaseState) -> str {
    token = _login_as(cs.hospital_id);
    mine = [a for a in hospital_alerts(token) if a.case_id == jid(cs)];
    return mine[0].request_id;
}

test "a decline re-matches and re-dispatches to another hospital" {
    cs = _dispatched_case();
    first = cs.hospital_id;
    token = _login_as(first);
    respond_alert(token, _alert_for(cs), False);

    assert cs.hospital_id != first;
    assert cs.hospital_id != "";
    assert first in cs.excluded_hospital_ids;
    assert cs.replan_count == 1;
    assert cs.status == CaseStatus.DISPATCHED;

    view = get_dispatch(jid(cs));
    assert len(view.requests) == 3;
    assert all([r.status == "SENT" for r in view.requests]);
    assert len(view.previous) == 3;
    old_ambulance = [r for r in view.previous if r.kind == "AMBULANCE"][0];
    assert old_ambulance.status == "CANCELLED";
    old_alert = [r for r in view.previous if r.kind == "HOSPITAL_ALERT"][0];
    assert old_alert.status == "DECLINED";

    # The new hospital can see the alert, the old one cannot get a fresh one.
    new_token = _login_as(cs.hospital_id);
    assert len([a for a in hospital_alerts(new_token) if a.case_id == jid(cs) and a.status == "SENT"]) == 1;

    steps = [e.step for e in case_events(jid(cs))];
    assert "hospital_declined" in steps and "re_match" in steps and "redispatch" in steps;
}

test "no answer within the timeout triggers a re-plan" {
    cs = _dispatched_case();
    first = cs.hospital_id;
    for r in [cs ->:CaseRequest:->] {
        r.sent_at = r.sent_at - 100.0;
    }
    view = get_dispatch(jid(cs));
    assert cs.hospital_id != first;
    assert cs.replan_count == 1;
    old_alert = [r for r in view.previous if r.kind == "HOSPITAL_ALERT"][0];
    assert old_alert.status == "TIMEOUT";
}

test "no free beds triggers a re-plan" {
    cs = _dispatched_case();
    first = cs.hospital_id;
    token = _login_as(first);
    set_free_beds(token, "CARDIAC", 0);
    get_dispatch(jid(cs));
    assert cs.hospital_id != first;
    assert cs.replan_count == 1;
}

test "an accepted hospital is never re-planned" {
    cs = _dispatched_case();
    first = cs.hospital_id;
    token = _login_as(first);
    respond_alert(token, _alert_for(cs), True);
    for r in [cs ->:CaseRequest:->] {
        r.sent_at = r.sent_at - 100.0;
    }
    get_dispatch(jid(cs));
    assert cs.hospital_id == first;
    assert cs.replan_count == 0;
}

test "re-planning stops after the limit" {
    cs = _dispatched_case();
    cs.replan_count = MAX_REPLANS;
    assert not replan_case(cs);
    assert cs.status == CaseStatus.DONE;
    titles = [e.title for e in case_events(jid(cs))];
    assert any(["tried" in t.lower() for t in titles]);
}

test "three declines in a row end at the limit" {
    cs = _dispatched_case();
    for _i in range(MAX_REPLANS) {
        token = _login_as(cs.hospital_id);
        respond_alert(token, _alert_for(cs), False);
    }
    assert cs.replan_count == MAX_REPLANS;
    assert cs.status == CaseStatus.DISPATCHED;
    token = _login_as(cs.hospital_id);
    respond_alert(token, _alert_for(cs), False);
    assert cs.status == CaseStatus.DONE;
}
