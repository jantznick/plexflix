"""NZBGet JSON-RPC client."""

from __future__ import annotations

import base64
from typing import Any

from .httputil import http_json


def _u32_pair(lo: int, hi: int) -> int:
    return (int(hi) << 32) + int(lo)


class NzbGet:
    def __init__(self, base_url: str, username: str = "", password: str = ""):
        self.base_url = base_url.rstrip("/")
        self.username = username
        self.password = password
        self._rpc_id = 0

    def _auth(self) -> tuple[str, str] | None:
        if self.username or self.password:
            return (self.username or "", self.password or "")
        return None

    def call(self, method: str, params: list | None = None) -> Any:
        self._rpc_id += 1
        # NZBGet's JSON parser is picky: put id before params
        payload = {
            "jsonrpc": "2.0",
            "id": self._rpc_id,
            "method": method,
            "params": params or [],
        }
        url = f"{self.base_url}/jsonrpc"
        result = http_json(url, method="POST", body=payload, auth=self._auth())
        if not isinstance(result, dict):
            raise RuntimeError(f"NZBGet returned unexpected payload: {result!r}")
        if result.get("error"):
            raise RuntimeError(f"NZBGet error: {result['error']}")
        return result.get("result")

    def append(
        self,
        *,
        filename: str,
        nzb_content: bytes,
        category: str,
        priority: int = 900,
        add_to_top: bool = True,
        dupe_key: str = "",
        dupe_mode: str = "SCORE",
    ) -> int:
        """Add an NZB with Force-capable priority. Returns NZBGet NZBID."""
        content_b64 = base64.b64encode(nzb_content).decode("ascii")
        # Filename, Content, Category, Priority, AddToTop, AddPaused,
        # DupeKey, DupeScore, DupeMode, PPParameters
        nzb_id = self.call(
            "append",
            [
                filename if filename.endswith(".nzb") else f"{filename}.nzb",
                content_b64,
                category,
                int(priority),
                bool(add_to_top),
                False,
                dupe_key,
                0,
                dupe_mode,
                [],
            ],
        )
        return int(nzb_id)

    def list_groups(self) -> list[dict]:
        result = self.call("listgroups")
        return list(result or [])

    def history(self, number_of_entries: int = 50) -> list[dict]:
        result = self.call("history", [False])
        items = list(result or [])
        return items[:number_of_entries]

    def find_group(self, nzb_id: int) -> dict | None:
        for group in self.list_groups():
            if int(group.get("NZBID") or 0) == int(nzb_id):
                return group
        return None

    def find_history(self, nzb_id: int) -> dict | None:
        for item in self.history(200):
            if int(item.get("NZBID") or 0) == int(nzb_id):
                return item
        return None

    @staticmethod
    def progress_from_group(group: dict) -> dict:
        total = _u32_pair(group.get("FileSizeLo") or 0, group.get("FileSizeHi") or 0)
        done = _u32_pair(
            group.get("DownloadedSizeLo") or 0, group.get("DownloadedSizeHi") or 0
        )
        percent = 0
        if total > 0:
            percent = max(0, min(100, int(done * 100 / total)))
        status = str(group.get("Status") or "")
        remaining = max(0, total - done)
        # NZBGet exposes DownloadTimeSec / RemainingSizeMB-ish via health; ETA best-effort
        eta_seconds = None
        speed = _u32_pair(
            group.get("DownloadRateLo") or group.get("DownloadRate") or 0,
            group.get("DownloadRateHi") or 0,
        )
        # DownloadRate is often bytes/sec directly on modern NZBGet as DownloadRate field
        rate = int(group.get("DownloadRate") or 0)
        if rate <= 0 and speed > 0:
            rate = speed
        if rate > 0 and remaining > 0:
            eta_seconds = int(remaining / rate)

        stage = "downloading"
        upper = status.upper()
        if "QUEUED" in upper:
            stage = "queued"
        elif "PP" in upper or "UNPACK" in upper or "MOVE" in upper or "RENAME" in upper:
            stage = "unpacking"
        elif "DOWNLOADING" in upper:
            stage = "downloading"

        return {
            "stage": stage,
            "status": status,
            "percent": percent,
            "bytesTotal": total,
            "bytesDone": done,
            "etaSeconds": eta_seconds,
            "name": group.get("NZBName") or group.get("Name") or "",
        }

    @staticmethod
    def outcome_from_history(item: dict) -> dict:
        status = str(item.get("Status") or "")
        upper = status.upper()
        ok = "SUCCESS" in upper
        return {
            "stage": "completed" if ok else "failed",
            "status": status,
            "percent": 100 if ok else 0,
            "bytesTotal": _u32_pair(item.get("FileSizeLo") or 0, item.get("FileSizeHi") or 0),
            "bytesDone": _u32_pair(
                item.get("DownloadedSizeLo") or 0, item.get("DownloadedSizeHi") or 0
            ),
            "etaSeconds": 0,
            "name": item.get("NZBName") or item.get("Name") or "",
            "ok": ok,
        }
