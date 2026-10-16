import unittest

from multiview import layouts
from multiview.playlist import StitchedPlaylist, master_playlist

class LayoutTests(unittest.TestCase):
    def test_every_layout_fits_the_canvas_with_even_sizes(self):
        for layout in layouts.LAYOUTS:
            for count in range(layouts.MIN_TILES, layouts.MAX_TILES + 1):
                for tile in layouts.tiles_for(layout, count):
                    self.assertEqual(tile["w"] % 2, 0)
                    self.assertEqual(tile["h"] % 2, 0)
                    self.assertGreaterEqual(tile["x"], 0)
                    self.assertGreaterEqual(tile["y"], 0)
                    self.assertLessEqual(tile["x"] + tile["w"], layouts.CANVAS_W)
                    self.assertLessEqual(tile["y"] + tile["h"], layouts.CANVAS_H)

    def test_grid_tiles_never_overlap(self):
        for count in range(2, 5):
            tiles = layouts.tiles_for("grid", count)
            for i, a in enumerate(tiles):
                for b in tiles[i + 1:]:
                    overlap = (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
                               and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"])
                    self.assertFalse(overlap, (count, a, b))

    def test_rejects_bad_counts_and_layouts(self):
        with self.assertRaises(ValueError):
            layouts.tiles_for("grid", 1)
        with self.assertRaises(ValueError):
            layouts.tiles_for("grid", 5)
        with self.assertRaises(ValueError):
            layouts.tiles_for("mosaic", 2)


class StitchTests(unittest.TestCase):
    def test_restart_becomes_a_discontinuity_with_continuous_sequence(self):
        playlist = StitchedPlaylist(window=4)
        playlist.add(1, [(2.0, "v_00000.ts"), (2.0, "v_00001.ts")], "gen-1")
        playlist.add(1, [(2.0, "v_00000.ts"), (2.0, "v_00001.ts"), (2.0, "v_00002.ts")], "gen-1")
        playlist.add(2, [(2.0, "v_00000.ts")], "gen-2")
        text = playlist.render()
        self.assertIn("#EXT-X-MEDIA-SEQUENCE:0", text)
        self.assertIn("#EXT-X-DISCONTINUITY-SEQUENCE:0", text)
        self.assertEqual(text.count("#EXT-X-DISCONTINUITY\n"), 1)
        self.assertLess(text.index("gen-1/v_00002.ts"), text.index("#EXT-X-DISCONTINUITY\n"))
        self.assertLess(text.index("#EXT-X-DISCONTINUITY\n"), text.index("gen-2/v_00000.ts"))

    def test_window_slides_and_counts_discontinuities_that_leave(self):
        playlist = StitchedPlaylist(window=3)
        playlist.add(1, [(2.0, "a.ts"), (2.0, "b.ts")], "gen-1")
        playlist.add(2, [(2.0, "a.ts")], "gen-2")
        playlist.add(2, [(2.0, "a.ts"), (2.0, "b.ts"), (2.0, "c.ts")], "gen-2")
        text = playlist.render()
        self.assertIn("#EXT-X-MEDIA-SEQUENCE:2", text)
        self.assertIn("#EXT-X-DISCONTINUITY-SEQUENCE:1", text)
        self.assertNotIn("#EXT-X-DISCONTINUITY\n", text)
        self.assertEqual(playlist.generations(), {2})

    def test_segments_still_listed_by_ffmpeg_are_not_re_added(self):
        playlist = StitchedPlaylist(window=2)
        segments = [(2.0, f"{i}.ts") for i in range(5)]
        playlist.add(1, segments, "gen-1")
        self.assertEqual(playlist.add(1, segments, "gen-1"), 0)
        self.assertEqual([e["uri"] for e in playlist.entries], ["gen-1/3.ts", "gen-1/4.ts"])

    def test_master_lists_one_audio_rendition_per_tile(self):
        text = master_playlist(3, 6384000)
        self.assertEqual(text.count("TYPE=AUDIO"), 3)
        self.assertIn('URI="a2.m3u8"', text)
        self.assertEqual(text.count("DEFAULT=YES"), 1)
        self.assertTrue(text.rstrip().endswith("v.m3u8"))


class FakeSession:
    def __init__(self, session_id, streams, layout, root, settings, relay=None):
        self.id = session_id
        self.last_seen = 0
        self.stopped = False

    def start(self):
        pass

    def stop(self):
        self.stopped = True


class ManagerTests(unittest.TestCase):
    def setUp(self):
        import tempfile
        from multiview.server import SessionManager
        self.now = [0.0]
        settings = {"data_dir": tempfile.mkdtemp(), "max_sessions": 2, "idle_timeout": 90}
        self.manager = SessionManager(settings, session_factory=FakeSession, clock=lambda: self.now[0])

    def test_full_manager_evicts_the_stalest_session(self):
        first = self.manager.create([], "grid")
        second = self.manager.create([], "grid")
        first.last_seen, second.last_seen = 5, 10
        third = self.manager.create([], "grid")
        self.assertTrue(first.stopped)
        self.assertIsNone(self.manager.get(first.id))
        self.assertIs(self.manager.get(third.id), third)
        self.assertFalse(second.stopped)

    def test_idle_sessions_are_reaped(self):
        session = self.manager.create([], "grid")
        session.last_seen = 0
        self.now[0] = 60
        self.manager.reap()
        self.assertFalse(session.stopped)
        self.now[0] = 91
        self.manager.reap()
        self.assertTrue(session.stopped)
        self.assertIsNone(self.manager.get(session.id))


if __name__ == "__main__":
    unittest.main()
