"""Understanding roku-feed's proxy URLs, so feeds can be fetched the way the
proxy fetches them instead of through it.

Mirrors roku-feed/src/proxy-payload.js and proxy/advanced-proxy.js: a feed URL
of the form http://<proxy>/proxy/<base64> carries the real URL and the headers
the CDN wants. Manifests the proxy serves point their segments back at the
proxy in the same form, so those are unwrapped the same way.
"""

import base64
import binascii
import json
import re
import urllib.parse
from dataclasses import dataclass, field

# Keep in lockstep with roku-feed/src/proxy-payload.js
DEFAULT_REFERER = "https://embedsports.top/"
BROWSER_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/154.0.0.0 Safari/537.36"
)
PNG_SIGNATURE = bytes.fromhex("89504e470d0a1a0a")
RIFF_MAGIC = b"RIFF"
WEBP_MAGIC = b"WEBP"
MPEG_TS_PACKET_SIZE = 188
MPEG_TS_SYNC = 0x47
# Payloads are standard base64, which can itself contain "/"
_PROXY_PATH = re.compile(r"/proxy/(.+)$")
_URI_ATTR = re.compile(r'URI="([^"]+)"')


@dataclass
class Upstream:
    url: str
    referer: str = ""
    headers: dict = field(default_factory=dict)
    embed: str = ""
    direct_ok: bool = True
    # Original proxy URL the feed came from (decode only; never fetched)
    proxy_url: str = ""

    def to_json(self):
        return {"u": self.url, "r": self.referer, "h": self.headers, "e": self.embed,
                "d": 1 if self.direct_ok else 0, "p": self.proxy_url}

    @classmethod
    def from_json(cls, data):
        return cls(url=data.get("u", ""), referer=data.get("r", ""), headers=data.get("h") or {},
                   embed=data.get("e", ""), direct_ok=bool(data.get("d")), proxy_url=data.get("p", ""))


def _b64decode(text):
    text = urllib.parse.unquote(text).strip()
    padded = text + "=" * (-len(text) % 4)
    return base64.b64decode(padded, validate=False)


def proxy_base(url):
    """scheme://host:port of a roku-feed proxy URL, or "" for anything else."""
    parts = urllib.parse.urlsplit(url)
    if not _PROXY_PATH.search(parts.path):
        return ""
    return f"{parts.scheme}://{parts.netloc}"


def parse_feed_url(url):
    """Decode a feed URL into an Upstream (CDN URL + headers), or a plain URL."""
    match = _PROXY_PATH.search(urllib.parse.urlsplit(url).path)
    if not match:
        return Upstream(url=url)
    try:
        raw = _b64decode(match.group(1)).decode("utf-8", "replace")
    except (binascii.Error, ValueError):
        return Upstream(url=url)
    if raw.startswith("{"):
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = None
        if isinstance(payload, dict) and payload.get("u"):
            return Upstream(
                url=payload["u"],
                referer=payload.get("r") or DEFAULT_REFERER,
                headers=payload.get("h") or {},
                embed=payload.get("e") or "",
                direct_ok=bool(payload.get("d")),
                proxy_url=url,
            )
    if raw.startswith(("http://", "https://")):
        # Legacy payload: just the URL, with the proxy's fixed referer
        return Upstream(url=raw, referer=DEFAULT_REFERER, direct_ok=False, proxy_url=url)
    return Upstream(url=url)


def encode_proxy_payload(url, referer, headers=None, embed="", direct_ok=False):
    """Same bytes encodeProxyPayload() produces, key order included."""
    payload = {"u": url, "r": referer or DEFAULT_REFERER}
    if embed:
        payload["e"] = embed
    if direct_ok:
        payload["d"] = 1
    if headers:
        payload["h"] = headers
    return base64.b64encode(json.dumps(payload, separators=(",", ":")).encode()).decode()


def manifest_headers(referer, extra=None):
    """buildFetchHeaders(): what the proxy sends for a non-minimal manifest fetch."""
    extra = {k.lower(): v for k, v in (extra or {}).items()}
    headers = {
        "User-Agent": BROWSER_USER_AGENT,
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
    }
    if referer:
        headers["Referer"] = referer
    headers.update(extra)
    if "origin" not in headers and referer:
        origin = _origin(referer)
        if origin:
            headers["Origin"] = origin
    if "sec-fetch-site" not in headers:
        headers["Sec-Fetch-Site"] = "cross-site"
        headers["Sec-Fetch-Mode"] = "cors"
        headers["Sec-Fetch-Dest"] = "empty"
    if "sec-ch-ua" not in headers:
        headers["sec-ch-ua"] = '"Chromium";v="148", "Google Chrome";v="148", "Not/A)Brand";v="99"'
        headers["sec-ch-ua-mobile"] = "?0"
        headers["sec-ch-ua-platform"] = '"macOS"'
    return headers


def minimal_headers(referer, extra=None):
    """fetchViaHttp(..., { minimal: true }): TimStreams / TikTok — no Origin.

    TikTok's image CDN often 403s (or stalls) when Origin is set.
    """
    headers = {
        "User-Agent": BROWSER_USER_AGENT,
        "Accept": "*/*",
    }
    if referer:
        headers["Referer"] = referer
    cookie = {k.lower(): v for k, v in (extra or {}).items()}.get("cookie")
    if cookie:
        headers["Cookie"] = cookie
    return headers


def segment_headers(referer, extra=None):
    """tryDirectSegmentFetch(): lighter set used on the Chromium segment path."""
    headers = {"User-Agent": BROWSER_USER_AGENT}
    if referer:
        headers["Referer"] = referer
        origin = _origin(referer)
        if origin:
            headers["Origin"] = origin
    cookie = {k.lower(): v for k, v in (extra or {}).items()}.get("cookie")
    if cookie:
        headers["Cookie"] = cookie
    return headers


def _origin(url):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme and parts.netloc:
        return f"{parts.scheme}://{parts.netloc}"
    return ""


def unwrap_goat_segment(body):
    """unwrapGoatSegment(): PNG wrapper; TS starts after IEND + CRC."""
    if not isinstance(body, (bytes, bytearray)) or len(body) < 8:
        return body
    if body[:8] != PNG_SIGNATURE:
        return body
    iend = body.find(b"IEND")
    if iend == -1:
        return body
    return body[iend + 8:]


def unwrap_webp_ts_segment(body):
    """unwrapWebpTsSegment(): fake WEBP whose payload is raw MPEG-TS.

    Find a sustained 0x47 sync run (188-byte packets) and return it — same as
    roku-feed/proxy/advanced-proxy.js.
    """
    if not isinstance(body, (bytes, bytearray)) or len(body) < 16:
        return body
    if body[:4] != RIFF_MAGIC or body[8:12] != WEBP_MAGIC:
        return body
    min_packets = 3
    search_limit = min(len(body), 64 * 1024)
    for i in range(search_limit):
        if body[i] != MPEG_TS_SYNC:
            continue
        packets = 0
        offset = i
        while offset + MPEG_TS_PACKET_SIZE <= len(body) and body[offset] == MPEG_TS_SYNC:
            packets += 1
            offset += MPEG_TS_PACKET_SIZE
        if packets >= min_packets:
            return body[i:i + packets * MPEG_TS_PACKET_SIZE]
    return body


def unwrap_goat(body):
    """unwrapDisguisedSegment(): PNG GOAT first, then WebP-TS."""
    after_png = unwrap_goat_segment(body)
    if after_png is not body:
        return after_png
    return unwrap_webp_ts_segment(body)


def is_manifest_url(url):
    return url.endswith(".m3u8") or ".m3u8?" in url


def is_hls_media_uri(uri):
    """isHlsMediaUri(): which bare playlist lines are media worth fetching."""
    trimmed = uri.strip()
    if not trimmed or trimmed.startswith("#"):
        return False
    if ".m3u8" in trimmed:
        return True
    if re.search(r"\.(ts|m4s|mp4|aac|vtt)(\?|#|$)", trimmed, re.IGNORECASE):
        return True
    if "strmd.st" in trimmed:
        return True
    if re.match(r"^https?://", trimmed, re.IGNORECASE):
        return True
    return " " not in trimmed


def rewrite_manifest(text, base_url, context, local_url):
    """Point every URI in a playlist at local_url(upstream, is_manifest).

    base_url is where the text actually came from (the CDN, or the proxy).
    context is the Upstream that was fetched: its referer and headers carry
    over to everything it lists, as they do in the proxy.
    """
    base = proxy_base(context.proxy_url) if context.proxy_url else ""

    def resolve(uri):
        absolute = urllib.parse.urljoin(base_url, uri)
        if proxy_base(absolute):
            return parse_feed_url(absolute)
        fallback = ""
        if base:
            fallback = f"{base}/proxy/" + encode_proxy_payload(
                absolute, context.referer, context.headers, context.embed, context.direct_ok)
        return Upstream(url=absolute, referer=context.referer, headers=dict(context.headers),
                        embed=context.embed, direct_ok=context.direct_ok, proxy_url=fallback)

    out = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            out.append(line)
            continue
        if stripped.startswith("#"):
            match = _URI_ATTR.search(stripped)
            if match:
                child = resolve(match.group(1))
                is_man = is_manifest_url(child.url) or "TYPE=AUDIO" in stripped or "TYPE=SUBTITLES" in stripped
                out.append(_URI_ATTR.sub(f'URI="{local_url(child, is_man)}"', stripped, count=1))
            else:
                out.append(stripped)
            continue
        if not is_hls_media_uri(stripped):
            out.append(stripped)
            continue
        child = resolve(stripped)
        out.append(local_url(child, is_manifest_url(child.url)))
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")
