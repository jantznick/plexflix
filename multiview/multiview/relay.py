"""Point ingest at the vendored roku-feed advanced-proxy running in this container.

The proxy sources live in multiview/proxy + multiview/src (copied from roku-feed).
entrypoint.sh starts advanced-proxy on 127.0.0.1:8787. Feeds that already carry a
/proxy/<payload> URL are rewritten to that local instance — same code path as the
standalone sidecar, not a Python reimplementation.
"""

import collections
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

_PROXY_PATH = re.compile(r"/proxy/(.+)$")


def local_proxy_base():
    port = os.environ.get("MULTIVIEW_PROXY_PORT", "18787")
    return os.environ.get("MULTIVIEW_PROXY_URL", f"http://127.0.0.1:{port}").rstrip("/")


def rewrite_to_local_proxy(url):
    """Keep the /proxy/<payload> path; force the host to the in-container proxy."""
    match = _PROXY_PATH.search(urllib.parse.urlsplit(url).path)
    if not match:
        return url
    return f"{local_proxy_base()}/proxy/{match.group(1)}"


class Relay:
    """Thin health/stats wrapper around the vendored Node proxy (no CDN fetches)."""

    def __init__(self, fetch=None, clock=time.monotonic, variant_height=720):
        self._clock = clock
        self.variant_height = variant_height
        self.port = int(os.environ.get("MULTIVIEW_PROXY_PORT", "18787"))
        self.stats = collections.Counter()
        self._lock = threading.Lock()

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
        # Nothing to bind — Node advanced-proxy is started by entrypoint.sh
        return self

    def close(self):
        pass


def source_for(spec, relay=None):
    url = spec["url"]
    if not url.startswith(("http://", "https://")):
        return url
    local = rewrite_to_local_proxy(url)
    if local != url and relay is not None:
        with relay._lock:
            relay.stats["via_vendored_proxy"] += 1
    return local
