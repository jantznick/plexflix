#!/usr/bin/env python3
"""Build a daily splash-poster pack for PlexFlix.

Pulls recent / random movie + TV posters from your Plex server, saves them as
numbered JPGs, and writes posters.json that the Roku channel loads from your CDN.

Typical cron (on your home server — not this laptop):

  0 5 * * * /path/to/venv/bin/python /path/to/update_splash_posters.py \\
      --env-file /path/to/plexflix.env --upload

Environment (or --env-file KEY=VALUE lines):
  PLEX_BASE_URL     e.g. http://192.168.1.50:32400
  PLEX_TOKEN        Plex X-Plex-Token
  SPLASH_CDN_BASE   Public base URL where files will be reachable, e.g.
                    https://roku-hockey.s3.us-west-004.backblazeb2.com/plexflix/splash
  SPLASH_OUT_DIR    Local directory to write into (default: ./splash-out)
  B2_BUCKET         Optional Backblaze B2 bucket name for --upload
  B2_KEY_ID / B2_APPLICATION_KEY
  B2_REMOTE_PREFIX  Object prefix inside the bucket (default: plexflix/splash)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_COUNT = 72
POSTER_W = 280
POSTER_H = 420


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


def plex_get(base: str, token: str, path: str, params: dict[str, Any] | None = None) -> Any:
    q = dict(params or {})
    q["X-Plex-Token"] = token
    url = base.rstrip("/") + path + "?" + urllib.parse.urlencode(q)
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "X-Plex-Token": token,
            "X-Plex-Product": "PlexFlix-Splash",
            "X-Plex-Version": "1.0",
            "X-Plex-Client-Identifier": "plexflix-splash-updater",
        },
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        return json.loads(resp.read().decode("utf-8"))


def poster_transcode_url(base: str, token: str, thumb_path: str) -> str:
    """Plex photo transcoder URL (used only to download locally — never published)."""
    q = urllib.parse.urlencode(
        {
            "width": POSTER_W,
            "height": POSTER_H,
            "minSize": 1,
            "upscale": 0,
            "url": thumb_path,
            "X-Plex-Token": token,
        }
    )
    return f"{base.rstrip('/')}/photo/:/transcode?{q}"


def collect_thumbs(base: str, token: str, want: int) -> list[str]:
    sections = plex_get(base, token, "/library/sections")
    dirs = sections.get("MediaContainer", {}).get("Directory", []) or []
    if isinstance(dirs, dict):
        dirs = [dirs]

    movie_tv = [
        d
        for d in dirs
        if str(d.get("type", "")).lower() in ("movie", "show")
    ]
    if not movie_tv:
        movie_tv = dirs

    thumbs: list[str] = []
    seen: set[str] = set()

    def add_from_meta(meta_list: Any) -> None:
        nonlocal thumbs
        if meta_list is None:
            return
        if isinstance(meta_list, dict):
            meta_list = [meta_list]
        for item in meta_list:
            thumb = item.get("thumb") or item.get("grandparentThumb") or item.get("art")
            if not thumb or thumb in seen:
                continue
            seen.add(thumb)
            thumbs.append(str(thumb))

    # Prefer recently added, then newest, then random-ish all
    for section in movie_tv:
        key = section.get("key")
        if not key:
            continue
        for endpoint, extra in (
            (f"/library/sections/{key}/recentlyAdded", {"X-Plex-Container-Start": 0, "X-Plex-Container-Size": 40}),
            (f"/library/sections/{key}/all", {"sort": "addedAt:desc", "X-Plex-Container-Start": 0, "X-Plex-Container-Size": 60}),
        ):
            try:
                data = plex_get(base, token, endpoint, extra)
            except Exception as exc:  # noqa: BLE001 — keep collecting other sections
                print(f"warn: {endpoint}: {exc}", file=sys.stderr)
                continue
            add_from_meta(data.get("MediaContainer", {}).get("Metadata"))
            if len(thumbs) >= want * 2:
                break
        if len(thumbs) >= want * 2:
            break

    random.shuffle(thumbs)
    return thumbs[: max(want, 12)]


def download(url: str, dest: Path) -> bool:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "PlexFlix-Splash/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
        if len(data) < 500:
            return False
        dest.write_bytes(data)
        return True
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"warn: download failed: {exc}", file=sys.stderr)
        return False


def write_pack(out_dir: Path, cdn_base: str, count: int) -> Path:
    base = require_env("PLEX_BASE_URL")
    token = require_env("PLEX_TOKEN")
    out_dir.mkdir(parents=True, exist_ok=True)

    thumbs = collect_thumbs(base, token, count)
    if len(thumbs) < 12:
        raise SystemExit(f"Only found {len(thumbs)} posters in Plex — need at least 12")

    posters: list[str] = []
    img_dir = out_dir / "images"
    img_dir.mkdir(exist_ok=True)

    # Clear previous numbered images so stale files don't linger
    for old in img_dir.glob("poster_*.jpg"):
        old.unlink(missing_ok=True)

    for i, thumb in enumerate(thumbs[:count]):
        src = poster_transcode_url(base, token, thumb)
        name = f"poster_{i:03d}.jpg"
        dest = img_dir / name
        if not download(src, dest):
            continue
        # Cache-bust so Roku/CDN pick up the daily refresh
        digest = hashlib.md5(dest.read_bytes()).hexdigest()[:8]
        public = f"{cdn_base.rstrip('/')}/images/{name}?v={digest}"
        posters.append(public)
        print(f"ok  {name}  ({len(dest.read_bytes())} bytes)")

    if len(posters) < 12:
        raise SystemExit(f"Downloaded only {len(posters)} images — aborting")

    manifest = {
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(posters),
        "posters": posters,
    }
    manifest_path = out_dir / "posters.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {manifest_path} ({len(posters)} posters)")
    return manifest_path


def upload_b2(out_dir: Path) -> None:
    try:
        from b2sdk.v2 import B2Api, InMemoryAccountInfo  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "b2sdk not installed. On the home server: pip install b2sdk\n"
            "Or sync out_dir yourself with rclone/aws s3 sync."
        ) from exc

    key_id = require_env("B2_KEY_ID")
    app_key = require_env("B2_APPLICATION_KEY")
    bucket_name = require_env("B2_BUCKET")
    prefix = os.environ.get("B2_REMOTE_PREFIX", "plexflix/splash").strip().strip("/")

    info = InMemoryAccountInfo()
    api = B2Api(info)
    api.authorize_account("production", key_id, app_key)
    bucket = api.get_bucket_by_name(bucket_name)

    files = [out_dir / "posters.json"] + sorted((out_dir / "images").glob("poster_*.jpg"))
    for path in files:
        if path.name == "posters.json":
            remote = f"{prefix}/posters.json"
        else:
            remote = f"{prefix}/images/{path.name}"
        print(f"upload {path.name} -> b2://{bucket_name}/{remote}")
        bucket.upload_local_file(local_file=str(path), file_name=remote)
    print("upload complete")


def main() -> int:
    parser = argparse.ArgumentParser(description="Refresh PlexFlix splash posters for CDN")
    parser.add_argument("--env-file", type=Path, help="Optional KEY=VALUE env file")
    parser.add_argument("--out-dir", type=Path, default=None, help="Output directory")
    parser.add_argument("--cdn-base", default=None, help="Public CDN base URL for posters.json links")
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT, help="How many posters to publish")
    parser.add_argument("--upload", action="store_true", help="Upload out_dir to Backblaze B2")
    parser.add_argument("--seed", type=int, default=None, help="Optional RNG seed (default: daily)")
    args = parser.parse_args()

    if args.env_file:
        load_env_file(args.env_file)

    out_dir = args.out_dir or Path(os.environ.get("SPLASH_OUT_DIR", "splash-out"))
    cdn_base = (args.cdn_base or os.environ.get("SPLASH_CDN_BASE", "")).strip()
    if not cdn_base:
        raise SystemExit("Set SPLASH_CDN_BASE or pass --cdn-base")

    if args.seed is not None:
        random.seed(args.seed)
    else:
        # Stable-ish daily shuffle so a second run the same day is similar
        random.seed(datetime.now(timezone.utc).strftime("%Y-%m-%d"))

    write_pack(out_dir, cdn_base, max(12, args.count))
    if args.upload:
        upload_b2(out_dir)

    print("\nPoint splashManifestUrl in PlexConfig.brs at:")
    print(f"  {cdn_base.rstrip('/')}/posters.json")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        raise SystemExit(130)
