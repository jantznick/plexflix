#!/usr/bin/env python3
"""Regenerate the PNG assets used by the watched badges and the player overlay.

Run from the repo root:  python3 roku/scripts/make_player_assets.py
Writes into roku/images/. No third-party dependencies.
"""

import os
import struct
import zlib

IMAGES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "images")

ACCENT = (0xE5, 0x09, 0x14)
SUPERSAMPLE = 4


def write_png(path, width, height, pixels):
    """pixels: flat list of (r, g, b, a) tuples, row-major."""
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0
        for x in range(width):
            raw.extend(pixels[y * width + x])

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", header)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")

    with open(path, "wb") as handle:
        handle.write(png)
    print("wrote %s (%dx%d)" % (path, width, height))


def segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    span = dx * dx + dy * dy
    if span == 0:
        t = 0.0
    else:
        t = ((px - ax) * dx + (py - ay) * dy) / span
        t = max(0.0, min(1.0, t))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def make_watched_check(size=64):
    """Accent disc with a white tick: the 'you finished this' badge."""
    # Tick drawn as two strokes in unit space so the shape scales with `size`
    strokes = (((0.27, 0.52), (0.44, 0.70)), ((0.44, 0.70), (0.75, 0.32)))
    half = 0.075
    hi = size * SUPERSAMPLE
    pixels = []
    for y in range(size):
        for x in range(size):
            disc = 0
            tick = 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    u = (x * SUPERSAMPLE + sx + 0.5) / hi
                    v = (y * SUPERSAMPLE + sy + 0.5) / hi
                    if (u - 0.5) ** 2 + (v - 0.5) ** 2 <= 0.25:
                        disc += 1
                        for (ax, ay), (bx, by) in strokes:
                            if segment_distance(u, v, ax, ay, bx, by) <= half:
                                tick += 1
                                break
            total = SUPERSAMPLE * SUPERSAMPLE
            alpha = disc / total
            if alpha == 0:
                pixels.append((0, 0, 0, 0))
                continue
            # Blend the tick over the disc, both weighted by their own coverage
            mix = tick / total / alpha
            mix = min(1.0, mix)
            r = int(round(ACCENT[0] * (1 - mix) + 255 * mix))
            g = int(round(ACCENT[1] * (1 - mix) + 255 * mix))
            b = int(round(ACCENT[2] * (1 - mix) + 255 * mix))
            pixels.append((r, g, b, int(round(alpha * 255))))
    write_png(os.path.join(IMAGES, "watched_check.png"), size, size, pixels)


def make_player_scrim(width=16, height=360):
    """Transparent-to-black vertical ramp, stretched behind the player controls."""
    pixels = []
    for y in range(height):
        t = y / (height - 1)
        # Eased so the top stays clear of the picture and the bottom goes solid
        alpha = int(round(235 * (t ** 1.6)))
        for _ in range(width):
            pixels.append((4, 4, 8, alpha))
    write_png(os.path.join(IMAGES, "player_scrim.png"), width, height, pixels)


if __name__ == "__main__":
    make_watched_check()
    make_player_scrim()
