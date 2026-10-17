"""Integrity checks for the fictional CareRoute hospital seed data."""


test "dataset includes public and private hospitals" {
    hospitals = hospital_seed_data();
    assert len(hospitals) == 10;
    assert any([hospital.sector == Sector.PUBLIC for hospital in hospitals]);
    assert any([hospital.sector == Sector.PRIVATE for hospital in hospitals]);
}


test "hospital identifiers and usernames are unique" {
    hospitals = hospital_seed_data();
    ids = [hospital.hospital_id for hospital in hospitals];
    usernames = [hospital.username for hospital in hospitals];
    assert len(set(ids)) == len(ids);
    assert len(set(usernames)) == len(usernames);
}


test "all care unit types are represented" {
    hospitals = hospital_seed_data();
    unit_types = {
        unit.unit_type
        for hospital in hospitals
        for unit in hospital.units
    };
    assert unit_types == {
        UnitType.CARDIAC,
        UnitType.TRAUMA,
        UnitType.ICU,
        UnitType.NEURO,
        UnitType.GENERAL,
    };
}


test "coordinates and bed counts are valid" {
    for hospital in hospital_seed_data() {
        assert 5.0 <= hospital.lat <= 10.0;
        assert 79.0 <= hospital.lon <= 82.0;
        assert len(hospital.units) > 0;
        for unit in hospital.units {
            assert unit.total_beds > 0;
            assert 0 <= unit.free_beds <= unit.total_beds;
        }
    }
}


