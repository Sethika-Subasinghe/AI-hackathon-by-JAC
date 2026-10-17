"""CareRoute - Clinic Reminder Agent (T22).

A clinic patient saves their clinic date. The agent:
1. looks at how busy the hospital is and suggests an arrival time,
2. schedules two reminders (evening before, morning of),
3. delivers each one as an in-app notice and a mock email in the patient's inbox,
   with the email text written by the model (a template if the model fails).

Time is simulated so the demo can jump ahead: `skip_time(hours)` moves the
clock and delivers whatever became due. Emails are mock only, nothing leaves the app.
"""

import time;
import from datetime { datetime, timedelta }
import from models { ClinicPatient, MailItem, ReminderTask }
import from graph_lock { GRAPH_LOCK }
import from hospitals { get_hospital }
import from reliability { model_available, record_model_success, record_model_failure }

glob SIM: dict[str, float] = {"offset_hours": 0.0};
glob LIVE_MODEL: dict[str, bool] = {"on": True};

"""A reminder email."""
obj EmailDraft {
    has subject: str,
        body: str;
}
sem EmailDraft.subject = "A short friendly subject line mentioning the clinic.";
sem EmailDraft.body = "Three or four short sentences: the clinic, the date, the suggested arrival time and one calm tip. No medical advice or diagnosis.";

"""A clinic patient as sent to the UI."""
obj ClinicView {
    has id: str,
        name: str,
        email: str,
        clinic: str,
        hospital_id: str,
        clinic_date: str,
        condition_note: str,
        arrival_tip: str;
}

"""Result of saving a clinic patient."""
obj ClinicResult {
    has ok: bool,
        message: str = "",
        patient: ClinicView | None = None;
}

"""One inbox item (mock email or in-app notice)."""
obj MailView {
    has id: str,
        channel: str,
        to: str,
        subject: str,
        body: str,
        sent_at: float,
        simulated: bool;
}

def _now() -> float {
    return time.time() + SIM["offset_hours"] * 3600.0;
}

"""Share of beds in use at a hospital, 0.0 (quiet) to 1.0 (full)."""
def get_hospital_load(hospital_id: str) -> float {
    h = get_hospital(hospital_id);
    if h is None {
        return 0.5;
    }
    total = 0;
    free = 0;
    for u in h.units {
        total += u.total;
        free += u.free;
    }
    if total == 0 {
        return 0.5;
    }
    return 1.0 - float(free) / float(total);
}

"""Busier hospitals mean arriving earlier."""
def suggest_arrival(load: float) -> str {
    if load >= 0.7 {
        return "7:30 AM (the hospital is busy, come early)";
    }
    if load >= 0.4 {
        return "8:00 AM";
    }
    return "8:30 AM (it is quiet right now)";
}

def _template_email(name: str, clinic: str, date: str, arrival: str, when: str) -> EmailDraft {
    return EmailDraft(
        subject=f"Reminder: {clinic} {when}",
        body=f"Hello {name}, this is a reminder of your visit to {clinic} on {date}. We suggest arriving around {arrival}. Please bring your clinic book and any recent reports."
    );
}

def compose_reminder(facts: str) -> EmailDraft by llm(temperature=0.3);
sem compose_reminder = "Write a short friendly reminder email for a clinic visit. Calm tone, no medical advice.";
sem compose_reminder.facts = "Patient name, clinic, date, suggested arrival time and which reminder this is.";

def _find_patient(patient_id: str) -> ClinicPatient | None {
    for p in [root.shared -->][?:ClinicPatient] {
        if jid(p) == patient_id {
            return p;
        }
    }
    return None;
}

def _view(p: ClinicPatient) -> ClinicView {
    return ClinicView(
        id=jid(p),
        name=p.name,
        email=p.email,
        clinic=p.clinic,
        hospital_id=p.hospital_id,
        clinic_date=p.clinic_date,
        condition_note=p.condition_note,
        arrival_tip=suggest_arrival(get_hospital_load(p.hospital_id))
    );
}

def _day_start(date: str) -> float {
    return datetime.strptime(date, "%Y-%m-%d").timestamp();
}

"""Save a clinic patient, schedule two reminders and deliver any that are already due."""
def:pub save_clinic_patient(
    name: str,
    email: str,
    clinic: str,
    hospital_id: str,
    clinic_date: str,
    condition_note: str = ""
) -> ClinicResult {
    if name.strip() == "" or "@" not in email {
        return ClinicResult(ok=False, message="Please enter your name and a valid email address.");
    }
    try {
        day = _day_start(clinic_date);
    } except Exception {
        return ClinicResult(ok=False, message="Please enter the clinic date as YYYY-MM-DD.");
    }
    with GRAPH_LOCK {
        p = (root.shared ++> ClinicPatient(
            name=name.strip(),
            email=email.strip(),
            clinic=clinic.strip(),
            hospital_id=hospital_id,
            clinic_date=clinic_date,
            condition_note=condition_note
        ))[0];
        # Evening before at 6 PM, morning of at 6:30 AM.
        root.shared ++> ReminderTask(patient_id=jid(p), kind="DAY_BEFORE", due_at=day - 6.0 * 3600.0);
        root.shared ++> ReminderTask(patient_id=jid(p), kind="MORNING_OF", due_at=day + 6.5 * 3600.0);
        _deliver_due();
    }
    return ClinicResult(ok=True, message="Saved. We will remind you before your visit.", patient=_view(p));
}

def _deliver(task: ReminderTask, p: ClinicPatient) {
    arrival = suggest_arrival(get_hospital_load(p.hospital_id));
    when = "tomorrow" if task.kind == "DAY_BEFORE" else "today";
    draft = _template_email(p.name, p.clinic, p.clinic_date, arrival, when);
    if LIVE_MODEL["on"] and model_available() {
        try {
            draft = compose_reminder(
                f"Patient {p.name}. Clinic {p.clinic} on {p.clinic_date}, which is {when}. Suggested arrival {arrival}."
            );
            record_model_success();
        } except Exception as err {
            record_model_failure(str(err));
            draft = _template_email(p.name, p.clinic, p.clinic_date, arrival, when);
        }
    }
    now = _now();
    root.shared ++> MailItem(
        patient_id=jid(p),
        channel="NOTICE",
        to=p.name,
        subject=f"Clinic visit {when}",
        body=f"{p.clinic} on {p.clinic_date}. Suggested arrival: {arrival}.",
        sent_at=now
    );
    root.shared ++> MailItem(
        patient_id=jid(p),
        channel="EMAIL",
        to=p.email,
        subject=draft.subject,
        body=draft.body,
        sent_at=now
    );
    task.sent = True;
}

"""Send every reminder that is due. Returns how many were sent."""
def _deliver_due() -> int {
    sent = 0;
    now = _now();
    for task in [root.shared -->][?:ReminderTask] {
        if (not task.sent) and task.due_at <= now {
            p = _find_patient(task.patient_id);
            if p is not None {
                _deliver(task, p);
                sent += 1;
            } else {
                task.sent = True;
            }
        }
    }
    return sent;
}

"""Demo button: move the clock forward and deliver what became due. Returns reminders sent."""
def:pub skip_time(hours: float) -> int {
    SIM["offset_hours"] += hours;
    return _deliver_due();
}

"""The next calendar day on the simulated clock, for a repeatable clinic demo."""
def:pub demo_clinic_date -> str {
    tomorrow = datetime.fromtimestamp(_now()) + timedelta(days=1);
    return tomorrow.strftime("%Y-%m-%d");
}

"""Reset the simulated clock to real time for a fresh demo."""
def reset_simulated_clock {
    SIM["offset_hours"] = 0.0;
}

"""A clinic patient's saved profile, or None."""
def:pub get_clinic_patient(patient_id: str) -> ClinicView | None {
    p = _find_patient(patient_id);
    if p is None {
        return None;
    }
    return _view(p);
}

"""The patient's inbox (mock emails and in-app notices), newest first."""
def:pub clinic_inbox(patient_id: str) -> list[MailView] {
    _deliver_due();
    items = [
        MailView(
            id=jid(m),
            channel=m.channel,
            to=m.to,
            subject=m.subject,
            body=m.body,
            sent_at=m.sent_at,
            simulated=m.simulated
        )
        for m in [root.shared -->][?:MailItem]
        if m.patient_id == patient_id
    ];
    return sorted(items, key=lambda m: MailView : -m.sent_at);
}
