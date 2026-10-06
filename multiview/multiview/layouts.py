"""Tile placement on the 1920x1080 canvas.

The Roku draws its focus ring and labels from these same rectangles, and its
FHD UI coordinates are 1:1 with this canvas, so nothing is scaled on device.
Every dimension is even because the 4:2:0 encode can't split a chroma sample.
"""

CANVAS_W = 1920
CANVAS_H = 1080

LAYOUTS = ("grid", "spotlight", "pip")
MIN_TILES = 2
MAX_TILES = 4


def tiles_for(layout, count):
    if count < MIN_TILES or count > MAX_TILES:
        raise ValueError(f"multiview takes {MIN_TILES}-{MAX_TILES} streams, got {count}")
    if layout == "grid":
        return _grid(count)
    if layout == "spotlight":
        return _spotlight(count)
    if layout == "pip":
        return _pip(count)
    raise ValueError(f"unknown layout {layout!r}")


def _rect(x, y, w, h):
    return {"x": x, "y": y, "w": w, "h": h}


def _grid(count):
    w, h = CANVAS_W // 2, CANVAS_H // 2
    if count == 2:
        return [_rect(0, 270, w, h), _rect(w, 270, w, h)]
    tiles = [_rect(0, 0, w, h), _rect(w, 0, w, h)]
    if count == 3:
        tiles.append(_rect(480, h, w, h))
    else:
        tiles += [_rect(0, h, w, h), _rect(w, h, w, h)]
    return tiles


def _spotlight(count):
    # 1440x810 main with the others stacked down its right edge at a third the
    # size; the stack is centred against the main tile when it is shorter
    main = _rect(0, 135, 1440, 810)
    side = count - 1
    top = 135 + (810 - side * 270) // 2
    return [main] + [_rect(1440, top + i * 270, 480, 270) for i in range(side)]


def _pip(count):
    margin, gap, w, h = 48, 24, 480, 270
    tiles = [_rect(0, 0, CANVAS_W, CANVAS_H)]
    for i in range(count - 1):
        x = CANVAS_W - margin - (i + 1) * w - i * gap
        tiles.append(_rect(x, CANVAS_H - margin - h, w, h))
    return tiles
