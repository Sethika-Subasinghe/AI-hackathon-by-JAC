"""Clinic visit form, reminder card and simulated inbox (T23)."""

import "./ClinicWorkspace.css";
import from .UiKit { StatusBadge }
import from .ClinicCards { EmailPreview, NoticeInbox, ReminderCard }
sv import from hospitals { HospitalView, list_hospitals }
sv import from clinic {
    ClinicView, MailView,
    save_clinic_patient, clinic_inbox, skip_time, demo_clinic_date
}

def:pub ClinicWorkspace -> JsxElement {
    has hospitals: list[HospitalView] = [],
        name: str = "",
        email: str = "",
        clinic_name: str = "",
        hospital_id: str = "",
        clinic_date: str = "",
        condition_note: str = "",
        patient: ClinicView | None = None,
        inbox_items: list[MailView] = [],
        loading_hospitals: bool = True,
        saving: bool = False,
        loading_demo: bool = False,
        refreshing: bool = False,
        skipping_time: bool = False,
        error: str = "",
        notice: str = "";

    async can with entry {
        try {
            loaded_hospitals = await list_hospitals();
            hospitals = loaded_hospitals;
            if len(loaded_hospitals) > 0 {
                hospital_id = loaded_hospitals[0].id;
            } else {
                error = "No demo hospitals are available right now.";
            }
        } except Exception {
            error = "Could not load demo hospitals. Please try the Clinic tab again.";
        }
        loading_hospitals = False;
    }

    def update_name(e: ChangeEvent) { name = e.target.value; }
    def update_email(e: ChangeEvent) { email = e.target.value; }
    def update_clinic_name(e: ChangeEvent) { clinic_name = e.target.value; }
    def update_hospital(e: ChangeEvent) { hospital_id = e.target.value; }
    def update_clinic_date(e: ChangeEvent) { clinic_date = e.target.value; }
    def update_condition_note(e: ChangeEvent) { condition_note = e.target.value; }

    async def submit_visit(e: FormEvent) {
        e.preventDefault();
        error = "";
        notice = "";
        saving = True;
        try {
            result = await save_clinic_patient(
                name,
                email,
                clinic_name,
                hospital_id,
                clinic_date,
                condition_note
            );
            if result.ok and result.patient is not None {
                patient = result.patient;
                inbox_items = await clinic_inbox(result.patient.id);
                notice = result.message;
            } else {
                error = result.message;
            }
        } except Exception as err {
            error = "Could not save this clinic visit: " + str(err);
        }
        saving = False;
    }

    async def refresh_inbox(_e: MouseEvent) -> None {
        if patient is None { return; }
        refreshing = True;
        error = "";
        try {
            inbox_items = await clinic_inbox(patient.id);
            notice = "Reminder inbox refreshed.";
        } except Exception as err {
            error = "Could not refresh reminders: " + str(err);
        }
        refreshing = False;
    }

    async def skip_demo_time(_e: MouseEvent) -> None {
        if patient is None { return; }
        error = "";
        skipping_time = True;
        try {
            delivered = await skip_time(24.0);
            inbox_items = await clinic_inbox(patient.id);
            skipping_time = False;
            notice = "Advanced the demo clock by 24 hours. " + str(delivered) + " reminders delivered.";
        } except Exception as err {
            skipping_time = False;
            error = "Could not advance the demo clock: " + str(err);
        }
    }

    async def load_demo_visit(_e: MouseEvent) -> None {
        if len(hospitals) == 0 { return; }
        loading_demo = True;
        error = "";
        try {
            demo_date = await demo_clinic_date();
            name = "Nimal Perera";
            email = "nimal.demo@example.com";
            clinic_name = "Cardiology clinic";
            hospital_id = hospitals[0].id;
            clinic_date = demo_date;
            condition_note = "Routine follow-up visit";
            notice = "Clinic demo details loaded. Save the visit, then skip 24 hours to show reminders.";
        } except Exception as err {
            error = "Could not load clinic demo: " + str(err);
        }
        loading_demo = False;
    }

    def start_another(_e: MouseEvent) {
        patient = None;
        inbox_items = [];
        name = "";
        email = "";
        clinic_name = "";
        clinic_date = "";
        condition_note = "";
        error = "";
        notice = "";
    }

    email_items = [item for item in inbox_items if item.channel == "EMAIL"];
    notice_items = [item for item in inbox_items if item.channel == "NOTICE"];
    latest_email: MailView | None = email_items[0] if len(email_items) > 0 else None;

    return <section className="clinic-workspace" aria-label="Clinic reminder workspace">
        {if patient is None {
            <div className="clinic-layout clinic-form-layout">
                <div className="clinic-intro">
                    <StatusBadge label="Private clinic profile" tone="teal"/>
                    <h3>Plan your next clinic visit</h3>
                    <p>Save the visit once. CareRoute will suggest when to arrive and prepare two simulated reminders.</p>
                    <ul>
                        <li><span>1</span> Evening-before reminder</li>
                        <li><span>2</span> Morning-of reminder</li>
                        <li><span>3</span> In-app notice and mock email</li>
                    </ul>
                </div>

                <form className="clinic-form" onSubmit={submit_visit}>
                    <button type="button" className="clinic-demo-button" onClick={load_demo_visit} disabled={loading_hospitals or saving or loading_demo}>
                        {"Loading..." if loading_demo else "Load clinic demo"}
                    </button>
                    {notice and <p className="clinic-message success" role="status">{notice}</p>}
                    <div className="clinic-field-grid">
                        <label>
                            <span>Your name</span>
                            <input type="text" value={name} onChange={update_name} autoComplete="name" placeholder="e.g. Nimal Perera" required={True}/>
                        </label>
                        <label>
                            <span>Email address</span>
                            <input type="email" value={email} onChange={update_email} autoComplete="email" placeholder="nimal@example.com" required={True}/>
                        </label>
                    </div>
                    <label>
                        <span>Clinic</span>
                        <input type="text" value={clinic_name} onChange={update_clinic_name} placeholder="e.g. Diabetes clinic" required={True}/>
                    </label>
                    <div className="clinic-field-grid">
                        <label>
                            <span>Hospital</span>
                            <select value={hospital_id} onChange={update_hospital} disabled={loading_hospitals} required={True}>
                                {if loading_hospitals {
                                    <option value="">Loading demo hospitals...</option>
                                } elif len(hospitals) == 0 {
                                    <option value="">No hospitals available</option>
                                } else {
                                    <>{for hospital in hospitals {
                                        <option value={hospital.id} key={hospital.id}>{hospital.name + " - " + hospital.city}</option>
                                    }}</>
                                }}
                            </select>
                        </label>
                        <label>
                            <span>Clinic date</span>
                            <input type="date" value={clinic_date} onChange={update_clinic_date} required={True}/>
                        </label>
                    </div>
                    <label>
                        <span>Condition note <small>optional</small></span>
                        <textarea value={condition_note} onChange={update_condition_note} rows={3} placeholder="A short note to help identify this visit"></textarea>
                    </label>
                    {error and <p className="clinic-message error" role="alert">{error}</p>}
                    <button type="submit" className="app-button clinic-submit" disabled={saving or loading_hospitals or hospital_id == ""}>
                        {"Saving clinic visit..." if saving else "Save visit and plan reminders"}
                    </button>
                    <p className="clinic-privacy">Saved only in this CareRoute demo. Mock emails never leave the app.</p>
                </form>
            </div>
        } else {
            <div className="clinic-saved">
                <div className="clinic-saved-heading">
                    <div>
                        <StatusBadge label="Visit saved" tone="teal"/>
                        <h3>{patient.clinic}</h3>
                        <p>{patient.name + " - " + patient.clinic_date}</p>
                    </div>
                    <div className="clinic-actions">
                        <button type="button" className="clinic-time-button" onClick={skip_demo_time} disabled={skipping_time}>
                            {"Advancing..." if skipping_time else "Skip 24 hours"}
                        </button>
                        <button type="button" className="clinic-text-button" onClick={start_another}>Add another visit</button>
                    </div>
                </div>

                {error and <p className="clinic-message error" role="alert">{error}</p>}
                {notice and <p className="clinic-message success" aria-live="polite">{notice}</p>}

                <div className="clinic-result-grid">
                    <ReminderCard patient={patient}/>
                    <NoticeInbox items={notice_items} refreshing={refreshing} on_refresh={refresh_inbox}/>
                </div>
                <EmailPreview item={latest_email}/>
            </div>
        }}
    </section>;
}
