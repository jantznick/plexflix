"""One ffmpeg process: proxied live feeds + placeholder tiles → 1080p HLS.

Reads the same relay/proxy HLS the Roku can play, scales each live feed into
its layout rectangle, draws placeholder slates for the rest, and writes a
video playlist plus one audio playlist per tile slot (live audio or silence)
so the Roku can switch sound with focus without touching the video.
"""

import os
import signal
import subprocess
import threading


def bitrate_bps(value):
    text = str(value).strip().lower()
    if text.endswith("k"):
        return int(float(text[:-1]) * 1000)
    if text.endswith("m"):
        return int(float(text[:-1]) * 1000000)
    return int(text)


def _drawtext_escape(text):
    return (
        text.replace("\\", "\\\\")
        .replace(":", "\\:")
        .replace("'", "\\'")
        .replace("%", "%%")
    )


def build_command(ffmpeg, feeds, placements, out_dir, settings):
    """feeds: [{live, url, title}], placements: slot-ordered [(feed_index, rect, z), ...]"""
    fps = int(settings.get("fps", 20))
    bitrate = settings.get("video_bitrate", "3M")
    font = settings.get("font_file") or ""
    os.makedirs(out_dir, exist_ok=True)

    cmd = [ffmpeg, "-hide_banner", "-nostdin", "-loglevel", "error", "-y"]
    filter_parts = []
    input_index = 0
    live_audio_by_feed = {}
    tile_labels = {}

    cmd += ["-f", "lavfi", "-i", f"color=c=black:s=1920x1080:r={fps}"]
    base_idx = input_index
    input_index += 1

    by_feed = {i: f for i, f in enumerate(feeds)}
    for feed_index, feed in by_feed.items():
        rect = None
        for fi, r, _z in placements:
            if fi == feed_index:
                rect = r
                break
        if rect is None:
            continue
        w, h = int(rect["w"]), int(rect["h"])
        label = f"t{feed_index}"
        if feed["live"] and feed.get("url"):
            cmd += [
                "-rw_timeout", "90000000",
                "-live_start_index", "-3",
                "-fflags", "+genpts+discardcorrupt",
                "-i", feed["url"],
            ]
            idx = input_index
            input_index += 1
            live_audio_by_feed[feed_index] = idx
            filter_parts.append(
                f"[{idx}:v]scale={w}:{h}:force_original_aspect_ratio=decrease,"
                f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps={fps},format=yuv420p[{label}]"
            )
        else:
            cmd += ["-f", "lavfi", "-i", f"color=c=0x1c1c1e:s={w}x{h}:r={fps}"]
            idx = input_index
            input_index += 1
            title = _drawtext_escape(feed.get("title") or "Stream")
            msg = _drawtext_escape("Other stream will play here")
            draw = f"[{idx}:v]format=yuv420p"
            if font and os.path.isfile(font):
                font_esc = font.replace("\\", "\\\\").replace(":", "\\:")
                draw += (
                    f",drawtext=fontfile={font_esc}:text='{title}':fontsize=36:"
                    f"fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2-30,"
                    f"drawtext=fontfile={font_esc}:text='{msg}':fontsize=28:"
                    f"fontcolor=0x9A9AA4:x=(w-text_w)/2:y=(h-text_h)/2+20"
                )
            draw += f"[{label}]"
            filter_parts.append(draw)
        tile_labels[feed_index] = label

    # Silence as a real input (filter-source anullsrc never finishes HLS segments).
    cmd += ["-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000"]
    silence_idx = input_index
    input_index += 1

    ordered = sorted(placements, key=lambda p: p[2])
    current = f"[{base_idx}:v]"
    for i, (feed_index, rect, _z) in enumerate(ordered):
        label = tile_labels[feed_index]
        out = "vout" if i == len(ordered) - 1 else f"o{i}"
        filter_parts.append(
            f"{current}[{label}]overlay={int(rect['x'])}:{int(rect['y'])}:shortest=0[{out}]"
        )
        current = f"[{out}]"

    # Audio per slot: that tile's live feed audio when available, else silence.
    slot_count = len(placements)
    silence_slots = []
    for slot, (feed_index, _rect, _z) in enumerate(placements):
        ain = live_audio_by_feed.get(feed_index)
        if ain is not None:
            filter_parts.append(
                f"[{ain}:a]aresample=async=1000,"
                f"aformat=sample_rates=48000:channel_layouts=stereo[a{slot}]"
            )
        else:
            silence_slots.append(slot)

    if silence_slots:
        if len(silence_slots) == 1:
            slot = silence_slots[0]
            filter_parts.append(
                f"[{silence_idx}:a]aformat=sample_rates=48000:channel_layouts=stereo[a{slot}]"
            )
        else:
            outs = "".join(f"[s{i}]" for i in range(len(silence_slots)))
            filter_parts.append(f"[{silence_idx}:a]asplit={len(silence_slots)}{outs}")
            for i, slot in enumerate(silence_slots):
                filter_parts.append(
                    f"[s{i}]aformat=sample_rates=48000:channel_layouts=stereo[a{slot}]"
                )

    filter_complex = ";".join(filter_parts)
    cmd += ["-filter_complex", filter_complex, "-map", "[vout]"]
    for slot in range(slot_count):
        cmd += ["-map", f"[a{slot}]"]

    gop = max(2, fps * 2)
    var_parts = ["v:0,agroup:aud,name:v"]
    for slot in range(slot_count):
        default = ",default:yes" if slot == 0 else ""
        var_parts.append(f"a:{slot},agroup:aud,name:a{slot}{default}")

    cmd += [
        "-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency",
        "-b:v", str(bitrate), "-maxrate", str(bitrate), "-bufsize", str(bitrate),
        "-g", str(gop), "-keyint_min", str(gop), "-bf", "0", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "128k", "-ac", "2", "-ar", "48000",
        "-f", "hls",
        "-hls_time", "2",
        "-hls_list_size", "10",
        "-hls_flags", "delete_segments+append_list+program_date_time",
        "-var_stream_map", " ".join(var_parts),
        "-hls_segment_filename", os.path.join(out_dir, "%v_%05d.ts"),
        os.path.join(out_dir, "%v.m3u8"),
    ]
    return cmd


class Mosaic:
    def __init__(self, out_dir, feeds, placements, settings, popen=subprocess.Popen):
        self.out_dir = out_dir
        self.feeds = feeds
        self.placements = placements
        self.settings = settings
        self._popen = popen
        self._proc = None
        self._stderr = []
        self._lock = threading.Lock()

    def start(self):
        ffmpeg = self.settings.get("ffmpeg", "ffmpeg")
        cmd = build_command(ffmpeg, self.feeds, self.placements, self.out_dir, self.settings)
        self._proc = self._popen(
            cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, start_new_session=True,
        )
        threading.Thread(target=self._drain_stderr, daemon=True).start()

    def apply_layout(self, placements):
        self.placements = placements

    def poll_error(self):
        proc = self._proc
        if proc is None:
            return "mosaic not started"
        code = proc.poll()
        if code is None:
            return ""
        with self._lock:
            tail = self._stderr[-3:]
        detail = "; ".join(tail) if tail else f"exit {code}"
        return f"ffmpeg mosaic exited: {detail}"

    def stop(self):
        proc = self._proc
        self._proc = None
        if proc is None:
            return
        if proc.stderr is not None:
            try:
                proc.stderr.close()
            except Exception:
                pass
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError, OSError):
            try:
                proc.terminate()
            except Exception:
                pass
        try:
            proc.wait(timeout=5)
        except Exception:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except Exception:
                pass

    def _drain_stderr(self):
        proc = self._proc
        if proc is None or proc.stderr is None:
            return
        try:
            for raw in proc.stderr:
                line = raw.decode("utf-8", "replace").rstrip()
                if not line:
                    continue
                with self._lock:
                    self._stderr.append(line)
                    if len(self._stderr) > 40:
                        self._stderr = self._stderr[-40:]
        except ValueError:
            pass
