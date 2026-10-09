#!/usr/bin/env python3
"""Build a Cable TV EPG sidecar JSON from a free XMLTV dump.

Runs on the home server (not this laptop). Independent of the 5‑minute sports
feed publisher: listings live in a separate object the Roku merges by channel id.

Typical cron (every 6–12 hours is enough):

  20 */6 * * * /path/to/venv/bin/python /path/to/enrich_cable_epg.py \\
      --env-file /path/to/plexflix.env --upload

Environment (or --env-file KEY=VALUE lines):
  EPG_XMLTV_URL       XMLTV .xml or .xml.gz (default: epgshare01 US2)
  TMDB_API_KEY        Optional — enrich programmes with overview/art/cast
  TMDB_CACHE_PATH     Optional cache file (default: ~/.cache/plexflix-cable-tmdb.json)
  B2_BUCKET           Optional Backblaze B2 bucket for --upload
  B2_KEY_ID / B2_APPLICATION_KEY
  B2_REMOTE_KEY       Object key (default: plexflix/cable-epg.json)

Output shape (cable-epg.json):
  {
    "updated": "…Z",
    "source": "https://…xml.gz",
    "channels": {
      "timst-cartoon-network": {
        "epgChannelId": "Cartoon.Network.HD.us2",
        "programs": [ { "title", "beginsAt", "endsAt", … }, … ]
      }
    }
  }

Point PlexConfig.brs cableEpgUrl at the public URL for that object.
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_EPG_URL = "https://epgshare01.online/epgshare01/epg_ripper_US2.xml.gz"
DEFAULT_REMOTE_KEY = "plexflix/cable-epg.json"
DEFAULT_PUBLIC_URL = (
    "https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/cable-epg.json"
)
DEFAULT_TMDB_CACHE = Path.home() / ".cache" / "plexflix-cable-tmdb.json"
TMDB_CAST_LIMIT = 8
TMDB_DESC_LIMIT = 320


def load_env_file(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"env file not found: {path}")
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = val


def require_env(name: str) -> str:
    val = os.environ.get(name, "").strip()
    if not val:
        raise SystemExit(f"Missing required env/config: {name}")
    return val


def http_get(url: str, timeout: int = 120) -> bytes:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "*/*",
            "User-Agent": "PlexFlix-CableEPG/1.1",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def load_map(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    channels = data.get("channels") or {}
    if not isinstance(channels, dict) or not channels:
        raise SystemExit(f"No channels map in {path}")
    return {str(k): str(v) for k, v in channels.items() if not str(k).startswith("_")}


def parse_xmltv_time(value: str) -> datetime | None:
    """XMLTV: 20261008050000 +0000 or 20261008050000."""
    if not value:
        return None
    raw = value.strip()
    stamp = raw.split()[0]
    if len(stamp) < 14 or not stamp[:14].isdigit():
        return None
    dt = datetime(
        int(stamp[0:4]),
        int(stamp[4:6]),
        int(stamp[6:8]),
        int(stamp[8:10]),
        int(stamp[10:12]),
        int(stamp[12:14]),
        tzinfo=timezone.utc,
    )
    if len(raw.split()) > 1:
        off = raw.split()[1]
        if len(off) == 5 and (off[0] == "+" or off[0] == "-") and off[1:].isdigit():
            sign = 1 if off[0] == "+" else -1
            hours = int(off[1:3])
            mins = int(off[3:5])
            dt = dt.replace(tzinfo=timezone(sign * timedelta(hours=hours, minutes=mins)))
            dt = dt.astimezone(timezone.utc)
    return dt


def text_of(node: ET.Element | None, default: str = "") -> str:
    if node is None or node.text is None:
        return default
    return " ".join(node.text.split())


def first_child(node: ET.Element, names: list[str]) -> ET.Element | None:
    for name in names:
        child = node.find(name)
        if child is not None:
            return child
        for el in node:
            if el.tag.endswith(name) or el.tag == name:
                return el
    return None


def programme_to_dict(node: ET.Element) -> dict[str, Any] | None:
    start = parse_xmltv_time(node.attrib.get("start", ""))
    stop = parse_xmltv_time(node.attrib.get("stop", ""))
    if start is None or stop is None or stop <= start:
        return None

    title = text_of(first_child(node, ["title"]))
    if not title:
        title = "Program"
    subtitle = text_of(first_child(node, ["sub-title"]))
    desc = text_of(first_child(node, ["desc"]))
    episode = text_of(first_child(node, ["episode-num"]))
    icon = first_child(node, ["icon"])
    art = ""
    if icon is not None:
        art = (icon.attrib.get("src") or "").strip()
    rating_val = ""
    for rating in node.findall("rating"):
        value = first_child(rating, ["value"])
        if value is not None and value.text:
            rating_val = value.text.strip()
            break

    if len(desc) > 280:
        desc = desc[:277].rstrip() + "…"

    prog: dict[str, Any] = {
        "title": title,
        "beginsAt": int(start.timestamp()),
        "endsAt": int(stop.timestamp()),
    }
    if subtitle:
        prog["subtitle"] = subtitle
    if desc:
        prog["description"] = desc
    if episode:
        prog["episodeLabel"] = episode
    if rating_val:
        prog["contentRating"] = rating_val
    if art:
        prog["art"] = art
    return prog


def extract_programmes(
    xmltv_bytes: bytes,
    wanted_xmltv_ids: set[str],
    window_start: datetime,
    window_end: datetime,
) -> dict[str, list[dict[str, Any]]]:
    """Stream-parse XMLTV; keep programmes for mapped channels inside the window."""
    if xmltv_bytes[:2] == b"\x1f\x8b":
        stream: Any = gzip.GzipFile(fileobj=io.BytesIO(xmltv_bytes))
    else:
        stream = io.BytesIO(xmltv_bytes)

    out: dict[str, list[dict[str, Any]]] = {cid: [] for cid in wanted_xmltv_ids}
    start_ts = int(window_start.timestamp())
    end_ts = int(window_end.timestamp())

    context = ET.iterparse(stream, events=("end",))
    for _event, elem in context:
        tag = elem.tag.rsplit("}", 1)[-1]
        if tag != "programme":
            continue
        channel = elem.attrib.get("channel", "")
        if channel not in out:
            elem.clear()
            continue
        prog = programme_to_dict(elem)
        elem.clear()
        if prog is None:
            continue
        if prog["endsAt"] <= start_ts or prog["beginsAt"] >= end_ts:
            continue
        out[channel].append(prog)

    for cid in out:
        out[cid].sort(key=lambda p: p["beginsAt"])
    return out


def build_sidecar(
    id_map: dict[str, str],
    programmes_by_xmltv: dict[str, list[dict[str, Any]]],
    source: str,
) -> tuple[dict[str, Any], dict[str, int]]:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    channels: dict[str, Any] = {}
    stats = {"mapped": 0, "withEpg": 0, "programmes": 0, "empty": 0}

    for feed_id, xmltv_id in id_map.items():
        stats["mapped"] += 1
        programs = programmes_by_xmltv.get(xmltv_id, [])
        entry = {"epgChannelId": xmltv_id, "programs": programs}
        channels[feed_id] = entry
        if programs:
            stats["withEpg"] += 1
            stats["programmes"] += len(programs)
        else:
            stats["empty"] += 1

    sidecar = {
        "updated": now,
        "source": source,
        "windowHoursBack": 6,
        "channels": channels,
    }
    return sidecar, stats


# ---------------------------------------------------------------------------
# TMDB enrichment (optional)
# ---------------------------------------------------------------------------

def clean_program_title(title: str) -> str:
    text = (title or "").strip()
    text = re.sub(r"^\[[^\]]+\]\s*", "", text)  # [as], [CC], …
    text = re.sub(r"\s+\(\d{4}\)\s*$", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def tmdb_cache_key(title: str) -> str:
    return clean_program_title(title).lower()


def load_tmdb_cache(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_tmdb_cache(path: Path, cache: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")


def tmdb_get(api_key: str, path: str, params: dict[str, str] | None = None) -> Any:
    q = dict(params or {})
    q["api_key"] = api_key
    url = "https://api.themoviedb.org/3" + path + "?" + urllib.parse.urlencode(q)
    try:
        raw = http_get(url, timeout=30)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"  tmdb error {path}: {exc}")
        return None
    try:
        return json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError:
        return None


def tmdb_search_best(api_key: str, title: str) -> tuple[str, dict[str, Any]] | None:
    """Return (kind, hit) for tv or movie, preferring TV for cable listings."""
    query = clean_program_title(title)
    if not query or query.lower() in {"paid programming", "to be announced", "tba", "sign off"}:
        return None

    for kind in ("tv", "movie"):
        data = tmdb_get(api_key, f"/search/{kind}", {"query": query})
        results = (data or {}).get("results") or []
        if results:
            return kind, results[0]
    return None


def tmdb_detail(api_key: str, kind: str, tmdb_id: str) -> dict[str, Any] | None:
    return tmdb_get(
        api_key,
        f"/{kind}/{tmdb_id}",
        {"append_to_response": "credits,content_ratings,release_dates"},
    )


def tmdb_content_rating(kind: str, detail: dict[str, Any]) -> str:
    if kind == "tv":
        for row in (detail.get("content_ratings") or {}).get("results") or []:
            if row.get("iso_3166_1") == "US" and row.get("rating"):
                return str(row["rating"]).strip()
    else:
        for row in (detail.get("release_dates") or {}).get("results") or []:
            if row.get("iso_3166_1") != "US":
                continue
            for d in row.get("release_dates") or []:
                cert = str(d.get("certification") or "").strip()
                if cert:
                    return cert
    return ""


def tmdb_meta_from_detail(kind: str, detail: dict[str, Any]) -> dict[str, Any]:
    overview = " ".join(str(detail.get("overview") or "").split())
    if len(overview) > TMDB_DESC_LIMIT:
        overview = overview[: TMDB_DESC_LIMIT - 1].rstrip() + "…"

    year = ""
    if kind == "tv":
        year = str(detail.get("first_air_date") or "")[:4]
    else:
        year = str(detail.get("release_date") or "")[:4]

    poster = ""
    backdrop = ""
    if detail.get("poster_path"):
        poster = "https://image.tmdb.org/t/p/w500" + str(detail["poster_path"])
    if detail.get("backdrop_path"):
        backdrop = "https://image.tmdb.org/t/p/w1280" + str(detail["backdrop_path"])

    rating = ""
    if detail.get("vote_average") is not None:
        try:
            rating = f"{float(detail['vote_average']):.1f}"
        except (TypeError, ValueError):
            rating = ""

    cast: list[dict[str, str]] = []
    credits = detail.get("credits") or {}
    for person in (credits.get("cast") or [])[:TMDB_CAST_LIMIT]:
        name = str(person.get("name") or "").strip()
        if not name:
            continue
        thumb = ""
        if person.get("profile_path"):
            thumb = "https://image.tmdb.org/t/p/w342" + str(person["profile_path"])
        cast.append(
            {
                "title": name,
                "shortTitle": name,
                "description": str(person.get("character") or "").strip(),
                "mediaType": "actor",
                "hdPosterUrl": thumb,
            }
        )

    return {
        "tmdbId": str(detail.get("id") or ""),
        "tmdbType": kind,
        "description": overview,
        "year": year,
        "rating": rating,
        "contentRating": tmdb_content_rating(kind, detail),
        "poster": poster,
        "backdrop": backdrop,
        "art": backdrop or poster,
        "cast": cast,
    }


def lookup_tmdb(
    api_key: str,
    title: str,
    cache: dict[str, Any],
    stats: dict[str, int],
) -> dict[str, Any] | None:
    key = tmdb_cache_key(title)
    if not key:
        return None
    if key in cache:
        stats["cacheHits"] += 1
        hit = cache[key]
        return hit if isinstance(hit, dict) else None

    stats["lookups"] += 1
    time.sleep(0.25)
    found = tmdb_search_best(api_key, title)
    if found is None:
        cache[key] = None
        stats["misses"] += 1
        return None

    kind, hit = found
    tmdb_id = str(hit.get("id") or "")
    if not tmdb_id:
        cache[key] = None
        stats["misses"] += 1
        return None

    time.sleep(0.25)
    detail = tmdb_detail(api_key, kind, tmdb_id)
    if detail is None:
        cache[key] = None
        stats["misses"] += 1
        return None

    meta = tmdb_meta_from_detail(kind, detail)
    cache[key] = meta
    stats["hits"] += 1
    return meta


def apply_tmdb_to_programmes(
    programmes_by_xmltv: dict[str, list[dict[str, Any]]],
    api_key: str,
    cache_path: Path,
) -> dict[str, int]:
    cache = load_tmdb_cache(cache_path)
    stats = {
        "titles": 0,
        "lookups": 0,
        "cacheHits": 0,
        "hits": 0,
        "misses": 0,
        "programmesTagged": 0,
    }

    # Unique titles first so the cache fills before we walk every airing
    unique_titles: list[str] = []
    seen: set[str] = set()
    for programs in programmes_by_xmltv.values():
        for prog in programs:
            key = tmdb_cache_key(str(prog.get("title") or ""))
            if key and key not in seen:
                seen.add(key)
                unique_titles.append(str(prog.get("title") or ""))
    stats["titles"] = len(unique_titles)
    print(f"tmdb: enriching {len(unique_titles)} unique titles (cache {cache_path})")

    title_meta: dict[str, dict[str, Any] | None] = {}
    for title in unique_titles:
        title_meta[tmdb_cache_key(title)] = lookup_tmdb(api_key, title, cache, stats)

    for programs in programmes_by_xmltv.values():
        for prog in programs:
            meta = title_meta.get(tmdb_cache_key(str(prog.get("title") or "")))
            if not meta:
                continue
            if meta.get("description"):
                # Prefer TMDB synopsis when EPG blurb is thin
                epg_desc = str(prog.get("description") or "")
                if len(epg_desc) < 80 or not epg_desc:
                    prog["description"] = meta["description"]
            if meta.get("art"):
                prog["art"] = meta["art"]
            if meta.get("poster"):
                prog["poster"] = meta["poster"]
            if meta.get("backdrop"):
                prog["backdrop"] = meta["backdrop"]
            if meta.get("year"):
                prog["year"] = meta["year"]
            if meta.get("rating"):
                prog["rating"] = meta["rating"]
            if meta.get("contentRating") and not prog.get("contentRating"):
                prog["contentRating"] = meta["contentRating"]
            if meta.get("tmdbId"):
                prog["tmdbId"] = meta["tmdbId"]
            if meta.get("tmdbType"):
                prog["tmdbType"] = meta["tmdbType"]
            if meta.get("cast"):
                prog["cast"] = meta["cast"]
            stats["programmesTagged"] += 1

    save_tmdb_cache(cache_path, cache)
    return stats


def upload_b2(local_path: Path, remote_key: str) -> None:
    try:
        from b2sdk.v2 import B2Api, InMemoryAccountInfo  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "b2sdk not installed. On the home server: pip install b2sdk\n"
            "Or copy the sidecar JSON to your CDN yourself."
        ) from exc

    key_id = require_env("B2_KEY_ID")
    app_key = require_env("B2_APPLICATION_KEY")
    bucket_name = require_env("B2_BUCKET")

    info = InMemoryAccountInfo()
    api = B2Api(info)
    api.authorize_account("production", key_id, app_key)
    bucket = api.get_bucket_by_name(bucket_name)
    print(f"upload {local_path.name} -> b2://{bucket_name}/{remote_key}")
    bucket.upload_local_file(local_file=str(local_path), file_name=remote_key)
    print("upload complete")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build PlexFlix Cable TV EPG sidecar (does not touch the sports feed)"
    )
    parser.add_argument("--env-file", type=Path, help="Optional KEY=VALUE env file")
    parser.add_argument(
        "--map",
        type=Path,
        default=SCRIPT_DIR / "cable_epg_map.json",
        help="Feed channel id → XMLTV id map",
    )
    parser.add_argument("--epg-url", default=None, help="XMLTV .xml / .xml.gz URL")
    parser.add_argument("--epg-file", type=Path, help="Local XMLTV instead of URL")
    parser.add_argument(
        "--days",
        type=int,
        default=1,
        help="Days of listings ahead of now (also keeps 6h of history; default 1)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Write sidecar JSON here (default: temp cable-epg.json)",
    )
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload sidecar JSON to Backblaze B2",
    )
    parser.add_argument(
        "--remote-key",
        default=None,
        help=f"B2 object key (default: env B2_REMOTE_KEY or {DEFAULT_REMOTE_KEY})",
    )
    parser.add_argument(
        "--skip-tmdb",
        action="store_true",
        help="Skip TMDB enrichment even if TMDB_API_KEY is set",
    )
    parser.add_argument(
        "--tmdb-cache",
        type=Path,
        default=None,
        help="TMDB title cache JSON (default: env TMDB_CACHE_PATH or ~/.cache/...)",
    )
    args = parser.parse_args()

    if args.env_file:
        load_env_file(args.env_file)

    id_map = load_map(args.map)
    epg_url = (args.epg_url or os.environ.get("EPG_XMLTV_URL") or DEFAULT_EPG_URL).strip()

    if args.epg_file:
        print(f"load epg {args.epg_file}")
        xmltv_bytes = args.epg_file.read_bytes()
        source = str(args.epg_file)
    else:
        print(f"download epg {epg_url}")
        xmltv_bytes = http_get(epg_url, timeout=180)
        print(f"  epg bytes {len(xmltv_bytes)}")
        source = epg_url

    now = datetime.now(timezone.utc)
    window_start = now - timedelta(hours=6)
    window_end = now + timedelta(days=max(1, args.days))
    wanted = set(id_map.values())
    print(f"parse programmes for {len(wanted)} xmltv ids ({window_start} → {window_end})")
    programmes = extract_programmes(xmltv_bytes, wanted, window_start, window_end)
    covered = sum(1 for v in programmes.values() if v)
    print(f"  xmltv channels with listings: {covered}/{len(wanted)}")

    tmdb_key = (os.environ.get("TMDB_API_KEY") or "").strip()
    if tmdb_key and tmdb_key.startswith("REPLACE"):
        tmdb_key = ""
    if args.skip_tmdb:
        tmdb_key = ""
    if tmdb_key:
        cache_path = (
            args.tmdb_cache
            or Path(os.environ.get("TMDB_CACHE_PATH") or DEFAULT_TMDB_CACHE)
        )
        tmdb_stats = apply_tmdb_to_programmes(programmes, tmdb_key, cache_path)
        print(
            f"tmdb: titles={tmdb_stats['titles']} lookups={tmdb_stats['lookups']} "
            f"cacheHits={tmdb_stats['cacheHits']} hits={tmdb_stats['hits']} "
            f"misses={tmdb_stats['misses']} tagged={tmdb_stats['programmesTagged']}"
        )
    else:
        print("tmdb: skipped (set TMDB_API_KEY to enrich overview/art/cast)")

    sidecar, stats = build_sidecar(id_map, programmes, source)
    sidecar["windowDaysAhead"] = max(1, args.days)
    if tmdb_key:
        sidecar["tmdbEnriched"] = True
    print(
        f"sidecar mapped={stats['mapped']} withEpg={stats['withEpg']} "
        f"programmes={stats['programmes']} empty={stats['empty']}"
    )

    out_path = args.out or (Path(tempfile.gettempdir()) / "cable-epg.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(sidecar, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {out_path} ({out_path.stat().st_size} bytes)")

    if args.upload:
        remote = (
            args.remote_key or os.environ.get("B2_REMOTE_KEY") or DEFAULT_REMOTE_KEY
        ).strip()
        upload_b2(out_path, remote)

    print("\nPoint cableEpgUrl in PlexConfig.brs at your public sidecar URL, e.g.")
    print(f"  {DEFAULT_PUBLIC_URL}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        raise SystemExit(130)
