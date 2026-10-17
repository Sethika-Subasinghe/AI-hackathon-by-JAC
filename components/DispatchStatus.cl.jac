"""Critical-case dispatch UI: the 10 second Cancel countdown and the live status panel."""

import "../assets/dispatch.css";
sv import from dispatch { DispatchView, RequestView }

glob COUNTDOWN_TOTAL: float = 10.0;
glob RING_LENGTH: float = 301.6;

glob KIND_LABELS: dict[str, str] = {
    "AMBULANCE": "Ambulance",
    "POLICE": "Police route clearance",
    "HOSPITAL_ALERT": "Hospital pre-alert"
};

def _kind_label(kind: str) -> str {
    return KIND_LABELS.get(kind, kind.title()) as str;
}

def _status_text(status: str) -> str {
    if status == "PENDING" {
        return "Ready, waiting for the countdown";
    }
    if status == "SENT" {
        return "Sent, waiting for a reply";
    }
    if status == "ACCEPTED" {
        return "Accepted";
    }
    if status == "DECLINED" {
        return "Declined";
    }
    if status == "TIMEOUT" {
        return "No answer in time";
    }
    if status == "CANCELLED" {
        return "Cancelled";
    }
    return status.title();
}

"""Red takeover banner with a ring countdown and a large Cancel button."""
def:pub CountdownBanner(seconds_left: float, on_cancel: Callable[[], None]) -> JsxElement {
    def cancel_click(_e: MouseEvent) { on_cancel(); }

    shown: int = int(seconds_left + 0.99);
    fraction: float = max(0.0, min(1.0, seconds_left / COUNTDOWN_TOTAL));
    offset: float = RING_LENGTH * (1.0 - fraction);

    return <section className="countdown-banner" role="alert" aria-live="assertive">
        <div className="cd-ring" aria-hidden="true">
            <svg viewBox="0 0 108 108" width="108" height="108">
                <circle className="cd-track" cx="54" cy="54" r="48"></circle>
                <circle
                    className="cd-progress"
                    cx="54"
                    cy="54"
                    r="48"
                    strokeDasharray={str(RING_LENGTH)}
                    strokeDashoffset={str(offset)}
                ></circle>
            </svg>
            <span className="cd-number">{str(shown)}</span>
        </div>
        <div className="cd-copy">
            <p className="cd-label">Critical case</p>
            <h3>{"Dispatching in " + str(shown) + "…"}</h3>
            <p>An ambulance, police route clearance and a hospital alert are ready. Nothing is sent until this reaches zero.</p>
            <button type="button" className="cd-cancel" onClick={cancel_click}>Cancel dispatch</button>
        </div>
    </section>;
}

def:pub RequestRow(r: RequestView) -> JsxElement {
    return <li className={"ds-row " + r.status.lower()}>
        <div className="ds-main">
            <p className="ds-kind">{_kind_label(r.kind)}</p>
            <p className="ds-target">{r.target}</p>
            <p className="ds-message">{r.message}</p>
        </div>
        <div className="ds-side">
            <span className={"ds-status " + r.status.lower()}>{_status_text(r.status)}</span>
            {if r.simulated {
                <span className="ds-sim">Simulated</span>
            }}
        </div>
    </li>;
}

"""Live status of the ambulance, police and hospital requests, plus earlier attempts."""
def:pub DispatchStatus(dispatch: DispatchView) -> JsxElement {
    percent: int = int(dispatch.ambulance_progress * 100.0);
    has_previous: bool = len(dispatch.previous) > 0;

    return <section className="dispatch-status" aria-label="Dispatch status" aria-live="polite">
        <h3>Help is on the way</h3>
        <p className="ds-note">These actions are simulated for the demo. In a real emergency call 1990.</p>
        <ul className="ds-list">
            {for r in dispatch.requests {
                <RequestRow key={r.id} r={r}/>
            }}
        </ul>
        {if dispatch.case_status == "DISPATCHED" {
            <div className="ds-progress" aria-label={"Ambulance progress " + str(percent) + " percent"}>
                <span className="ds-progress-label">{"Ambulance on its way: " + str(percent) + "%"}</span>
                <div className="ds-bar"><span style={{"width": str(percent) + "%"}}></span></div>
            </div>
        }}
        {if has_previous {
            <details className="ds-previous">
                <summary>Earlier attempts</summary>
                <ul className="ds-list">
                    {for r in dispatch.previous {
                        <RequestRow key={r.id} r={r}/>
                    }}
                </ul>
            </details>
        }}
    </section>;
}
