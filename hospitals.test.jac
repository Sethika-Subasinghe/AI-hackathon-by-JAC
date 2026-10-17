"""Tests for hospitals.jac (annex)."""

test "login, list and bed updates" {
    add_hospital(
        "Test General", Sector.PUBLIC, "Colombo", 6.9, 79.8,
        "t_staff", "pw123", {"ICU": 4, "CARDIAC": 2}
    );
    mine = [h for h in list_hospitals() if h.name == "Test General"];
    assert len(mine) == 1;
    assert len(mine[0].units) == 2;

    bad = hospital_login("t_staff", "nope");
    assert not bad.ok;
    good = hospital_login("t_staff", "pw123");
    assert good.ok;

    assert set_free_beds("bad-token", "ICU", 1) is None;

    view = set_free_beds(good.token, "ICU", 1);
    assert view is not None;
    icu = [u for u in view.units if u.unit_type == "ICU"];
    assert icu[0].free == 1;

    view = change_free_beds(good.token, "ICU", -5);
    icu = [u for u in view.units if u.unit_type == "ICU"];
    assert icu[0].free == 0;

    view = change_free_beds(good.token, "ICU", 99);
    icu = [u for u in view.units if u.unit_type == "ICU"];
    assert icu[0].free == 4;

    assert hospital_logout(good.token);
    assert my_hospital(good.token) is None;
}

test "demo hospitals seed once with initial free beds" {
    first = list_hospitals();
    second = list_hospitals();
    seeded = [hospital for hospital in second if hospital.name.endswith("(Demo)")];
    assert len(seeded) == 10;
    assert len(first) == len(second);
    colombo = [
        hospital
        for hospital in seeded
        if hospital.name == "Colombo Central Care Hospital (Demo)"
    ][0];
    icu = [unit for unit in colombo.units if unit.unit_type == "ICU"][0];
    assert icu.total == 18;
    assert icu.free == 3;
}
