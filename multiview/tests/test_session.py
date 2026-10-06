"""A real session, with real ffmpeg ingests and a real GStreamer compositor,
fed from local HLS files so no network is involved.
"""

import os
import shutil
import subprocess
import tempfile
import time
import unittest

from multiview import compositor as compositor_module
from multiview import ingest as ingest_module
from multiview.session import Session

HAVE_TOOLS = shutil.which("ffmpeg") is not None and compositor_module.available()


def wait_for(predicate, timeout, step=0.25):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(step)
    return False


def make_feed(path, audio=True, seconds=120):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error",
           "-f", "lavfi", "-i", "testsrc2=s=640x360:r=30"]
    if audio:
        cmd += ["-f", "lavfi", "-i", "sine=f=330:r=48000", "-c:a", "aac"]
    cmd += ["-t", str(seconds), "-c:v", "libx264", "-preset", "ultrafast", "-g", "60",
            "-f", "hls", "-hls_time", "2", "-hls_list_size", "0", path]
    subprocess.run(cmd, check=True)


@unittest.skipUnless(HAVE_TOOLS, "needs ffmpeg and GStreamer (python3-gi)")
class SessionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="multiview-test-")
        cls.feed = os.path.join(cls.tmp, "feed", "index.m3u8")
        cls.silent = os.path.join(cls.tmp, "silent", "index.m3u8")
        make_feed(cls.feed)
        make_feed(cls.silent, audio=False)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def setUp(self):
        self.saved = {name: getattr(ingest_module, name) for name in ("FREEZE_SECONDS", "RESTART_AFTER")}
        ingest_module.FREEZE_SECONDS = 1.5
        ingest_module.RESTART_AFTER = 3
        self.root = tempfile.mkdtemp(prefix="sessions-", dir=self.tmp)
        self.settings = {"ffmpeg": "ffmpeg", "encoder": "libx264", "fps": 30, "video_bitrate": "2M",
                         "font_file": "", "allow_local_inputs": True}
        self.sessions = []

    def tearDown(self):
        for session in self.sessions:
            session.stop()
        for name, value in self.saved.items():
            setattr(ingest_module, name, value)

    def make_session(self, urls, layout="grid"):
        streams = [{"url": url, "title": f"Game {i + 1}"} for i, url in enumerate(urls)]
        session = Session("0" * 8 + "-0000-0000-0000-" + "0" * 12, streams, layout, self.root, self.settings)
        self.sessions.append(session)
        return session

    def copy_feed(self, name):
        target = os.path.join(self.tmp, name)
        shutil.copytree(os.path.dirname(self.feed), target)
        return os.path.join(target, "index.m3u8")

    def read(self, session, name):
        try:
            with open(os.path.join(session.dir, name), encoding="utf-8") as handle:
                return handle.read()
        except FileNotFoundError:
            return ""

    def statuses(self, session):
        return [t["status"] for t in session.snapshot()["tiles"]]

    def segment_count(self, session):
        return self.read(session, "v.m3u8").count("#EXTINF")

    def last_sequence(self, session):
        for line in self.read(session, "v.m3u8").splitlines():
            if line.startswith("#EXT-X-MEDIA-SEQUENCE:"):
                return int(line.split(":")[1]) + self.segment_count(session)
        return 0

    def test_one_feed_dying_leaves_the_others_and_the_output_alone(self):
        broken = self.copy_feed("broken")
        session = self.make_session([self.feed, broken])
        session.start()
        self.assertTrue(wait_for(lambda: session.state == "running", 40), session.snapshot())
        self.assertTrue(wait_for(lambda: self.statuses(session) == ["live", "live"], 20), session.snapshot())
        self.assertIn('URI="a1.m3u8"', self.read(session, "master.m3u8"))

        os.rename(os.path.dirname(broken), os.path.dirname(broken) + ".off")
        session.feeds[1].ingest._kill()
        self.assertTrue(wait_for(lambda: self.statuses(session) == ["live", "reconnecting"], 15),
                        session.snapshot())
        before = self.last_sequence(session)
        time.sleep(6)
        self.assertGreater(self.last_sequence(session), before, "output stopped while a feed was down")
        self.assertEqual(session.generation, 1)
        self.assertEqual(session.snapshot()["tiles"][0]["status"], "live")
        self.assertEqual(session.state, "running")

        os.rename(os.path.dirname(broken) + ".off", os.path.dirname(broken))
        self.assertTrue(wait_for(lambda: self.statuses(session) == ["live", "live"], 30), session.snapshot())
        self.assertEqual(session.generation, 1)
        self.assertNotIn("#EXT-X-DISCONTINUITY\n", self.read(session, "v.m3u8"))

    def test_layout_and_order_changes_apply_without_a_restart(self):
        session = self.make_session([self.feed, self.feed, self.feed])
        session.start()
        self.assertTrue(wait_for(lambda: session.state == "running", 40), session.snapshot())
        session.reconfigure(layout="spotlight", order=[2, 0, 1])
        snap = session.snapshot()
        self.assertEqual([t["stream"] for t in snap["tiles"]], [2, 0, 1])
        self.assertEqual((snap["tiles"][0]["w"], snap["tiles"][0]["h"]), (1440, 810))
        self.assertEqual(session._compositor.pad_rect(2), {"x": 0, "y": 135, "w": 1440, "h": 810})
        before = self.last_sequence(session)
        self.assertTrue(wait_for(lambda: self.last_sequence(session) > before + 1, 15))
        self.assertEqual(session.generation, 1)
        self.assertEqual(session.state, "running")

    def test_feed_without_audio_still_plays(self):
        session = self.make_session([self.feed, self.silent])
        session.start()
        self.assertTrue(wait_for(lambda: self.statuses(session) == ["live", "live"], 40), session.snapshot())
        self.assertFalse(session.feeds[1].ingest.has_audio)
        self.assertTrue(wait_for(lambda: self.read(session, "a1.m3u8").count("#EXTINF") >= 2, 20))

    def test_failed_pipeline_is_rebuilt_as_a_discontinuity(self):
        session = self.make_session([self.feed, self.feed])
        session.start()
        self.assertTrue(wait_for(lambda: session.state == "running", 40), session.snapshot())
        session._pump_error = "simulated pipeline failure"
        self.assertTrue(wait_for(lambda: session.generation == 2, 10))
        self.assertTrue(wait_for(lambda: "gen-2/" in self.read(session, "v.m3u8"), 20))
        self.assertIn("#EXT-X-DISCONTINUITY\n", self.read(session, "v.m3u8"))
        self.assertIn("gen-2/", self.read(session, "a1.m3u8"))
        self.assertTrue(wait_for(lambda: session.state == "running", 20))
        self.assertEqual(self.statuses(session), ["live", "live"])

    def test_stop_cleans_up(self):
        session = self.make_session([self.feed, self.feed])
        session.start()
        self.assertTrue(wait_for(lambda: session.state == "running", 40))
        procs = [f.ingest._proc for f in session.feeds]
        session.stop()
        self.sessions.remove(session)
        self.assertFalse(os.path.exists(session.dir))
        self.assertTrue(all(p is None or p.poll() is not None for p in procs))


if __name__ == "__main__":
    unittest.main()
