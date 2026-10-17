"""CareRoute - map settings for the browser (T16).

The result screen draws the map with Leaflet. This endpoint tells it which tile
server to use: Geoapify tiles when a key is configured, plain OpenStreetMap
tiles otherwise, so the map still works without a key.
"""

import from geoapify { _api_key }

"""Tile server settings for the map."""
obj MapConfig {
    has tile_url: str,
        attribution: str,
        provider: str;
}

"""Where the map should get its tiles."""
def:pub get_map_config() -> MapConfig {
    key = _api_key();
    if key != "" {
        return MapConfig(
            tile_url=f"https://maps.geoapify.com/v1/tile/osm-bright/{{z}}/{{x}}/{{y}}.png?apiKey={key}",
            attribution="Powered by Geoapify | OpenStreetMap contributors",
            provider="geoapify"
        );
    }
    return MapConfig(
        tile_url="https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        attribution="OpenStreetMap contributors",
        provider="openstreetmap"
    );
}
