"""Tests for the Geoapify adapter. Network calls are excluded."""

test "normalizes cache keys and validates short queries" {
    assert _cache_key("  Colombo   Fort ") == "colombo fort";
    assert autocomplete(" ") == [];
    assert not geocode(" ").ok;
}

test "calculates distance and labelled fallback ETA" {
    assert haversine_km(6.9271, 79.8612, 6.9271, 79.8612) == 0.0;
    distance = haversine_km(6.9271, 79.8612, 7.2906, 80.6337);
    assert distance > 90.0;
    assert distance < 110.0;

    fallback = _fallback_route(6.9271, 79.8612, 6.0535, 80.2210, "test outage");
    assert fallback.ok;
    assert fallback.estimated;
    assert fallback.distance_km > 100.0;
    assert fallback.eta_minutes > 0.0;
    assert len(fallback.coordinates) == 2;
    assert "Estimated" in fallback.message;
}

test "converts GeoJSON line coordinates for the map" {
    line = _route_coordinates({
        "type": "LineString",
        "coordinates": [[79.86, 6.92], [80.22, 6.05]]
    });
    assert line == [[6.92, 79.86], [6.05, 80.22]];

    multi = _route_coordinates({
        "type": "MultiLineString",
        "coordinates": [[[79.0, 6.0]], [[80.0, 7.0]]]
    });
    assert multi == [[6.0, 79.0], [7.0, 80.0]];
}

test "returns an existing cached route without a provider call" {
    key = "1.00000,2.00000|3.00000,4.00000";
    cached = RouteResult(ok=True, distance_km=9.0, eta_minutes=12.0);
    route_cache[key] = cached;
    assert get_route(1.0, 2.0, 3.0, 4.0) is cached;
}
