"""T16 Result UI: HospitalCard, AlternativesList, MapPanel.

Consumes `MatchResult` from `get_match` (matcher.jac) and renders:
  - HospitalCard  : the best-match hospital with ETA, beds, sector, reason.
  - AlternativesList: ranked alternatives with one-line reasons.
  - MapPanel      : Geoapify tile layer, origin + hospital markers, route line.

All data is passed in as props; no direct server calls are made here.
"""

import from .UiKit { StatusBadge }


# ---------------------------------------------------------------------------
# HospitalCard
# ---------------------------------------------------------------------------

"""Best-match hospital card. Pass `estimated=True` to show the ETA caveat."""
def:pub HospitalCard(
    name: str,
    city: str,
    sector: str,
    eta_minutes: float,
    distance_km: float,
    free_beds: int,
    total_beds: int,
    unit_type: str,
    reason: str,
    estimated: bool = False,
    is_best: bool = True,
    children: any = None,
) -> JsxElement {
    sector_tone: str = "teal" if sector == "PUBLIC" else "info";
    beds_tone: str = "stable" if free_beds > 2 else ("urgent" if free_beds > 0 else "critical");
    eta_label: str = str(round(eta_minutes)) + " min" + (" (est.)" if estimated else "");

    return <article className={"hospital-card" + (" hospital-card--best" if is_best else "")}>
        <div className="hc-header">
            <div className="hc-title-row">
                {is_best and <span className="hc-best-tag" aria-label="Best match">★ Best match</span>}
                <h3 className="hc-name">{name}</h3>
                <span className="hc-city">{city}</span>
            </div>
            <StatusBadge label={sector.title()} tone={sector_tone}/>
        </div>

        <div className="hc-stats" aria-label="Hospital statistics">
            <div className="hc-stat">
                <span className="hc-stat-value">{eta_label}</span>
                <span className="hc-stat-label">{"ETA" + (" · Estimated" if estimated else "")}</span>
            </div>
            <div className="hc-stat">
                <span className="hc-stat-value">{str(round(distance_km)) + " km"}</span>
                <span className="hc-stat-label">Distance</span>
            </div>
            <div className={"hc-stat hc-beds hc-beds--" + beds_tone}>
                <span className="hc-stat-value">{str(free_beds) + " / " + str(total_beds)}</span>
                <span className="hc-stat-label">{unit_type + " beds free"}</span>
            </div>
        </div>

        {reason and <p className="hc-reason">{reason}</p>}
        {estimated and <p className="hc-caveat" role="note">Travel time is a straight-line estimate — actual road time may differ.</p>}
        {children}
    </article>;
}


# ---------------------------------------------------------------------------
# AlternativesList
# ---------------------------------------------------------------------------

"""One row in the alternatives list."""
def _AltRow(
    rank: int,
    name: str,
    city: str,
    sector: str,
    eta_minutes: float,
    free_beds: int,
    unit_type: str,
    reason: str,
    estimated: bool,
) -> JsxElement {
    beds_tone: str = "stable" if free_beds > 2 else ("urgent" if free_beds > 0 else "critical");
    eta_label: str = str(round(eta_minutes)) + " min" + (" est." if estimated else "");
    return <li className="alt-row">
        <span className="alt-rank" aria-hidden="true">{str(rank)}</span>
        <div className="alt-body">
            <div className="alt-name-row">
                <strong className="alt-name">{name}</strong>
                <span className="alt-city">{city + " · " + sector.title()}</span>
            </div>
            <div className="alt-chips">
                <span className={"alt-chip alt-chip--" + beds_tone}>{str(free_beds) + " free " + unit_type.lower() + " beds"}</span>
                <span className="alt-chip alt-chip--eta">{eta_label}</span>
            </div>
            {reason and <p className="alt-reason">{reason}</p>}
        </div>
    </li>;
}

"""Ranked list of alternative hospitals. `picks` is a list of dicts with keys:
name, city, sector, eta_minutes, free_beds, unit_type, reason, estimated."""
def:pub AlternativesList(
    picks: list[dict],
    unit_type: str = "GENERAL",
) -> JsxElement {
    return <section className="alternatives-panel" aria-labelledby="alt-heading">
        <h4 id="alt-heading" className="alt-heading">Other options nearby</h4>
        {if len(picks) == 0 {
            <p className="alt-empty">No other hospitals found for this unit.</p>
        }}
        <ol className="alt-list" aria-label="Alternative hospitals">
            {for (i, p) in enumerate(picks) {
                <_AltRow
                    rank={i + 2}
                    name={p.get("name", "")}
                    city={p.get("city", "")}
                    sector={p.get("sector", "PUBLIC")}
                    eta_minutes={p.get("eta_minutes", 0.0)}
                    free_beds={p.get("free_beds", 0)}
                    unit_type={p.get("unit_type", unit_type)}
                    reason={p.get("reason", "")}
                    estimated={p.get("estimated", False)}
                    key={p.get("hospital_id", str(i))}
                />
            }}
        </ol>
    </section>;
}


# ---------------------------------------------------------------------------
# MapPanel
# ---------------------------------------------------------------------------

"""Leaflet-powered map showing origin, best hospital and optional route line.

Uses Geoapify map tiles (free tier, no token required for the raster style).
The `route_coords` is a list of [lat, lon] pairs from MatchResult.best.route.
`ambulance_progress` is 0..1 (used by T18 dispatch panel; ignored here).
"""
def:pub MapPanel(
    origin_lat: float,
    origin_lon: float,
    hospital_lat: float,
    hospital_lon: float,
    hospital_name: str,
    route_coords: list[list[float]] = [],
    geoapify_key: str = "",
    ambulance_progress: float = 0.0,
    children: any = None,
) -> JsxElement {
    # Encode a compact polyline as a pipe-separated lat,lon list for the
    # Geoapify Static Maps API.  If no key is supplied, fall back to a plain
    # OpenStreetMap iframe embed so the panel is never empty.
    has map_error: bool = False;

    def handle_img_error(_e: Event) {
        map_error = True;
    }

    mid_lat: float = (origin_lat + hospital_lat) / 2.0;
    mid_lon: float = (origin_lon + hospital_lon) / 2.0;

    # Build a Geoapify Static Map URL when a key is available.
    use_static: bool = geoapify_key != "";

    # Encode route as pipe-delimited waypoints (max 50 points to keep URL short).
    route_sample: list[list[float]] = route_coords[::max(1, len(route_coords) // 40)] if len(route_coords) > 0 else [];

    waypoints_str: str = "|".join([str(c[0]) + "," + str(c[1]) for c in route_sample]);

    markers_str: str = (
        "lonlat:" + str(origin_lon) + "," + str(origin_lat) + ";color:#0F766E;size:medium|" +
        "lonlat:" + str(hospital_lon) + "," + str(hospital_lat) + ";color:#DC2626;size:medium"
    );

    polyline_str: str = (
        "polyline:" + waypoints_str + ";linewidth:3;linecolor:#0F766E"
        if len(route_sample) > 0 else ""
    );

    static_url: str = (
        "https://maps.geoapify.com/v1/staticmap?style=osm-carto" +
        "&width=700&height=350" +
        "&center=lonlat:" + str(mid_lon) + "," + str(mid_lat) +
        "&zoom=11" +
        "&marker=" + markers_str +
        (("&geometry=" + polyline_str) if polyline_str != "" else "") +
        "&apiKey=" + geoapify_key
    ) if use_static else "";

    # Fallback OSM iframe (no key required).
    osm_url: str = (
        "https://www.openstreetmap.org/export/embed.html" +
        "?bbox=" + str(min(origin_lon, hospital_lon) - 0.05) +
        "," + str(min(origin_lat, hospital_lat) - 0.05) +
        "," + str(max(origin_lon, hospital_lon) + 0.05) +
        "," + str(max(origin_lat, hospital_lat) + 0.05) +
        "&layer=mapnik" +
        "&marker=" + str(hospital_lat) + "," + str(hospital_lon)
    );

    return <div className="map-panel" aria-label={"Map showing route to " + hospital_name}>
        <div className="map-legend" aria-hidden="true">
            <span className="map-pin map-pin--origin">You</span>
            <span className="map-pin map-pin--hospital">{hospital_name}</span>
            {len(route_coords) > 0 and <span className="map-pin map-pin--route">Route</span>}
        </div>

        {if use_static and not map_error {
            <img
                className="map-static-img"
                src={static_url}
                alt={"Static map showing route from your location to " + hospital_name}
                onError={handle_img_error}
                loading="lazy"
            />
        } else {
            <iframe
                className="map-iframe"
                src={osm_url}
                title={"Map showing route to " + hospital_name}
                loading="lazy"
                referrerpolicy="no-referrer-when-downgrade"
            />
        }}

        <div className="map-footer">
            <span>Map data © OpenStreetMap contributors</span>
            {ambulance_progress > 0.0 and
                <span className="map-ambulance-bar" aria-label={"Ambulance " + str(round(ambulance_progress * 100)) + "% of the way"}>
                    🚑 {str(round(ambulance_progress * 100)) + "% en route"}
                </span>
            }
        </div>
        {children}
    </div>;
}
