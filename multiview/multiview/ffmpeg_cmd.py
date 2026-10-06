"""Builds the ffmpeg command for one generation of a session.

Every tile always produces video and audio. A feed that is down is swapped for
a generated slate plus silence, so the outputs (one video playlist, one audio
playlist per tile) keep the same shape however many feeds are healthy.
"""

import os

from .layouts import CANVAS_H, CANVAS_W
from .probe import header_args

SEGMENT_SECONDS = 2
SLATE_COLOR = "0x14141C"
SLATE_TEXT_COLOR = "0xC8C8D0"

ENCODERS = {
    "libx264": {
        "pix_fmt": "yuv420p",
        "args": ["-c:v", "libx264", "-preset", "veryfast", "-profile:v", "high", "-sc_threshold", "0"],
    },
    "h264_nvenc": {
        "pix_fmt": "yuv420p",
        "args": ["-c:v", "h264_nvenc", "-preset", "p4", "-profile:v", "high"],
    },
    "h264_qsv": {
        "pix_fmt": "nv12",
        "args": ["-c:v", "h264_qsv", "-preset", "veryfast", "-profile:v", "high"],
    },
    "h264_vaapi": {
        "pix_fmt": "nv12",
        "hwupload": True,
        "args": ["-c:v", "h264_vaapi", "-profile:v", "high"],
    },
}


def escape_filter_value(value):
    """Quote a value for use inside a filtergraph option."""
    return value.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def build_command(slots, gen_dir, settings):
    """
    slots: one dict per tile, in layout order, each with
        rect: {x, y, w, h}
        live: bool
        url, program, headers, has_audio: for live slots
        slate_text_file: for slots that are down
    settings: dict with ffmpeg, encoder, fps, video_bitrate, font_file, vaapi_device
    """
    encoder = ENCODERS.get(settings["encoder"])
    if encoder is None:
        raise ValueError(f"unsupported encoder {settings['encoder']!r}; pick one of {sorted(ENCODERS)}")
    fps = int(settings["fps"])

    cmd = [settings["ffmpeg"], "-hide_banner", "-nostdin", "-loglevel", "warning", "-y"]
    if encoder.get("hwupload"):
        cmd += ["-vaapi_device", settings.get("vaapi_device") or "/dev/dri/renderD128"]

    inputs = []
    filters = []
    audio_maps = []
    input_count = 0

    def add_input(args):
        nonlocal input_count
        inputs.extend(args)
        input_count += 1
        return input_count - 1

    for i, slot in enumerate(slots):
        rect = slot["rect"]
        w, h = rect["w"], rect["h"]
        if slot["live"]:
            args = header_args(slot.get("headers"))
            args += [
                "-thread_queue_size", "1024",
                "-rw_timeout", "15000000",
                "-live_start_index", "-3",
                "-fflags", "+genpts+discardcorrupt",
                "-i", slot["url"],
            ]
            index = add_input(args)
            program = slot.get("program")
            prefix = f"{index}:p:{program}:" if program is not None else f"{index}:"
            filters.append(
                f"[{prefix}v:0]scale={w}:{h}:force_original_aspect_ratio=decrease,"
                f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps={fps}[t{i}]"
            )
            if slot.get("has_audio"):
                audio_maps.append(f"{prefix}a:0")
            else:
                audio_maps.append(f"{add_input(_silence())}:a:0")
        else:
            index = add_input([
                "-re", "-f", "lavfi", "-i", f"color=c={SLATE_COLOR}:s={w}x{h}:r={fps}",
            ])
            chain = f"[{index}:v:0]"
            font = settings.get("font_file") or ""
            text_file = slot.get("slate_text_file") or ""
            if font and os.path.exists(font) and text_file:
                size = max(20, h // 14)
                chain += (
                    f"drawtext=fontfile='{escape_filter_value(font)}':"
                    f"textfile='{escape_filter_value(text_file)}':"
                    f"fontcolor={SLATE_TEXT_COLOR}:fontsize={size}:line_spacing={size // 2}:"
                    "x=(w-text_w)/2:y=(h-text_h)/2,"
                )
            filters.append(f"{chain}setsar=1[t{i}]")
            audio_maps.append(f"{add_input(_silence())}:a:0")

    filters.append(f"color=c=black:s={CANVAS_W}x{CANVAS_H}:r={fps}[bg]")
    last = "bg"
    for i, slot in enumerate(slots):
        rect = slot["rect"]
        label = f"o{i}"
        filters.append(f"[{last}][t{i}]overlay={rect['x']}:{rect['y']}:eof_action=repeat:repeatlast=1[{label}]")
        last = label
    tail = f"format={encoder['pix_fmt']}"
    if encoder.get("hwupload"):
        tail += ",hwupload"
    filters.append(f"[{last}]{tail}[vout]")

    cmd += inputs
    cmd += ["-filter_complex", ";".join(filters)]

    gop = fps * SEGMENT_SECONDS
    bitrate = settings["video_bitrate"]
    cmd += ["-map", "[vout]"]
    cmd += encoder["args"]
    cmd += [
        "-b:v", bitrate, "-maxrate", bitrate, "-bufsize", _double(bitrate),
        "-g", str(gop), "-keyint_min", str(gop),
        "-force_key_frames", f"expr:gte(t,n_forced*{SEGMENT_SECONDS})",
    ]
    cmd += _hls_output(gen_dir, "v")

    for i, source in enumerate(audio_maps):
        cmd += [
            "-map", source,
            "-c:a", "aac", "-b:a", "128k", "-ac", "2", "-ar", "48000",
            "-af", "aresample=async=1",
        ]
        cmd += _hls_output(gen_dir, f"a{i}")
    return cmd


def _silence():
    return ["-re", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"]


def _hls_output(gen_dir, name):
    return [
        "-f", "hls",
        "-hls_time", str(SEGMENT_SECONDS),
        "-hls_list_size", "15",
        "-hls_flags", "delete_segments+independent_segments",
        "-hls_segment_filename", os.path.join(gen_dir, f"{name}_%05d.ts"),
        os.path.join(gen_dir, f"{name}.m3u8"),
    ]


def _double(bitrate):
    suffix = bitrate[-1] if bitrate and bitrate[-1].isalpha() else ""
    number = bitrate[:-1] if suffix else bitrate
    try:
        return f"{int(float(number) * 2)}{suffix}"
    except ValueError:
        return bitrate
