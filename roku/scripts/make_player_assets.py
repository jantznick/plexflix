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


def make_guide_fades(length=360, thickness=16, color=(8, 11, 18)):
    """Guide-background ramps that melt the program art into the page.

    guide_fade_h: solid on the left, clear on the right.
    guide_fade_v: clear on top, solid at the bottom.
    """
    r, g, b = color
    ramp = [int(round(255 * ((1 - i / (length - 1)) ** 1.4))) for i in range(length)]
    pixels = []
    for _ in range(thickness):
        for x in range(length):
            pixels.append((r, g, b, ramp[x]))
    write_png(os.path.join(IMAGES, "guide_fade_h.png"), length, thickness, pixels)

    pixels = []
    for y in range(length):
        for _ in range(thickness):
            pixels.append((r, g, b, ramp[length - 1 - y]))
    write_png(os.path.join(IMAGES, "guide_fade_v.png"), thickness, length, pixels)


def make_focus_ring(size=32, thick=4, corner=8):
    """9-patch focus border for the RowList / MarkupGrid native focus indicator.

    The firmware stretches only the marked middle band, so the white edge and
    the red inner accent stay `thick` px on every tile size. The outer 1px is
    the 9-patch marker frame (black = stretchable / content area).
    """
    full = size + 2
    clear = (0, 0, 0, 0)
    marker = (0, 0, 0, 255)
    white = (255, 255, 255, 255)
    accent = ACCENT + (255,)
    pixels = []
    for y in range(full):
        for x in range(full):
            edge_x = x in (0, full - 1)
            edge_y = y in (0, full - 1)
            if edge_x and edge_y:
                pixels.append(clear)
                continue
            if edge_y:
                pixels.append(marker if corner < x <= size - corner else clear)
                continue
            if edge_x:
                pixels.append(marker if corner < y <= size - corner else clear)
                continue
            cx, cy = x - 1, y - 1
            if cx < thick or cy < thick or cx >= size - thick or cy >= size - thick:
                pixels.append(white)
            elif size - thick * 2 <= cy < size - thick:
                pixels.append(accent)
            else:
                pixels.append(clear)
    write_png(os.path.join(IMAGES, "focus_ring.9.png"), full, full, pixels)


def rect_strokes(x0, y0, x1, y1):
    return [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]


def ring_hit(u, v, cx, cy, radius, half):
    return abs(((u - cx) ** 2 + (v - cy) ** 2) ** 0.5 - radius) <= half


def nav_icon_shapes():
    """Unit-space hit tests for the collapsed side nav's outline icons."""
    half = 0.045

    def strokes_hit(strokes):
        def hit(u, v):
            for (ax, ay), (bx, by) in strokes:
                if segment_distance(u, v, ax, ay, bx, by) <= half:
                    return True
            return False
        return hit

    home = strokes_hit([
        ((0.12, 0.50), (0.50, 0.16)), ((0.50, 0.16), (0.88, 0.50)),
        ((0.24, 0.42), (0.24, 0.86)), ((0.76, 0.42), (0.76, 0.86)),
        ((0.24, 0.86), (0.76, 0.86)),
        ((0.42, 0.86), (0.42, 0.62)), ((0.42, 0.62), (0.58, 0.62)), ((0.58, 0.62), (0.58, 0.86)),
    ])

    tv = strokes_hit(rect_strokes(0.12, 0.20, 0.88, 0.72) + [
        ((0.50, 0.72), (0.50, 0.85)), ((0.34, 0.86), (0.66, 0.86)),
    ])

    film_strokes = rect_strokes(0.20, 0.12, 0.80, 0.88) + [
        ((0.35, 0.12), (0.35, 0.88)), ((0.65, 0.12), (0.65, 0.88)),
    ]
    for y in (0.31, 0.50, 0.69):
        film_strokes.append(((0.20, y), (0.35, y)))
        film_strokes.append(((0.65, y), (0.80, y)))
    film = strokes_hit(film_strokes)

    def live(u, v):
        if (u - 0.5) ** 2 + (v - 0.5) ** 2 <= 0.075 ** 2:
            return True
        # Broadcast arcs, kept to the left and right of the dot
        if abs(u - 0.5) < abs(v - 0.5) * 1.1:
            return False
        return ring_hit(u, v, 0.5, 0.5, 0.22, half) or ring_hit(u, v, 0.5, 0.5, 0.37, half)

    def sports(u, v):
        inside = (u - 0.5) ** 2 + (v - 0.5) ** 2 <= 0.37 ** 2
        if ring_hit(u, v, 0.5, 0.5, 0.37, half):
            return True
        if not inside:
            return False
        if abs(u - 0.5) <= half or abs(v - 0.5) <= half:
            return True
        return ring_hit(u, v, 0.08, 0.5, 0.30, half) or ring_hit(u, v, 0.92, 0.5, 0.30, half)

    return {"home": home, "tv": tv, "movie": film, "live": live, "sports": sports}


def make_nav_icons(size=48):
    """White outline icons; the nav tints them with Poster.blendColor."""
    hi = size * SUPERSAMPLE
    total = SUPERSAMPLE * SUPERSAMPLE
    for name, hit in nav_icon_shapes().items():
        pixels = []
        for y in range(size):
            for x in range(size):
                covered = 0
                for sy in range(SUPERSAMPLE):
                    for sx in range(SUPERSAMPLE):
                        u = (x * SUPERSAMPLE + sx + 0.5) / hi
                        v = (y * SUPERSAMPLE + sy + 0.5) / hi
                        if hit(u, v):
                            covered += 1
                pixels.append((255, 255, 255, int(round(255 * covered / total))))
        write_png(os.path.join(IMAGES, "nav_%s.png" % name), size, size, pixels)


if __name__ == "__main__":
    make_watched_check()
    make_player_scrim()
    make_focus_ring()
    make_nav_icons()
    make_guide_fades()
