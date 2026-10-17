"""CareRoute client shell and responsive landing workspace."""

import "./assets/theme.css";
import from .components.AppHeader { AppHeader }
import from .components.SafetyBanner { SafetyBanner }
import from .components.UiKit { AppButton, EmptyState, StatusBadge, SurfaceCard }


def:pub app -> JsxElement {
    has active_view: str = "patient";

    def select_view(view: str);

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
                            <EmptyState
                                icon=">"
                                title="Start with what you know"
                                detail="The guided patient form and location tools arrive in T11."
                            >
                                <AppButton label="Patient intake coming next" disabled={True}/>
                            </EmptyState>
                        } elif active_view == "hospital" {
                            <EmptyState
                                icon="H"
                                title="Capacity at a glance"
                                detail="Hospital login, bed controls, and alerts arrive in T08."
                            >
                                <AppButton label="Hospital dashboard planned" disabled={True}/>
                            </EmptyState>
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
