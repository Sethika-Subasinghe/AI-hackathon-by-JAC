"""Tests for matcher.jac (annex). Live services are switched off, so no network is used."""

import from models { Location }
import from agent_log { case_events }

def _offline() {
    LIVE_SERVICES["on"] = False;
}

test "ranking prefers speed for critical cases and skips full units" {
    _offline();
    hospitals = list_hospitals();
    result = rank_hospitals(hospitals, "ICU", Severity.CRITICAL, 6.93, 79.85, []);
    assert result.best is not None;
    assert result.best.free_beds > 0;
    assert result.best.estimated;
    assert len(result.alternatives) <= 3;
    scores = [result.best.score] + [a.score for a in result.alternatives];
    assert scores == sorted(scores, reverse=True);
    assert "Best match" in result.best.reason;
}

test "excluded hospitals are never returned" {
    _offline();
    hospitals = list_hospitals();
    first = rank_hospitals(hospitals, "ICU", Severity.URGENT, 6.93, 79.85, []);
    second = rank_hospitals(hospitals, "ICU", Severity.URGENT, 6.93, 79.85, [first.best.hospital_id]);
    assert second.best is not None;
    assert second.best.hospital_id != first.best.hospital_id;
    ids = [a.hospital_id for a in second.alternatives];
    assert first.best.hospital_id not in ids;
}

test "nearest hospital is shown when no beds are free" {
    _offline();
    hospitals = list_hospitals();
    all_ids: list[str] = [];
    result = rank_hospitals(hospitals, "NEURO", Severity.CRITICAL, 6.93, 79.85, all_ids);
    # Empty every NEURO unit by excluding nobody but asking for a unit nobody has.
    none = rank_hospitals(hospitals, "NO_SUCH_UNIT", Severity.CRITICAL, 6.93, 79.85, []);
    assert none.best is not None;
    assert none.best.free_beds == 0;
    assert "nearest" in none.summary.lower();
    everyone = [h.id for h in hospitals];
    empty = rank_hospitals(hospitals, "ICU", Severity.CRITICAL, 6.93, 79.85, everyone);
    assert empty.best is None;
    assert "1990" in empty.summary;
    assert result.best is not None;
}

test "match_case writes the choice, logs it and keeps the match" {
    _offline();
    cs = (root.shared ++> CaseState(
        description="chest pain",
        origin=Location(lat=6.93, lon=79.85)
    ))[0];
    cid = jid(cs);
    cs.unit_needed = UnitType.CARDIAC;
    cs.severity = Severity.CRITICAL;
    result = match_case(cs);
    assert result.best is not None;
    assert cs.hospital_id == result.best.hospital_id;
    assert cs.status == CaseStatus.MATCHED;
    assert get_match(cid) is not None;
    agents = [e.agent for e in case_events(cid)];
    assert "matcher" in agents;
    # Re-plan: exclude the chosen hospital and match again.
    cs.excluded_hospital_ids = [result.best.hospital_id];
    again = match_case(cs);
    assert again.best is not None;
    assert cs.hospital_id != result.best.hospital_id;
}
