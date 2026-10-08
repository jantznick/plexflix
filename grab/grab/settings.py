"""Environment-driven settings for the grab service."""

from __future__ import annotations

import os


def _int(env: dict, key: str, default: int) -> int:
    raw = env.get(key)
    if raw is None or raw == "":
        return default
    return int(raw)


def settings_from_env(env: dict | None = None) -> dict:
    env = env if env is not None else os.environ
    return {
        "port": _int(env, "PORT", 8096),
        "token": env.get("GRAB_TOKEN", "") or "",
        "nzbfinder_url": (env.get("NZBFINDER_URL") or "https://nzbfinder.ws").rstrip("/"),
        "nzbfinder_api_key": env.get("NZBFINDER_API_KEY", "") or "",
        # Defaults assume host LAN IP reachability (not docker DNS / localhost)
        "nzbget_url": (env.get("NZBGET_URL") or "http://192.168.1.50:6789").rstrip("/"),
        "nzbget_username": env.get("NZBGET_USERNAME", "") or "",
        "nzbget_password": env.get("NZBGET_PASSWORD", "") or "",
        # 900 = Force: jumps the queue; downloads even while NZBGet is paused
        "nzbget_priority": _int(env, "NZBGET_PRIORITY", 900),
        "nzbget_category_movie": env.get("NZBGET_CATEGORY_MOVIE") or "PlexFlix-Movies",
        "nzbget_category_tv": env.get("NZBGET_CATEGORY_TV") or "PlexFlix-Series",
        "max_size_bytes": _int(env, "MAX_SIZE_BYTES", 5 * 1024 * 1024 * 1024),
        "prefer_resolution": (env.get("PREFER_RESOLUTION") or "1080p").lower(),
        "plex_url": (env.get("PLEX_URL") or "http://192.168.1.50:32400").rstrip("/"),
        "plex_token": env.get("PLEX_TOKEN", "") or "",
        "plex_movie_section_id": env.get("PLEX_MOVIE_SECTION_ID", "") or "",
        "plex_tv_section_id": env.get("PLEX_TV_SECTION_ID", "") or "",
        "sonarr_url": (env.get("SONARR_URL") or "http://192.168.1.50:8989").rstrip("/"),
        "sonarr_api_key": env.get("SONARR_API_KEY", "") or "",
        # How long finished/failed jobs stick around for Roku re-polls
        "job_ttl_seconds": _int(env, "JOB_TTL_SECONDS", 3600),
    }
