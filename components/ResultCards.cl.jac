"""Result screen cards: the best hospital and the ranked alternatives, each with its reason."""

import "../assets/result.css";
sv import from matcher { HospitalPick }

glob UNIT_NAMES: dict[str, str] = {
    "CARDIAC": "cardiac",
    "TRAUMA": "trauma",
    "ICU": "ICU",
    "NEURO": "neuro",
    "GENERAL": "general"
};

def _km(distance: float) -> str {
    if distance < 10.0 {
        return f"{distance:.1f} km";
    }
    return str(int(distance + 0.5)) + " km";
}

def _minutes(eta: float) -> str {
    if eta < 1.0 {
        return "under 1 min";
    }
    return str(int(eta + 0.5)) + " min";
}

"""The best match: name, sector, ETA, free beds and why."""
def:pub HospitalCard(pick: HospitalPick, unit: str) -> JsxElement {
    unit_name: str = UNIT_NAMES.get(unit, unit.lower()) as str;
    beds_text: str = str(pick.free_beds) + " of " + str(pick.total_beds) + " " + unit_name + " beds free";
    eta_label: str = "Estimated travel time" if pick.estimated else "Travel time by road";

    return <article className="hospital-card" aria-label="Best hospital">
        <div className="hc-top">
            <span className="hc-best">Best match</span>
            <span className={"hc-sector " + pick.sector.lower()}>{pick.sector.title()}</span>
        </div>
        <h3>{pick.name}</h3>
        <p className="hc-city">{pick.city}</p>
        <div className="hc-stats">
            <div>
                <p className="hc-number">{_minutes(pick.eta_minutes)}</p>
                <p className="hc-label">{eta_label}</p>
            </div>
            <div>
                <p className="hc-number">{str(pick.free_beds)}</p>
                <p className="hc-label">{beds_text}</p>
            </div>
            <div>
                <p className="hc-number">{_km(pick.distance_km)}</p>
                <p className="hc-label">Distance</p>
            </div>
        </div>
        <p className="hc-reason">{pick.reason}</p>
        {if pick.estimated {
            <p className="hc-note">Estimated: live road routing was not available.</p>
        }}
        {if pick.free_beds == 0 {
            <p className="hc-warning" role="alert">No free beds right now. This is the nearest hospital. Please call ahead or dial 1990.</p>
        }}
    </article>;
}

def:pub AlternativeItem(pick: HospitalPick) -> JsxElement {
    return <li className="alt-item">
        <div className="alt-main">
            <p className="alt-name">{pick.name}</p>
            <p className="alt-reason">{pick.reason}</p>
        </div>
        <div className="alt-side">
            <span className="alt-eta">{_minutes(pick.eta_minutes)}</span>
            <span className="alt-beds">{str(pick.free_beds) + (" bed" if pick.free_beds == 1 else " beds")}</span>
            <span className={"hc-sector " + pick.sector.lower()}>{pick.sector.title()}</span>
        </div>
    </li>;
}

"""Other good options, each with a one-line reason."""
def:pub AlternativesList(alternatives: list[HospitalPick]) -> JsxElement {
    return <section className="alternatives" aria-label="Other options">
        <h3>Other options</h3>
        {if len(alternatives) == 0 {
            <p className="alt-empty">No other hospital currently has free beds for this need.</p>
        }}
        <ul className="alt-list">
            {for alt in alternatives {
                <AlternativeItem key={alt.hospital_id} pick={alt}/>
            }}
        </ul>
    </section>;
}
