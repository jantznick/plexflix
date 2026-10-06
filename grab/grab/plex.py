"""Plex library refresh helper."""

from __future__ import annotations

import urllib.parse
import urllib.request


class PlexClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip("/")
        self.token = token

    def refresh_section(self, section_id: str) -> None:
        if not self.token:
            raise RuntimeError("PLEX_TOKEN is not set")
        if not section_id:
            raise RuntimeError("Plex section id is empty")
        path = f"/library/sections/{urllib.parse.quote(str(section_id))}/refresh"
        url = f"{self.base_url}{path}?{urllib.parse.urlencode({'X-Plex-Token': self.token})}"
        request = urllib.request.Request(
            url,
            headers={
                "Accept": "application/json",
                "X-Plex-Token": self.token,
                "User-Agent": "PlexFlixGrab/0.1",
            },
            method="GET",
        )
        with urllib.request.urlopen(request, timeout=30) as resp:
            resp.read()
