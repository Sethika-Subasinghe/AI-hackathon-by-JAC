"""CareRoute patient workspace: intake form, then the live status of the case.

Stateful shell: all state and handlers live here (bodies in PatientFlow.impl.jac).
T11 (form + chips + location), T12 (timeline), T16 (HospitalCard, AlternativesList,
MapPanel) and T18 (countdown) plug into the `current` branch.
"""

import from react { useEffect }
import from .IntakeForm { IntakeForm }
import from .AgentTimeline { AgentTimeline }
import from .ResultCards { HospitalCard, AlternativesList }
import from .MapPanel { MapPanel }
import from .UiKit { StatusBadge }
import from .DispatchStatus { DispatchPanel }
sv import from orchestrator { CaseView, create_case, run_case_by_id, get_case, answer_followup }
sv import from dispatch { DispatchView, get_dispatch, cancel_dispatch }
sv import from agent_log { EventView, case_events }
sv import from geoapify { AddressSuggestion, GeocodeResult, autocomplete, geocode }
sv import from matcher { MatchResult, get_match }


def:pub PatientFlow -> JsxElement {
    has description: str = "",
        address: str = "",
        lat: float = 6.9271,
        lon: float = 79.8612,
        location_ready: bool = False,
        locating: bool = False,
        suggestions: list[AddressSuggestion] = [],
        address_searching: bool = False,
        address_feedback: str = "",
        picked_file: any = None,
        file_name: str = "",
        submitting: bool = False,
        error: str = "",
        case_error: str = "",
        case_id: str = "",
        current: CaseView | None = None,
        followup_answer: str = "",
        match_result: MatchResult | None = None,
        events: list[EventView] = [],
        dispatch: DispatchView | None = None;

    def update_description(e: ChangeEvent);
    def pick_example(text: str);
    def load_demo_scenario;
    async def update_address(e: ChangeEvent) -> None;
    def pick_suggestion(label: str, s_lat: float, s_lon: float);
    def use_my_location();
    def pick_file(e: ChangeEvent);
    def drop_file(e: Event);
    def remove_file();
    async def submit_intake(e: FormEvent) -> None;
    async def refresh_case() -> None;
    async def cancel_countdown() -> None;
    def update_followup(e: ChangeEvent);
    async def send_followup(e: FormEvent) -> None;
    def start_over();

    # Poll the case about once a second while one is open.
    useEffect(lambda {
        interval = setInterval(lambda { refresh_case(); }, 1000);
        return lambda { clearInterval(interval); };
    }, [case_id]);

    def reset_click(_e: MouseEvent) { start_over(); }

    tone: str = "info";
    status_text: str = "Starting your request";
    if current is not None {
        status_text = "Request received";
        if current.status == "NEEDS_INFO" {
            status_text = "More information needed";
        } elif current.status == "TRIAGED" {
            status_text = "Urgency checked";
        } elif current.status == "MATCHED" {
            status_text = "Hospital found";
        } elif current.status == "DISPATCHING" {
            status_text = "Dispatch countdown";
        } elif current.status == "DISPATCHED" {
            status_text = "Help is on the way";
        } elif current.status == "REPLANNING" {
            status_text = "Finding another hospital";
        } elif current.status == "DONE" {
            status_text = "Request complete";
        } elif current.status == "CANCELLED" {
            status_text = "Request cancelled";
        }
        if current.severity == "CRITICAL" {
            tone = "critical";
        } elif current.severity == "URGENT" {
            tone = "urgent";
        } else {
            tone = "stable";
        }
    }

    unit_label: str = current.unit if current is not None else "GENERAL";
    result_loading: bool = current is None or current.status not in ["DONE", "CANCELLED"];
    result_message: str = "Sending your request to the agents..." if current is None else "Agents are working - your hospital recommendation will appear here.";
    if current is not None and current.status == "DONE" {
        result_message = "No hospital recommendation is available right now. If this is an emergency, call 1990.";
    } elif current is not None and current.status == "CANCELLED" {
        result_message = "This request was cancelled. You can start a new request whenever you are ready.";
    }

    return <div className="patient-flow">
        {if case_id == "" {
            <IntakeForm
                key="patient-intake"
                description={description}
                address={address}
                suggestions={suggestions}
                address_searching={address_searching}
                address_feedback={address_feedback}
                location_ready={location_ready}
                locating={locating}
                file_name={file_name}
                submitting={submitting}
                error={error}
                on_description={update_description}
                on_example={pick_example}
                on_load_demo={load_demo_scenario}
                on_address={update_address}
                on_suggestion={pick_suggestion}
                on_locate={use_my_location}
                on_file={pick_file}
                on_drop={drop_file}
                on_remove_file={remove_file}
                on_submit={submit_intake}
            />
        } else {
            <section key="case-panel" className="case-panel" aria-label="Your request">

                <div className="case-header" aria-live="polite">
                    <StatusBadge label={status_text} tone={tone}/>
                    {current is not None and current.used_fallback and
                        <span className="fallback-notice" role="note">Using backup logic</span>
                    }
                    <button type="button" className="link-button" onClick={reset_click}>Start a new request</button>
                </div>

                {if case_error != "" {
                    <p key="case-refresh-error" className="case-error" role="status">{case_error}</p>
                }}

                {#* Follow-up question from triage agent *#}
                {if current is not None and current.status == "NEEDS_INFO" {
                    <div key="follow-up" className="followup-box" role="alert">
                        <p className="followup-question">{current.followup_question}</p>
                        <form className="followup-form" onSubmit={send_followup}>
                            <input
                                id="followup-answer"
                                type="text"
                                className="field-input"
                                value={followup_answer}
                                onChange={update_followup}
                                placeholder="Type your answer"
                                aria-label={current.followup_question}
                            />
                            <button type="submit" className="app-button">Send answer</button>
                        </form>
                    </div>
                }}
                {#* Two-column: result and map on left, timeline on right *#}
                <div className="result-layout">
                    <div className="result-main">
                        {if match_result is None or match_result.best is None {
                            <div key="result-placeholder" className="result-placeholder" role="status" aria-live="polite" aria-busy={result_loading}>
                                <span className="result-spinner" aria-hidden="true">{"..." if result_loading else "i"}</span>
                                <p>{result_message}</p>
                            </div>
                        } else {
                            if match_result.summary != "" {
                                <p key="result-summary" className="result-summary">{match_result.summary}</p>
                            }
                            <HospitalCard key="best-hospital" pick={match_result.best} unit={unit_label}/>
                            <MapPanel
                                key="hospital-map"
                                origin_lat={lat}
                                origin_lon={lon}
                                best={match_result.best}
                                alternatives={match_result.alternatives}
                                ambulance_progress={dispatch.ambulance_progress if dispatch is not None else 0.0}
                            />
                            <AlternativesList key="hospital-alternatives" alternatives={match_result.alternatives}/>
                        }}
                    </div>

                    <aside className="result-timeline-aside">
                        <AgentTimeline events={events}/>
                    </aside>
                </div>
                <DispatchPanel dispatch={dispatch} on_cancel={cancel_countdown}/>
            </section>
        }}
    </div>;
}
