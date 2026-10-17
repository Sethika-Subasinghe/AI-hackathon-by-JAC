"""CareRoute - surgery waiting lists (T33).

Many planned operations in Sri Lanka, such as cataract surgery, have long waiting
lists. Hospitals keep the number of patients waiting (and how many operations they
do per week). A patient picks a surgery and CareRoute ranks the hospitals that offer
it by expected wait and distance, then the patient can join that hospital's list.

Expected wait in weeks = patients waiting / operations per week.
"""

import time;
import from models { Hospital, SurgeryList, SurgeryApplication, HasSurgery, HasApplication }
import from graph_lock { GRAPH_LOCK }
import from hospitals { list_hospitals, _session_hospital }
import from geoapify { haversine_km }
import from data.surgery_seed { SURGERY_CATALOG, SURGERY_OFFERS, SurgeryInfo }

"""Each kilometre counts like this many weeks of waiting, so 100 km counts like 10 weeks."""
glob WEEKS_PER_KM: float = 0.1;

"""One hospital that offers a surgery, as shown to the patient."""
obj SurgeryOption {
    has hospital_id: str,
        hospital_name: str,
        sector: str,
        city: str,
        lat: float,
        lon: float,
        distance_km: float,
        waiting: int,
        weekly_capacity: int,
        wait_weeks: float,
        reason: str = "";
}

"""The best hospital for a surgery and the other options in order."""
obj SurgeryChoice {
    has surgery: SurgeryInfo | None = None,
        best: SurgeryOption | None = None,
        alternatives: list[SurgeryOption] = [],
        summary: str = "";
}

"""One surgery on a hospital's own list, for the hospital dashboard."""
obj SurgeryListView {
    has surgery_code: str,
        name: str,
        speciality: str,
        waiting: int,
        weekly_capacity: int,
        wait_weeks: float;
}

"""Result of joining a waiting list."""
obj JoinResult {
    has ok: bool,
        message: str,
        hospital_name: str = "",
        position: int = 0,
        estimated_weeks: float = 0.0;
}

def _info(code: str) -> SurgeryInfo | None {
    for s in SURGERY_CATALOG {
        if s.code == code {
            return s;
        }
    }
    return None;
}

def _weeks(waiting: int, weekly: int) -> float {
    return float(waiting) / float(max(weekly, 1));
}

"""Give every demo hospital its surgery lists, once."""
def _ensure_seeded() {
    list_hospitals();
    with GRAPH_LOCK {
        for h in [root.shared -->][?:Hospital] {
            if len([h ->:HasSurgery:->]) == 0 and h.name in SURGERY_OFFERS {
                for offer in SURGERY_OFFERS[h.name] {
                    h +>:HasSurgery():+> SurgeryList(
                        surgery_code=offer.code,
                        waiting=offer.waiting,
                        weekly_capacity=offer.weekly_capacity,
                        updated_at=time.time()
                    );
                }
            }
        }
    }
}

def _list_for(h: Hospital, code: str) -> SurgeryList | None {
    for sl in [h ->:HasSurgery:->] {
        if sl.surgery_code == code {
            return sl;
        }
    }
    return None;
}

def _list_views(h: Hospital) -> list[SurgeryListView] {
    views: list[SurgeryListView] = [];
    for sl in [h ->:HasSurgery:->] {
        info = _info(sl.surgery_code);
        if info is not None {
            views.append(SurgeryListView(
                surgery_code=sl.surgery_code,
                name=info.name,
                speciality=info.speciality,
                waiting=sl.waiting,
                weekly_capacity=sl.weekly_capacity,
                wait_weeks=_weeks(sl.waiting, sl.weekly_capacity)
            ));
        }
    }
    return sorted(views, key=lambda v: SurgeryListView : v.name);
}

def _weeks_text(weeks: float) -> str {
    if weeks < 1.0 {
        return "less than a week";
    }
    if weeks < 1.5 {
        return "about 1 week";
    }
    return f"about {round(weeks)} weeks";
}

"""The planned surgeries a patient can apply for."""
def:pub list_surgery_catalog() -> list[SurgeryInfo] {
    return SURGERY_CATALOG;
}

"""Rank the hospitals that offer a surgery by expected wait and distance from the patient.
Pass lat and lon as 0 when the location is unknown: then only the wait counts."""
def:pub find_surgery_hospitals(code: str, lat: float, lon: float) -> SurgeryChoice {
    _ensure_seeded();
    info = _info(code);
    if info is None {
        return SurgeryChoice(summary="Please choose a surgery from the list.");
    }
    known = lat != 0.0 or lon != 0.0;
    options: list[SurgeryOption] = [];
    for h in [root.shared -->][?:Hospital] {
        sl = _list_for(h, code);
        if sl is not None {
            distance = haversine_km(lat, lon, h.lat, h.lon) if known else 0.0;
            weeks = _weeks(sl.waiting, sl.weekly_capacity);
            where = f", {round(distance)} km away" if known else "";
            options.append(SurgeryOption(
                hospital_id=jid(h),
                hospital_name=h.name,
                sector=h.sector.name,
                city=h.city,
                lat=h.lat,
                lon=h.lon,
                distance_km=distance,
                waiting=sl.waiting,
                weekly_capacity=sl.weekly_capacity,
                wait_weeks=weeks,
                reason=f"{sl.waiting} patients waiting, {sl.weekly_capacity} operations a week: wait {_weeks_text(weeks)}{where}."
            ));
        }
    }
    if len(options) == 0 {
        return SurgeryChoice(surgery=info, summary=f"No hospital in the demo offers {info.name.lower()} yet.");
    }
    ranked = sorted(options, key=lambda o: SurgeryOption : o.wait_weeks + o.distance_km * WEEKS_PER_KM);
    best = ranked[0];
    summary = f"{best.hospital_name} has the shortest wait for {info.name.lower()}: {_weeks_text(best.wait_weeks)}.";
    return SurgeryChoice(surgery=info, best=best, alternatives=ranked[1:4], summary=summary);
}

"""Join a hospital's waiting list. Returns the place in the queue and the expected wait."""
def:pub join_surgery_list(code: str, hospital_id: str, patient_name: str) -> JoinResult {
    _ensure_seeded();
    name = patient_name.strip();
    if name == "" {
        return JoinResult(ok=False, message="Please enter your name to join the list.");
    }
    with GRAPH_LOCK {
        for h in [root.shared -->][?:Hospital] {
            if jid(h) == hospital_id {
                sl = _list_for(h, code);
                if sl is None {
                    return JoinResult(ok=False, message="This hospital does not offer that surgery.");
                }
                sl.waiting += 1;
                sl.updated_at = time.time();
                sl +>:HasApplication():+> SurgeryApplication(
                    surgery_code=code,
                    hospital_id=hospital_id,
                    patient_name=name,
                    position=sl.waiting,
                    applied_at=time.time()
                );
                weeks = _weeks(sl.waiting, sl.weekly_capacity);
                return JoinResult(
                    ok=True,
                    message=f"{name}, you are number {sl.waiting} on the list at {h.name}. Expected wait: {_weeks_text(weeks)}. The hospital will contact you.",
                    hospital_name=h.name,
                    position=sl.waiting,
                    estimated_weeks=weeks
                );
            }
        }
    }
    return JoinResult(ok=False, message="We could not find that hospital.");
}

# ---------------- hospital side (needs the staff token from hospital_login) ----------------

"""The signed-in hospital's surgery lists, or None when the token is missing or expired."""
def:pub my_surgery_lists(token: str) -> list[SurgeryListView] | None {
    _ensure_seeded();
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    return _list_views(h);
}

"""Set how many patients are waiting for a surgery. Never below 0."""
def:pub set_surgery_waiting(token: str, code: str, waiting: int) -> list[SurgeryListView] | None {
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    sl = _list_for(h, code);
    if sl is not None {
        sl.waiting = max(0, waiting);
        sl.updated_at = time.time();
    }
    return _list_views(h);
}

"""Add or remove patients with the stepper, for example delta=-1."""
def:pub change_surgery_waiting(token: str, code: str, delta: int) -> list[SurgeryListView] | None {
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    sl = _list_for(h, code);
    if sl is not None {
        sl.waiting = max(0, sl.waiting + delta);
        sl.updated_at = time.time();
    }
    return _list_views(h);
}

"""Change how many operations the hospital does per week (at least 1)."""
def:pub change_surgery_capacity(token: str, code: str, delta: int) -> list[SurgeryListView] | None {
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    sl = _list_for(h, code);
    if sl is not None {
        sl.weekly_capacity = max(1, sl.weekly_capacity + delta);
        sl.updated_at = time.time();
    }
    return _list_views(h);
}

"""Start offering a surgery (empty list) or stop offering it."""
def:pub set_surgery_offered(token: str, code: str, offered: bool) -> list[SurgeryListView] | None {
    h = _session_hospital(token);
    if h is None or _info(code) is None {
        return None if h is None else _list_views(h);
    }
    with GRAPH_LOCK {
        sl = _list_for(h, code);
        if offered and sl is None {
            h +>:HasSurgery():+> SurgeryList(surgery_code=code, waiting=0, weekly_capacity=5, updated_at=time.time());
        }
        if (not offered) and sl is not None {
            del sl;
        }
    }
    return _list_views(h);
}

"""Put every waiting list back to its demo numbers (used by "Reset demo data")."""
def reset_surgery_lists() -> int {
    removed = 0;
    with GRAPH_LOCK {
        for h in [root.shared -->][?:Hospital] {
            for sl in [h ->:HasSurgery:->] {
                for application in [sl ->:HasApplication:->] {
                    del application;
                }
                del sl;
                removed += 1;
            }
        }
    }
    _ensure_seeded();
    return removed;
}
