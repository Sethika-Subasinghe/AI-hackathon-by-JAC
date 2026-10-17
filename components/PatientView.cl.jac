"""T11/T16 Patient view: form → agent timeline → result cards + map.

The patient describes a medical situation, optionally shares location, and
submits. The orchestrator runs; the AgentTimeline polls events live. When the
case reaches MATCHED (or DONE), ResultPanel shows the best hospital, ranked
alternatives and a Geoapify/OSM map with the route.
"""

import from .UiKit { AppButton, StatusBadge, SurfaceCard }
import from .AgentTimeline { AgentTimeline }
import from .ResultPanel { HospitalCard, AlternativesList, MapPanel }
sv import from orchestrator { CaseView, create_case, run_case_by_id, get_case, answer_followup }
sv import from matcher { HospitalPick, MatchResult, get_match }
sv import from geoapify { autocomplete, AddressSuggestion }


# ---------------------------------------------------------------------------
# Example chips (quick-fill prompts)
# ---------------------------------------------------------------------------
glob EXAMPLE_CHIPS: list[str] = [
    "Chest pain and shortness of breath",
    "Severe head injury after a fall",
    "Stroke symptoms — sudden face drooping",
    "Child with high fever and seizures",
    "Stable knee pain, need specialist",
];

# Default location: Colombo, Sri Lanka
glob DEFAULT_LAT: float = 6.9271;
glob DEFAULT_LON: float = 79.8612;


# ---------------------------------------------------------------------------
# Severity colour helper
# ---------------------------------------------------------------------------
def _severity_tone(severity: str) -> str {
    if severity == "CRITICAL" { return "critical"; }
    if severity == "URGENT"   { return "urgent"; }
    return "stable";
}

def _severity_label(severity: str) -> str {
    if severity == "CRITICAL" { return "🔴 Critical"; }
    if severity == "URGENT"   { return "🟠 Urgent"; }
    if severity == "STABLE"   { return "🟢 Stable"; }
    return severity;
}


# ---------------------------------------------------------------------------
# Main patient view
# ---------------------------------------------------------------------------

"""Full patient intake, agent timeline and result panel."""
def:pub PatientView(geoapify_key: str = "") -> JsxElement {
    # Form state
    has description: str = "";
    has address_query: str = "";
    has suggestions: list[AddressSuggestion] = [];
    has chosen_lat: float = DEFAULT_LAT;
    has chosen_lon: float = DEFAULT_LON;
    has chosen_address: str = "Colombo, Sri Lanka (default)";
    has location_loading: bool = False;
    has show_suggestions: bool = False;

    # Case state
    has case_id: str = "";
    has case_status: str = "";
    has case_view: CaseView | None = None;
    has submitting: bool = False;
    has submit_error: str = "";

    # Follow-up
    has followup_answer: str = "";
    has sending_followup: bool = False;

    # Match result
    has match_result: MatchResult | None = None;

    # -----------------------------------------------------------------------
    # Handlers
    # -----------------------------------------------------------------------
    def on_change_description(e: ChangeEvent) {
        description = e.target.value;
    }

    def on_change_followup(e: ChangeEvent) {
        followup_answer = e.target.value;
    }

    def use_chip(chip: str) {
        description = chip;
    }

    async def on_address_input(e: ChangeEvent) {
        address_query = e.target.value;
        if len(address_query) < 3 {
            suggestions = [];
            show_suggestions = False;
            return;
        }
        location_loading = True;
        got = await autocomplete(address_query, "lk");
        location_loading = False;
        suggestions = got if got is not None else [];
        show_suggestions = len(suggestions) > 0;
    }

    def pick_suggestion(s: AddressSuggestion) {
        chosen_lat = s.lat;
        chosen_lon = s.lon;
        chosen_address = s.label;
        address_query = s.label;
        suggestions = [];
        show_suggestions = False;
    }

    def use_default_location(_e: MouseEvent) {
        chosen_lat = DEFAULT_LAT;
        chosen_lon = DEFAULT_LON;
        chosen_address = "Colombo, Sri Lanka";
        address_query = "Colombo, Sri Lanka";
        suggestions = [];
        show_suggestions = False;
    }

    async def _poll_case() {
        if case_id == "" { return; }
        cv = await get_case(case_id);
        if cv is not None {
            case_view = cv;
            case_status = cv.status;
            # Fetch match result when matched
            if cv.status in ["MATCHED", "DISPATCHING", "DISPATCHED", "DONE"] and match_result is None {
                mr = await get_match(case_id);
                if mr is not None {
                    match_result = mr;
                }
            }
        }
    }

    async def submit(_e: MouseEvent) {
        if not description.strip() {
            submit_error = "Please describe the medical situation.";
            return;
        }
        submitting = True;
        submit_error = "";
        case_id = "";
        case_status = "";
        case_view = None;
        match_result = None;

        new_id = await create_case(description.strip(), chosen_lat, chosen_lon, chosen_address);
        if new_id is None or new_id == "" {
            submit_error = "Could not start a case. Please try again.";
            submitting = False;
            return;
        }
        case_id = new_id;
        # Kick off the orchestrator (fire and forget; timeline polls events).
        run_case_by_id(new_id);
        submitting = False;
        # Start polling case status every second.
        interval = setInterval(lambda { _poll_case(); }, 1000);
    }

    async def send_followup(_e: MouseEvent) {
        if case_id == "" or not followup_answer.strip() { return; }
        sending_followup = True;
        await answer_followup(case_id, followup_answer.strip());
        followup_answer = "";
        sending_followup = False;
        run_case_by_id(case_id);
    }

    # -----------------------------------------------------------------------
    # Helpers for match result -> plain dicts for AlternativesList
    # -----------------------------------------------------------------------
    def _pick_to_dict(p: HospitalPick, unit_type: str) -> dict {
        return {
            "hospital_id": p.hospital_id,
            "name": p.name,
            "city": p.city,
            "sector": p.sector,
            "eta_minutes": p.eta_minutes,
            "distance_km": p.distance_km,
            "free_beds": p.free_beds,
            "total_beds": p.total_beds,
            "unit_type": unit_type,
            "reason": p.reason,
            "estimated": p.estimated,
        };
    }

    # -----------------------------------------------------------------------
    # Computed values
    # -----------------------------------------------------------------------
    has_case: bool = case_id != "";
    waiting_for_followup: bool = case_view is not None and case_view.status == "NEEDS_INFO";
    is_done: bool = case_view is not None and case_view.status in ["DONE", "MATCHED", "DISPATCHING", "DISPATCHED"];
    has_result: bool = match_result is not None and match_result.best is not None;

    unit_label: str = case_view.unit if case_view is not None else "GENERAL";
    alts_dicts: list[dict] = [];
    if match_result is not None {
        for alt in match_result.alternatives {
            alts_dicts.append(_pick_to_dict(alt, unit_label));
        }
    }

    # -----------------------------------------------------------------------
    # JSX
    # -----------------------------------------------------------------------
    return <div className="patient-view">

        {#* ---- Intake form ---- *#}
        {not has_case and <section className="intake-form" aria-labelledby="intake-heading">
            <h2 id="intake-heading" className="intake-heading">Describe the situation</h2>
            <p className="intake-hint">Be as specific as you can. CareRoute will coordinate the next safe step.</p>

            <div className="chip-row" role="list" aria-label="Example situations">
                {for chip in EXAMPLE_CHIPS {
                    <button
                        type="button"
                        className={"chip" + (" chip--active" if description == chip else "")}
                        onClick={lambda (_e: MouseEvent) { use_chip(chip); }}
                        key={chip}
                        role="listitem"
                    >{chip}</button>
                }}
            </div>

            <div className="field-group">
                <label for="case-description" className="field-label">What is happening?</label>
                <textarea
                    id="case-description"
                    className="field-textarea"
                    rows={4}
                    placeholder="E.g. My father has severe chest pain and is sweating heavily..."
                    value={description}
                    onChange={on_change_description}
                    aria-required={True}
                />
            </div>

            <div className="field-group location-group">
                <label for="address-input" className="field-label">Location (Sri Lanka)</label>
                <div className="location-input-wrap">
                    <input
                        id="address-input"
                        type="text"
                        className="field-input"
                        placeholder="Start typing a Sri Lanka city or address..."
                        value={address_query}
                        onInput={on_address_input}
                        aria-autocomplete="list"
                        aria-expanded={show_suggestions}
                    />
                    <button type="button" className="loc-default-btn" onClick={use_default_location} title="Use Colombo default">
                        📍
                    </button>
                </div>
                {location_loading and <span className="loc-loading" aria-live="polite">Looking up…</span>}
                {show_suggestions and <ul className="suggestions-list" role="listbox" aria-label="Address suggestions">
                    {for s in suggestions {
                        <li
                            className="suggestion-item"
                            role="option"
                            key={s.label}
                            onClick={lambda (_e: MouseEvent) { pick_suggestion(s); }}
                        >{s.label}</li>
                    }}
                </ul>}
                {chosen_address != "" and not show_suggestions and <p className="loc-chosen">📍 {chosen_address}</p>}
            </div>

            {submit_error and <p className="form-error" role="alert">{submit_error}</p>}

            <AppButton
                label={"Finding care route…" if submitting else "Find the best hospital"}
                disabled={submitting or not description.strip()}
                on_press={lambda { submit(None); }}
            />
        </section>}

        {#* ---- Running case: timeline + follow-up ---- *#}
        {has_case and <div className="case-panel">

            <div className="case-meta">
                <StatusBadge
                    label={_severity_label(case_view.severity) if case_view is not None else "Analysing…"}
                    tone={_severity_tone(case_view.severity) if case_view is not None else "info"}
                />
                {case_view is not None and case_view.used_fallback and
                    <span className="fallback-notice" role="note">⚠ Using backup logic — real AI call unavailable</span>
                }
                <button
                    type="button"
                    className="app-button secondary new-case-btn"
                    onClick={lambda (_e: MouseEvent) {
                        case_id = "";
                        case_status = "";
                        case_view = None;
                        match_result = None;
                        description = "";
                        address_query = "";
                    }}
                >Start a new case</button>
            </div>

            {#* Follow-up question from triage agent *#}
            {waiting_for_followup and case_view is not None and <div className="followup-box" role="alert">
                <p className="followup-question">{case_view.followup_question}</p>
                <div className="followup-row">
                    <input
                        type="text"
                        className="field-input followup-input"
                        placeholder="Type your answer…"
                        value={followup_answer}
                        onChange={on_change_followup}
                    />
                    <AppButton
                        label={"Sending…" if sending_followup else "Answer"}
                        disabled={sending_followup or not followup_answer.strip()}
                        on_press={lambda { send_followup(None); }}
                    />
                </div>
            </div>}

            {#* Two-column layout: left = result, right = timeline *#}
            <div className="result-layout">
                <div className="result-main">
                    {has_result and match_result is not None and match_result.best is not None and
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
                            <AlternativesList picks={alts_dicts} unit_type={unit_label}/>
                            <MapPanel
                                origin_lat={chosen_lat}
                                origin_lon={chosen_lon}
                                hospital_lat={match_result.best.lat}
                                hospital_lon={match_result.best.lon}
                                hospital_name={match_result.best.name}
                                route_coords={match_result.best.route}
                                geoapify_key={geoapify_key}
                            />
                        </div>
                    }
                    {not has_result and <div className="result-placeholder">
                        <span className="result-spinner" aria-hidden="true">⏳</span>
                        <p>Agents are working… the best hospital will appear here.</p>
                    </div>}
                </div>

                <aside className="result-timeline-aside">
                    <AgentTimeline case_id={case_id} case_status={case_status}/>
                </aside>
            </div>
        </div>}

    </div>;
}
