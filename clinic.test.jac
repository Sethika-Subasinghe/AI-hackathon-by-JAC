"""Tests for clinic.jac. The model is off, so phone messages use the template."""

import from hospitals { list_hospitals }

def _setup() {
    LIVE_MODEL["on"] = False;
    SIM["offset_hours"] = 0.0;
}

def _date_in_days(days: int) -> str {
    return datetime.fromtimestamp(time.time() + float(days) * 86400.0).strftime("%Y-%m-%d");
}

test "invalid input is rejected with a friendly message" {
    _setup();
    bad_phone = save_clinic_patient("Nimal", "123", "PATIENT", "Diabetes clinic", "x", _date_in_days(3), "09:00");
    assert not bad_phone.ok;
    bad_role = save_clinic_patient("Nimal", "0771234567", "OTHER", "Diabetes clinic", "x", _date_in_days(3), "09:00");
    assert not bad_role.ok;
    bad_date = save_clinic_patient("Nimal", "0771234567", "PATIENT", "Diabetes clinic", "x", "next week", "09:00");
    assert not bad_date.ok;
    bad_time = save_clinic_patient("Nimal", "0771234567", "PATIENT", "Diabetes clinic", "x", _date_in_days(3), "morning");
    assert not bad_time.ok;
}

test "reminders arrive as the demo clock moves forward" {
    _setup();
    hospital = list_hospitals()[0];
    res = save_clinic_patient("Nimal", "0771234567", "GUARDIAN", "Diabetes clinic", hospital.id, _date_in_days(3), "09:30");
    assert res.ok;
    assert res.patient is not None;
    assert "AM" in res.patient.arrival_tip;
    assert res.patient.phone == "0771234567";
    assert res.patient.contact_role == "GUARDIAN";
    assert res.patient.clinic_time == "09:30";
    pid = res.patient.id;
    assert len(clinic_inbox(pid)) == 0;

    # Jump to the evening before the visit: one reminder (notice + phone message).
    sent = skip_time(24.0 * 2.0 + 20.0);
    assert sent >= 1;
    inbox = clinic_inbox(pid);
    channels = [m.channel for m in inbox];
    assert "SMS" in channels and "NOTICE" in channels;
    message = [m for m in inbox if m.channel == "SMS"][0];
    assert message.to == "0771234567";
    assert "Diabetes clinic" in message.subject;
    assert "09:30" in message.body;
    assert message.simulated;

    # Jump past the morning of the visit: the second reminder, never repeated.
    skip_time(24.0);
    assert len([m for m in clinic_inbox(pid) if m.channel == "SMS"]) == 2;
    skip_time(24.0);
    assert len([m for m in clinic_inbox(pid) if m.channel == "SMS"]) == 2;
}

test "a visit tomorrow gets its evening reminder once the day moves on" {
    _setup();
    hospital = list_hospitals()[0];
    res = save_clinic_patient("Kamala", "+94771234567", "PATIENT", "Eye clinic", hospital.id, _date_in_days(1), "14:15");
    assert res.ok;
    skip_time(24.0);
    assert len(clinic_inbox(res.patient.id)) >= 2;
}

test "unknown patient has no profile or inbox" {
    _setup();
    assert get_clinic_patient("nope") is None;
    assert clinic_inbox("nope") == [];
}

test "busier hospitals get an earlier arrival time" {
    assert suggest_arrival(0.9, "09:00").startswith("8:00");
    assert suggest_arrival(0.5, "09:00").startswith("8:30");
    assert suggest_arrival(0.1, "09:00").startswith("8:45");
}
