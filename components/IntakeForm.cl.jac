"""Patient intake form: description with example chips, location, optional PDF report."""

sv import from geoapify { AddressSuggestion }

glob EXAMPLES: list[str] = [
    "My father has chest pain and is sweating",
    "Road accident, heavy bleeding from the leg",
    "Sudden weakness on one side and slurred speech",
    "My child has a high fever and a mild cough"
];

def:pub ExampleChip(text: str, on_pick: Callable[[str], None]) -> JsxElement {
    def pick(_e: MouseEvent) { on_pick(text); }
    return <button type="button" className="chip" onClick={pick}>{text}</button>;
}

def:pub SuggestionItem(
    s: AddressSuggestion,
    on_pick: Callable[[str, float, float], None],
) -> JsxElement {
    def pick(_e: MouseEvent) { on_pick(s.label, s.lat, s.lon); }
    return <li>
        <button type="button" role="option" onClick={pick}>{s.label}</button>
    </li>;
}

def:pub IntakeForm(
    description: str,
    address: str,
    suggestions: list[AddressSuggestion],
    address_searching: bool,
    address_feedback: str,
    location_ready: bool,
    locating: bool,
    file_name: str,
    submitting: bool,
    error: str,
    on_description: Callable[[ChangeEvent], None],
    on_example: Callable[[str], None],
    on_load_demo: Callable[[], None],
    on_address: Callable[[ChangeEvent], None],
    on_suggestion: Callable[[str, float, float], None],
    on_locate: Callable[[], None],
    on_file: Callable[[ChangeEvent], None],
    on_drop: Callable[[Event], None],
    on_remove_file: Callable[[], None],
    on_submit: Callable[[FormEvent], None],
) -> JsxElement {
    def stop_default(e: Event) { e.preventDefault(); }
    def locate_click(_e: MouseEvent) { on_locate(); }
    def remove_click(_e: MouseEvent) { on_remove_file(); }
    def load_demo_click(_e: MouseEvent) { on_load_demo(); }

    can_submit: bool = description.strip() != "" and not submitting;
    location_note: str = "Location set" if location_ready else "Choose a suggestion or use your location";

    return <form className="intake" onSubmit={on_submit} aria-label="Describe the situation">
        <div className="field">
            <label htmlFor="intake-description">What is happening?</label>
            <textarea
                id="intake-description"
                rows={4}
                value={description}
                onChange={on_description}
                placeholder="Describe the symptoms in everyday words. Do not worry about medical terms."
                required={True}
            ></textarea>
            <button type="button" className="demo-scenario-button" onClick={load_demo_click} disabled={submitting}>
                Load chest pain demo
            </button>
            <div className="chips" role="group" aria-label="Example situations">
                {for ex in EXAMPLES {
                    <ExampleChip key={ex} text={ex} on_pick={on_example}/>
                }}
            </div>
        </div>

        <div className="field">
            <label htmlFor="intake-address">Where is the patient?</label>
            <div className="locate-row">
                <input
                    id="intake-address"
                    type="text"
                    autoComplete="off"
                    value={address}
                    onChange={on_address}
                    placeholder="Start typing an address or town in Sri Lanka"
                />
                <button type="button" className="locate-button" onClick={locate_click} disabled={locating}>
                    {"Locating..." if locating else "Use my location"}
                </button>
            </div>
            <p className={"hint ok" if location_ready else "hint"} aria-live="polite">{location_note}</p>
            {if len(suggestions) > 0 {
                <ul key="address-suggestions" className="suggestions" role="listbox" aria-label="Address suggestions">
                    {for s in suggestions {
                        <SuggestionItem key={s.label + str(s.lat)} s={s} on_pick={on_suggestion}/>
                    }}
                </ul>
            }}
            {if address_searching {
                <p key="address-searching" className="hint" role="status" aria-live="polite">Searching for nearby addresses…</p>
            } elif address_feedback != "" {
                <p key="address-feedback" className="hint" role="status" aria-live="polite">{address_feedback}</p>
            }}
        </div>

        <div className="field">
            <span className="field-label">Medical report (optional PDF)</span>
            <label
                className="dropzone"
                htmlFor="intake-file"
                onDragOver={stop_default}
                onDrop={on_drop}
            >
                <span className="drop-icon" aria-hidden="true">PDF</span>
                <span className="drop-copy">
                    {file_name if file_name != "" else "Drop a report here or tap to choose a file"}
                </span>
                <input id="intake-file" type="file" accept="application/pdf" onChange={on_file}/>
            </label>
            {if file_name != "" {
                <button key="remove-report" type="button" className="link-button" onClick={remove_click}>Remove report</button>
            }}
        </div>

        {if error != "" {
            <p key="intake-error" className="form-error" role="alert">{error}</p>
        }}

        <button type="submit" className="app-button submit" disabled={not can_submit}>
            {"Sending..." if submitting else "Find the right hospital"}
        </button>
        <p className="hint">Not a medical diagnosis. In a real emergency call 1990.</p>
    </form>;
}
