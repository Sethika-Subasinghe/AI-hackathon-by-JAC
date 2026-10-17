"""Persistent medical safety notice shown on every CareRoute view."""


def:pub SafetyBanner -> JsxElement {
    return <aside className="safety-banner" role="note" aria-label="Medical safety notice">
        <span className="safety-icon" aria-hidden="true">!</span>
        <p><strong>Not a medical diagnosis.</strong> CareRoute supports urgency and hospital choice only.</p>
        <a href="tel:1990" aria-label="Call 1990 Suwa Seriya ambulance service">In a real emergency, call <strong>1990</strong></a>
    </aside>;
}
