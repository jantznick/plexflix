"""Caching front for the vendored roku-feed advanced-proxy.

entrypoint.sh runs advanced-proxy on 127.0.0.1:18787 (exact proxy JS). This
module is only a loopback cache so ffmpeg's aggressive HLS re-polls do not
re-open Puppeteer / re-fetch multi‑MB segments on every tick. Fetch + unwrap
still happen in the Node proxy — we just memoize the responses.
"""

import collections
import re
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

_PROXY_PATH = re.compile(r"/proxy/(.+)$")
_PROXY_URL = re.compile(r"https?://[^/\s\"']+/proxy/[A-Za-z0-9+/=_%.-]+")

# Live playlists are ~5–7s target duration. Keep Chromium off the hot path:
# serve fresh for a few seconds, then stale immediately while a background
# refresh runs (ffmpeg polls many times a second).
MANIFEST_TTL = 4.0
MANIFEST_STALE_TTL = 45
SEGMENT_TTL = 120
SEGMENT_CACHE_MAX = 96
PREFETCH_SEGMENTS = 3
TOKEN_TTL = 3600
UPSTREAM_TIMEOUT = 90  # Chromium cold start can take ~45s per embed


def local_proxy_base():
    import os
    port = os.environ.get("MULTIVIEW_PROXY_PORT", "18787")
    return os.environ.get("MULTIVIEW_PROXY_URL", f"http://127.0.0.1:{port}").rstrip("/")


def rewrite_to_local_proxy(url):
    match = _PROXY_PATH.search(urllib.parse.urlsplit(url).path)
    if not match:
        return url
    return f"{local_proxy_base()}/proxy/{match.group(1)}"


class RelayError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


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
            event.wait(UPSTREAM_TIMEOUT + 10)
        if "error" in holder:
            raise holder["error"]
        if "value" not in holder:
            raise RelayError(HTTPStatus.BAD_GATEWAY, "upstream fetch timed out")
        return holder["value"]


class Relay:
    def __init__(self, fetch=None, clock=time.monotonic, variant_height=720):
        self._fetch = fetch or self._http_get
        self._clock = clock
        self.variant_height = variant_height
        self.port = 0
        self.stats = collections.Counter()
        self._tokens = {}
        self._token_keys = {}
        self._manifest_cache = {}
        self._segment_cache = collections.OrderedDict()
        self._flight = _SingleFlight()
        self._lock = threading.RLock()
        self._revalidating = set()
        self._server = None

    def _http_get(self, url, timeout):
        request = urllib.request.Request(url, headers={"User-Agent": "multiview-relay/1"})
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.status, response.read(), response.headers.get("Content-Type", "")
        except urllib.error.HTTPError as exc:
            body = b""
            try:
                body = exc.read()
            except Exception:
                pass
            return exc.code, body, ""

    def url_for(self, upstream_url):
        """Stable local URL for an absolute vendored-proxy URL."""
        with self._lock:
            token = self._token_keys.get(upstream_url)
            if token is None or token not in self._tokens:
                token = secrets.token_urlsafe(18)
                self._token_keys[upstream_url] = token
            self._tokens[token] = (upstream_url, self._clock())
            if len(self._tokens) > 4000:
                self._prune_tokens()
        path = urllib.parse.urlsplit(upstream_url).path.lower()
        ext = ".m3u8" if ".m3u8" in path else ".ts"
        return f"http://127.0.0.1:{self.port}/r/{token}{ext}"

    def warm(self, urls):
        """Hit the proxy (via cache) for each feed URL before ffmpeg starts."""
        def one(url):
            try:
                self.handle(self.url_for(url).split("/r/", 1)[1].rsplit(".", 1)[0])
                self._count("warm_ok")
            except Exception as exc:
                self._count("warm_failed")
                print(f"[relay] warm failed {url[:80]}: {exc}", flush=True)

        threads = [threading.Thread(target=one, args=(u,), daemon=True) for u in urls]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=UPSTREAM_TIMEOUT + 15)

    def handle(self, token):
        with self._lock:
            entry = self._tokens.get(token)
        if entry is None:
            raise RelayError(HTTPStatus.NOT_FOUND, "bad or expired relay token")
        upstream_url = entry[0]
        # /proxy/<base64> paths do not end in .m3u8 — sniff after fetch.
        body = self._fetch_cached(upstream_url)
        if body.lstrip().startswith(b"#EXTM3U"):
            return "application/vnd.apple.mpegurl", body
        return "video/mp2t", body

    def fetch(self, upstream_url):
        """Fetch by absolute vendored-proxy URL (same cache as /r/<token>)."""
        return self.handle(self.url_for(upstream_url).split("/r/", 1)[1].rsplit(".", 1)[0])

    def relative_playlist(self, body):
        """Rewrite loopback relay URLs so a Roku on the LAN can follow them."""
        if not body.lstrip().startswith(b"#EXTM3U"):
            return body
        text = body.decode("utf-8", "replace")
        text = text.replace(f"http://127.0.0.1:{self.port}/r/", "r/")
        return text.encode("utf-8")

    def _fetch_cached(self, upstream_url):
        """Manifest or segment, with the right cache, based on response body."""
        now = self._clock()
        with self._lock:
            cached_m = self._manifest_cache.get(upstream_url)
            cached_s = self._segment_cache.get(upstream_url)

        if cached_m is not None:
            fresh_until, stale_until, text = cached_m
            if fresh_until > now:
                self._count("manifest_cache")
                return text.encode("utf-8")
            if stale_until > now:
                # Don't block ffmpeg on Chromium — refresh in the background.
                self._count("manifest_stale")
                self._revalidate_later(upstream_url)
                return text.encode("utf-8")

        if cached_s is not None and cached_s[0] > now:
            with self._lock:
                self._segment_cache.move_to_end(upstream_url)
            self._count("segment_cache")
            return cached_s[1]

        try:
            return self._flight.do(("u", upstream_url), lambda: self._load_upstream(upstream_url))
        except RelayError:
            if cached_m is not None and cached_m[1] > now:
                self._count("manifest_stale")
                return cached_m[2].encode("utf-8")
            self._count("fetch_failed")
            raise

    def _revalidate_later(self, upstream_url):
        with self._lock:
            if upstream_url in self._revalidating:
                return
            self._revalidating.add(upstream_url)

        def run():
            try:
                self._flight.do(("u", upstream_url), lambda: self._load_upstream(upstream_url))
                self._count("manifest_revalidate")
            except Exception:
                self._count("manifest_revalidate_failed")
            finally:
                with self._lock:
                    self._revalidating.discard(upstream_url)

        threading.Thread(target=run, name="relay-revalidate", daemon=True).start()

    def _load_upstream(self, upstream_url):
        with self._lock:
            again_m = self._manifest_cache.get(upstream_url)
            if again_m is not None and again_m[0] > self._clock():
                return again_m[2].encode("utf-8")
            again_s = self._segment_cache.get(upstream_url)
            if again_s is not None and again_s[0] > self._clock():
                return again_s[1]
        status, body, _ = self._fetch(upstream_url, UPSTREAM_TIMEOUT)
        if not 200 <= status < 300 or not body:
            raise RelayError(HTTPStatus.BAD_GATEWAY, f"proxy HTTP {status}")
        if body.lstrip().startswith(b"#EXTM3U"):
            text = self._rewrite_playlist(body.decode("utf-8", "replace"))
            stamp = self._clock()
            with self._lock:
                self._manifest_cache[upstream_url] = (
                    stamp + MANIFEST_TTL, stamp + MANIFEST_STALE_TTL, text)
            self._count("manifest_proxy")
            self._prefetch_from_playlist(text)
            return text.encode("utf-8")
        with self._lock:
            self._segment_cache[upstream_url] = (self._clock() + SEGMENT_TTL, body)
            self._segment_cache.move_to_end(upstream_url)
            while len(self._segment_cache) > SEGMENT_CACHE_MAX:
                self._segment_cache.popitem(last=False)
        self._count("segment_proxy")
        return body

    def _prefetch_from_playlist(self, text):
        targets = []
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("http://127.0.0.1:") and "/r/" in line:
                targets.append(line)
        for local_url in targets[-PREFETCH_SEGMENTS:]:
            token = local_url.split("/r/", 1)[1].rsplit(".", 1)[0]
            with self._lock:
                entry = self._tokens.get(token)
            if entry is None:
                continue
            upstream = entry[0]
            with self._lock:
                cached = self._segment_cache.get(upstream)
                if cached is not None and cached[0] > self._clock():
                    continue
            threading.Thread(
                target=self._prefetch_one, args=(upstream,),
                name="relay-prefetch", daemon=True,
            ).start()

    def _prefetch_one(self, upstream_url):
        try:
            self._flight.do(("u", upstream_url), lambda: self._load_upstream(upstream_url))
            self._count("segment_prefetch")
        except Exception:
            pass

    def _rewrite_playlist(self, text):
        """Point every vendored-proxy URL in the playlist back through this cache."""
        def repl(match):
            return self.url_for(match.group(0))
        return _PROXY_URL.sub(repl, text)

    def _count(self, key):
        with self._lock:
            self.stats[key] += 1

    def _prune_tokens(self):
        cutoff = self._clock() - TOKEN_TTL
        alive = {k: v for k, v in self._tokens.items() if v[1] >= cutoff}
        self._tokens = alive
        self._token_keys = {k: t for k, t in self._token_keys.items() if t in alive}

    def snapshot(self):
        with self._lock:
            stats = dict(self.stats)
        stats["proxy"] = local_proxy_base()
        stats["proxy_up"] = self.proxy_up()
        return stats

    def proxy_up(self):
        try:
            urllib.request.urlopen(f"{local_proxy_base()}/", timeout=2)
            return True
        except Exception:
            return False

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
            try:
                content_type, body = relay.handle(token)
            except RelayError as exc:
                print(f"[relay] {token[:16]}: {exc}", flush=True)
                return self._send(exc.status, "text/plain", str(exc).encode("utf-8"))
            # Manifests mis-detected as segments come back as text
            if body.lstrip()[:7] == b"#EXTM3U":
                content_type = "application/vnd.apple.mpegurl"
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
    upstream = rewrite_to_local_proxy(url)
    return relay.url_for(upstream)
