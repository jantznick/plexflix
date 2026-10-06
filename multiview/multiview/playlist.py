"""One continuous HLS playlist per rendition, across ffmpeg restarts.

Each ffmpeg run (a "generation") writes its own playlists into its own
directory. The playlists the Roku actually loads are stitched from those: a
restart shows up as an EXT-X-DISCONTINUITY, not as a new stream, so the player
rides through it with a short rebuffer instead of erroring out.
"""

import math
import os


def read_media_playlist(path):
    """(duration, uri) pairs from an ffmpeg-written media playlist."""
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except FileNotFoundError:
        return []
    segments = []
    duration = None
    for line in lines:
        line = line.strip()
        if line.startswith("#EXTINF:"):
            try:
                duration = float(line[8:].split(",", 1)[0])
            except ValueError:
                duration = None
        elif line and not line.startswith("#"):
            if duration is not None:
                segments.append((duration, line))
            duration = None
    return segments


class StitchedPlaylist:
    def __init__(self, window=10, target_duration=2):
        self.window = window
        self.min_target = target_duration
        self.entries = []  # dicts: uri, duration, generation, discontinuity
        self.first_sequence = 0
        self.discontinuity_sequence = 0
        self._seen = set()
        self._last_generation = None

    def add(self, generation, segments, prefix):
        """Append segments of a generation not seen before. Returns how many."""
        added = 0
        for duration, uri in segments:
            key = (generation, uri)
            if key in self._seen:
                continue
            discontinuity = self._last_generation is not None and generation != self._last_generation
            if discontinuity:
                # Only the running generation is ever re-read, so older keys
                # can go; the running one's must stay, since ffmpeg keeps
                # listing segments after they leave this window
                self._seen = {k for k in self._seen if k[0] == generation}
            self._seen.add(key)
            self._last_generation = generation
            self.entries.append({
                "uri": f"{prefix}/{uri}",
                "duration": duration,
                "generation": generation,
                "discontinuity": discontinuity,
            })
            added += 1
        self._trim()
        return added

    def _trim(self):
        while len(self.entries) > self.window:
            dropped = self.entries.pop(0)
            self.first_sequence += 1
            # The tag is attached to the segment after a break; once that
            # segment slides out, the break has to be counted instead
            if dropped["discontinuity"]:
                self.discontinuity_sequence += 1
        if self.entries and self.entries[0]["discontinuity"]:
            self.entries[0] = dict(self.entries[0], discontinuity=False)
            self.discontinuity_sequence += 1

    def generations(self):
        return {entry["generation"] for entry in self.entries}

    def render(self):
        target = self.min_target
        if self.entries:
            target = max(target, math.ceil(max(e["duration"] for e in self.entries)))
        lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:3",
            f"#EXT-X-TARGETDURATION:{target}",
            f"#EXT-X-MEDIA-SEQUENCE:{self.first_sequence}",
            f"#EXT-X-DISCONTINUITY-SEQUENCE:{self.discontinuity_sequence}",
        ]
        for entry in self.entries:
            if entry["discontinuity"]:
                lines.append("#EXT-X-DISCONTINUITY")
            lines.append(f"#EXTINF:{entry['duration']:.3f},")
            lines.append(entry["uri"])
        return "\n".join(lines) + "\n"


def master_playlist(audio_count, bandwidth):
    """Video rendition plus one alternate audio rendition per tile.

    Audio is named by slot rather than by game: a reorder changes which game
    sits in a slot, and this file is written once for the whole session.
    """
    lines = ["#EXTM3U", "#EXT-X-VERSION:3", "#EXT-X-INDEPENDENT-SEGMENTS"]
    for i in range(audio_count):
        default = "YES" if i == 0 else "NO"
        lines.append(
            f'#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Tile {i + 1}",'
            f'DEFAULT={default},AUTOSELECT={default},URI="a{i}.m3u8"'
        )
    lines.append(
        f'#EXT-X-STREAM-INF:BANDWIDTH={bandwidth},RESOLUTION=1920x1080,'
        f'CODECS="avc1.640028,mp4a.40.2",AUDIO="aud"'
    )
    lines.append("v.m3u8")
    return "\n".join(lines) + "\n"


def write_atomic(path, text):
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)
