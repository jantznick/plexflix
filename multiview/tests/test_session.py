"""Mosaic command shaping and a smoke encode when ffmpeg is available."""

import os
import shutil
import subprocess
import tempfile
import unittest

from multiview.mosaic import build_command
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
        self.assertIn("var_stream_map", joined)
        self.assertIn("name:a0", joined)
        self.assertIn("name:a1", joined)
        self.assertIn("anullsrc", joined)
        self.assertTrue(cmd[-1].endswith("%v.m3u8"))


@unittest.skipUnless(HAVE_FFMPEG, "needs ffmpeg")
class MosaicEncodeTests(unittest.TestCase):
    def test_placeholder_only_writes_hls_segments(self):
        # Finite lavfi graph (same shape as mosaic, smaller) — proves var_stream_map
        # names v/a0/a1 without waiting on a live 1080p encode.
        tmp = tempfile.mkdtemp(prefix="mosaic-")
        try:
            out = os.path.join(tmp, "out")
            os.makedirs(out)
            cmd = [
                "ffmpeg", "-hide_banner", "-nostdin", "-loglevel", "error", "-y",
                "-f", "lavfi", "-i", "color=c=black:s=640x360:r=10",
                "-f", "lavfi", "-i", "color=c=0x1c1c1e:s=320x180:r=10",
                "-f", "lavfi", "-i", "color=c=0x1c1c1e:s=320x180:r=10",
                "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
                "-t", "3",
                "-filter_complex",
                "[1:v]format=yuv420p[t0];[2:v]format=yuv420p[t1];"
                "[0:v][t0]overlay=0:90:shortest=1[o0];[o0][t1]overlay=320:90:shortest=1[vout];"
                "[3:a]asplit=2[s0][s1];"
                "[s0]aformat=sample_rates=48000:channel_layouts=stereo[a0];"
                "[s1]aformat=sample_rates=48000:channel_layouts=stereo[a1]",
                "-map", "[vout]", "-map", "[a0]", "-map", "[a1]",
                "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", "-b:a", "64k",
                "-shortest",
                "-f", "hls", "-hls_time", "1", "-hls_list_size", "0",
                "-var_stream_map",
                "v:0,agroup:aud,name:v a:0,agroup:aud,default:yes,name:a0 a:1,agroup:aud,name:a1",
                "-hls_segment_filename", os.path.join(out, "%v_%05d.ts"),
                os.path.join(out, "%v.m3u8"),
            ]
            subprocess.run(cmd, check=True, timeout=30)
            for name in ("v.m3u8", "a0.m3u8", "a1.m3u8"):
                path = os.path.join(out, name)
                self.assertTrue(os.path.isfile(path), name)
                with open(path, encoding="utf-8") as handle:
                    self.assertIn("#EXTINF", handle.read())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


class SessionWarmTests(unittest.TestCase):
    def test_session_requires_relay(self):
        with self.assertRaises(ValueError):
            Session("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                    [{"url": "http://example/a.m3u8"}, {"url": "http://example/b.m3u8"}],
                    "grid", "/tmp", {}, relay=None)


class _FakeRelay:
    def warm(self, _urls):
        return None


class _FakeMosaic:
    def __init__(self, *args, **kwargs):
        pass

    def stop(self):
        return None


class SessionReconfigureTests(unittest.TestCase):
    def _session(self, count=2, live_slots=2):
        streams = [
            {"url": f"http://example/{i}.m3u8", "title": chr(ord("A") + i)}
            for i in range(count)
        ]
        return Session(
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            streams,
            "grid",
            "/tmp",
            {"live_slots": live_slots},
            relay=_FakeRelay(),
            mosaic_factory=_FakeMosaic,
        )

    def test_reconfigure_accepts_float_order_from_roku_json(self):
        session = self._session()
        session._mosaic = _FakeMosaic()
        session.reconfigure(order=[1.0, 0.0])
        self.assertEqual(session.order, [1, 0])
        snap = session.snapshot()
        self.assertEqual(snap["tiles"][0]["stream"], 1)
        self.assertEqual(snap["tiles"][0]["title"], "B")

    def test_live_slots_follow_order_prefix(self):
        session = self._session(count=3, live_slots=2)
        self.assertTrue(session.feeds[0].live)
        self.assertTrue(session.feeds[1].live)
        self.assertFalse(session.feeds[2].live)
        session._mosaic = _FakeMosaic()
        session.reconfigure(order=[2, 0, 1])
        self.assertTrue(session.feeds[2].live)
        self.assertTrue(session.feeds[0].live)
        self.assertFalse(session.feeds[1].live)
        snap = session.snapshot()
        self.assertEqual(snap["tiles"][0]["stream"], 2)
        self.assertEqual(snap["tiles"][2]["status"], "placeholder")

    def test_pause_stops_mosaic_for_fullscreen_promote(self):
        session = self._session()
        session._mosaic = _FakeMosaic()
        session.state = "running"
        session.reconfigure(paused=True)
        self.assertTrue(session.paused)
        self.assertEqual(session.state, "paused")
        self.assertIsNone(session._mosaic)
        session.reconfigure(paused=False)
        self.assertFalse(session.paused)
        self.assertEqual(session.state, "starting")


if __name__ == "__main__":
    unittest.main()
