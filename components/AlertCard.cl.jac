"""Incoming patient alert for hospital staff, with Accept and Decline."""

import "../assets/alerts.css";
sv import from dispatch { AlertView }

def _clock(ts: float) -> str {
    when: any = new(Date, ts * 1000);  # jac:ignore[E1053]
    return when.toLocaleTimeString() as str;
}

def _eta_text(eta: float) -> str {
    if eta < 1.0 {
        return "under 1 min away";
    }
    return "about " + str(int(eta + 0.5)) + " min away";
}

def:pub AlertCard(
    alert: AlertView,
    busy: bool,
    on_respond: Callable[[str, bool], None],
) -> JsxElement {
    # Named handlers: a lambda inside a list slot compiles to a render-time call.
    def accept_click(_e: MouseEvent) { on_respond(alert.request_id, True); }
    def decline_click(_e: MouseEvent) { on_respond(alert.request_id, False); }

    waiting: bool = alert.status == "SENT";
    status_label: str = "Waiting for you";
    if alert.status == "ACCEPTED" {
        status_label = "You accepted";
    } elif alert.status == "DECLINED" {
        status_label = "You declined";
    } elif alert.status == "TIMEOUT" {
        status_label = "No answer in time";
    }

    return <article className={"alert-card " + alert.status.lower()} aria-label={"Incoming patient, " + alert.severity.lower()}>
        <div className="alert-top">
            <span className="alert-severity"><span aria-hidden="true">!</span> {alert.severity.title()}</span>
            <span className="alert-status">{status_label}</span>
        </div>
        <p className="alert-line">
            <strong>{alert.unit.title() + " care needed"}</strong>
            {" · " + _eta_text(alert.eta_minutes)}
        </p>
        <p className="alert-message">{alert.message}</p>
        <p className="alert-meta">{"Received " + _clock(alert.created_at)}<span className="alert-sim">Simulated</span></p>
        {if waiting {
            <div className="alert-actions">
                <button type="button" className="alert-accept" onClick={accept_click} disabled={busy}>Accept patient</button>
                <button type="button" className="alert-decline" onClick={decline_click} disabled={busy}>Decline</button>
            </div>
        }}
    </article>;
}
