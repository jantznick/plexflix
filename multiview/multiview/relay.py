"""A loopback HLS relay that fetches feeds the way roku-feed's proxy does.

Proxy URLs in the sports feed are decoded for their real CDN URL and the
referer / cookies / headers the CDN wants. From then on this process talks to
the CDN itself — same headers, Chrome TLS fingerprint, GOAT unwrap. It never
calls the roku-feed proxy: if we can't get a feed, the proxy on the same box
would only add load for the same failure.

ffmpeg re-polls playlists many times a second and re-reads the same segments,
so manifests and segments are cached and identical in-flight fetches share one
upstream call.
"""

import collections
import secrets
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
from .hls import choose_variant, parse_master

MANIFEST_TIMEOUT = 10
SEGMENT_TIMEOUT = 20
MAX_BODY = 64 * 1024 * 1024
TOKEN_TTL = 3600
MANIFEST_TTL = 1.5
MANIFEST_STALE_TTL = 12
SEGMENT_TTL = 120
SEGMENT_CACHE_MAX = 96
PREFETCH_SEGMENTS = 3
_MEDIA_EXTENSIONS = (".ts", ".m4s", ".mp4", ".aac", ".m4a", ".vtt", ".key")
# Match what Node's fetch looks like to CDNs that fingerprint TLS
_CHROME_IMPERSONATE = "chrome131"


class RelayError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def http_fetch(url, headers, timeout):
    """(status, body, final_url). Uses Chrome TLS when curl_cffi is available."""
    try:
        from curl_cffi import requests as crequests
    except ImportError:
        crequests = None
    if crequests is not None:
        response = crequests.get(
            url, headers=dict(headers), timeout=timeout, allow_redirects=True,
            impersonate=_CHROME_IMPERSONATE,
        )
        body = response.content
        if len(body) > MAX_BODY:
            body = body[:MAX_BODY]
        return response.status_code, body, str(response.url)

    request = urllib.request.Request(url, headers=dict(headers))
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read(MAX_BODY), response.geturl()
    except urllib.error.HTTPError as exc:
        body = b""
        try:
            body = exc.read(MAX_BODY)
        except Exception:
            pass
        return exc.code, body, url


class _SingleFlight:
    def __init__(self):
        self._lock = threading.Lock()
        self._inflight = {}

    def do(self, key, fn):
        with self._lock:
            existing = self._inflight.get(key)
            if existing is None:
                event = threading.Event()
                holder = {}
                self._inflight[key] = (event, holder)
                leader = True
            else:
                event, holder = existing
                leader = False
        if leader:
            try:
                holder["value"] = fn()
            except Exception as exc:
                holder["error"] = exc
            finally:
                with self._lock:
                    self._inflight.pop(key, None)
                event.set()
        else:
            event.wait(SEGMENT_TIMEOUT + MANIFEST_TIMEOUT + 5)
        if "error" in holder:
            raise holder["error"]
        if "value" not in holder:
            raise RelayError(HTTPStatus.BAD_GATEWAY, "upstream fetch timed out")
        return holder["value"]


class Relay:
    def __init__(self, fetch=http_fetch, clock=time.monotonic, variant_height=720):
        self._fetch = fetch
        self._clock = clock
        self.variant_height = variant_height
        self.port = 0
        self.stats = collections.Counter()
        self._tokens = {}
        self._token_keys = {}
        self._manifest_cache = {}
        self._segment_cache = collections.OrderedDict()
        self._flight = _SingleFlight()
        self._lock = threading.Lock()
        self._server = None

    def url_for(self, upstream, kind):
        """Stable local URL so playlist rewrites reuse tokens."""
        key = (kind, upstream.url, upstream.referer or "",
               tuple(sorted((upstream.headers or {}).items())))
        with self._lock:
            token = self._token_keys.get(key)
            if token is None or token not in self._tokens:
                token = secrets.token_urlsafe(18)
                self._token_keys[key] = token
            self._tokens[token] = (upstream, kind, self._clock())
            if len(self._tokens) > 4000:
                self._prune_tokens()
        if kind in ("feed", "m"):
            ext = ".m3u8"
        else:
            path = urllib.parse.urlsplit(upstream.url).path.lower()
            ext = next((e for e in _MEDIA_EXTENSIONS if path.endswith(e)), ".ts")
        return f"http://127.0.0.1:{self.port}/r/{token}{ext}"

    def resolve_token(self, token):
        with self._lock:
            entry = self._tokens.get(token)
        if entry is None:
            return None, None
        return entry[0], entry[1]

    def handle(self, token):
        upstream, kind = self.resolve_token(token)
        if upstream is None:
            raise RelayError(HTTPStatus.NOT_FOUND, "bad or expired relay token")
        if kind in ("feed", "m"):
            return "application/vnd.apple.mpegurl", self.manifest(upstream, kind == "feed").encode("utf-8")
        return "video/mp2t", self.segment(upstream)

    def _load(self, upstream):
        """Fetch a playlist from the CDN only — never the roku-feed proxy."""
        url = upstream.url
        headers = manifest_headers(upstream.referer, upstream.headers)
        try:
            status, body, final_url = self._fetch(url, headers, MANIFEST_TIMEOUT)
        except Exception as exc:
            raise RelayError(HTTPStatus.BAD_GATEWAY, f"direct: {exc or exc.__class__.__name__}") from exc
        text = body.decode("utf-8", "replace").lstrip("\ufeff")
        if not 200 <= status < 300 or "#EXTM3U" not in text[:1024]:
            hint = f"HTTP {status}" if status >= 300 else "not a playlist"
            if body and "#EXTM3U" not in text[:1024]:
                hint += f" ({body[:80]!r})"
            raise RelayError(HTTPStatus.BAD_GATEWAY, f"direct: {hint}")
        return text, final_url or url

    def _child_upstream(self, parent, absolute_url):
        # Nested proxy URLs in a playlist (shouldn't appear on a CDN manifest)
        # still get unwrapped to the real upstream
        if absolute_url.startswith(("http://", "https://")) and "/proxy/" in absolute_url:
            child = parse_feed_url(absolute_url)
            if child.url != absolute_url:
                return child
        return Upstream(url=absolute_url, referer=parent.referer, headers=dict(parent.headers),
                        embed=parent.embed, direct_ok=True, proxy_url="")

    def manifest(self, upstream, top_level=False):
        cache_key = ("m", top_level, upstream.url, upstream.referer or "")
        now = self._clock()
        with self._lock:
            cached = self._manifest_cache.get(cache_key)
        if cached is not None and cached[0] > now:
            self._count("manifest_cache")
            return cached[2]

        def load():
            with self._lock:
                again = self._manifest_cache.get(cache_key)
            if again is not None and again[0] > self._clock():
                return again[2]
            return self._manifest_uncached(upstream, top_level, cache_key)

        try:
            return self._flight.do(("manifest", cache_key), load)
        except RelayError:
            if cached is not None and cached[1] > now:
                self._count("manifest_stale")
                return cached[2]
            self._count("manifest_failed")
            raise

    def _manifest_uncached(self, upstream, top_level, cache_key):
        text, final_url = self._load(upstream)
        context = upstream
        resolved = False
        if top_level and "#EXT-X-STREAM-INF" in text:
            variant = choose_variant(parse_master(text, final_url), self.variant_height)
            if variant is None:
                raise RelayError(HTTPStatus.BAD_GATEWAY, "master playlist has no variants")
            media = self._child_upstream(upstream, variant["url"])
            text, final_url = self._load(media)
            context = media
            resolved = True
            self._count("manifest_resolved")
        self._count("manifest_direct")
        segment_targets = []

        def local(target, is_manifest):
            if not is_manifest:
                segment_targets.append(target)
            return self.url_for(target, "m" if is_manifest else "s")

        rewritten = rewrite_manifest(text, final_url, context, local)
        segments = sum(1 for line in rewritten.splitlines() if line.strip() and not line.strip().startswith("#"))
        if segments == 0:
            raise RelayError(HTTPStatus.BAD_GATEWAY, "playlist has no segments after rewrite")
        now = self._clock()
        with self._lock:
            self._manifest_cache[cache_key] = (now + MANIFEST_TTL, now + MANIFEST_STALE_TTL, rewritten)
        note = " (resolved master)" if resolved else ""
        print(f"[relay] {upstream.url}: {segments} segments via direct{note}", flush=True)
        self._prefetch(segment_targets[-PREFETCH_SEGMENTS:])
        return rewritten

    def segment(self, upstream):
        now = self._clock()
        with self._lock:
            cached = self._segment_cache.get(upstream.url)
            if cached is not None and cached[0] > now:
                self._segment_cache.move_to_end(upstream.url)
                self._count("segment_cache")
                return cached[1]

        def load():
            with self._lock:
                again = self._segment_cache.get(upstream.url)
            if again is not None and again[0] > self._clock():
                return again[1]
            body = self._segment_uncached(upstream)
            with self._lock:
                self._segment_cache[upstream.url] = (self._clock() + SEGMENT_TTL, body)
                self._segment_cache.move_to_end(upstream.url)
                while len(self._segment_cache) > SEGMENT_CACHE_MAX:
                    self._segment_cache.popitem(last=False)
            return body

        return self._flight.do(("segment", upstream.url), load)

    def _segment_uncached(self, upstream):
        headers = segment_headers(upstream.referer, upstream.headers)
        try:
            status, body, _ = self._fetch(upstream.url, headers, SEGMENT_TIMEOUT)
        except Exception as exc:
            self._count("segment_failed")
            raise RelayError(HTTPStatus.BAD_GATEWAY, f"direct: {exc or exc.__class__.__name__}") from exc
        if not 200 <= status < 300:
            self._count("segment_failed")
            raise RelayError(HTTPStatus.BAD_GATEWAY, f"direct: HTTP {status}")
        if not body:
            self._count("segment_failed")
            raise RelayError(HTTPStatus.BAD_GATEWAY, "direct: empty body")
        if not _looks_like_media(body):
            self._count("segment_failed")
            raise RelayError(
                HTTPStatus.BAD_GATEWAY,
                f"direct: not media ({len(body)} bytes, head={body[:24]!r})",
            )
        self._count("segment_direct")
        return unwrap_goat(body)

    def _prefetch(self, targets):
        for upstream in targets:
            with self._lock:
                cached = self._segment_cache.get(upstream.url)
                if cached is not None and cached[0] > self._clock():
                    continue
            threading.Thread(target=self._prefetch_one, args=(upstream,),
                             name="relay-prefetch", daemon=True).start()

    def _prefetch_one(self, upstream):
        try:
            self.segment(upstream)
            self._count("segment_prefetch")
        except Exception:
            pass

    def _count(self, key):
        with self._lock:
            self.stats[key] += 1

    def _prune_tokens(self):
        cutoff = self._clock() - TOKEN_TTL
        alive = {k: v for k, v in self._tokens.items() if v[2] >= cutoff}
        self._tokens = alive
        self._token_keys = {k: t for k, t in self._token_keys.items() if t in alive}

    def snapshot(self):
        with self._lock:
            return dict(self.stats)

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


def _looks_like_media(body):
    if not body or _looks_like_html(body):
        return False
    head = body.lstrip()
    if head[:1] in (b"{", b"[") or head.lower().startswith((b"<", b"error", b"forbidden", b"denied")):
        return False
    payload = unwrap_goat(body)
    if len(payload) == 16:
        return True
    if payload and payload[0] == 0x47:
        return True
    if b"ftyp" in payload[:64]:
        return True
    return False


def _make_handler(relay):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.0"

        def log_message(self, fmt, *args):
            pass

        def handle(self):
            try:
                super().handle()
            except (ConnectionResetError, BrokenPipeError):
                pass

        def do_GET(self):
            path = self.path.split("?", 1)[0]
            if not path.startswith("/r/"):
                return self._send(HTTPStatus.NOT_FOUND, "text/plain", b"not found")
            token = path[3:].rsplit(".", 1)[0]
            upstream, kind = relay.resolve_token(token)
            label = upstream.url if upstream is not None else token[:24]
            try:
                content_type, body = relay.handle(token)
            except RelayError as exc:
                print(f"[relay] {kind or '?'} {label}: {exc}", flush=True)
                return self._send(exc.status, "text/plain", str(exc).encode("utf-8"))
            return self._send(HTTPStatus.OK, content_type, body)

        def _send(self, status, content_type, body):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "close")
            self.end_headers()
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    return Handler


def source_for(spec, relay):
    url = spec["url"]
    if relay is None or not url.startswith(("http://", "https://")):
        return url
    upstream = parse_feed_url(url)
    if spec.get("headers"):
        upstream.headers = dict(upstream.headers, **spec["headers"])
    # Drop any proxy_url so nothing downstream is tempted to use it
    upstream.proxy_url = ""
    upstream.direct_ok = True
    return relay.url_for(upstream, "feed")
