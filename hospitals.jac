"""CareRoute - hospital login and bed-update backend (T06).

Hospital data lives on the shared public graph (`root.shared`) so anonymous
patients can read it. Hospital staff sign in with `hospital_login` and send
the returned token to the write endpoints. Demo-grade auth: session tokens
are kept in memory and passwords are hashed with SHA-256 (production auth
hardening is out of scope, see plan.md).
"""

import hashlib;
import secrets;
import time;
import from models { Hospital, Unit, BedStatus, HasUnit, HasBeds, Sector, UnitType }
import from graph_lock { GRAPH_LOCK }
import from data.hospital_seed { DEMO_HOSPITAL_PASSWORD, hospital_seed_data }

"""Beds for one unit, as sent to the UI."""
obj UnitView {
    has unit_type: str,
        total: int,
        free: int;
}

"""A hospital with its units, as sent to the UI."""
obj HospitalView {
    has id: str,
        name: str,
        sector: str,
        city: str,
        lat: float,
        lon: float,
        units: list[UnitView] = [];
}

"""Result of a hospital login attempt."""
obj LoginResult {
    has ok: bool,
        token: str = "",
        hospital_id: str = "",
        message: str = "";
}

glob sessions: dict[str, str] = {};

def _hash(password: str) -> str {
    return hashlib.sha256(password.encode()).hexdigest();
}

def _unit_views(h: Hospital) -> list[UnitView] {
    views: list[UnitView] = [];
    for u in [h ->:HasUnit:->] {
        for b in [u ->:HasBeds:->] {
            views.append(UnitView(unit_type=u.unit_type.name, total=b.total, free=b.free));
        }
    }
    return views;
}

def _view(h: Hospital) -> HospitalView {
    return HospitalView(
        id=jid(h),
        name=h.name,
        sector=h.sector.name,
        city=h.city,
        lat=h.lat,
        lon=h.lon,
        units=_unit_views(h)
    );
}

def _find_hospital(hospital_id: str) -> Hospital | None {
    for h in [root.shared -->][?:Hospital] {
        if jid(h) == hospital_id {
            return h;
        }
    }
    return None;
}

def _session_hospital(token: str) -> Hospital | None {
    hospital_id = sessions.get(token, "");
    if hospital_id == "" {
        return None;
    }
    return _find_hospital(hospital_id);
}

"""Create a hospital with units. `units` maps a UnitType name to its bed
count, e.g. {"ICU": 10, "CARDIAC": 6}; every bed starts free. T04 (seed
data) calls this."""
# jac:ignore[W3030] Public seed API mirrors all required Hospital fields.
def add_hospital(
    name: str,
    sector: Sector,
    city: str,
    lat: float,
    lon: float,
    username: str,
    password: str,
    units: dict[str, int]
) -> Hospital {
    h = (root.shared ++> Hospital(
        name=name,
        sector=sector,
        city=city,
        lat=lat,
        lon=lon,
        username=username,
        password_hash=_hash(password)
    ))[0];
    for ut in UnitType {
        if ut.name in units {
            u = (h +>:HasUnit():+> Unit(unit_type=ut))[0];
            beds = units[ut.name];
            u +>:HasBeds():+> BedStatus(total=beds, free=beds, updated_at=time.time());
        }
    }
    return h;
}

"""Create missing fictional hospitals and their initial free-bed counts."""
def _seed_demo_hospitals -> int {
    with GRAPH_LOCK {
        existing_names = {h.name for h in [root.shared -->][?:Hospital]};
        created = 0;
        for seed in hospital_seed_data() {
            if seed.name not in existing_names {
                totals = {
                    unit.unit_type.name: unit.total_beds
                    for unit in seed.units
                };
                hospital = add_hospital(
                    name=seed.name,
                    sector=seed.sector,
                    city=seed.city,
                    lat=seed.lat,
                    lon=seed.lon,
                    username=seed.username,
                    password=DEMO_HOSPITAL_PASSWORD,
                    units=totals,
                );
                hospital.phone = seed.phone;
                for unit in seed.units {
                    _set_free(hospital, unit.unit_type.name, unit.free_beds);
                }
                existing_names.add(seed.name);
                created += 1;
            }
        }
        return created;
    }
}

"""Restore the fictional demo hospitals to their original bed counts and clear staff sessions."""
def reset_demo_hospitals -> int {
    _seed_demo_hospitals();
    seeds = hospital_seed_data();
    restored = 0;
    for h in [root.shared -->][?:Hospital] {
        for seed in seeds {
            if h.name == seed.name {
                for unit in seed.units {
                    _set_free(h, unit.unit_type.name, unit.free_beds);
                }
                restored += 1;
                break;
            }
        }
    }
    sessions.clear();
    return restored;
}

def _set_free(h: Hospital, unit_type: str, free: int) {
    for u in [h ->:HasUnit:->] {
        if u.unit_type.name == unit_type {
            for b in [u ->:HasBeds:->] {
                b.free = max(0, min(free, b.total));
                b.updated_at = time.time();
            }
        }
    }
}

def _current_free(h: Hospital, unit_type: str) -> int {
    for u in [h ->:HasUnit:->] {
        if u.unit_type.name == unit_type {
            for b in [u ->:HasBeds:->] {
                return b.free;
            }
        }
    }
    return 0;
}

"""All hospitals with their bed counts (patients and the matcher read this)."""
def:pub list_hospitals -> list[HospitalView] {
    _seed_demo_hospitals();
    return [_view(h) for h in [root.shared -->][?:Hospital]];
}

"""One hospital by id, or None."""
def:pub get_hospital(hospital_id: str) -> HospitalView | None {
    h = _find_hospital(hospital_id);
    if h is None {
        return None;
    }
    return _view(h);
}

"""Hospital staff sign in. Returns a token to send to the write endpoints."""
def:pub hospital_login(username: str, password: str) -> LoginResult {
    for h in [root.shared -->][?:Hospital] {
        if h.username == username and h.username != "" {
            if h.password_hash == _hash(password) {
                token = secrets.token_hex(16);
                sessions[token] = jid(h);
                return LoginResult(ok=True, token=token, hospital_id=jid(h), message="Signed in");
            }
        }
    }
    return LoginResult(ok=False, message="Wrong username or password");
}

"""End a hospital session."""
def:pub hospital_logout(token: str) -> bool {
    if token in sessions {
        sessions.pop(token);
        return True;
    }
    return False;
}

"""The signed-in hospital, or None when the token is missing or expired."""
def:pub my_hospital(token: str) -> HospitalView | None {
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    return _view(h);
}

"""Set the free beds of one unit (0 up to its total). None if not signed in."""
def:pub set_free_beds(token: str, unit_type: str, free: int) -> HospitalView | None {
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    _set_free(h, unit_type, free);
    return _view(h);
}

"""Add or remove beds with the stepper, e.g. delta=-1. None if not signed in."""
def:pub change_free_beds(token: str, unit_type: str, delta: int) -> HospitalView | None {
    h = _session_hospital(token);
    if h is None {
        return None;
    }
    _set_free(h, unit_type, _current_free(h, unit_type) + delta);
    return _view(h);
}
