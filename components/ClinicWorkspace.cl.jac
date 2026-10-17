"""Clinic visit form, reminder card and simulated inbox (T23)."""

import "./ClinicWorkspace.css";
import from .UiKit { StatusBadge }
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
        loaded_hospitals = await list_hospitals();
        hospitals = loaded_hospitals;
        if len(loaded_hospitals) > 0 {
            hospital_id = loaded_hospitals[0].id;
        }
        loading_hospitals = False;
    }

    async def submit_visit(e: FormEvent) {
        e.preventDefault();
        error = "";
        notice = "";
        saving = True;
        result = await save_clinic_patient(
            name,
            email,
            clinic_name,
            hospital_id,
            clinic_date,
            condition_note
        );
        saving = False;
        if result.ok and result.patient is not None {
            patient = result.patient;
            inbox_items = await clinic_inbox(result.patient.id);
            notice = result.message;
        } else {
            error = result.message;
        }
    }

    async def refresh_inbox(_e: MouseEvent) -> None {
        if patient is None { return; }
        refreshing = True;
        inbox_items = await clinic_inbox(patient.id);
        refreshing = False;
        notice = "Reminder inbox refreshed.";
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
                            <input type="text" value={name} onChange={lambda e: ChangeEvent { name = e.target.value; }} autoComplete="name" placeholder="e.g. Nimal Perera" required={True}/>
                        </label>
                        <label>
                            <span>Email address</span>
                            <input type="email" value={email} onChange={lambda e: ChangeEvent { email = e.target.value; }} autoComplete="email" placeholder="nimal@example.com" required={True}/>
                        </label>
                    </div>
                    <label>
                        <span>Clinic</span>
                        <input type="text" value={clinic_name} onChange={lambda e: ChangeEvent { clinic_name = e.target.value; }} placeholder="e.g. Diabetes clinic" required={True}/>
                    </label>
                    <div className="clinic-field-grid">
                        <label>
                            <span>Hospital</span>
                            <select value={hospital_id} onChange={lambda e: ChangeEvent { hospital_id = e.target.value; }} disabled={loading_hospitals} required={True}>
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
                            <input type="date" value={clinic_date} onChange={lambda e: ChangeEvent { clinic_date = e.target.value; }} required={True}/>
                        </label>
                    </div>
                    <label>
                        <span>Condition note <small>optional</small></span>
                        <textarea value={condition_note} onChange={lambda e: ChangeEvent { condition_note = e.target.value; }} rows={3} placeholder="A short note to help identify this visit"></textarea>
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
                    <article className="reminder-card">
                        <p className="clinic-eyebrow">Suggested arrival</p>
                        <strong>{patient.arrival_tip}</strong>
                        <p>Based on the current load at your selected demo hospital.</p>
                        <div className="visit-facts">
                            <span><small>Clinic</small>{patient.clinic}</span>
                            <span><small>Date</small>{patient.clinic_date}</span>
                            <span><small>Reminders</small>Evening before + morning of</span>
                        </div>
                    </article>

                    <section className="notice-panel" aria-labelledby="clinic-notices-title">
                        <div className="clinic-panel-heading">
                            <div><p className="clinic-eyebrow">In-app notices</p><h4 id="clinic-notices-title">Reminder inbox</h4></div>
                            <button type="button" onClick={refresh_inbox} disabled={refreshing}>{"Refreshing..." if refreshing else "Refresh"}</button>
                        </div>
                        {if len(notice_items) == 0 {
                            <p className="clinic-empty">No notice is due yet. CareRoute will add one here before the clinic date.</p>
                        } else {
                            <div className="notice-list">{for item in notice_items {
                                <article key={item.id}>
                                    <span aria-hidden="true">!</span>
                                    <div><strong>{item.subject}</strong><p>{item.body}</p><small>Simulated in-app notice</small></div>
                                </article>
                            }}</div>
                        }}
                    </section>
                </div>

                <section className="email-preview" aria-labelledby="email-preview-title">
                    <div className="email-toolbar">
                        <div><span></span><span></span><span></span></div>
                        <strong id="email-preview-title">Mock email preview</strong>
                        <em>Simulated</em>
                    </div>
                    {if latest_email is None {
                        <div className="email-empty">
                            <strong>Your reminder email will appear here</strong>
                            <p>It is prepared when the evening-before or morning-of reminder becomes due.</p>
                        </div>
                    } else {
                        <div className="email-content">
                            <dl><div><dt>To</dt><dd>{latest_email.to}</dd></div><div><dt>Subject</dt><dd>{latest_email.subject}</dd></div></dl>
                            <p>{latest_email.body}</p>
                            <small>Demo message only - no email was sent.</small>
                        </div>
                    }}
                </section>
            </div>
        }}
    </section>;
}
