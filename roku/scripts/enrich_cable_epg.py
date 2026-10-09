#!/usr/bin/env python3
"""Build a Cable TV EPG sidecar JSON from a free XMLTV dump.

Runs on the home server (not this laptop). Independent of the 5‑minute sports
feed publisher: listings live in a separate object the Roku merges by channel id.

Typical cron (every 6–12 hours is enough):

  20 */6 * * * /path/to/venv/bin/python /path/to/enrich_cable_epg.py \\
      --env-file /path/to/plexflix.env --upload

Environment (or --env-file KEY=VALUE lines):
  EPG_XMLTV_URL       XMLTV .xml or .xml.gz (default: epgshare01 US2)
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
import sys
import tempfile
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

    sidecar, stats = build_sidecar(id_map, programmes, source)
    sidecar["windowDaysAhead"] = max(1, args.days)
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
