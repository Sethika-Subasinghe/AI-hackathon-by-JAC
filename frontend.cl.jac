"""CareRoute client shell and responsive landing workspace."""

import "./assets/theme.css";
import "./assets/demo.css";
import from .components.AppHeader { AppHeader }
import from .components.SafetyBanner { SafetyBanner }
import from .components.SystemBanner { SystemBanner }
import from .components.Skeleton { Skeleton }
import from .components.UiKit { AppButton, EmptyState, StatusBadge, SurfaceCard }
import from .components.PatientFlow { PatientFlow }
import from .components.BedCard { BedCard }
import from .components.SurgeryPlanner { SurgeryPlanner }
import from .components.SurgeryLists { SurgeryLists }
import from .components.AlertCard { AlertCard }
import from react { useEffect }
sv import from dispatch { AlertView, hospital_alerts, respond_alert }
import from .components.ClinicWorkspace { ClinicWorkspace }
sv import from hospitals { HospitalView, list_hospitals, hospital_login, hospital_logout, my_hospital, change_free_beds }
sv import from demo { DemoResetResult, reset_demo_data }
import "./assets/design.css";


def:pub app -> JsxElement {
    has active_view: str = "patient",
        hospital_username: str = "",
        hospital_password: str = "",
        hospital_token: str = "",
        hospital: HospitalView | None = None,
        hospital_loading: bool = False,
        hospital_error: str = "",
        hospital_notice: str = "",
        updating_unit: str = "",
        alerts: list[AlertView] = [],
        responding: bool = False,
        demo_reset_version: int = 0,
        resetting_demo: bool = False,
        confirming_demo_reset: bool = False,
        demo_reset_error: str = "",
        demo_reset_message: str = "";

    def select_view(view: str);
    async def submit_hospital_login(e: FormEvent) -> None;
    async def adjust_beds(unit_type: str, delta: int) -> None;
    async def sign_out_hospital() -> None;
    async def refresh_alerts() -> None;
    async def answer_alert(request_id: str, accept: bool) -> None;
    def update_hospital_username(e: ChangeEvent);
    def update_hospital_password(e: ChangeEvent);
    def request_demo_reset(_e: MouseEvent);
    def cancel_demo_reset(_e: MouseEvent);
    async def confirm_demo_reset(_e: MouseEvent) -> None;

    # Look for incoming patients every 2 seconds while a hospital is signed in.
    useEffect(lambda {
        interval = setInterval(lambda { refresh_alerts(); }, 2000);
        return lambda { clearInterval(interval); };
    }, [hospital_token]);

    waiting_alerts: int = len([a for a in alerts if a.status == "SENT"]);
    view_title: str = "Tell us what is happening.";
    view_detail: str = "We find a hospital with free beds and warn it before you arrive.";
    if active_view == "hospital" {
        view_title = "Hospital operations";
        view_detail = "Keep free beds accurate and answer incoming patients.";
    } elif active_view == "surgery" {
        view_title = "Planned surgery";
        view_detail = "See which hospital can operate soonest and join its waiting list.";
    } elif active_view == "clinic" {
        view_title = "Clinic reminders";
        view_detail = "Save your visit once and get reminders in good time.";
    }

    return <div className={"app-shell view-" + active_view}>
        <AppHeader active_view={active_view} on_select={select_view}/>
        <SafetyBanner/>
        <SystemBanner/>

        <main className="main-shell">
            <section className="demo-tools" aria-label="Demo controls">
                <div>
                    <strong>Demo tools</strong>
                    <p>Try the pre-filled scenarios, or clear fictional cases and restore demo capacity.</p>
                </div>
                {if confirming_demo_reset {
                    <div className="demo-tool-actions">
                        <span>Clear cases and clinic profiles, reset beds and simulated time?</span>
                        <button type="button" className="demo-reset-confirm" onClick={confirm_demo_reset} disabled={resetting_demo}>
                            {"Resetting..." if resetting_demo else "Confirm reset"}
                        </button>
                        <button type="button" className="demo-reset-cancel" onClick={cancel_demo_reset} disabled={resetting_demo}>Keep data</button>
                    </div>
                } else {
                    <button type="button" className="demo-reset-button" onClick={request_demo_reset}>Reset demo data</button>
                }}
                {demo_reset_message and <p className="demo-reset-message" role="status">{demo_reset_message}</p>}
                {demo_reset_error and <p className="demo-reset-error" role="alert">{demo_reset_error}</p>}
            </section>

            <section className="intro-band" aria-labelledby="care-route-title">
                <div className="intro-copy">
                    <h1 id="care-route-title">{view_title}</h1>
                    <p>{view_detail}</p>
                </div>
                <ol className="route-steps" aria-label="Your route through CareRoute">
                    <li className="rs-describe"><span className="rs-pin" aria-hidden="true"></span>Describe</li>
                    <li className="rs-locate"><span className="rs-pin" aria-hidden="true"></span>Locate</li>
                    <li className="rs-route"><span className="rs-pin" aria-hidden="true"></span>Route</li>
                </ol>
            </section>

            <section className="workspace-grid" aria-label="CareRoute workspace">
                <div aria-live="polite">
                    <section className="workspace-card">
                        {if active_view == "patient" {
                            <PatientFlow key={str(demo_reset_version)}/>
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
                                        {hospital_loading and <Skeleton count={2} height={96}/>}
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
                                        <section className="ops-alerts" aria-label="Incoming patients" aria-live="assertive">
                                            <h4>Incoming patients {waiting_alerts > 0 and <span className="alert-count">{str(waiting_alerts)}</span>}</h4>
                                            {if len(alerts) == 0 {
                                                <p className="alert-empty">No incoming patients right now. New alerts appear here automatically.</p>
                                            }}
                                            <div className="alert-list">
                                                {for a in alerts[:6] {
                                                    <AlertCard key={a.request_id} alert={a} busy={responding} on_respond={answer_alert}/>
                                                }}
                                            </div>
                                        </section>
                                        <SurgeryLists token={hospital_token}/>
                                    </div>
                                }}
                            </section>
                        } elif active_view == "surgery" {
                            <SurgeryPlanner/>
                        } else {
                            <ClinicWorkspace key={str(demo_reset_version)}/>
                        }}
                    </section>
                </div>

                <aside className="side-stack" aria-label="How CareRoute works">
                    <SurfaceCard eyebrow="" title="What happens next">
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
