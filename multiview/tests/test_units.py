import unittest

from multiview import layouts
from multiview.ffmpeg_cmd import build_command
from multiview.playlist import StitchedPlaylist, master_playlist
from multiview.probe import FeedProbe, choose_variant, parse_master, streams_have_audio

MASTER = """#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080
hi/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720
mid/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=640x360,AUDIO="aud"
lo/index.m3u8
"""


def media(sequence, count, ended=False):
    lines = ["#EXTM3U", "#EXT-X-TARGETDURATION:6", f"#EXT-X-MEDIA-SEQUENCE:{sequence}"]
    for i in range(count):
        lines += ["#EXTINF:6.0,", f"seg{sequence + i}.ts"]
    if ended:
        lines.append("#EXT-X-ENDLIST")
    return "\n".join(lines)


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


class ProbeTests(unittest.TestCase):
    def test_master_variants_resolve_relative_urls_in_order(self):
        variants = parse_master(MASTER, "https://cdn.example/live/master.m3u8")
        self.assertEqual([v["program"] for v in variants], [0, 1, 2])
        self.assertEqual(variants[1]["url"], "https://cdn.example/live/mid/index.m3u8")
        self.assertEqual(variants[2]["audio_group"], "aud")

    def test_variant_choice_is_smallest_that_fills_the_tile(self):
        variants = parse_master(MASTER, "https://cdn.example/m.m3u8")
        self.assertEqual(choose_variant(variants, 270)["height"], 360)
        self.assertEqual(choose_variant(variants, 540)["height"], 720)
        self.assertEqual(choose_variant(variants, 1080)["height"], 1080)
        self.assertEqual(choose_variant(variants, 2160)["height"], 1080)

    def test_feed_goes_stale_when_playlist_stops_advancing(self):
        now = [0.0]
        playlists = {"u": media(10, 3)}
        probe = FeedProbe("u", fetch=lambda url, headers: (playlists[url], url), clock=lambda: now[0])
        self.assertTrue(probe.check())
        now[0] = 20
        self.assertTrue(probe.check())
        now[0] = 30
        self.assertFalse(probe.check())
        self.assertIn("stopped advancing", probe.error)
        playlists["u"] = media(11, 3)
        self.assertTrue(probe.check())

    def test_ended_and_unreachable_feeds_are_unhealthy(self):
        probe = FeedProbe("u", fetch=lambda url, headers: (media(1, 3, ended=True), url))
        self.assertFalse(probe.check())

        def boom(url, headers):
            raise OSError("connection refused")

        probe = FeedProbe("u", fetch=boom)
        self.assertFalse(probe.check())
        self.assertIn("refused", probe.error)

    def test_master_feeds_map_by_program(self):
        pages = {"https://x/m.m3u8": MASTER, "https://x/lo/index.m3u8": media(1, 3)}
        probe = FeedProbe("https://x/m.m3u8", tile_height=270, fetch=lambda url, headers: (pages[url], url))
        self.assertTrue(probe.check())
        self.assertEqual(probe.input_target(), ("https://x/m.m3u8", 2))

    def test_audio_detection_reads_the_chosen_program(self):
        data = {"programs": [
            {"program_id": 0, "streams": [{"codec_type": "video"}]},
            {"program_id": 1, "streams": [{"codec_type": "video"}, {"codec_type": "audio"}]},
        ]}
        self.assertFalse(streams_have_audio(data, 0))
        self.assertTrue(streams_have_audio(data, 1))
        self.assertFalse(streams_have_audio({"streams": [{"codec_type": "video"}]}, None))


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


class CommandTests(unittest.TestCase):
    SETTINGS = {"ffmpeg": "ffmpeg", "encoder": "libx264", "fps": 30, "video_bitrate": "6M", "font_file": ""}

    def test_down_and_silent_feeds_still_produce_an_audio_output(self):
        rects = layouts.tiles_for("grid", 3)
        slots = [
            {"rect": rects[0], "live": True, "url": "https://a/m.m3u8", "program": 1, "has_audio": True},
            {"rect": rects[1], "live": True, "url": "https://b/i.m3u8", "program": None, "has_audio": False},
            {"rect": rects[2], "live": False, "slate_text_file": "/tmp/x.txt"},
        ]
        cmd = build_command(slots, "/tmp/gen-1", self.SETTINGS)
        outputs = [arg for arg in cmd if arg.endswith(".m3u8") and arg.startswith("/tmp/gen-1")]
        self.assertEqual(outputs, ["/tmp/gen-1/v.m3u8", "/tmp/gen-1/a0.m3u8", "/tmp/gen-1/a1.m3u8", "/tmp/gen-1/a2.m3u8"])
        graph = cmd[cmd.index("-filter_complex") + 1]
        self.assertIn("[0:p:1:v:0]", graph)
        self.assertIn("0:p:1:a:0", cmd)

    def test_unknown_encoder_is_rejected(self):
        with self.assertRaises(ValueError):
            build_command([], "/tmp", dict(self.SETTINGS, encoder="h265_magic"))


class FakeSession:
    def __init__(self, session_id, streams, layout, root, settings):
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
