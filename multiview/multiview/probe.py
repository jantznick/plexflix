"""Lightweight HLS health checks, run outside ffmpeg.

ffmpeg can't say which of its inputs broke a mosaic, so every feed is also
watched independently: a feed is healthy while its playlist loads and keeps
advancing. The same pass resolves master playlists to the variant ffmpeg
should decode, which keeps a 480x270 tile from pulling a 1080p rendition.
"""

import json
import re
import subprocess
import time
import urllib.parse
import urllib.request

FETCH_TIMEOUT = 8
# A live playlist that hasn't gained a segment in this long is stuck, even if
# the server still answers it
STALE_SECONDS = 25

_ATTR_RE = re.compile(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)')


def parse_attributes(text):
    attrs = {}
    for key, value in _ATTR_RE.findall(text):
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        attrs[key] = value
    return attrs


def parse_master(text, base_url):
    """Variants of a master playlist, in file order.

    File order matters: ffmpeg's HLS demuxer numbers its programs the same way,
    which is how a chosen variant is mapped on the command line.
    """
    variants = []
    lines = [line.strip() for line in text.splitlines()]
    for i, line in enumerate(lines):
        if not line.startswith("#EXT-X-STREAM-INF:"):
            continue
        attrs = parse_attributes(line.split(":", 1)[1])
        uri = ""
        for following in lines[i + 1:]:
            if following and not following.startswith("#"):
                uri = following
                break
        if not uri:
            continue
        width = height = 0
        resolution = attrs.get("RESOLUTION", "")
        if "x" in resolution:
            try:
                width, height = (int(part) for part in resolution.lower().split("x", 1))
            except ValueError:
                width = height = 0
        try:
            bandwidth = int(attrs.get("BANDWIDTH", "0"))
        except ValueError:
            bandwidth = 0
        variants.append({
            "program": len(variants),
            "url": urllib.parse.urljoin(base_url, uri),
            "width": width,
            "height": height,
            "bandwidth": bandwidth,
            "codecs": attrs.get("CODECS", ""),
            "audio_group": attrs.get("AUDIO", ""),
        })
    return variants


def parse_media(text):
    sequence = 0
    segments = []
    ended = False
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#EXT-X-MEDIA-SEQUENCE:"):
            try:
                sequence = int(line.split(":", 1)[1])
            except ValueError:
                sequence = 0
        elif line == "#EXT-X-ENDLIST":
            ended = True
        elif line and not line.startswith("#"):
            segments.append(line)
    return {"sequence": sequence, "segments": segments, "ended": ended}


def choose_variant(variants, tile_height):
    """Smallest rendition that still fills the tile, else the biggest there is."""
    if not variants:
        return None
    sized = [v for v in variants if v["height"] > 0]
    if not sized:
        return max(variants, key=lambda v: v["bandwidth"])
    fits = [v for v in sized if v["height"] >= tile_height]
    if fits:
        return min(fits, key=lambda v: (v["height"], v["bandwidth"]))
    return max(sized, key=lambda v: (v["height"], v["bandwidth"]))


def fetch_text(url, headers=None, timeout=FETCH_TIMEOUT):
    request = urllib.request.Request(url, headers=dict(headers or {}))
    if "User-Agent" not in request.headers and "User-agent" not in request.headers:
        request.add_header("User-Agent", "PlexFlix-Multiview/1.0")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read(2 * 1024 * 1024)
        return body.decode("utf-8", "replace"), response.geturl()


class FeedProbe:
    """Tracks one feed's health across repeated checks."""

    def __init__(self, url, headers=None, tile_height=540, fetch=fetch_text, clock=time.monotonic):
        self.url = url
        self.headers = dict(headers or {})
        self.tile_height = tile_height
        self._fetch = fetch
        self._clock = clock
        self.variant = None
        self.media_url = url
        self.last_marker = None
        self.last_advance = None
        self.error = ""
        self.has_audio = None

    def check(self):
        """One probe. Returns True while the feed looks playable."""
        try:
            text, final_url = self._fetch(self.url, self.headers)
            if "#EXTM3U" not in text:
                return self._fail("not an HLS playlist")
            media_text = text
            if "#EXT-X-STREAM-INF" in text:
                variants = parse_master(text, final_url)
                variant = choose_variant(variants, self.tile_height)
                if variant is None:
                    return self._fail("master playlist has no variants")
                self.variant = variant
                self.media_url = variant["url"]
                media_text, _ = self._fetch(self.media_url, self.headers)
            else:
                self.variant = None
                self.media_url = final_url
            media = parse_media(media_text)
        except Exception as exc:  # network errors, timeouts, bad UTF-8
            return self._fail(str(exc) or exc.__class__.__name__)

        if not media["segments"]:
            return self._fail("playlist has no segments")
        if media["ended"]:
            return self._fail("stream ended")

        now = self._clock()
        marker = (media["sequence"], media["segments"][-1])
        if marker != self.last_marker:
            self.last_marker = marker
            self.last_advance = now
        if now - self.last_advance > STALE_SECONDS:
            return self._fail("playlist stopped advancing")
        self.error = ""
        return True

    def _fail(self, reason):
        self.error = reason
        return False

    def input_target(self):
        """What ffmpeg should open and which program in it to map.

        Masters are handed to ffmpeg whole, mapped to one program, so demuxed
        audio renditions keep working. ffmpeg only downloads segments for
        streams it actually maps.
        """
        if self.variant is not None:
            return self.url, self.variant["program"]
        return self.media_url, None

    def detect_audio(self, ffprobe="ffprobe", timeout=25):
        """Whether the chosen rendition carries audio. Cached once known."""
        if self.has_audio is not None:
            return self.has_audio
        url, program = self.input_target()
        cmd = [ffprobe, "-v", "error", "-print_format", "json", "-show_programs", "-show_streams"]
        cmd += header_args(self.headers)
        cmd.append(url)
        try:
            result = subprocess.run(cmd, capture_output=True, timeout=timeout, check=False)
            data = json.loads(result.stdout or b"{}")
        except (subprocess.TimeoutExpired, ValueError, OSError):
            return None
        self.has_audio = streams_have_audio(data, program)
        return self.has_audio


def streams_have_audio(probe_json, program):
    if program is not None:
        for entry in probe_json.get("programs", []):
            if int(entry.get("program_id", -1)) == program:
                return any(s.get("codec_type") == "audio" for s in entry.get("streams", []))
    return any(s.get("codec_type") == "audio" for s in probe_json.get("streams", []))


def header_args(headers):
    """ffmpeg/ffprobe options for the headers a feed needs."""
    args = []
    extra = []
    for key, value in (headers or {}).items():
        lowered = key.lower()
        if lowered == "user-agent":
            args += ["-user_agent", value]
        elif lowered == "referer":
            args += ["-referer", value]
        else:
            extra.append(f"{key}: {value}\r\n")
    if extra:
        args += ["-headers", "".join(extra)]
    return args
