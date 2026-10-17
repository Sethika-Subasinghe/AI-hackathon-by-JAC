"""Map of the patient, the chosen hospital, alternatives, the route and the ambulance (Leaflet)."""

import "leaflet/dist/leaflet.css";
import "../assets/map.css";
import from react { useEffect }
import from "leaflet" { map as leaflet_map, tileLayer, marker, polyline, latLngBounds, divIcon }
sv import from mapconfig { MapConfig, get_map_config }
sv import from matcher { HospitalPick }

"""Straight-line distance in kilometres (for the live "to go" number)."""
def _km_between(lat1: float, lon1: float, lat2: float, lon2: float) -> float {
    m: any = Math;
    rad: float = 3.141592653589793 / 180.0;
    d_lat: float = (lat2 - lat1) * rad;
    d_lon: float = (lon2 - lon1) * rad;
    s_lat: float = m.sin(d_lat / 2.0) as float;
    s_lon: float = m.sin(d_lon / 2.0) as float;
    c1: float = m.cos(lat1 * rad) as float;
    c2: float = m.cos(lat2 * rad) as float;
    a: float = s_lat * s_lat + c1 * c2 * s_lon * s_lon;
    root_a: float = m.sqrt(a) as float;
    root_b: float = m.sqrt(1.0 - a) as float;
    return 6371.0 * 2.0 * (m.atan2(root_a, root_b) as float);
}

def _dot(kind: str, label: str) -> any {
    return divIcon({"className": "map-pin " + kind, "html": "<span>" + label + "</span>", "iconSize": [30, 30], "iconAnchor": [15, 15]});
}

"""Where the ambulance is along the route, 0.0 (start) to 1.0 (arrived)."""
def _along(route: list[list[float]], progress: float) -> list[float] {
    count = len(route);
    index = int(progress * float(count - 1));
    return route[max(0, min(count - 1, index))];
}

def:pub MapPanel(
    origin_lat: float,
    origin_lon: float,
    best: HospitalPick | None,
    alternatives: list[HospitalPick],
    ambulance_progress: float = 0.0,
) -> JsxElement {
    has container: Ref[any] = Ref(),
        map_ref: Ref[any] = Ref(),
        layers_ref: Ref[any] = Ref(),
        ambulance_ref: Ref[any] = Ref(),
        cleared_ref: Ref[any] = Ref(),
        me_ref: Ref[any] = Ref(),
        config: MapConfig | None = None,
        following: bool = False,
        my_lat: float = 0.0,
        my_lon: float = 0.0,
        follow_note: str = "";

    def toggle_follow(_e: MouseEvent) {
        follow_note = "";
        following = not following;
    }

    # Load the tile settings once.
    async def load_config() -> None {
        config = await get_map_config();
    }

    useEffect(lambda { load_config(); return lambda {}; }, []);

    # Create the map once the tile settings and the container exist.
    useEffect(lambda {
        if config is not None and container.current and not map_ref.current {
            m: any = leaflet_map(container.current, {"scrollWheelZoom": False});
            tileLayer(config.tile_url, {"attribution": config.attribution, "maxZoom": 18}).addTo(m);
            m.setView([origin_lat, origin_lon], 12);
            map_ref.current = m;  # jac:ignore[E1001]
            layers_ref.current = None;
        }
        return lambda {};
    }, [config]);

    # Redraw markers and the route when the choice changes.
    best_id: str = best.hospital_id if best is not None else "";
    route_size: int = len(best.route) if best is not None else 0;
    useEffect(lambda {
        m: any = map_ref.current;
        if m and best is not None {
            # Clear the previous hospital's markers and route, and the ambulance that followed it.
            if layers_ref.current {
                for old in layers_ref.current {
                    m.removeLayer(old);
                }
            }
            if ambulance_ref.current {
                m.removeLayer(ambulance_ref.current);
                ambulance_ref.current = None;  # jac:ignore[E1001]
            }
            if cleared_ref.current {
                m.removeLayer(cleared_ref.current);
                cleared_ref.current = None;  # jac:ignore[E1001]
            }
            origin_marker: any = marker([origin_lat, origin_lon], {"icon": _dot("patient", "P"), "title": "Patient"});
            best_marker: any = marker([best.lat, best.lon], {"icon": _dot("best", "H"), "title": best.name});
            origin_marker.addTo(m);
            best_marker.addTo(m);
            made: list[any] = [origin_marker, best_marker];
            bounds: any = latLngBounds([[origin_lat, origin_lon], [best.lat, best.lon]]);
            for alt in alternatives {
                alt_marker: any = marker([alt.lat, alt.lon], {"icon": _dot("alt", "+"), "title": alt.name});
                alt_marker.addTo(m);
                made.append(alt_marker);
            }
            if len(best.route) > 1 {
                line: any = polyline(best.route, {"color": "#0f766e", "weight": 5, "opacity": 0.85});
                line.addTo(m);
                made.append(line);
                bounds.extend(best.route);
            }
            layers_ref.current = made;  # jac:ignore[E1001]
            m.fitBounds(bounds, {"padding": [30, 30]});
        }
        return lambda {};
    }, [best_id, route_size, config]);

    # Follow the patient's own position (their phone's GPS) while they travel.
    useEffect(lambda {
        nav: any = navigator;
        if following and nav.geolocation {
            watch_id: any = nav.geolocation.watchPosition(
                lambda(pos: any) {
                    my_lat = pos.coords.latitude as float;
                    my_lon = pos.coords.longitude as float;
                },
                lambda(_err: any) {
                    follow_note = "We could not read your location. Allow location access and try again.";
                    following = False;
                },
                {"enableHighAccuracy": True, "maximumAge": 2000}
            );
            return lambda { nav.geolocation.clearWatch(watch_id); };
        }
        return lambda {};
    }, [following]);

    # Draw "you are here" and keep it in view.
    useEffect(lambda {
        m: any = map_ref.current;
        if m and following and my_lat != 0.0 {
            if me_ref.current {
                me_ref.current.setLatLng([my_lat, my_lon]);
            } else {
                me: any = marker([my_lat, my_lon], {"icon": _dot("me", "Me"), "title": "You are here", "zIndexOffset": 900});
                me.addTo(m);
                me_ref.current = me;  # jac:ignore[E1001]
            }
            m.panTo([my_lat, my_lon]);
        }
        if m and not following and me_ref.current {
            m.removeLayer(me_ref.current);
            me_ref.current = None;  # jac:ignore[E1001]
        }
        return lambda {};
    }, [my_lat, my_lon, following]);

    km_left: float = -1.0;
    if following and my_lat != 0.0 and best is not None {
        km_left = _km_between(my_lat, my_lon, best.lat, best.lon);
    }

    # Move the ambulance marker along the route.
    useEffect(lambda {
        m: any = map_ref.current;
        if m and best is not None and len(best.route) > 1 and ambulance_progress > 0.0 {
            spot: list[float] = _along(best.route, ambulance_progress);
            # Blue line = the part of the route police have cleared so far (simulated).
            done: int = max(1, int(ambulance_progress * float(len(best.route) - 1)) + 1);
            cleared_path: list[list[float]] = best.route[0:done];
            if cleared_ref.current {
                cleared_ref.current.setLatLngs(cleared_path);
            } else {
                cleared: any = polyline(cleared_path, {"color": "#2563eb", "weight": 7, "opacity": 0.9});
                cleared.addTo(m);
                cleared_ref.current = cleared;  # jac:ignore[E1001]
            }
            if ambulance_ref.current {
                ambulance_ref.current.setLatLng(spot);
            } else {
                amb: any = marker(spot, {"icon": _dot("ambulance", "A"), "title": "Ambulance (simulated)", "zIndexOffset": 1000});
                amb.addTo(m);
                ambulance_ref.current = amb;  # jac:ignore[E1001]
            }
        }
        return lambda {};
    }, [ambulance_progress, best_id]);

    return <section className="map-panel" aria-label="Map of the route to the hospital">
        <div className="map-follow">
            <button type="button" className={"follow-button" + (" on" if following else "")} onClick={toggle_follow} aria-pressed={following}>
                {"Stop following me" if following else "Follow my location"}
            </button>
            {if km_left >= 0.0 {
                <span className="follow-km" role="status">{f"{km_left:.1f} km to the hospital"}</span>
            }}
            {if follow_note != "" {
                <span className="follow-error" role="alert">{follow_note}</span>
            }}
        </div>
        <div ref={container} className="map-canvas" role="img" aria-label="Map with the patient, hospital and route"></div>
        <ul className="map-legend" aria-hidden="true">
            <li><span className="map-pin patient"><span>P</span></span> You</li>
            <li><span className="map-pin best"><span>H</span></span> Best hospital</li>
            <li><span className="map-pin alt"><span>+</span></span> Alternatives</li>
            <li><span className="map-pin ambulance"><span>A</span></span> Ambulance (simulated)</li>
            {if following {
                <li><span className="map-pin me"><span>Me</span></span> You (live)</li>
            }}
            <li><span className="map-line-key"></span> Route cleared by police (simulated)</li>
        </ul>
    </section>;
}
