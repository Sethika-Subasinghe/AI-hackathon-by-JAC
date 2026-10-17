"""CareRoute - Clinic Reminder Agent (T22).

A clinic patient or guardian saves the clinic date, time and phone number. The agent:
1. looks at how busy the hospital is and suggests an arrival time,
2. schedules two reminders (evening before, morning of),
3. delivers each one as an in-app notice and a simulated phone message,
   with the message text written by the model (a template if the model fails).

Time is simulated so the demo can jump ahead: `skip_time(hours)` moves the
clock and delivers whatever became due. Phone messages are simulated; nothing leaves the app.
"""

import time;
import from datetime { datetime, timedelta }
import from models { ClinicPatient, MailItem, ReminderTask }
import from graph_lock { GRAPH_LOCK }
import from hospitals { get_hospital }
import from reliability { model_available, record_model_success, record_model_failure }

glob SIM: dict[str, float] = {"offset_hours": 0.0};
glob LIVE_MODEL: dict[str, bool] = {"on": True};

"""A short reminder message for the saved phone number."""
obj MessageDraft {
    has subject: str,
        body: str;
}
sem MessageDraft.subject = "A short friendly title mentioning the clinic.";
sem MessageDraft.body = "A concise phone message with the clinic, appointment date and time, suggested arrival time and one calm tip. No medical advice or diagnosis.";

"""A clinic patient as sent to the UI."""
obj ClinicView {
    has id: str,
        name: str,
        phone: str,
        contact_role: str,
        clinic: str,
        hospital_id: str,
        clinic_date: str,
        clinic_time: str,
        condition_note: str,
        arrival_tip: str;
}

"""Result of saving a clinic patient."""
obj ClinicResult {
    has ok: bool,
        message: str = "",
        patient: ClinicView | None = None;
}

"""One inbox item (simulated phone message or in-app notice)."""
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

"""Busier hospitals mean arriving earlier for the saved clinic time."""
def suggest_arrival(load: float, clinic_time: str = "09:00") -> str {
    minutes_early = 15;
    if load >= 0.7 {
        minutes_early = 60;
    } elif load >= 0.4 {
        minutes_early = 30;
    }
    try {
        appointment = datetime.strptime(clinic_time, "%H:%M");
        arrival = (appointment - timedelta(minutes=minutes_early)).strftime("%I:%M %p").lstrip("0");
    } except Exception {
        arrival = clinic_time;
    }
    if load >= 0.7 {
        return f"{arrival} (arrive {minutes_early} min early; the hospital is busy)";
    }
    return f"{arrival} (arrive {minutes_early} min early)";
}

def _template_message(name: str, clinic: str, date: str, clinic_time: str, arrival: str, when: str) -> MessageDraft {
    return MessageDraft(
        subject=f"Reminder: {clinic} {when}",
        body=f"Hello {name}, your {clinic} visit is {when}, {date} at {clinic_time}. Suggested arrival: {arrival}. Please bring your clinic book and recent reports."
    );
}

def compose_reminder(facts: str) -> MessageDraft by llm(temperature=0.3);
sem compose_reminder = "Write a short friendly phone reminder for a clinic visit. Calm tone, no medical advice.";
sem compose_reminder.facts = "Patient name, clinic, appointment date and time, suggested arrival time and which reminder this is.";

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
        phone=p.phone,
        contact_role=p.contact_role,
        clinic=p.clinic,
        hospital_id=p.hospital_id,
        clinic_date=p.clinic_date,
        clinic_time=p.clinic_time,
        condition_note=p.condition_note,
        arrival_tip=suggest_arrival(get_hospital_load(p.hospital_id), p.clinic_time)
    );
}

def _day_start(date: str) -> float {
    return datetime.strptime(date, "%Y-%m-%d").timestamp();
}

def _appointment_time(date: str, clinic_time: str) -> float {
    return datetime.strptime(date + " " + clinic_time, "%Y-%m-%d %H:%M").timestamp();
}

def _valid_phone(phone: str) -> bool {
    digits = "".join([char for char in phone if char.isdigit()]);
    return (len(digits) == 10 and digits.startswith("0")) or (len(digits) == 11 and digits.startswith("94"));
}

"""Save a clinic patient, schedule two reminders and deliver any that are already due."""
def:pub save_clinic_patient(
    name: str,
    phone: str,
    contact_role: str,
    clinic: str,
    hospital_id: str,
    clinic_date: str,
    clinic_time: str,
    condition_note: str = ""
) -> ClinicResult {
    if name.strip() == "" or not _valid_phone(phone) {
        return ClinicResult(ok=False, message="Please enter the patient's name and a valid Sri Lankan phone number.");
    }
    if contact_role not in ["PATIENT", "GUARDIAN"] {
        return ClinicResult(ok=False, message="Please say whether this number belongs to the patient or guardian.");
    }
    if clinic.strip() == "" or hospital_id == "" {
        return ClinicResult(ok=False, message="Please choose the clinic and hospital.");
    }
    try {
        day = _day_start(clinic_date);
        appointment = _appointment_time(clinic_date, clinic_time);
    } except Exception {
        return ClinicResult(ok=False, message="Please enter a valid clinic date and time.");
    }
    with GRAPH_LOCK {
        p = (root.shared ++> ClinicPatient(
            name=name.strip(),
            phone=phone.strip(),
            contact_role=contact_role,
            clinic=clinic.strip(),
            hospital_id=hospital_id,
            clinic_date=clinic_date,
            clinic_time=clinic_time,
            condition_note=condition_note
        ))[0];
        # Evening before at 6 PM, then two hours before the clinic time.
        root.shared ++> ReminderTask(patient_id=jid(p), kind="DAY_BEFORE", due_at=day - 6.0 * 3600.0);
        root.shared ++> ReminderTask(patient_id=jid(p), kind="MORNING_OF", due_at=appointment - 2.0 * 3600.0);
        _deliver_due();
    }
    return ClinicResult(ok=True, message="Saved. We will remind you before your visit.", patient=_view(p));
}

def _deliver(task: ReminderTask, p: ClinicPatient) {
    arrival = suggest_arrival(get_hospital_load(p.hospital_id), p.clinic_time);
    when = "tomorrow" if task.kind == "DAY_BEFORE" else "today";
    draft = _template_message(p.name, p.clinic, p.clinic_date, p.clinic_time, arrival, when);
    if LIVE_MODEL["on"] and model_available() {
        try {
            draft = compose_reminder(
                f"Patient {p.name}. Clinic {p.clinic} on {p.clinic_date} at {p.clinic_time}, which is {when}. Suggested arrival {arrival}."
            );
            record_model_success();
        } except Exception as err {
            record_model_failure(str(err));
            draft = _template_message(p.name, p.clinic, p.clinic_date, p.clinic_time, arrival, when);
        }
    }
    now = _now();
    root.shared ++> MailItem(
        patient_id=jid(p),
        channel="NOTICE",
        to=p.name,
        subject=f"Clinic visit {when}",
        body=f"{p.clinic} on {p.clinic_date} at {p.clinic_time}. Suggested arrival: {arrival}.",
        sent_at=now
    );
    root.shared ++> MailItem(
        patient_id=jid(p),
        channel="SMS",
        to=p.phone,
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

"""The patient's inbox (simulated phone messages and in-app notices), newest first."""
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
