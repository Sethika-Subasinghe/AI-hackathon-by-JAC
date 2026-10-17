"""CareRoute patient workspace: intake form, then the live status of the case.

Stateful shell: all state and handlers live here (bodies in PatientFlow.impl.jac).
T11 (form + chips + location), T12 (timeline), T16 (HospitalCard, AlternativesList,
MapPanel) and T18 (countdown) plug into the `current` branch.
"""

import from react { useEffect }
import from .IntakeForm { IntakeForm }
import from .AgentTimeline { AgentTimeline }
import from .ResultPanel { HospitalCard, AlternativesList, MapPanel }
import from .UiKit { StatusBadge }
sv import from orchestrator { CaseView, create_case, run_case_by_id, get_case, answer_followup }
sv import from geoapify { AddressSuggestion, GeocodeResult, autocomplete, geocode }
sv import from matcher { MatchResult, HospitalPick, get_match }


def:pub PatientFlow -> JsxElement {
    has description: str = "",
        address: str = "",
        lat: float = 6.9271,
        lon: float = 79.8612,
        location_ready: bool = False,
        locating: bool = False,
        suggestions: list[AddressSuggestion] = [],
        picked_file: any = None,
        file_name: str = "",
        submitting: bool = False,
        error: str = "",
        case_id: str = "",
        current: CaseView | None = None,
        followup_answer: str = "",
        match_result: MatchResult | None = None;

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

    has_result: bool = match_result is not None and match_result.best is not None;
    unit_label: str = current.unit if current is not None else "GENERAL";

    def _pick_to_dict(p: HospitalPick) -> dict {
        return {
            "hospital_id": p.hospital_id,
            "name": p.name,
            "city": p.city,
            "sector": p.sector,
            "eta_minutes": p.eta_minutes,
            "distance_km": p.distance_km,
            "free_beds": p.free_beds,
            "total_beds": p.total_beds,
            "unit_type": unit_label,
            "reason": p.reason,
            "estimated": p.estimated,
        };
    }

    alts_dicts: list[dict] = [];
    if match_result is not None {
        for alt in match_result.alternatives {
            alts_dicts.append(_pick_to_dict(alt));
        }
    }

    is_done: bool = current is not None and current.status in ["DONE", "MATCHED", "DISPATCHING", "DISPATCHED", "CANCELLED"];

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

                <div className="case-header">
                    <StatusBadge label={status_text} tone={tone}/>
                    {current is not None and current.used_fallback and
                        <span className="fallback-notice" role="note">⚠ Using backup logic</span>
                    }
                    <button type="button" className="link-button" onClick={reset_click}>Start a new request</button>
                </div>

                {# Follow-up question from triage agent #}
                {if current is not None and current.status == "NEEDS_INFO" {
                    <div className="followup-box" role="alert">
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

                {# Two-column: result + map on left, timeline on right #}
                <div className="result-layout">
                    <div className="result-main">
                        {if has_result and match_result is not None and match_result.best is not None {
                            <div className="result-cards">
                                {match_result.summary and <p className="result-summary">{match_result.summary}</p>}
                                <HospitalCard
                                    name={match_result.best.name}
                                    city={match_result.best.city}
                                    sector={match_result.best.sector}
                                    eta_minutes={match_result.best.eta_minutes}
                                    distance_km={match_result.best.distance_km}
                                    free_beds={match_result.best.free_beds}
                                    total_beds={match_result.best.total_beds}
                                    unit_type={unit_label}
                                    reason={match_result.best.reason}
                                    estimated={match_result.best.estimated}
                                    is_best={True}
                                />
                                {len(alts_dicts) > 0 and
                                    <AlternativesList picks={alts_dicts} unit_type={unit_label}/>
                                }
                                <MapPanel
                                    origin_lat={lat}
                                    origin_lon={lon}
                                    hospital_lat={match_result.best.lat}
                                    hospital_lon={match_result.best.lon}
                                    hospital_name={match_result.best.name}
                                    route_coords={match_result.best.route}
                                />
                            </div>
                        } else {
                            <div className="result-placeholder">
                                <span className="result-spinner" aria-hidden="true">⏳</span>
                                <p>
                                    {if current is None {
                                        "Sending your request to the agents…"
                                    } elif current.status in ["DONE", "MATCHED"] {
                                        "Loading hospital recommendation…"
                                    } else {
                                        "Agents are working — hospital recommendation will appear here."
                                    }}
                                </p>
                            </div>
                        }}
                    </div>

                    <aside className="result-timeline-aside">
                        <AgentTimeline
                            case_id={case_id}
                            case_status={status_text}
                        />
                    </aside>
                </div>
            </section>
        }}
    </div>;
}
