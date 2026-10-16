"""Mosaic command shaping and a smoke encode when ffmpeg is available."""

import os
import shutil
import subprocess
import tempfile
import time
import unittest

from multiview.mosaic import Mosaic, build_command
from multiview.session import Session

HAVE_FFMPEG = shutil.which("ffmpeg") is not None


class MosaicCommandTests(unittest.TestCase):
    def test_live_feed_and_placeholder_are_overlaid_on_canvas(self):
        feeds = [
            {"live": True, "url": "http://127.0.0.1:9/r/x.m3u8", "title": "A"},
            {"live": False, "url": "", "title": "B"},
        ]
        placements = [
            (0, {"x": 0, "y": 270, "w": 960, "h": 540}, 0),
            (1, {"x": 960, "y": 270, "w": 960, "h": 540}, 1),
        ]
        cmd = build_command("ffmpeg", feeds, placements, "/tmp/mosaic-out", {
            "fps": 20, "video_bitrate": "2M", "font_file": "",
        })
        joined = " ".join(cmd)
        self.assertIn("filter_complex", joined)
        self.assertIn("overlay=0:270", joined)
        self.assertIn("overlay=960:270", joined)
        self.assertIn("http://127.0.0.1:9/r/x.m3u8", joined)
        self.assertIn("color=c=0x1c1c1e", joined)
        self.assertTrue(joined.endswith("/tmp/mosaic-out/v.m3u8") or cmd[-1].endswith("v.m3u8"))


@unittest.skipUnless(HAVE_FFMPEG, "needs ffmpeg")
class MosaicEncodeTests(unittest.TestCase):
    def test_placeholder_only_writes_hls_segments(self):
        tmp = tempfile.mkdtemp(prefix="mosaic-")
        try:
            feeds = [
                {"live": False, "url": "", "title": "Left"},
                {"live": False, "url": "", "title": "Right"},
            ]
            placements = [
                (0, {"x": 0, "y": 270, "w": 960, "h": 540}, 0),
                (1, {"x": 960, "y": 270, "w": 960, "h": 540}, 1),
            ]
            # Force a short finite encode via lavfi + -t by running build pieces
            out = os.path.join(tmp, "out")
            os.makedirs(out)
            # Two color sources composited — no network
            mosaic = Mosaic(out, feeds, placements, {
                "ffmpeg": "ffmpeg", "fps": 10, "video_bitrate": "1M", "font_file": "",
            })
            mosaic.start()
            deadline = time.monotonic() + 20
            playlist = os.path.join(out, "v.m3u8")
            while time.monotonic() < deadline:
                if os.path.isfile(playlist) and os.path.getsize(playlist) > 0:
                    break
                err = mosaic.poll_error()
                if err:
                    self.fail(err)
                time.sleep(0.25)
            mosaic.stop()
            self.assertTrue(os.path.isfile(playlist), "expected v.m3u8")
            text = open(playlist, encoding="utf-8").read()
            self.assertIn("#EXTINF", text)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


class SessionWarmTests(unittest.TestCase):
    def test_session_requires_relay(self):
        with self.assertRaises(ValueError):
            Session("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                    [{"url": "http://example/a.m3u8"}, {"url": "http://example/b.m3u8"}],
                    "grid", "/tmp", {}, relay=None)


if __name__ == "__main__":
    unittest.main()
