"""Minimal HTTP helpers (stdlib only)."""

from __future__ import annotations

import base64
import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


def http_json(
    url: str,
    *,
    method: str = "GET",
    body: dict | list | None = None,
    headers: dict | None = None,
    timeout: float = 30.0,
    auth: tuple[str, str] | None = None,
) -> Any:
    data = None
    req_headers = {"Accept": "application/json", "User-Agent": "PlexFlixGrab/0.1"}
    if headers:
        req_headers.update(headers)
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        req_headers.setdefault("Content-Type", "application/json")
    request = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    if auth is not None:
        user, password = auth
        token = base64.b64encode(f"{user}:{password}".encode("utf-8")).decode("ascii")
        request.add_header("Authorization", f"Basic {token}")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            raw = resp.read()
            if not raw:
                return None
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from {url}: {detail[:300]}") from exc


def http_bytes(
    url: str,
    *,
    headers: dict | None = None,
    timeout: float = 60.0,
    auth: tuple[str, str] | None = None,
) -> bytes:
    req_headers = {"User-Agent": "PlexFlixGrab/0.1"}
    if headers:
        req_headers.update(headers)
    request = urllib.request.Request(url, headers=req_headers, method="GET")
    if auth is not None:
        user, password = auth
        token = base64.b64encode(f"{user}:{password}".encode("utf-8")).decode("ascii")
        request.add_header("Authorization", f"Basic {token}")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from {url}: {detail[:300]}") from exc


def http_xml_get(url: str, *, timeout: float = 30.0) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"Accept": "application/xml", "User-Agent": "PlexFlixGrab/0.1"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from {url}: {detail[:300]}") from exc


def build_query(base: str, params: dict) -> str:
    cleaned = {k: v for k, v in params.items() if v is not None and v != ""}
    return base + "?" + urllib.parse.urlencode(cleaned)
