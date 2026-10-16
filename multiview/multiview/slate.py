"""Still frames for tiles that have no picture yet, or have lost it."""

import os
import subprocess
import tempfile

from .ingest import FRAME_BYTES, FRAME_H, FRAME_W

BACKGROUND = "0x10141c"


def blank_frame():
    """Dark grey I420, for when ffmpeg can't draw a slate."""
    y = FRAME_W * FRAME_H
    return bytes([24]) * y + bytes([128]) * (y // 2)


def render(ffmpeg, font_file, title, message):
    with tempfile.TemporaryDirectory(prefix="slate-") as tmp:
        title_file = os.path.join(tmp, "title.txt")
        message_file = os.path.join(tmp, "message.txt")
        with open(title_file, "w", encoding="utf-8") as handle:
            handle.write(title[:40])
        with open(message_file, "w", encoding="utf-8") as handle:
            handle.write(message)
        font = f":fontfile='{font_file}'" if font_file and os.path.exists(font_file) else ""
        graph = (
            f"drawtext=textfile='{title_file}'{font}:fontsize=64:fontcolor=white:"
            f"x=(w-text_w)/2:y=h/2-text_h-16,"
            f"drawtext=textfile='{message_file}'{font}:fontsize=44:fontcolor=0xa8b3c4:"
            f"x=(w-text_w)/2:y=h/2+16"
        )
        cmd = [
            ffmpeg, "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", f"color=c={BACKGROUND}:s={FRAME_W}x{FRAME_H}",
            "-vf", graph, "-frames:v", "1", "-pix_fmt", "yuv420p", "-f", "rawvideo", "pipe:1",
        ]
        try:
            result = subprocess.run(cmd, capture_output=True, timeout=15, check=False)
        except (OSError, subprocess.TimeoutExpired):
            return blank_frame()
    if len(result.stdout) != FRAME_BYTES:
        return blank_frame()
    return result.stdout
