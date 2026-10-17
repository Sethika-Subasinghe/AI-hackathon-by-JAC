"""Tests for sos.jac (annex). Live services off, no network."""

import from matcher { LIVE_SERVICES, get_match }
import from dispatch { LIVE_MODEL, AUTO_ACCEPT, get_dispatch, cancel_dispatch }

def _offline() {
    AUTO_ACCEPT["on"] = False;
    LIVE_SERVICES["on"] = False;
    LIVE_MODEL["on"] = False;
}

test "SOS makes a critical case without any typing" {
    _offline();
    case_id = start_sos(6.8649, 79.8997);
    cs = find_case(case_id);
    assert cs is not None;
    assert cs.severity == Severity.CRITICAL;
    assert cs.origin.lat == 6.8649;
    assert "Emergency button pressed" in cs.red_flags;
}

test "SOS picks the nearest hospital with a free bed and starts the cancel window" {
    _offline();
    case_id = start_sos(6.9271, 79.8612);
    view = run_sos(case_id);
    assert view is not None;
    assert view.hospital_id != "";
    assert view.status == "DISPATCHING";
    found = get_match(case_id);
    assert found.best is not None;
    assert found.best.free_beds > 0;
    d = get_dispatch(case_id);
    kinds = [r.kind for r in d.requests];
    assert "AMBULANCE" in kinds and "POLICE" in kinds and "HOSPITAL_ALERT" in kinds;
    assert d.countdown_total == SOS_CANCEL_SECONDS;
    assert d.seconds_left <= SOS_CANCEL_SECONDS;
}

test "SOS sends ambulance and police when the short window ends" {
    _offline();
    case_id = start_sos(6.9271, 79.8612);
    run_sos(case_id);
    cs = find_case(case_id);
    cs.countdown_ends_at = 0.0;
    d = get_dispatch(case_id);
    assert d.case_status == "DISPATCHED";
    assert all([r.status in ["SENT", "ACCEPTED"] for r in d.requests]);
}

test "SOS can be cancelled during the short window" {
    _offline();
    case_id = start_sos(6.9271, 79.8612);
    run_sos(case_id);
    d = cancel_dispatch(case_id);
    assert d.case_status == "CANCELLED";
}

test "SOS with an unknown case id returns nothing" {
    assert run_sos("does-not-exist") is None;
}
