"""CareRoute patient workspace: intake form, then the live status of the case.

Stateful shell: all state and handlers live here (bodies in PatientFlow.impl.jac),
the sections below it are stateless. T12 (timeline), T16 (result) and T18
(countdown) plug into the `current` branch.
"""

import "../assets/patient.css";
import from react { useEffect }
import from .IntakeForm { IntakeForm }
import from .UiKit { StatusBadge }
import from .AgentTimeline { AgentTimeline }
import from .DispatchStatus { CountdownBanner, DispatchStatus }
sv import from orchestrator { CaseView, create_case, run_case_by_id, get_case, answer_followup }
sv import from dispatch { DispatchView, get_dispatch, cancel_dispatch }
sv import from agent_log { EventView, case_events }
sv import from geoapify { AddressSuggestion, GeocodeResult, autocomplete, geocode }

def:pub PatientFlow -> JsxElement {
    has description: str = "",
        address: str = "",
        lat: float = 0.0,
        lon: float = 0.0,
        location_ready: bool = False,
        locating: bool = False,
        suggestions: list[AddressSuggestion] = [],
        picked_file: any = None,
        file_name: str = "",
        submitting: bool = False,
        error: str = "",
        case_id: str = "",
        current: CaseView | None = None,
        events: list[EventView] = [],
        dispatch: DispatchView | None = None,
        followup_answer: str = "";

    def update_description(e: ChangeEvent);
    def pick_example(text: str);
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
        status_text = current.status;
        if current.severity == "CRITICAL" {
            tone = "critical";
        } elif current.severity == "URGENT" {
            tone = "urgent";
        } else {
            tone = "stable";
        }
    }

    return <div className="patient-flow">
        {if case_id == "" {
            <IntakeForm
                description={description}
                address={address}
                suggestions={suggestions}
                location_ready={location_ready}
                locating={locating}
                file_name={file_name}
                submitting={submitting}
                error={error}
                on_description={update_description}
                on_example={pick_example}
                on_address={update_address}
                on_suggestion={pick_suggestion}
                on_locate={use_my_location}
                on_file={pick_file}
                on_drop={drop_file}
                on_remove_file={remove_file}
                on_submit={submit_intake}
            />
        } else {
            <section className="case-panel" aria-live="polite" aria-label="Your request">
                <StatusBadge label={status_text} tone={tone}/>
                {if current is not None and current.status == "NEEDS_INFO" {
                    <form className="followup" onSubmit={send_followup}>
                        <label htmlFor="followup-answer">{current.followup_question}</label>
                        <input
                            id="followup-answer"
                            type="text"
                            value={followup_answer}
                            onChange={update_followup}
                            placeholder="Type your answer"
                        />
                        <button type="submit" className="app-button">Send answer</button>
                    </form>
                } else {
                    <p className="case-note">
                        {"Your request is being handled. Severity: " + current.severity + "." if current is not None else "Sending your request..."}
                    </p>
                }}
                {if dispatch is not None and dispatch.case_status == "DISPATCHING" {
                    <CountdownBanner seconds_left={dispatch.seconds_left} on_cancel={cancel_countdown}/>
                }}
                {if dispatch is not None and dispatch.case_status == "CANCELLED" {
                    <p className="cancelled-note" role="status">
                        Dispatch cancelled. Nothing was sent. If this is still an emergency, call 1990 now.
                    </p>
                }}
                {if dispatch is not None and (dispatch.case_status == "DISPATCHED" or dispatch.case_status == "DISPATCHING") {
                    <DispatchStatus dispatch={dispatch}/>
                }}
                <AgentTimeline events={events}/>
                <button type="button" className="link-button" onClick={reset_click}>Start a new request</button>
            </section>
        }}
    </div>;
}
