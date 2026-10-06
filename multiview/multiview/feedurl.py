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

DEFAULT_REFERER = "https://embedsports.top/"
BROWSER_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36"
)
PNG_SIGNATURE = bytes.fromhex("89504e470d0a1a0a")
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
    # Where the roku-feed proxy would serve this same resource; the fallback
    # whenever fetching it directly doesn't work
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
    for decoder in (base64.b64decode, base64.urlsafe_b64decode):
        try:
            return decoder(padded).decode("utf-8")
        except (binascii.Error, ValueError, UnicodeDecodeError):
            continue
    return None


def proxy_base(url):
    """scheme://host:port of a roku-feed proxy URL, or "" for anything else."""
    parts = urllib.parse.urlsplit(url)
    if not _PROXY_PATH.search(parts.path):
        return ""
    return f"{parts.scheme}://{parts.netloc}"


def parse_feed_url(url):
    """The upstream behind a feed URL. Plain URLs are their own upstream."""
    parts = urllib.parse.urlsplit(url)
    match = _PROXY_PATH.search(parts.path)
    if not match:
        return Upstream(url=url)
    raw = _b64decode(match.group(1))
    if raw is None:
        return Upstream(url=url)
    if raw.startswith("{"):
        try:
            payload = json.loads(raw)
        except ValueError:
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
    raw = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    return base64.b64encode(raw.encode("utf-8")).decode("ascii")


def manifest_headers(referer, extra=None):
    """buildFetchHeaders(): what the proxy sends for a direct manifest fetch."""
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


def segment_headers(referer, extra=None):
    """tryDirectSegmentFetch(): the lighter set the proxy uses for segments."""
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


def unwrap_goat(body):
    """GOAT hides MPEG-TS inside a PNG; the TS starts after the IEND chunk."""
    if len(body) < 8 or body[:8] != PNG_SIGNATURE:
        return body
    end = body.find(b"IEND")
    if end == -1:
        return body
    return body[end + 8:]


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
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith(("#EXT-X-KEY:", "#EXT-X-MAP:", "#EXT-X-MEDIA:")):
            match = _URI_ATTR.search(line)
            if match:
                target = resolve(match.group(1))
                manifest = stripped.startswith("#EXT-X-MEDIA:")
                line = line.replace(match.group(1), local_url(target, manifest))
            out.append(line)
            continue
        if stripped and not stripped.startswith("#"):
            if not is_hls_media_uri(stripped):
                continue
            target = resolve(stripped)
            out.append(local_url(target, is_manifest_url(target.url)))
            continue
        out.append(line)
    return "\n".join(out)
