"""Small HLS playlist helpers."""

import re
import urllib.parse

_ATTR_RE = re.compile(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)')
# Groups that are dropped along with the variants that used them
_DROPPED_GROUP_ATTRS = re.compile(r',(?:SUBTITLES|CLOSED-CAPTIONS|VIDEO)=("[^"]*"|[^,]*)')


def parse_attributes(text):
    attrs = {}
    for key, value in _ATTR_RE.findall(text):
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        attrs[key] = value
    return attrs


def parse_master(text, base_url):
    """Variants of a master playlist, in file order."""
    variants = []
    lines = [line.strip() for line in text.splitlines()]
    for i, line in enumerate(lines):
        if not line.startswith("#EXT-X-STREAM-INF:"):
            continue
        attrs = parse_attributes(line.split(":", 1)[1])
        uri_index = None
        for j in range(i + 1, len(lines)):
            if lines[j] and not lines[j].startswith("#"):
                uri_index = j
                break
        if uri_index is None:
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
            "index": len(variants),
            "line": i,
            "uri_line": uri_index,
            "url": urllib.parse.urljoin(base_url, lines[uri_index]),
            "width": width,
            "height": height,
            "bandwidth": bandwidth,
            "audio_group": attrs.get("AUDIO", ""),
        })
    return variants


def choose_variant(variants, height):
    """Smallest rendition at least this tall, else the biggest there is."""
    if not variants:
        return None
    sized = [v for v in variants if v["height"] > 0]
    if not sized:
        return max(variants, key=lambda v: v["bandwidth"])
    fits = [v for v in sized if v["height"] >= height]
    if fits:
        return min(fits, key=lambda v: (v["height"], v["bandwidth"]))
    return max(sized, key=lambda v: (v["height"], v["bandwidth"]))


def filter_master(text, height):
    """The master playlist cut down to one variant and one audio rendition.

    ffmpeg opens every playlist a master lists, and reads a segment of each
    while probing; with one variant left, the source only ever serves the
    rendition that is actually decoded.
    """
    lines = text.splitlines()
    variant = choose_variant(parse_master(text, ""), height)
    if variant is None:
        return text
    audio_line = None
    if variant["audio_group"]:
        candidates = []
        for i, line in enumerate(lines):
            stripped = line.strip()
            if not stripped.startswith("#EXT-X-MEDIA:"):
                continue
            attrs = parse_attributes(stripped.split(":", 1)[1])
            if attrs.get("TYPE") == "AUDIO" and attrs.get("GROUP-ID") == variant["audio_group"]:
                candidates.append((attrs.get("DEFAULT") != "YES", attrs.get("URI") is None, i))
        if candidates:
            audio_line = min(candidates)[2]

    out = []
    for i, line in enumerate(lines):
        stripped = line.strip()
        if i == variant["line"]:
            out.append(_DROPPED_GROUP_ATTRS.sub("", stripped))
        elif i == variant["uri_line"]:
            out.append(stripped)
        elif i == audio_line:
            out.append(stripped)
        elif stripped.startswith(("#EXT-X-STREAM-INF:", "#EXT-X-MEDIA:", "#EXT-X-I-FRAME-STREAM-INF:")):
            continue
        elif stripped and not stripped.startswith("#"):
            continue  # another variant's URI
        else:
            out.append(line)
    return "\n".join(out) + "\n"
