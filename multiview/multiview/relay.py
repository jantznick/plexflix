"""A loopback HLS relay that fetches feeds the way roku-feed's proxy does.

Every playlist and segment the ingest ffmpegs read goes through here. The
relay talks to the CDNs itself, with the referer and headers the proxy would
use, so the proxy only does what nothing else can: manifests that need its
Chromium session (d=0 payloads), and anything that fails when fetched
directly. Hosts that keep refusing direct fetches go to the proxy first for a
while, rather than paying for a failed attempt on every segment.
"""

import base64
import collections
import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .feedurl import (
    Upstream, manifest_headers, parse_feed_url, rewrite_manifest, segment_headers, unwrap_goat,
)
from .hls import filter_master

MANIFEST_TIMEOUT = 10
SEGMENT_TIMEOUT = 20
# The proxy's Chromium capture can take a while on a cold embed page
PROXY_MANIFEST_TIMEOUT = 30
DIRECT_FAILURES_BEFORE_PROXY_FIRST = 3
PROXY_FIRST_SECONDS = 300
MAX_BODY = 64 * 1024 * 1024
_MEDIA_EXTENSIONS = (".ts", ".m4s", ".mp4", ".aac", ".m4a", ".vtt", ".key")


class RelayError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def http_fetch(url, headers, timeout):
    """(status, body, final_url). Network failures raise."""
    request = urllib.request.Request(url, headers=dict(headers))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read(MAX_BODY), response.geturl()
    except urllib.error.HTTPError as exc:
        return exc.code, b"", url


def encode_token(upstream, kind):
    data = dict(upstream.to_json(), k=kind)
    raw = json.dumps(data, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_token(token):
    try:
        raw = base64.urlsafe_b64decode(token + "=" * (-len(token) % 4))
        data = json.loads(raw)
    except ValueError:
        return None, None
    if not isinstance(data, dict) or not data.get("u"):
        return None, None
    return Upstream.from_json(data), data.get("k", "s")


class Relay:
    def __init__(self, fetch=http_fetch, clock=time.monotonic, variant_height=720):
        self._fetch = fetch
        self._clock = clock
        self.variant_height = variant_height
        self.port = 0
        self.stats = collections.Counter()
        self._hosts = {}  # host -> [consecutive direct failures, proxy-first until]
        self._lock = threading.Lock()
        self._server = None

    # ------------------------------------------------------------------

    def url_for(self, upstream, kind):
        """Local URL for an upstream. kind: "feed" (top level), "m", "s"."""
        if kind in ("feed", "m"):
            ext = ".m3u8"
        else:
            path = urllib.parse.urlsplit(upstream.url).path.lower()
            ext = next((e for e in _MEDIA_EXTENSIONS if path.endswith(e)), ".ts")
        return f"http://127.0.0.1:{self.port}/r/{encode_token(upstream, kind)}{ext}"

    def handle(self, token):
        """(content type, body) for a token from url_for()."""
        upstream, kind = decode_token(token)
        if upstream is None:
            raise RelayError(HTTPStatus.NOT_FOUND, "bad relay token")
        if kind in ("feed", "m"):
            return "application/vnd.apple.mpegurl", self.manifest(upstream, kind == "feed").encode("utf-8")
        return "video/mp2t", self.segment(upstream)

    def manifest(self, upstream, top_level=False):
        attempts = []
        if upstream.direct_ok or not upstream.proxy_url:
            attempts.append(("direct", upstream.url, manifest_headers(upstream.referer, upstream.headers),
                             MANIFEST_TIMEOUT))
        if upstream.proxy_url:
            attempts.append(("proxy", upstream.proxy_url, {}, PROXY_MANIFEST_TIMEOUT))
        errors = []
        for route, url, headers, timeout in attempts:
            try:
                status, body, final_url = self._fetch(url, headers, timeout)
            except Exception as exc:  # timeouts, refused, DNS
                errors.append(f"{route}: {exc or exc.__class__.__name__}")
                continue
            text = body.decode("utf-8", "replace").lstrip("\ufeff")
            if not 200 <= status < 300 or "#EXTM3U" not in text[:1024]:
                errors.append(f"{route}: HTTP {status}" if status >= 300 else f"{route}: not a playlist")
                continue
            self._count(f"manifest_{route}")
            if top_level and "#EXT-X-STREAM-INF" in text:
                text = filter_master(text, self.variant_height)
            return rewrite_manifest(text, final_url or url, upstream,
                                    lambda target, is_manifest: self.url_for(target, "m" if is_manifest else "s"))
        self._count("manifest_failed")
        raise RelayError(HTTPStatus.BAD_GATEWAY, "; ".join(errors) or "no way to fetch manifest")

    def segment(self, upstream):
        host = urllib.parse.urlsplit(upstream.url).netloc
        direct = ("direct", upstream.url, segment_headers(upstream.referer, upstream.headers))
        attempts = [direct]
        if upstream.proxy_url:
            proxy = ("proxy", upstream.proxy_url, {})
            attempts = [proxy, direct] if self._proxy_first(host) else [direct, proxy]
        errors = []
        for route, url, headers in attempts:
            try:
                status, body, _ = self._fetch(url, headers, SEGMENT_TIMEOUT)
                ok = 200 <= status < 300 and body and not _looks_like_html(body)
                reason = "" if ok else (f"HTTP {status}" if status >= 300 else "not media")
            except Exception as exc:
                ok, reason = False, str(exc) or exc.__class__.__name__
            if route == "direct":
                self._direct_result(host, ok)
            if ok:
                self._count(f"segment_{route}")
                return unwrap_goat(body)
            errors.append(f"{route}: {reason}")
        self._count("segment_failed")
        raise RelayError(HTTPStatus.BAD_GATEWAY, "; ".join(errors))

    # ------------------------------------------------------------------

    def _proxy_first(self, host):
        with self._lock:
            entry = self._hosts.get(host)
            return bool(entry) and entry[1] > self._clock()

    def _direct_result(self, host, ok):
        with self._lock:
            entry = self._hosts.setdefault(host, [0, 0.0])
            if ok:
                entry[0] = 0
                entry[1] = 0.0
                return
            entry[0] += 1
            if entry[0] >= DIRECT_FAILURES_BEFORE_PROXY_FIRST and entry[1] <= self._clock():
                entry[1] = self._clock() + PROXY_FIRST_SECONDS
                print(f"[relay] {host}: direct fetches failing, using the proxy first for "
                      f"{PROXY_FIRST_SECONDS}s", flush=True)

    def _count(self, key):
        with self._lock:
            self.stats[key] += 1

    def snapshot(self):
        with self._lock:
            return dict(self.stats)

    # ------------------------------------------------------------------

    def serve(self, host="127.0.0.1", port=0):
        self._server = ThreadingHTTPServer((host, port), _make_handler(self))
        self._server.daemon_threads = True
        self.port = self._server.server_address[1]
        threading.Thread(target=self._server.serve_forever, name="relay", daemon=True).start()
        return self

    def close(self):
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._server = None


def _looks_like_html(body):
    head = body[:64].lstrip().lower()
    return head.startswith((b"<!doctype", b"<html"))


def _make_handler(relay):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt, *args):
            pass

        def do_GET(self):
            path = self.path.split("?", 1)[0]
            if not path.startswith("/r/"):
                return self._send(HTTPStatus.NOT_FOUND, "text/plain", b"not found")
            token = path[3:].rsplit(".", 1)[0]
            try:
                content_type, body = relay.handle(token)
            except RelayError as exc:
                print(f"[relay] {exc}", flush=True)
                return self._send(exc.status, "text/plain", str(exc).encode("utf-8"))
            return self._send(HTTPStatus.OK, content_type, body)

        def _send(self, status, content_type, body):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    return Handler


def source_for(spec, relay):
    """What an ingest ffmpeg should open for a stream spec."""
    url = spec["url"]
    if relay is None or not url.startswith(("http://", "https://")):
        return url
    upstream = parse_feed_url(url)
    if spec.get("headers"):
        upstream.headers = dict(upstream.headers, **spec["headers"])
    return relay.url_for(upstream, "feed")
