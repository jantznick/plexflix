"""NZBFinder Newznab/Torznab client."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from typing import Any

from .httputil import build_query, http_bytes, http_xml_get

NEWZNAB_NS = {"newznab": "http://www.newznab.com/DTD/2010/feeds/attributes/"}

# Title tokens we treat as 1080p-class releases
_RES_1080 = re.compile(r"(?i)(?:^|[.\s_\-\[])(1080p|1080i)(?:$|[.\s_\-\]])")
_RES_OTHER = re.compile(r"(?i)(?:^|[.\s_\-\[])(2160p|4k|720p|480p|576p)(?:$|[.\s_\-\]])")
_REMUX = re.compile(r"(?i)(?:^|[.\s_\-\[])REMUX(?:$|[.\s_\-\]])")


def _attr_map(item: ET.Element) -> dict[str, str]:
    out: dict[str, str] = {}
    for attr in item.findall("newznab:attr", NEWZNAB_NS):
        name = attr.attrib.get("name")
        value = attr.attrib.get("value")
        if name and value is not None:
            out[name] = value
    return out


def _text(item: ET.Element, tag: str) -> str:
    node = item.find(tag)
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def parse_newznab_items(xml_bytes: bytes) -> list[dict[str, Any]]:
    root = ET.fromstring(xml_bytes)
    items = []
    for item in root.findall("./channel/item"):
        attrs = _attr_map(item)
        size = 0
        if "size" in attrs:
            try:
                size = int(attrs["size"])
            except ValueError:
                size = 0
        title = _text(item, "title")
        link = _text(item, "link")
        guid = _text(item, "guid") or link
        items.append(
            {
                "title": title,
                "link": link,
                "guid": guid,
                "size": size,
                "attrs": attrs,
            }
        )
    return items


def looks_like_resolution(title: str, resolution: str) -> bool:
    resolution = resolution.lower()
    if resolution == "1080p":
        if _RES_1080.search(title):
            return True
        # Some indexers put resolution only in attrs; title-less 1080 still ok if no other res
        if _RES_OTHER.search(title):
            return False
        return False
    return resolution.lower() in title.lower()


def score_release(item: dict[str, Any], *, prefer_resolution: str, max_size: int) -> int | None:
    """Return a higher-is-better score, or None if the release is rejected."""
    title = item.get("title") or ""
    size = int(item.get("size") or 0)
    if size <= 0 or size > max_size:
        return None
    if prefer_resolution and not looks_like_resolution(title, prefer_resolution):
        # Also accept when newznab resolution attr matches
        attrs = item.get("attrs") or {}
        res_attr = (attrs.get("resolution") or attrs.get("video") or "").lower()
        if prefer_resolution not in res_attr and "1080" not in res_attr:
            return None
    if _REMUX.search(title):
        return None

    score = 0
    lower = title.lower()
    # Prefer common fast encodes over huge sources
    if "web-dl" in lower or "webdl" in lower:
        score += 40
    elif "webrip" in lower or "web-rip" in lower:
        score += 30
    elif "bluray" in lower or "blu-ray" in lower or "bdrip" in lower:
        score += 20
    if "x265" in lower or "hevc" in lower:
        score += 10
    if "x264" in lower or "h264" in lower:
        score += 5
    # Prefer smaller within the cap (faster download), mild bias
    # 5GB max → more points when closer to ~2–4GB sweet spot
    gb = size / (1024**3)
    if 1.5 <= gb <= 4.0:
        score += 15
    elif gb < 1.5:
        score += 5
    # Prefer higher grab counts / newer when present
    attrs = item.get("attrs") or {}
    try:
        grabs = int(attrs.get("grabs") or 0)
        score += min(grabs, 50)
    except ValueError:
        pass
    try:
        age_hours = int(attrs.get("age") or 0)
        if age_hours and age_hours < 24 * 30:
            score += 10
        elif age_hours and age_hours < 24 * 365:
            score += 5
    except ValueError:
        pass
    return score


def pick_best(
    items: list[dict[str, Any]],
    *,
    prefer_resolution: str,
    max_size: int,
) -> dict[str, Any] | None:
    best = None
    best_score = None
    for item in items:
        score = score_release(item, prefer_resolution=prefer_resolution, max_size=max_size)
        if score is None:
            continue
        if best_score is None or score > best_score:
            best = item
            best_score = score
    return best


class NzbFinder:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key

    def _api(self, params: dict) -> bytes:
        if not self.api_key:
            raise RuntimeError("NZBFINDER_API_KEY is not set")
        params = dict(params)
        params["apikey"] = self.api_key
        url = build_query(f"{self.base_url}/api", params)
        return http_xml_get(url)

    def search_movie(
        self,
        *,
        imdb_id: str = "",
        tmdb_id: str = "",
        query: str = "",
        year: str = "",
    ) -> list[dict[str, Any]]:
        params: dict[str, str] = {"t": "movie", "extended": "1", "limit": "50"}
        if imdb_id:
            # Newznab wants digits only for imdbid (no "tt")
            params["imdbid"] = imdb_id.lower().replace("tt", "")
        elif tmdb_id:
            params["tmdbid"] = str(tmdb_id)
        elif query:
            params["t"] = "search"
            params["q"] = f"{query} {year}".strip() if year else query
            params["cat"] = "2000"  # movies
        else:
            raise ValueError("movie search needs imdbId, tmdbId, or title query")
        return parse_newznab_items(self._api(params))

    def search_episode(
        self,
        *,
        tvdb_id: str = "",
        tmdb_id: str = "",
        query: str = "",
        season: int,
        episode: int,
    ) -> list[dict[str, Any]]:
        params: dict[str, str] = {
            "t": "tvsearch",
            "extended": "1",
            "limit": "50",
            "season": str(season),
            "ep": str(episode),
        }
        if tvdb_id:
            params["tvdbid"] = str(tvdb_id)
        elif tmdb_id:
            params["tmdbid"] = str(tmdb_id)
        elif query:
            params["q"] = query
        else:
            raise ValueError("episode search needs tvdbId, tmdbId, or title query")
        return parse_newznab_items(self._api(params))

    def download_nzb(self, link: str) -> bytes:
        """Fetch NZB bytes. NZBFinder links usually already include apikey."""
        return http_bytes(link)
