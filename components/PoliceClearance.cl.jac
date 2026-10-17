"""Police route-clearance panel: who was asked, which route, and how much of it is cleared."""

import "../assets/police.css";
sv import from dispatch { DispatchView }

def _km_text(km: float) -> str {
    return str(round(km * 10.0) / 10.0) + " km";
}

"""Shows the simulated police request next to the map, with the cleared part of the route."""
def:pub PoliceClearance(dispatch: DispatchView, distance_km: float) -> JsxElement {
    found = [r for r in dispatch.requests if r.kind == "POLICE"];
    if len(found) == 0 {
        return <div></div>;
    }
    req = found[0];
    sent: bool = req.status != "PENDING" and req.status != "CANCELLED";
    progress: float = dispatch.ambulance_progress if sent else 0.0;
    percent: int = int(progress * 100.0);
    cleared_km: float = distance_km * progress;
    arrived: bool = percent >= 100;

    label: str = "Waiting for the countdown";
    if req.status == "CANCELLED" {
        label = "Cancelled";
    } elif sent and arrived {
        label = "Route fully cleared";
    } elif sent {
        label = "Clearing the route ahead of the ambulance";
    }

    return <section className="police-clearance" aria-label="Police route clearance">
        <div className="pc-head">
            <span className="pc-badge" aria-hidden="true">P</span>
            <div>
                <h3>Police route clearance</h3>
                <p className="pc-target">{req.target}</p>
            </div>
            <span className="pc-sim">Simulated</span>
        </div>
        <p className="pc-message">{req.message}</p>
        <dl className="pc-facts">
            <div><dt>Route length</dt><dd>{_km_text(distance_km)}</dd></div>
            <div><dt>Cleared so far</dt><dd>{_km_text(cleared_km)}</dd></div>
            <div><dt>Status</dt><dd>{label}</dd></div>
        </dl>
        <div className="pc-bar" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percent} aria-label={"Route cleared " + str(percent) + " percent"}>
            <span style={{"width": str(percent) + "%"}}></span>
        </div>
    </section>;
}
