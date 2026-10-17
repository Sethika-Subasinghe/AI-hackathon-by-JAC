"""CareRoute brand header and primary workspace navigation."""


def:pub AppHeader(
    active_view: str,
    on_select: Callable[[str], None],
) -> JsxElement {
    def show_patient(_e: MouseEvent) { on_select("patient"); }
    def show_hospital(_e: MouseEvent) { on_select("hospital"); }
    def show_clinic(_e: MouseEvent) { on_select("clinic"); }

    patient_class: str = "nav-button active" if active_view == "patient" else "nav-button";
    hospital_class: str = "nav-button active" if active_view == "hospital" else "nav-button";
    clinic_class: str = "nav-button active" if active_view == "clinic" else "nav-button";

    return <header className="app-header">
        <a className="brand" href="#care-route-title" aria-label="CareRoute home">
            <span className="brand-mark" aria-hidden="true"><span className="brand-loop"></span><span className="brand-plus">+</span></span>
            <span><strong>Care</strong>Route<small>Coordinated care, clearly.</small></span>
        </a>
        <nav className="primary-nav" aria-label="Primary navigation">
            <button type="button" className={patient_class} aria-pressed={active_view == "patient"} onClick={show_patient}>
                Patient
            </button>
            <button type="button" className={hospital_class} aria-pressed={active_view == "hospital"} onClick={show_hospital}>
                Hospital
            </button>
            <button type="button" className={clinic_class} aria-pressed={active_view == "clinic"} onClick={show_clinic}>
                Clinic
            </button>
        </nav>
        <div className="system-state" title="Demo services are simulated">
            <span aria-hidden="true"></span> Demo online
        </div>
    </header>;
}
