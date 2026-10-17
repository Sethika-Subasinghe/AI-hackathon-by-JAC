"""CareRoute - Geoapify location services (T14).

Forward geocoding and autocomplete are restricted to Sri Lanka. Successful
responses are cached in memory to protect the free API quota. Routing falls
back to a clearly labelled straight-line estimate when Geoapify is unavailable.
"""

import json;
import math;
import os;
import from urllib.parse { urlencode }
import from urllib.request { Request, urlopen }

glob GEOAPIFY_BASE_URL: str = "https://api.geoapify.com/v1",
    DEFAULT_DRIVE_SPEED_KMH: float = 40.0,
    geocode_cache: dict[str, GeocodeResult] = {},
    autocomplete_cache: dict[str, list[AddressSuggestion]] = {},
    route_cache: dict[str, RouteResult] = {};

"""One normalized address suggestion for the patient location field."""
obj AddressSuggestion {
    has label: str,
        lat: float,
        lon: float,
        city: str = "",
        postcode: str = "";
}

"""Result of resolving an address to coordinates."""
obj GeocodeResult {
    has ok: bool,
        label: str = "",
        lat: float = 0.0,
        lon: float = 0.0,
        message: str = "";
}

"""Driving route and ETA. `estimated` is true only for the fallback."""
obj RouteResult {
    has ok: bool,
        distance_km: float,
        eta_minutes: float,
        coordinates: list[list[float]] = [],
        estimated: bool = False,
        message: str = "";
}

def _api_key -> str {
    key = os.getenv("GEOAPIFY_API_KEY", "").strip();
    if key != "" {
        return key;
    }
    try {
        with open(".env", encoding="utf-8") as env_file {
            for raw_line in env_file {
                line = raw_line.strip();
                if line.startswith("GEOAPIFY_API_KEY=") {
                    return line.split("=", 1)[1].strip().strip("\"").strip("'");
                }
            }
        }
    } except OSError {
        return "";
    }
    return "";
}

def _cache_key(text: str) -> str {
    return " ".join(text.lower().strip().split());
}

def _get_json(path: str, parameters: dict[str, str]) -> any {
    params = dict(parameters);
    params["apiKey"] = _api_key();
    url = f"{GEOAPIFY_BASE_URL}{path}?{urlencode(params)}";
    request = Request(url, headers={"User-Agent": "CareRoute/0.1"});
    response = urlopen(request, timeout=10);
    raw = response.read() as bytes;
    response.close();
    return json.loads(raw.decode("utf-8"));
}

def _suggestion(item: any) -> AddressSuggestion {
    return AddressSuggestion(
        label=str(item.get("formatted", "")),
        lat=float(item.get("lat", 0.0) as float),
        lon=float(item.get("lon", 0.0) as float),
        city=str(item.get("city", item.get("county", ""))),
        postcode=str(item.get("postcode", ""))
    );
}

def _route_coordinates(geometry: any) -> list[list[float]] {
    points: list[list[float]] = [];
    if geometry.get("type", "") == "LineString" {
        for raw_point in geometry.get("coordinates", []) {
            point = raw_point as list[float];
            points.append([float(point[1]), float(point[0])]);
        }
    } elif geometry.get("type", "") == "MultiLineString" {
        for raw_line in geometry.get("coordinates", []) {
            line = raw_line as list[list[float]];
            for point in line {
                points.append([float(point[1]), float(point[0])]);
            }
        }
    }
    return points;
}

"""Great-circle distance in kilometres."""
def haversine_km(
    origin_lat: float,
    origin_lon: float,
    destination_lat: float,
    destination_lon: float
) -> float {
    lat_delta = math.radians(destination_lat - origin_lat);
    lon_delta = math.radians(destination_lon - origin_lon);
    start_lat = math.radians(origin_lat);
    end_lat = math.radians(destination_lat);
    a = (
        math.sin(lat_delta / 2.0) ** 2
        + math.cos(start_lat)
        * math.cos(end_lat)
        * math.sin(lon_delta / 2.0) ** 2
    );
    return 6371.0 * 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
}

def _fallback_route(
    origin_lat: float,
    origin_lon: float,
    destination_lat: float,
    destination_lon: float,
    reason: str
) -> RouteResult {
    distance = haversine_km(
        origin_lat, origin_lon, destination_lat, destination_lon
    );
    return RouteResult(
        ok=True,
        distance_km=distance,
        eta_minutes=(distance / DEFAULT_DRIVE_SPEED_KMH) * 60.0,
        coordinates=[
            [origin_lat, origin_lon],
            [destination_lat, destination_lon]
        ],
        estimated=True,
        message=f"Estimated from straight-line distance: {reason}"
    );
}

"""Resolve a Sri Lankan address. Empty or failed lookups return `ok=False`."""
def:pub geocode(query: str) -> GeocodeResult {
    key = _cache_key(query);
    if key == "" {
        return GeocodeResult(ok=False, message="Enter an address");
    }
    if key in geocode_cache {
        return geocode_cache[key];
    }
    if _api_key() == "" {
        return GeocodeResult(ok=False, message="Geoapify API key is not configured");
    }
    try {
        data = _get_json(
            "/geocode/search",
            {"text": query, "filter": "countrycode:lk", "limit": "1", "format": "json"}
        );
        results = data.get("results", []) as list[any];
        if len(results) == 0 {
            return GeocodeResult(ok=False, message="Address not found");
        }
        item = results[0];
        result = GeocodeResult(
            ok=True,
            label=str(item.get("formatted", query)),
            lat=float(item.get("lat", 0.0) as float),
            lon=float(item.get("lon", 0.0) as float)
        );
        geocode_cache[key] = result;
        return result;
    } except Exception {
        return GeocodeResult(ok=False, message="Address lookup is temporarily unavailable");
    }
}

"""Autocomplete a partial Sri Lankan address, with at most 10 suggestions."""
def:pub autocomplete(query: str, limit: int = 5) -> list[AddressSuggestion] {
    safe_limit = max(1, min(limit, 10));
    key = f"{_cache_key(query)}:{safe_limit}";
    if len(query.strip()) < 2 {
        return [];
    }
    if key in autocomplete_cache {
        return autocomplete_cache[key];
    }
    if _api_key() == "" {
        return [];
    }
    try {
        data = _get_json(
            "/geocode/autocomplete",
            {
                "text": query,
                "filter": "countrycode:lk",
                "limit": str(safe_limit),
                "format": "json"
            }
        );
        items = data.get("results", []) as list[any];
        suggestions = [_suggestion(item) for item in items];
        autocomplete_cache[key] = suggestions;
        return suggestions;
    } except Exception {
        return [];
    }
}

"""Return a cached Geoapify driving route or a labelled distance estimate."""
def:pub get_route(
    origin_lat: float,
    origin_lon: float,
    destination_lat: float,
    destination_lon: float
) -> RouteResult {
    key = (
        f"{origin_lat:.5f},{origin_lon:.5f}|"
        f"{destination_lat:.5f},{destination_lon:.5f}"
    );
    if key in route_cache {
        return route_cache[key];
    }
    if _api_key() == "" {
        result = _fallback_route(
            origin_lat, origin_lon, destination_lat, destination_lon,
            "routing service is not configured"
        );
        route_cache[key] = result;
        return result;
    }
    try {
        data = _get_json(
            "/routing",
            {
                "waypoints": (
                    f"{origin_lat},{origin_lon}|"
                    f"{destination_lat},{destination_lon}"
                ),
                "mode": "drive"
            }
        );
        features = data.get("features", []) as list[any];
        if len(features) == 0 {
            raise ValueError("route not found");
        }
        feature = features[0];
        properties = feature.get("properties", {});
        result = RouteResult(
            ok=True,
            distance_km=float(properties.get("distance", 0.0) as float) / 1000.0,
            eta_minutes=float(properties.get("time", 0.0) as float) / 60.0,
            coordinates=_route_coordinates(feature.get("geometry", {}))
        );
        route_cache[key] = result;
        return result;
    } except Exception {
        result = _fallback_route(
            origin_lat, origin_lon, destination_lat, destination_lon,
            "live routing was unavailable"
        );
        route_cache[key] = result;
        return result;
    }
}

"""Convenience tool used by the Hospital Matcher Agent."""
def:pub get_eta(
    origin_lat: float,
    origin_lon: float,
    destination_lat: float,
    destination_lon: float
) -> float {
    return get_route(
        origin_lat, origin_lon, destination_lat, destination_lon
    ).eta_minutes;
}
