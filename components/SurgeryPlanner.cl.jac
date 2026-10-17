"""Patient side: pick a planned surgery, see the best hospital by wait and distance, join its list."""

import "../assets/surgery.css";
sv import from surgery { SurgeryOption, SurgeryChoice, JoinResult, list_surgery_catalog, find_surgery_hospitals, join_surgery_list }
sv import from data.surgery_seed { SurgeryInfo }
sv import from geoapify { AddressSuggestion, GeocodeResult, autocomplete, geocode }

def _weeks_text(weeks: float) -> str {
    if weeks < 1.0 {
        return "under 1 week";
    }
    if weeks < 1.5 {
        return "about 1 week";
    }
    return "about " + str(int(weeks + 0.5)) + " weeks";
}

"""One surgery the patient can choose."""
def:pub SurgeryChoiceCard(
    info: SurgeryInfo,
    selected: bool,
    on_pick: Callable[[str], None],
) -> JsxElement {
    def pick(_e: MouseEvent) { on_pick(info.code); }
    return <button
        type="button"
        className={"sp-surgery" + (" selected" if selected else "")}
        aria-pressed={selected}
        onClick={pick}
    >
        <span className="sp-name">{info.name}</span>
        <span className="sp-speciality">{info.speciality}</span>
    </button>;
}

"""A hospital that offers the surgery: wait, queue, distance and a join button."""
def:pub SurgeryOptionCard(
    option: SurgeryOption,
    best: bool,
    busy: bool,
    on_join: Callable[[str], None],
) -> JsxElement {
    def join(_e: MouseEvent) { on_join(option.hospital_id); }
    has_distance: bool = option.distance_km > 0.0;
    return <article className={"sp-option" + (" best" if best else "")}>
        <div className="sp-option-top">
            {if best {
                <span className="sp-best">Shortest wait for you</span>
            }}
            <span className={"hc-sector " + option.sector.lower()}>{option.sector.title()}</span>
        </div>
        <h4>{option.hospital_name}</h4>
        <p className="sp-city">{option.city}</p>
        <div className="sp-stats">
            <div><p className="sp-big">{_weeks_text(option.wait_weeks)}</p><p className="sp-label">Expected wait</p></div>
            <div><p className="sp-big">{str(option.waiting)}</p><p className="sp-label">Patients on the list</p></div>
            <div><p className="sp-big">{str(option.weekly_capacity)}</p><p className="sp-label">Operations a week</p></div>
            {if has_distance {
                <div><p className="sp-big">{str(int(option.distance_km + 0.5)) + " km"}</p><p className="sp-label">From you</p></div>
            }}
        </div>
        <button type="button" className="app-button sp-join" onClick={join} disabled={busy}>Join this waiting list</button>
    </article>;
}

def:pub SurgeryPlanner() -> JsxElement {
    has catalog: list[SurgeryInfo] = [],
        selected: str = "",
        address: str = "",
        suggestions: list[AddressSuggestion] = [],
        lat: float = 0.0,
        lon: float = 0.0,
        location_ready: bool = False,
        locating: bool = False,
        choice: SurgeryChoice | None = None,
        searching: bool = False,
        patient_name: str = "",
        join_result: JoinResult | None = None,
        joining: bool = False,
        error: str = "";

    async can with entry {
        catalog = await list_surgery_catalog();
    }

    def pick_surgery(code: str) {
        selected = code;
        choice = None;
        join_result = None;
        error = "";
    }

    async def update_address(e: ChangeEvent) -> None {
        value = e.target.value;
        address = value;
        location_ready = False;
        if len(value.strip()) >= 3 {
            suggestions = await autocomplete(value, 5);
        } else {
            suggestions = [];
        }
    }

    def update_name(e: ChangeEvent) { patient_name = e.target.value; }

    def pick_place(label: str, s_lat: float, s_lon: float) {
        address = label;
        lat = s_lat;
        lon = s_lon;
        location_ready = True;
        suggestions = [];
    }

    def use_my_location() {
        nav: any = navigator;
        if not nav.geolocation {
            error = "Your browser cannot share its location. Type a town instead.";
            return;
        }
        locating = True;
        nav.geolocation.getCurrentPosition(
            lambda(pos: any) {
                lat = pos.coords.latitude as float;
                lon = pos.coords.longitude as float;
                address = "My current location";
                location_ready = True;
                suggestions = [];
                locating = False;
            },
            lambda(_err: any) {
                locating = False;
                error = "We could not get your location. Type a town instead.";
            }
        );
    }

    async def search(e: FormEvent) -> None {
        e.preventDefault();
        error = "";
        join_result = None;
        if selected == "" {
            error = "Choose a surgery first.";
            return;
        }
        searching = True;
        use_lat = lat;
        use_lon = lon;
        if not location_ready and address.strip() != "" {
            found = await geocode(address);
            if found.ok {
                use_lat = found.lat;
                use_lon = found.lon;
                lat = found.lat;
                lon = found.lon;
                location_ready = True;
            } else {
                error = "We could not find that place, so hospitals are ranked by waiting time only.";
            }
        }
        choice = await find_surgery_hospitals(selected, use_lat, use_lon);
        searching = False;
    }

    async def join_list(hospital_id: str) -> None {
        if patient_name.strip() == "" {
            error = "Enter your name above, then join the list.";
            return;
        }
        error = "";
        joining = True;
        join_result = await join_surgery_list(selected, hospital_id, patient_name);
        joining = False;
        # Show the updated queue numbers.
        choice = await find_surgery_hospitals(selected, lat, lon);
    }

    chosen_name: str = "";
    for s in catalog {
        if s.code == selected {
            chosen_name = s.name;
        }
    }

    return <div className="surgery-planner">
        <section aria-label="Choose a surgery">
            <h3 className="sp-heading">1. Which surgery do you need?</h3>
            <div className="sp-grid" role="group" aria-label="Planned surgeries">
                {for info in catalog {
                    <SurgeryChoiceCard key={info.code} info={info} selected={info.code == selected} on_pick={pick_surgery}/>
                }}
            </div>
        </section>

        <form className="sp-form" onSubmit={search} aria-label="Find a hospital for this surgery">
            <h3 className="sp-heading">2. Where are you? <span className="sp-optional">(optional, helps us find hospitals near you)</span></h3>
            <div className="sp-locate">
                <input
                    id="surgery-address"
                    type="text"
                    autoComplete="off"
                    value={address}
                    onChange={update_address}
                    placeholder="Start typing a town in Sri Lanka"
                    aria-label="Your town or address"
                />
                <button type="button" className="sp-locate-button" onClick={use_my_location} disabled={locating}>
                    {"Locating..." if locating else "Use my location"}
                </button>
            </div>
            {if len(suggestions) > 0 {
                <ul className="sp-suggestions" aria-label="Address suggestions">
                    {for sug in suggestions {
                        <SuggestionRow key={sug.label + str(sug.lat)} s={sug} on_pick={pick_place}/>
                    }}
                </ul>
            }}
            {if error != "" {
                <p className="sp-error" role="alert">{error}</p>
            }}
            <button type="submit" className="app-button" disabled={selected == "" or searching}>
                {"Searching..." if searching else ("Find the best hospital for " + chosen_name.lower() if chosen_name != "" else "Find the best hospital")}
            </button>
        </form>

        {if choice is not None {
            <section className="sp-results" aria-live="polite" aria-label="Hospitals for this surgery">
                <h3 className="sp-heading">3. Your options</h3>
                <p className="sp-summary">{choice.summary}</p>
                {if choice.best is not None {
                    <div className="sp-name-row">
                        <label htmlFor="surgery-name">Your name (to join a list)</label>
                        <input id="surgery-name" type="text" value={patient_name} onChange={update_name} placeholder="e.g. Nimal Perera"/>
                    </div>
                    if join_result is not None {
                        <p className={"sp-join-result" + (" ok" if join_result.ok else " fail")} role="status">{join_result.message}</p>
                    }
                    <SurgeryOptionCard option={choice.best} best={True} busy={joining} on_join={join_list}/>
                    for alt in choice.alternatives {
                        <SurgeryOptionCard key={alt.hospital_id} option={alt} best={False} busy={joining} on_join={join_list}/>
                    }
                    <p className="sp-note">Waiting times are estimates from the numbers each hospital keeps up to date. Demo data only. Not medical advice.</p>
                }}
            </section>
        }}
    </div>;
}

def:pub SuggestionRow(
    s: AddressSuggestion,
    on_pick: Callable[[str, float, float], None],
) -> JsxElement {
    def pick(_e: MouseEvent) { on_pick(s.label, s.lat, s.lon); }
    return <li><button type="button" onClick={pick}>{s.label}</button></li>;
}
