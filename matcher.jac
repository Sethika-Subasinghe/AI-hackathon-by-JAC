"""CareRoute - Hospital Matcher Agent (T15).

Picks the best hospital with free beds for the unit a case needs and explains
why. The ranking is deterministic so the demo never breaks:

1. `find_hospitals`: hospitals with a free bed in the needed unit, minus excluded ones,
2. the nearest few get a real route and ETA from Geoapify (`get_route`),
3. `score_hospital` ranks them (critical: speed first, stable: also load and sector),
4. `explain_picks` (by llm) words the reasons, with templates as the fallback.

`match_case` also serves the Re-plan Agent (T20): add ids to the case's
`excluded_hospital_ids` and call it again.
"""

import from models { CaseState, CaseStatus, EventStatus, Severity, UnitType }
import from agent_log { start_event, finish_event, find_case }
import from reliability { model_available, record_model_success, record_model_failure }
import from hospitals { list_hospitals, HospitalView }
import from geoapify { get_route, haversine_km, DEFAULT_DRIVE_SPEED_KMH }

"""One hospital in the ranking. `estimated` is true when the ETA is a straight-line estimate."""
obj HospitalPick {
    has hospital_id: str,
        name: str,
        sector: str,
        city: str,
        lat: float,
        lon: float,
        eta_minutes: float,
        distance_km: float,
        free_beds: int,
        total_beds: int,
        score: float = 0.0,
        estimated: bool = False,
        reason: str = "",
        route: list[list[float]] = [],
        steps: list[str] = [];
}

"""Best hospital plus ranked alternatives."""
obj MatchResult {
    has best: HospitalPick | None = None,
        alternatives: list[HospitalPick] = [],
        summary: str = "",
        used_fallback: bool = False;
}

glob MAX_ROUTED: int = 5;
glob MAX_ALTERNATIVES: int = 3;
# Tests turn live services (Geoapify routes, the model) off.
glob LIVE_SERVICES: dict[str, bool] = {"on": True};
glob matches: dict[str, MatchResult] = {};

def _unit_free(h: HospitalView, unit_name: str) -> int {
    for u in h.units {
        if u.unit_type == unit_name {
            return u.free;
        }
    }
    return 0;
}

def _unit_total(h: HospitalView, unit_name: str) -> int {
    for u in h.units {
        if u.unit_type == unit_name {
            return u.total;
        }
    }
    return 0;
}

"""Hospitals with a free bed in the unit, leaving out excluded ids."""
def find_hospitals(
    hospitals: list[HospitalView],
    unit_name: str,
    exclude: list[str]
) -> list[HospitalView] {
    return [
        h for h in hospitals
        if h.id not in exclude and _unit_free(h, unit_name) > 0
    ];
}

"""Higher is better. Critical cases weigh speed and capacity, stable cases also load and sector."""
def score_hospital(
    severity: Severity,
    eta_minutes: float,
    free_beds: int,
    total_beds: int,
    sector: str,
    icu_free: int
) -> float {
    capped_free = float(min(free_beds, 5));
    if severity == Severity.CRITICAL {
        icu_bonus = 3.0 if icu_free > 0 else 0.0;
        return 100.0 - eta_minutes * 1.0 + capped_free * 2.0 + icu_bonus;
    }
    if severity == Severity.URGENT {
        return 100.0 - eta_minutes * 0.8 + capped_free * 3.0;
    }
    ratio = float(free_beds) / float(max(total_beds, 1));
    public_bonus = 2.0 if sector == "PUBLIC" else 0.0;
    return 100.0 - eta_minutes * 0.5 + ratio * 10.0 + public_bonus;
}

def _template_reason(p: HospitalPick, unit_name: str, best: bool) -> str {
    how = "estimated" if p.estimated else "by road";
    bed_word = "bed" if p.free_beds == 1 else "beds";
    text = f"About {round(p.eta_minutes)} min away ({how}), {p.free_beds} free {unit_name.lower()} {bed_word}, {p.sector.lower()} hospital";
    if best {
        return "Best match: " + text;
    }
    return text;
}

"""Write one short plain sentence per hospital, in the same order."""
def explain_picks(severity: str, unit_name: str, facts: list[str]) -> list[str] by llm(temperature=0.2);
sem explain_picks = "Explain in one short plain sentence each why a hospital suits a patient who needs this unit. Mention travel time and free beds. Never diagnose. Return exactly one sentence per fact line, in the same order.";
sem explain_picks.severity = "CRITICAL, URGENT or STABLE.";
sem explain_picks.unit_name = "The unit needed.";
sem explain_picks.facts = "One line per hospital with its name, ETA, free beds and sector, best first.";

def _make_pick(h: HospitalView, unit_name: str, origin_lat: float, origin_lon: float) -> HospitalPick {
    distance = haversine_km(origin_lat, origin_lon, h.lat, h.lon);
    eta = distance / DEFAULT_DRIVE_SPEED_KMH * 60.0;
    estimated = True;
    coords: list[list[float]] = [];
    directions: list[str] = [];
    if LIVE_SERVICES["on"] {
        route = get_route(origin_lat, origin_lon, h.lat, h.lon);
        distance = route.distance_km;
        eta = route.eta_minutes;
        estimated = route.estimated;
        coords = route.coordinates;
        directions = route.steps;
    }
    return HospitalPick(
        hospital_id=h.id,
        name=h.name,
        sector=h.sector,
        city=h.city,
        lat=h.lat,
        lon=h.lon,
        eta_minutes=eta,
        distance_km=distance,
        free_beds=_unit_free(h, unit_name),
        total_beds=_unit_total(h, unit_name),
        estimated=estimated,
        route=coords,
        steps=directions
    );
}

"""Rank hospitals for a unit and a starting point. Pure function, easy to test."""
def rank_hospitals(
    hospitals: list[HospitalView],
    unit_name: str,
    severity: Severity,
    origin_lat: float,
    origin_lon: float,
    exclude: list[str]
) -> MatchResult {
    candidates = find_hospitals(hospitals, unit_name, exclude);
    if len(candidates) == 0 {
        # Nobody has a free bed: show the nearest remaining hospital and say so.
        rest = [h for h in hospitals if h.id not in exclude];
        if len(rest) == 0 {
            return MatchResult(summary="No hospital is available. Please call 1990.");
        }
        nearest = sorted(rest, key=lambda h: HospitalView : haversine_km(origin_lat, origin_lon, h.lat, h.lon))[0];
        pick = _make_pick(nearest, unit_name, origin_lat, origin_lon);
        pick.reason = f"No free {unit_name.lower()} beds anywhere right now. This is the nearest hospital, please call ahead or dial 1990.";
        return MatchResult(best=pick, summary="No hospital has a free bed for this unit. Showing the nearest hospital.");
    }
    nearest_few = sorted(
        candidates,
        key=lambda h: HospitalView : haversine_km(origin_lat, origin_lon, h.lat, h.lon)
    )[:MAX_ROUTED];
    picks: list[HospitalPick] = [];
    for h in nearest_few {
        p = _make_pick(h, unit_name, origin_lat, origin_lon);
        p.score = score_hospital(
            severity, p.eta_minutes, p.free_beds, p.total_beds, p.sector, _unit_free(h, "ICU")
        );
        picks.append(p);
    }
    picks = sorted(picks, key=lambda p: HospitalPick : -p.score);
    for i in range(len(picks)) {
        picks[i].reason = _template_reason(picks[i], unit_name, i == 0);
    }
    best = picks[0];
    alts = picks[1:1 + MAX_ALTERNATIVES];
    summary = f"{best.name} is the best match: about {round(best.eta_minutes)} min away with {best.free_beds} free {unit_name.lower()} beds.";
    return MatchResult(best=best, alternatives=alts, summary=summary);
}

"""Match a case: rank hospitals, word the reasons, write the choice onto the case and log it."""
def match_case(cs: CaseState) -> MatchResult {
    ev = start_event(cs, "matcher", "find_hospital", "Looking for the best hospital");
    unit_name = cs.unit_needed.name;
    result = rank_hospitals(
        list_hospitals(),
        unit_name,
        cs.severity,
        cs.origin.lat,
        cs.origin.lon,
        cs.excluded_hospital_ids
    );
    best = result.best;
    if best is None {
        matches[jid(cs)] = result;
        finish_event(ev, EventStatus.FAILED, "No hospital found", result.summary);
        return result;
    }
    if LIVE_SERVICES["on"] and model_available() and len(result.alternatives) > 0 and best.free_beds > 0 {
        shown = [best] + result.alternatives;
        facts = [
            f"{p.name}: {round(p.eta_minutes)} min, {p.free_beds} free beds, {p.sector.lower()}"
            for p in shown
        ];
        try {
            sentences = explain_picks(cs.severity.name, unit_name, facts);
            record_model_success();
            if len(sentences) == len(shown) {
                for i in range(len(shown)) {
                    shown[i].reason = sentences[i];
                }
            }
        } except Exception as err {
            record_model_failure(str(err));
            result.used_fallback = True;
        }
    }
    cs.hospital_id = best.hospital_id;
    cs.eta_minutes = best.eta_minutes;
    cs.status = CaseStatus.MATCHED;
    cs.used_fallback = cs.used_fallback or result.used_fallback or best.estimated;
    matches[jid(cs)] = result;
    detail = result.summary;
    if best.estimated {
        detail += " The travel time is an estimate.";
    }
    finish_event(ev, EventStatus.DONE, f"Best hospital: {best.name}", detail);
    return result;
}

"""The last match for a case (best hospital, alternatives with reasons), or None."""
def:pub get_match(case_id: str) -> MatchResult | None {
    # Reading the case from the graph (not only the dict) lets the server see that the case
    # changed, so it does not serve a cached answer after a re-plan.
    cs = find_case(case_id);
    if cs is None {
        return None;
    }
    return matches.get(case_id, None);
}
