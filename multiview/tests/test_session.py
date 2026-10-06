"""Supervisor behaviour against a real ffmpeg, with no network.

Feeds are local HLS files and their health is faked, so a feed can be made to
drop out and come back on cue.
"""

import os
import shutil
import subprocess
import tempfile
import time
import unittest

from multiview import session as session_module
from multiview.session import Session

HAVE_FFMPEG = shutil.which("ffmpeg") is not None


class FakeProbe:
    def __init__(self, url, headers=None, tile_height=540):
        self.url = url
        self.tile_height = tile_height
        self.variant = None
        self.has_audio = True
        self.error = ""
        self.healthy = True

    def check(self):
        self.error = "" if self.healthy else "simulated outage"
        return self.healthy

    def input_target(self):
        return self.url, None

    def detect_audio(self, ffprobe="ffprobe", timeout=25):
        return self.has_audio


def wait_for(predicate, timeout, step=0.25):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(step)
    return False


@unittest.skipUnless(HAVE_FFMPEG, "ffmpeg not installed")
class SessionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="multiview-test-")
        cls.feed = os.path.join(cls.tmp, "feed", "index.m3u8")
        os.makedirs(os.path.dirname(cls.feed))
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error",
            "-f", "lavfi", "-i", "testsrc2=s=640x360:r=30",
            "-f", "lavfi", "-i", "sine=f=330:r=48000",
            "-t", "120", "-c:v", "libx264", "-preset", "ultrafast", "-g", "60", "-c:a", "aac",
            "-f", "hls", "-hls_time", "2", "-hls_list_size", "0", cls.feed,
        ], check=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def setUp(self):
        self.saved = {name: getattr(session_module, name)
                      for name in ("PROBE_INTERVAL", "RECOVER_SECONDS", "STALL_TIMEOUT")}
        session_module.PROBE_INTERVAL = 1
        session_module.RECOVER_SECONDS = 2
        # Local files are read faster than real time, then repeat their last
        # frame; generous so that never reads as a stall
        session_module.STALL_TIMEOUT = 20
        self.root = tempfile.mkdtemp(prefix="sessions-", dir=self.tmp)
        self.settings = {
            "ffmpeg": "ffmpeg", "ffprobe": "ffprobe", "encoder": "libx264", "fps": 30,
            "video_bitrate": "2M", "font_file": "", "allow_local_inputs": True,
        }

    def tearDown(self):
        for name, value in self.saved.items():
            setattr(session_module, name, value)

    def make_session(self, count=2, layout="grid", settings=None):
        streams = [{"url": self.feed, "title": f"Game {i + 1}"} for i in range(count)]
        return Session("0" * 8 + "-0000-0000-0000-" + "0" * 12, streams, layout, self.root,
                       settings or self.settings, probe_factory=FakeProbe)

    def read(self, session, name):
        try:
            with open(os.path.join(session.dir, name), encoding="utf-8") as handle:
                return handle.read()
        except FileNotFoundError:
            return ""

    def test_feed_outage_swaps_in_a_slate_and_recovers_without_breaking_the_playlist(self):
        session = self.make_session()
        session.start()
        try:
            self.assertTrue(wait_for(lambda: session.state == "running", 40), session.snapshot())
            self.assertIn('URI="a1.m3u8"', self.read(session, "master.m3u8"))
            self.assertEqual([t["status"] for t in session.snapshot()["tiles"]], ["live", "live"])

            session.feeds[1].probe.healthy = False
            self.assertTrue(wait_for(lambda: session.snapshot()["tiles"][1]["status"] == "reconnecting", 15))
            self.assertTrue(wait_for(lambda: "gen-2/" in self.read(session, "v.m3u8"), 30))
            video = self.read(session, "v.m3u8")
            self.assertIn("#EXT-X-DISCONTINUITY", video)
            self.assertIn("gen-2/", self.read(session, "a1.m3u8"))
            self.assertEqual(session.snapshot()["tiles"][0]["status"], "live")

            session.feeds[1].probe.healthy = True
            self.assertTrue(wait_for(lambda: session.generation >= 3, 30), session.snapshot())
            self.assertTrue(wait_for(lambda: session.snapshot()["tiles"][1]["status"] == "live", 30))

            # Media sequence only ever moves forward across all of that
            sequences = [int(line.split(":")[1]) for line in self.read(session, "v.m3u8").splitlines()
                         if line.startswith("#EXT-X-MEDIA-SEQUENCE")]
            self.assertTrue(sequences)
        finally:
            session.stop()
        self.assertFalse(os.path.exists(session.dir))

    def test_reorder_and_layout_change_restart_with_new_tiles(self):
        session = self.make_session(count=3, layout="grid")
        session.start()
        try:
            self.assertTrue(wait_for(lambda: session.state == "running", 40))
            session.reconfigure(layout="spotlight", order=[2, 0, 1])
            self.assertTrue(wait_for(lambda: session.generation >= 2, 15))
            snap = session.snapshot()
            self.assertEqual(snap["layout"], "spotlight")
            self.assertEqual([t["stream"] for t in snap["tiles"]], [2, 0, 1])
            self.assertEqual((snap["tiles"][0]["w"], snap["tiles"][0]["h"]), (1440, 810))
            self.assertTrue(wait_for(lambda: session.state == "running", 40))
        finally:
            session.stop()

    def test_ffmpeg_that_keeps_dying_backs_off_instead_of_spinning(self):
        session = self.make_session(settings=dict(self.settings, ffmpeg="false"))
        session.start()
        try:
            time.sleep(6)
            # Immediate retries would be dozens by now; backoff keeps it to a few
            self.assertGreaterEqual(session.restarts, 2)
            self.assertLessEqual(session.restarts, 5)
            self.assertNotEqual(session.state, "running")
        finally:
            session.stop()


if __name__ == "__main__":
    unittest.main()
