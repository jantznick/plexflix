"""In-memory grab jobs: search → NZBGet Force download → Plex scan."""

from __future__ import annotations

import threading
import time
import uuid
from typing import Any, Callable

from .nzbfinder import NzbFinder, pick_best
from .nzbget import NzbGet
from .plex import PlexClient


TERMINAL = frozenset({"ready", "failed"})


class JobStore:
    def __init__(self, settings: dict, clock: Callable[[], float] = time.monotonic):
        self.settings = settings
        self._clock = clock
        self._jobs: dict[str, dict] = {}
        self._lock = threading.Lock()
        self._finder = NzbFinder(settings["nzbfinder_url"], settings["nzbfinder_api_key"])
        self._nzbget = NzbGet(
            settings["nzbget_url"],
            settings["nzbget_username"],
            settings["nzbget_password"],
        )
        self._plex = PlexClient(settings["plex_url"], settings["plex_token"])

    def create(self, body: dict) -> dict:
        media_type = (body.get("mediaType") or body.get("type") or "movie").lower()
        if media_type in ("tv", "show", "series", "episode"):
            if body.get("season") is None or body.get("episode") is None:
                raise ValueError(
                    "TV jobs need season + episode for now "
                    "(Start fresh / queue-next Sonarr wiring comes next)"
                )
            media_type = "episode"

        identity = self._identity_key(media_type, body)
        with self._lock:
            existing = self._find_active_locked(identity)
            if existing is not None:
                return self._public(existing)

        job = {
            "id": str(uuid.uuid4()),
            "identity": identity,
            "mediaType": media_type,
            "title": str(body.get("title") or ""),
            "year": str(body.get("year") or ""),
            "imdbId": str(body.get("imdbId") or body.get("imdb_id") or ""),
            "tmdbId": str(body.get("tmdbId") or body.get("tmdb_id") or ""),
            "tvdbId": str(body.get("tvdbId") or body.get("tvdb_id") or ""),
            "guid": str(body.get("guid") or ""),
            "season": body.get("season"),
            "episode": body.get("episode"),
            "status": "queued",
            "stage": "queued",
            "percent": 0,
            "etaSeconds": None,
            "message": "Queued",
            "nzbgetId": None,
            "releaseTitle": None,
            "error": None,
            "createdAt": time.time(),
            "updatedAt": time.time(),
            "lastSeen": self._clock(),
        }
        with self._lock:
            self._jobs[job["id"]] = job
        threading.Thread(target=self._run, args=(job["id"],), daemon=True).start()
        return self._public(job)

    def get(self, job_id: str) -> dict | None:
        with self._lock:
            job = self._jobs.get(job_id)
            if job is None:
                return None
            job["lastSeen"] = self._clock()
            if job["status"] not in TERMINAL and job.get("nzbgetId"):
                self._refresh_progress_locked(job)
            return self._public(job)

    def find_by_query(self, *, guid: str = "", tmdb_id: str = "", imdb_id: str = "") -> dict | None:
        with self._lock:
            for job in self._jobs.values():
                match = (
                    (guid and job.get("guid") == guid)
                    or (tmdb_id and job.get("tmdbId") == str(tmdb_id))
                    or (imdb_id and job.get("imdbId") == str(imdb_id))
                )
                if not match:
                    continue
                job["lastSeen"] = self._clock()
                if job["status"] not in TERMINAL and job.get("nzbgetId"):
                    self._refresh_progress_locked(job)
                return self._public(job)
        return None

    def reap(self) -> None:
        ttl = self.settings["job_ttl_seconds"]
        now = self._clock()
        with self._lock:
            dead = [
                jid
                for jid, job in self._jobs.items()
                if job["status"] in TERMINAL and now - job["lastSeen"] > ttl
            ]
            for jid in dead:
                self._jobs.pop(jid, None)

    def _run(self, job_id: str) -> None:
        try:
            with self._lock:
                job = self._jobs.get(job_id)
                if job is None:
                    return
                media_type = job["mediaType"]

            self._set(job_id, status="searching", stage="searching", message="Searching NZBFinder…")
            release = self._search(job_id)
            if release is None:
                self._set(
                    job_id,
                    status="failed",
                    stage="failed",
                    message="No matching 1080p release under size cap",
                    error="no_results",
                )
                return

            self._set(
                job_id,
                status="downloading",
                stage="downloading",
                message=f"Sending to NZBGet: {release['title']}",
                releaseTitle=release["title"],
                percent=0,
            )
            nzb_bytes = self._finder.download_nzb(release["link"])
            category = (
                self.settings["nzbget_category_tv"]
                if media_type == "episode"
                else self.settings["nzbget_category_movie"]
            )
            nzb_id = self._nzbget.append(
                filename=self._safe_filename(release["title"]),
                nzb_content=nzb_bytes,
                category=category,
                priority=self.settings["nzbget_priority"],
                add_to_top=True,
                dupe_key=job.get("identity") or "",
                dupe_mode="FORCE",
            )
            self._set(job_id, nzbgetId=nzb_id, message="Downloading (Force priority)")

            # Poll until NZBGet history shows success or failure
            while True:
                time.sleep(2)
                with self._lock:
                    job = self._jobs.get(job_id)
                    if job is None:
                        return
                    finished = self._refresh_progress_locked(job)
                    failed = job["status"] == "failed"
                    succeeded = bool(job.get("_history_ok"))
                if finished and (failed or succeeded):
                    break

            with self._lock:
                job = self._jobs.get(job_id)
                if job is None or job["status"] == "failed":
                    return

            self._set(job_id, status="scanning", stage="scanning", message="Refreshing Plex…", percent=100)
            section = (
                self.settings["plex_tv_section_id"]
                if media_type == "episode"
                else self.settings["plex_movie_section_id"]
            )
            if section and self.settings["plex_token"]:
                self._plex.refresh_section(section)
                time.sleep(3)
            self._set(job_id, status="ready", stage="ready", message="Ready in Plex", percent=100)
        except Exception as exc:  # noqa: BLE001 - surface any failure to the Roku
            self._set(
                job_id,
                status="failed",
                stage="failed",
                message=str(exc),
                error="exception",
            )

    def _search(self, job_id: str) -> dict | None:
        with self._lock:
            job = dict(self._jobs[job_id])
        if job["mediaType"] == "episode":
            items = self._finder.search_episode(
                tvdb_id=job["tvdbId"],
                tmdb_id=job["tmdbId"],
                query=job["title"],
                season=int(job["season"]),
                episode=int(job["episode"]),
            )
        else:
            items = self._finder.search_movie(
                imdb_id=job["imdbId"],
                tmdb_id=job["tmdbId"],
                query=job["title"],
                year=job["year"],
            )
        return pick_best(
            items,
            prefer_resolution=self.settings["prefer_resolution"],
            max_size=self.settings["max_size_bytes"],
        )

    def _refresh_progress_locked(self, job: dict) -> bool:
        """Update job from NZBGet. True when download+PP finished (ok or fail)."""
        nzb_id = job.get("nzbgetId")
        if not nzb_id:
            return False
        group = self._nzbget.find_group(int(nzb_id))
        if group is not None:
            prog = NzbGet.progress_from_group(group)
            job["stage"] = prog["stage"]
            job["percent"] = prog["percent"]
            job["etaSeconds"] = prog["etaSeconds"]
            job["status"] = "unpacking" if prog["stage"] == "unpacking" else "downloading"
            job["message"] = prog["status"] or prog["stage"]
            job["updatedAt"] = time.time()
            return False

        history = self._nzbget.find_history(int(nzb_id))
        if history is None:
            return False
        outcome = NzbGet.outcome_from_history(history)
        job["percent"] = outcome["percent"]
        job["etaSeconds"] = 0
        job["updatedAt"] = time.time()
        if outcome["ok"]:
            job["stage"] = "completed"
            job["status"] = "scanning"
            job["message"] = "Download complete"
            job["_history_ok"] = True
            return True
        job["stage"] = "failed"
        job["status"] = "failed"
        job["message"] = outcome["status"] or "NZBGet reported failure"
        job["error"] = "nzbget_failed"
        return True

    def _set(self, job_id: str, **fields: Any) -> None:
        with self._lock:
            job = self._jobs.get(job_id)
            if job is None:
                return
            job.update(fields)
            job["updatedAt"] = time.time()

    def _find_active_locked(self, identity: str) -> dict | None:
        for job in self._jobs.values():
            if job.get("identity") == identity and job["status"] != "failed":
                return job
        return None

    @staticmethod
    def _identity_key(media_type: str, body: dict) -> str:
        if media_type == "episode":
            sid = body.get("tvdbId") or body.get("tmdbId") or body.get("title") or "tv"
            return f"ep:{sid}:S{int(body['season']):02d}E{int(body['episode']):02d}"
        mid = body.get("imdbId") or body.get("tmdbId") or body.get("guid") or body.get("title")
        return f"movie:{mid}"

    @staticmethod
    def _safe_filename(title: str) -> str:
        cleaned = "".join(ch if ch.isalnum() or ch in " ._-" else "_" for ch in title)
        return (cleaned[:120] or "plexflix").strip() + ".nzb"

    @staticmethod
    def _public(job: dict) -> dict:
        return {
            "id": job["id"],
            "mediaType": job["mediaType"],
            "title": job["title"],
            "year": job["year"],
            "imdbId": job["imdbId"],
            "tmdbId": job["tmdbId"],
            "tvdbId": job["tvdbId"],
            "guid": job["guid"],
            "season": job.get("season"),
            "episode": job.get("episode"),
            "status": job["status"],
            "stage": job["stage"],
            "percent": job["percent"],
            "etaSeconds": job.get("etaSeconds"),
            "message": job.get("message") or "",
            "releaseTitle": job.get("releaseTitle"),
            "nzbgetId": job.get("nzbgetId"),
            "error": job.get("error"),
            "ok": job["status"] != "failed",
        }
