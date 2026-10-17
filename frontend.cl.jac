"""CareRoute client shell and responsive landing workspace."""

import "./assets/theme.css";
import from .components.AppHeader { AppHeader }
import from .components.SafetyBanner { SafetyBanner }
import from .components.UiKit { AppButton, EmptyState, StatusBadge, SurfaceCard }
import from .components.PatientFlow { PatientFlow }
import from .components.BedCard { BedCard }
sv import from hospitals { HospitalView, list_hospitals, hospital_login, hospital_logout, my_hospital, change_free_beds }


def:pub app -> JsxElement {
    has active_view: str = "patient",
        hospital_username: str = "",
        hospital_password: str = "",
        hospital_token: str = "",
        hospital: HospitalView | None = None,
        hospital_loading: bool = False,
        hospital_error: str = "",
        hospital_notice: str = "",
        updating_unit: str = "";

    def select_view(view: str);
    async def submit_hospital_login(e: FormEvent) -> None;
    async def adjust_beds(unit_type: str, delta: int) -> None;
    async def sign_out_hospital() -> None;
    def update_hospital_username(e: ChangeEvent);
    def update_hospital_password(e: ChangeEvent);

    view_title: str = "Patient care";
    view_detail: str = "Describe what is happening and CareRoute will coordinate the next safe step.";
    if active_view == "hospital" {
        view_title = "Hospital operations";
        view_detail = "Update capacity and respond to incoming patient alerts from one calm workspace.";
    } elif active_view == "clinic" {
        view_title = "Clinic reminders";
        view_detail = "Save a clinic visit and preview timely in-app and email reminders.";
    }

    return <div className="app-shell">
        <AppHeader active_view={active_view} on_select={select_view}/>
        <SafetyBanner/>

        <main className="main-shell">
            <section className="hero" aria-labelledby="care-route-title">
                <div className="hero-copy">
                    <StatusBadge label="Agent-assisted care routing" tone="teal"/>
                    <h1 id="care-route-title">The right care route, when every minute matters.</h1>
                    <p>
                        CareRoute helps families find suitable hospitals with available beds,
                        while keeping the people coordinating care in the loop.
                    </p>
                    <div className="trust-row" aria-label="CareRoute capabilities">
                        <span><strong>24/7</strong> guidance</span>
                        <span><strong>Live</strong> capacity</span>
                        <span><strong>Visible</strong> agent steps</span>
                    </div>
                </div>
                <div className="hero-orbit" aria-hidden="true">
                    <div className="orbit-ring orbit-ring-large"></div>
                    <div className="orbit-ring orbit-ring-small"></div>
                    <div className="orbit-core"><span>+</span></div>
                    <span className="orbit-node node-one">01</span>
                    <span className="orbit-node node-two">02</span>
                    <span className="orbit-node node-three">03</span>
                </div>
            </section>

            <section className="workspace-grid" aria-label="CareRoute workspace">
                <div aria-live="polite">
                    <SurfaceCard eyebrow="Your workspace" title={view_title} accent={True}>
                        <p className="workspace-detail">{view_detail}</p>
                        {if active_view == "patient" {
                            <PatientFlow/>
                        } elif active_view == "hospital" {
                            <section className="hospital-ops" aria-label="Hospital operations dashboard">
                                {if hospital is None {
                                    <div className="ops-login">
                                        <div className="ops-icon" aria-hidden="true">+</div>
                                        <div>
                                            <h3>Staff sign in</h3>
                                            <p>Use your demo hospital account to update live capacity.</p>
                                        </div>
                                        <form className="ops-form" onSubmit={submit_hospital_login}>
                                            <label for="hospital-username">Username</label>
                                            <input id="hospital-username" type="text" autoComplete="username" value={hospital_username} onChange={update_hospital_username} placeholder="e.g. colombo_central_demo" required={True}/>
                                            <label for="hospital-password">Password</label>
                                            <input id="hospital-password" type="password" autoComplete="current-password" value={hospital_password} onChange={update_hospital_password} placeholder="Demo password" required={True}/>
                                            {hospital_error and <p className="ops-error" role="alert">{hospital_error}</p>}
                                            <button type="submit" className="app-button" disabled={hospital_loading}>
                                                {"Signing in..." if hospital_loading else "Open capacity dashboard"}
                                            </button>
                                        </form>
                                        <p className="ops-help">Demo only: credentials are provided by the event team. No real hospital data is used.</p>
                                    </div>
                                } else {
                                    <div className="ops-dashboard">
                                        <div className="ops-heading">
                                            <div>
                                                <StatusBadge label="Authenticated staff session" tone="teal"/>
                                                <h3>{hospital.name}</h3>
                                                <p>{hospital.city + " · " + hospital.sector.title() + " demo hospital"}</p>
                                            </div>
                                            <button type="button" className="ops-signout" onClick={sign_out_hospital}>Sign out</button>
                                        </div>
                                        <div className="ops-summary">
                                            <strong>Live capacity</strong>
                                            <span>Update free beds as arrivals and discharges are confirmed.</span>
                                        </div>
                                        {hospital_notice and <p className="ops-success" aria-live="polite">{hospital_notice}</p>}
                                        <div className="bed-grid" aria-live="polite">
                                            {for unit in hospital.units {
                                                <BedCard key={unit.unit_type} unit={unit} busy={updating_unit != ""} on_adjust={adjust_beds}/>
                                            }}
                                        </div>
                                    </div>
                                }}
                            </section>
                        } else {
                            <EmptyState
                                icon="C"
                                title="Never miss a clinic date"
                                detail="Clinic profiles and reminder previews arrive in T23."
                            >
                                <AppButton label="Clinic reminders planned" disabled={True}/>
                            </EmptyState>
                        }}
                    </SurfaceCard>
                </div>

                <aside className="side-stack" aria-label="How CareRoute works">
                    <SurfaceCard eyebrow="What happens next" title="A clear, visible hand-off">
                        <ol className="step-list">
                            <li><span>1</span><div><strong>Describe</strong><p>Share the concern in everyday language.</p></div></li>
                            <li><span>2</span><div><strong>Locate</strong><p>Compare suitable hospitals and live capacity.</p></div></li>
                            <li><span>3</span><div><strong>Route</strong><p>See the recommendation and every agent step.</p></div></li>
                        </ol>
                    </SurfaceCard>
                    <div className="confidence-card">
                        <div className="confidence-icon" aria-hidden="true">OK</div>
                        <div>
                            <strong>Designed for calm decisions</strong>
                            <p>Fake demo data only. Simulated actions will always be labelled.</p>
                        </div>
                    </div>
                </aside>
            </section>
        </main>

        <footer className="app-footer">
            <span>CareRoute - Jac AI Hackathon 2026</span>
            <span>English - Sri Lanka</span>
        </footer>
    </div>;
}
