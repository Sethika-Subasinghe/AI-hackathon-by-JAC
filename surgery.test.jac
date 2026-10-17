"""Tests for surgery.jac (annex)."""

import from hospitals { hospital_login }
import from data.hospital_seed { DEMO_HOSPITAL_PASSWORD }

def _token(username: str) -> str {
    list_surgery_catalog();
    _ensure_seeded();
    return hospital_login(username, DEMO_HOSPITAL_PASSWORD).token;
}

test "the catalog lists common planned surgeries" {
    codes = [s.code for s in list_surgery_catalog()];
    assert "CATARACT" in codes and "KNEE" in codes and "HERNIA" in codes;
    assert len(codes) >= 8;
}

test "every demo hospital gets its lists once" {
    _ensure_seeded();
    _ensure_seeded();
    colombo = [h for h in [root.shared -->][?:Hospital] if h.name.startswith("Colombo Central")][0];
    assert len([colombo ->:HasSurgery:->]) == 9;
}

test "without a location the shortest wait wins" {
    choice = find_surgery_hospitals("CATARACT", 0.0, 0.0);
    assert choice.best is not None;
    waits = [choice.best.wait_weeks] + [a.wait_weeks for a in choice.alternatives];
    assert choice.best.wait_weeks == min(waits);
    assert choice.best.wait_weeks < 2.0;
    assert len(choice.alternatives) == 3;
}

test "distance can outweigh a slightly shorter wait" {
    near_jaffna = find_surgery_hospitals("CATARACT", 9.66, 80.01);
    assert near_jaffna.best.hospital_name.startswith("Jaffna");
    near_colombo = find_surgery_hospitals("CATARACT", 6.93, 79.85);
    assert not near_colombo.best.hospital_name.startswith("Jaffna");
}

test "an unknown surgery is handled" {
    choice = find_surgery_hospitals("NOPE", 6.9, 79.8);
    assert choice.best is None;
    assert "choose" in choice.summary.lower();
}

test "joining a list adds the patient to the queue" {
    choice = find_surgery_hospitals("HERNIA", 6.93, 79.85);
    best = choice.best;
    before = best.waiting;
    joined = join_surgery_list("HERNIA", best.hospital_id, "Nimal Perera");
    assert joined.ok;
    assert joined.position == before + 1;
    assert "Nimal Perera" in joined.message;
    again = find_surgery_hospitals("HERNIA", 6.93, 79.85);
    everyone = [again.best] + again.alternatives;
    now = [o for o in everyone if o.hospital_id == best.hospital_id][0];
    assert now.waiting == before + 1;
    assert not join_surgery_list("HERNIA", best.hospital_id, "   ").ok;
    assert not join_surgery_list("HERNIA", "no-such-hospital", "Nimal").ok;
}

test "hospital staff manage their own lists" {
    token = _token("colombo_central_demo");
    assert token != "";
    lists = my_surgery_lists(token);
    assert len(lists) == 9;
    cataract = [l for l in lists if l.surgery_code == "CATARACT"][0];
    start = cataract.waiting;

    after = change_surgery_waiting(token, "CATARACT", -1);
    assert [l for l in after if l.surgery_code == "CATARACT"][0].waiting == start - 1;
    after = set_surgery_waiting(token, "CATARACT", 0);
    assert [l for l in after if l.surgery_code == "CATARACT"][0].waiting == 0;
    after = change_surgery_waiting(token, "CATARACT", -5);
    assert [l for l in after if l.surgery_code == "CATARACT"][0].waiting == 0;
    after = change_surgery_capacity(token, "CATARACT", -999);
    assert [l for l in after if l.surgery_code == "CATARACT"][0].weekly_capacity == 1;

    after = set_surgery_offered(token, "CATARACT", False);
    assert len(after) == 8;
    after = set_surgery_offered(token, "CATARACT", True);
    assert len(after) == 9;
    assert [l for l in after if l.surgery_code == "CATARACT"][0].waiting == 0;
}

test "bad tokens change nothing" {
    assert my_surgery_lists("bad-token") is None;
    assert change_surgery_waiting("bad-token", "CATARACT", 1) is None;
    assert set_surgery_offered("bad-token", "CATARACT", True) is None;
}

test "reset puts the waiting lists back to the demo numbers" {
    choice = find_surgery_hospitals("KNEE", 6.93, 79.85);
    best = choice.best;
    join_surgery_list("KNEE", best.hospital_id, "Kamala Silva");
    token = _token("colombo_central_demo");
    set_surgery_waiting(token, "KNEE", 5);
    reset_surgery_lists();
    after = find_surgery_hospitals("KNEE", 6.93, 79.85);
    assert after.best.waiting == best.waiting;
    lists = my_surgery_lists(token);
    assert [l for l in lists if l.surgery_code == "KNEE"][0].waiting == 340;
}
