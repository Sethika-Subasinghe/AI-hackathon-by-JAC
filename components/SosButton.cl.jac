"""One-tap emergency button: shares the phone's location and asks for help, no typing."""

import "../assets/sos.css";

def:pub SosButton(
    busy: bool,
    message: str,
    on_press: Callable[[], None],
) -> JsxElement {
    def press(_e: MouseEvent) { on_press(); }

    return <section className="sos-card" aria-label="Emergency help">
        <button type="button" className="sos-button" onClick={press} disabled={busy}>
            <span className="sos-icon" aria-hidden="true">SOS</span>
            <span className="sos-copy">
                <strong>{"Finding your location…" if busy else "Emergency: get help now"}</strong>
                <small>One tap. We use your location, find the nearest hospital with a free bed and alert an ambulance and the police to clear the road.</small>
            </span>
        </button>
        {message and <p className="sos-message" role="alert">{message}</p>}
        <p className="sos-note">Simulated for the demo. In a real emergency also call <a href="tel:1990">1990</a>. You get a few seconds to cancel if you tapped by mistake.</p>
    </section>;
}
