"""Tests for clinic.jac (annex). The model is off, so emails use the template."""

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
    bad_email = save_clinic_patient("Nimal", "nimal-at-mail", "Diabetes clinic", "x", _date_in_days(3));
    assert not bad_email.ok;
    bad_date = save_clinic_patient("Nimal", "n@mail.com", "Diabetes clinic", "x", "next week");
    assert not bad_date.ok;
    assert "YYYY-MM-DD" in bad_date.message;
}

test "reminders arrive as the demo clock moves forward" {
    _setup();
    hospital = list_hospitals()[0];
    res = save_clinic_patient("Nimal", "nimal@mail.com", "Diabetes clinic", hospital.id, _date_in_days(3));
    assert res.ok;
    assert res.patient is not None;
    assert "AM" in res.patient.arrival_tip;
    pid = res.patient.id;
    assert len(clinic_inbox(pid)) == 0;

    # Jump to the evening before the visit: one reminder (notice + email).
    sent = skip_time(24.0 * 2.0 + 20.0);
    assert sent >= 1;
    inbox = clinic_inbox(pid);
    channels = [m.channel for m in inbox];
    assert "EMAIL" in channels and "NOTICE" in channels;
    email = [m for m in inbox if m.channel == "EMAIL"][0];
    assert email.to == "nimal@mail.com";
    assert "Diabetes clinic" in email.subject;
    assert email.simulated;

    # Jump past the morning of the visit: the second reminder, never repeated.
    skip_time(24.0);
    assert len([m for m in clinic_inbox(pid) if m.channel == "EMAIL"]) == 2;
    skip_time(24.0);
    assert len([m for m in clinic_inbox(pid) if m.channel == "EMAIL"]) == 2;
}

test "a visit tomorrow gets its evening reminder once the day moves on" {
    _setup();
    hospital = list_hospitals()[0];
    res = save_clinic_patient("Kamala", "k@mail.com", "Eye clinic", hospital.id, _date_in_days(1));
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
    assert suggest_arrival(0.9).startswith("7:30");
    assert suggest_arrival(0.5).startswith("8:00");
    assert suggest_arrival(0.1).startswith("8:30");
}
