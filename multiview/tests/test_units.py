import unittest

from multiview import layouts


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
