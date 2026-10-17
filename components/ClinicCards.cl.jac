"""Reusable clinic reminder, notice inbox and phone message cards."""

sv import from clinic { ClinicView, MailView }


def:pub ReminderCard(patient: ClinicView) -> JsxElement {
    return <article className="reminder-card">
        <p className="clinic-eyebrow">Suggested arrival</p>
        <strong>{patient.arrival_tip}</strong>
        <p>Based on the current load at your selected demo hospital.</p>
        <div className="visit-facts">
            <span><small>Clinic</small>{patient.clinic}</span>
            <span><small>Date</small>{patient.clinic_date}</span>
            <span><small>Time</small>{patient.clinic_time}</span>
            <span><small>Message to</small>{"Guardian" if patient.contact_role == "GUARDIAN" else "Patient"}</span>
            <span><small>Reminders</small>Evening before + morning of</span>
        </div>
    </article>;
}


def NoticeItems(items: list[MailView]) -> JsxElement {
    if len(items) == 0 {
        return <p className="clinic-empty">
            No notice is due yet. CareRoute will add one here before the clinic date.
        </p>;
    }
    return <div className="notice-list">
        {for item in items {
            <article key={item.id}>
                <span aria-hidden="true">!</span>
                <div>
                    <strong>{item.subject}</strong>
                    <p>{item.body}</p>
                    <small>Simulated in-app notice</small>
                </div>
            </article>
        }}
    </div>;
}


def:pub NoticeInbox(
    items: list[MailView],
    refreshing: bool,
    on_refresh: Callable[[MouseEvent], None]
) -> JsxElement {
    return <section className="notice-panel" aria-labelledby="clinic-notices-title">
        <div className="clinic-panel-heading">
            <div>
                <p className="clinic-eyebrow">In-app notices</p>
                <h4 id="clinic-notices-title">Reminder inbox</h4>
            </div>
            <button type="button" onClick={on_refresh} disabled={refreshing}>
                {"Refreshing..." if refreshing else "Refresh"}
            </button>
        </div>
        <NoticeItems items={items}/>
    </section>;
}


def:pub MessagePreview(item: MailView | None) -> JsxElement {
    if item is None {
        return <section className="message-preview" aria-labelledby="message-preview-title">
            <div className="message-toolbar">
                <div><span></span><span></span><span></span></div>
                <strong id="message-preview-title">Phone message preview</strong>
                <em>Simulated</em>
            </div>
            <div className="message-empty">
                <strong>Your reminder message will appear here</strong>
                <p>It is prepared for the saved phone number when a reminder becomes due.</p>
            </div>
        </section>;
    }
    return <section className="message-preview" aria-labelledby="message-preview-title">
        <div className="message-toolbar">
            <div><span></span><span></span><span></span></div>
            <strong id="message-preview-title">Phone message preview</strong>
            <em>Simulated</em>
        </div>
        <div className="message-content">
            <dl>
                <div><dt>To</dt><dd>{item.to}</dd></div>
                <div><dt>Subject</dt><dd>{item.subject}</dd></div>
            </dl>
            <p>{item.body}</p>
            <small>Simulated message only - no SMS was sent.</small>
        </div>
    </section>;
}
