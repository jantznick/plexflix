"""The GStreamer pipeline that tiles the feeds and writes the HLS output.

Feeds come in as raw frames pushed into appsrcs, one video pad per feed and
one audio branch per tile slot. Nothing upstream of the pipeline can stall it:
every frame tick pushes a buffer into every pad, whether that's fresh video,
a frozen frame or a slate. Layout changes are pad properties on the
compositor, applied while it runs.
"""

import threading

from .ingest import AUDIO_RATE, FRAME_H, FRAME_W
from .layouts import CANVAS_H, CANVAS_W

_gst = None
_gst_lock = threading.Lock()

ENCODER_ALIASES = {
    "libx264": "x264", "x264": "x264", "x264enc": "x264",
    "h264_vaapi": "va", "vaapi": "va", "va": "va", "vah264enc": "va",
    "h264_qsv": "qsv", "qsv": "qsv", "qsvh264enc": "qsv",
    "h264_nvenc": "nvenc", "nvenc": "nvenc", "nvh264enc": "nvenc",
    "h264_videotoolbox": "vt", "videotoolbox": "vt", "vt": "vt", "vtenc_h264": "vt",
}
# Candidates per family, best first, with the properties that matter here.
# Properties an installed element doesn't have are left out, since names
# shift between GStreamer releases.
ENCODERS = {
    "x264": [
        ("x264enc", "I420", {"tune": "zerolatency", "speed-preset": "veryfast", "bitrate": "{kbps}",
                             "key-int-max": "{gop}", "bframes": "0"}),
    ],
    "va": [
        ("vah264enc", "NV12", {"bitrate": "{kbps}", "key-int-max": "{gop}", "b-frames": "0"}),
        ("vaapih264enc", "NV12", {"bitrate": "{kbps}", "keyframe-period": "{gop}", "max-bframes": "0"}),
    ],
    "qsv": [
        ("qsvh264enc", "NV12", {"bitrate": "{kbps}", "gop-size": "{gop}", "b-frames": "0"}),
        ("msdkh264enc", "NV12", {"bitrate": "{kbps}", "gop-size": "{gop}", "b-frames": "0"}),
    ],
    "nvenc": [
        ("nvh264enc", "NV12", {"bitrate": "{kbps}", "gop-size": "{gop}", "bframes": "0", "zerolatency": "true"}),
    ],
    # macOS (Apple silicon or Intel Macs)
    "vt": [
        ("vtenc_h264", "NV12", {"bitrate": "{kbps}", "max-keyframe-interval": "{gop}",
                                "allow-frame-reordering": "false", "realtime": "true"}),
    ],
}
AAC_ENCODERS = ("voaacenc", "avenc_aac", "fdkaacenc")
# How late a pushed frame can be and still make it into the mosaic
COMPOSITOR_LATENCY_NS = 500_000_000


def gst():
    global _gst
    with _gst_lock:
        if _gst is None:
            import gi
            gi.require_version("Gst", "1.0")
            from gi.repository import Gst
            Gst.init(None)
            _gst = Gst
    return _gst


def available():
    try:
        Gst = gst()
    except (ImportError, ValueError):
        return False
    return all(Gst.ElementFactory.find(name) for name in ("compositor", "appsrc", "hlssink2"))


def encoder_description(settings):
    """gst-launch fragment for the configured encoder, falling back to x264."""
    Gst = gst()
    wanted = settings.get("encoder", "libx264")
    family = ENCODER_ALIASES.get(wanted)
    if family is None:
        raise ValueError(f"unknown ENCODER {wanted!r}; use one of x264, va, qsv, nvenc, vt")
    kbps = max(500, bitrate_bps(settings.get("video_bitrate", "6M")) // 1000)
    gop = settings.get("fps", 30) * 2
    candidates = ENCODERS[family] + (ENCODERS["x264"] if family != "x264" else [])
    for name, fmt, props in candidates:
        element = Gst.ElementFactory.make(name, None)
        if element is None:
            continue
        if family != "x264" and name == "x264enc":
            print(f"[compositor] no {wanted} encoder available here; using x264enc", flush=True)
        parts = [name]
        for key, value in props.items():
            if element.find_property(key) is not None:
                parts.append(f"{key}={value.format(kbps=kbps, gop=gop)}")
        return fmt, " ".join(parts)
    raise RuntimeError("no H.264 encoder found in GStreamer (install gstreamer1.0-plugins-ugly)")


def aac_encoder():
    Gst = gst()
    for name in AAC_ENCODERS:
        if Gst.ElementFactory.find(name):
            return f"{name} bitrate=128000"
    raise RuntimeError("no AAC encoder found in GStreamer (install gstreamer1.0-plugins-bad)")


def bitrate_bps(value):
    multipliers = {"k": 1000, "m": 1000000}
    value = str(value or "")
    suffix = value[-1].lower() if value else ""
    try:
        if suffix in multipliers:
            return int(float(value[:-1]) * multipliers[suffix])
        return int(value)
    except ValueError:
        return 6000000


class Compositor:
    def __init__(self, out_dir, feed_count, settings):
        self.out_dir = out_dir
        self.feed_count = feed_count
        self.fps = settings.get("fps", 30)
        self._settings = settings
        self._pipeline = None
        self._video_src = []
        self._audio_src = []
        self._pads = []
        self._cache = {}
        self._offset = 0
        self.frame_ns = 0

    def description(self):
        fps = self.fps
        fmt, encoder = encoder_description(self._settings)
        aac = aac_encoder()
        out = self.out_dir
        parts = [
            f"compositor name=comp background=black latency={COMPOSITOR_LATENCY_NS} "
            f"! video/x-raw,width={CANVAS_W},height={CANVAS_H},framerate={fps}/1 "
            f"! videoconvert ! video/x-raw,format={fmt} ! {encoder} ! h264parse config-interval=-1 "
            f"! hlssink2 name=vsink target-duration=2 playlist-length=10 max-files=20 "
            f"send-keyframe-requests=true location={out}/v_%05d.ts playlist-location={out}/v.m3u8"
        ]
        for i in range(self.feed_count):
            parts.append(
                f"appsrc name=v{i} is-live=true format=time do-timestamp=false "
                f"caps=video/x-raw,format=I420,width={FRAME_W},height={FRAME_H},framerate={fps}/1,"
                f"pixel-aspect-ratio=1/1 ! queue max-size-buffers=4 leaky=downstream ! comp.sink_{i}"
            )
            parts.append(
                f"appsrc name=a{i} is-live=true format=time do-timestamp=false "
                f"caps=audio/x-raw,format=S16LE,rate={AUDIO_RATE},channels=2,layout=interleaved "
                f"! queue ! audioconvert ! {aac} ! aacparse "
                f"! hlssink2 name=as{i} target-duration=2 playlist-length=10 max-files=20 "
                f"location={out}/a{i}_%05d.ts playlist-location={out}/a{i}.m3u8"
            )
        return " ".join(parts)

    def start(self):
        Gst = gst()
        self._pipeline = Gst.parse_launch(self.description())
        comp = self._pipeline.get_by_name("comp")
        self._video_src = [self._pipeline.get_by_name(f"v{i}") for i in range(self.feed_count)]
        self._audio_src = [self._pipeline.get_by_name(f"a{i}") for i in range(self.feed_count)]
        self._pads = [comp.get_static_pad(f"sink_{i}") for i in range(self.feed_count)]
        self._pipeline.set_state(Gst.State.PLAYING)
        self._pipeline.get_state(2 * Gst.SECOND)
        self.frame_ns = Gst.SECOND // self.fps
        # Timestamps start at the pipeline's current running time; starting at
        # zero would make every frame late, and the compositor drops late frames
        clock = self._pipeline.get_clock()
        if clock is not None:
            self._offset = max(0, clock.get_time() - self._pipeline.get_base_time())

    def apply_layout(self, placements):
        """placements: (feed index, rect dict, zorder) for every feed."""
        for feed_index, rect, zorder in placements:
            pad = self._pads[feed_index]
            for key, value in (("xpos", rect["x"]), ("ypos", rect["y"]), ("width", rect["w"]),
                               ("height", rect["h"]), ("zorder", zorder)):
                pad.set_property(key, value)

    def pad_rect(self, feed_index):
        pad = self._pads[feed_index]
        return {k: pad.get_property(p) for k, p in (("x", "xpos"), ("y", "ypos"), ("w", "width"), ("h", "height"))}

    def push_video(self, feed_index, frame, n):
        self._push(self._video_src[feed_index], ("v", feed_index), frame, n, self.frame_ns)

    def push_audio(self, slot, pcm, n):
        self._push(self._audio_src[slot], ("a", slot), pcm, n, self.frame_ns)

    def _push(self, src, key, data, n, duration):
        Gst = gst()
        cached = self._cache.get(key)
        if cached is not None and cached[0] is data:
            buf = cached[1].copy()
        else:
            buf = Gst.Buffer.new_wrapped(data)
            self._cache[key] = (data, buf)
            buf = buf.copy()
        buf.pts = self._offset + n * duration
        buf.duration = duration
        src.emit("push-buffer", buf)

    def poll_error(self):
        if self._pipeline is None:
            return None
        Gst = gst()
        bus = self._pipeline.get_bus()
        while True:
            msg = bus.pop_filtered(Gst.MessageType.ERROR | Gst.MessageType.WARNING)
            if msg is None:
                return None
            if msg.type == Gst.MessageType.ERROR:
                err, debug = msg.parse_error()
                return f"{msg.src.get_name()}: {err.message}"
            warning, _ = msg.parse_warning()
            print(f"[compositor] warning from {msg.src.get_name()}: {warning.message}", flush=True)

    def stop(self):
        pipeline = self._pipeline
        self._pipeline = None
        if pipeline is None:
            return
        Gst = gst()
        for src in self._video_src + self._audio_src:
            src.emit("end-of-stream")
        # EOS lets hlssink2 close out its last segment so it stays playable
        pipeline.get_bus().timed_pop_filtered(3 * Gst.SECOND, Gst.MessageType.EOS | Gst.MessageType.ERROR)
        pipeline.set_state(Gst.State.NULL)
        self._cache.clear()
