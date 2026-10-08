import unittest
from unittest import mock

from grab.nzbfinder import parse_newznab_items, pick_best, score_release
from grab.nzbget import NzbGet
from grab.settings import settings_from_env
from grab.jobs import JobStore


SAMPLE_FEED = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:newznab="http://www.newznab.com/DTD/2010/feeds/attributes/">
  <channel>
    <item>
      <title>Some.Movie.2020.2160p.WEB-DL.mkv</title>
      <link>https://nzbfinder.ws/getnzb/big.nzb</link>
      <guid>big</guid>
      <newznab:attr name="size" value="12000000000"/>
    </item>
    <item>
      <title>Some.Movie.2020.1080p.WEB-DL.x264</title>
      <link>https://nzbfinder.ws/getnzb/good.nzb</link>
      <guid>good</guid>
      <newznab:attr name="size" value="3500000000"/>
      <newznab:attr name="grabs" value="40"/>
    </item>
    <item>
      <title>Some.Movie.2020.1080p.REMUX.mkv</title>
      <link>https://nzbfinder.ws/getnzb/remux.nzb</link>
      <guid>remux</guid>
      <newznab:attr name="size" value="4000000000"/>
    </item>
    <item>
      <title>Some.Movie.2020.720p.WEBRip.x264</title>
      <link>https://nzbfinder.ws/getnzb/sd.nzb</link>
      <guid>sd</guid>
      <newznab:attr name="size" value="2000000000"/>
    </item>
  </channel>
</rss>
"""


class SettingsTests(unittest.TestCase):
    def test_defaults(self):
        s = settings_from_env({})
        self.assertEqual(s["port"], 8096)
        self.assertEqual(s["nzbget_priority"], 900)
        self.assertEqual(s["max_size_bytes"], 5 * 1024 * 1024 * 1024)


class NzbFinderParseTests(unittest.TestCase):
    def test_parse_and_pick_1080_under_5gb(self):
        items = parse_newznab_items(SAMPLE_FEED)
        self.assertEqual(len(items), 4)
        best = pick_best(items, prefer_resolution="1080p", max_size=5 * 1024 * 1024 * 1024)
        self.assertIsNotNone(best)
        self.assertIn("1080p.WEB-DL", best["title"])
        self.assertNotIn("REMUX", best["title"])
        self.assertNotIn("2160p", best["title"])

    def test_reject_oversized(self):
        items = parse_newznab_items(SAMPLE_FEED)
        big = items[0]
        self.assertIsNone(score_release(big, prefer_resolution="1080p", max_size=5 * 1024**3))


class NzbGetProgressTests(unittest.TestCase):
    def test_progress_percent(self):
        group = {
            "Status": "DOWNLOADING",
            "FileSizeLo": 1000,
            "FileSizeHi": 0,
            "DownloadedSizeLo": 250,
            "DownloadedSizeHi": 0,
            "DownloadRate": 50,
            "NZBName": "x",
        }
        prog = NzbGet.progress_from_group(group)
        self.assertEqual(prog["percent"], 25)
        self.assertEqual(prog["stage"], "downloading")
        self.assertEqual(prog["etaSeconds"], 15)

    def test_history_success(self):
        outcome = NzbGet.outcome_from_history({"Status": "SUCCESS/HEALTH", "FileSizeLo": 10, "FileSizeHi": 0})
        self.assertTrue(outcome["ok"])
        self.assertEqual(outcome["stage"], "completed")


class JobStoreTests(unittest.TestCase):
    def test_dedupe_by_identity(self):
        settings = settings_from_env(
            {
                "NZBFINDER_API_KEY": "x",
                "PLEX_TOKEN": "",
                "PLEX_MOVIE_SECTION_ID": "",
            }
        )
        store = JobStore(settings)

        def fake_run(job_id):
            store._set(job_id, status="downloading", stage="downloading", message="stub")

        with mock.patch.object(store, "_run", side_effect=fake_run):
            # Bypass thread: call create but stub _run via patch on Thread... simpler to
            # inject jobs directly for dedupe test
            pass

        body = {"mediaType": "movie", "tmdbId": "42", "title": "Test"}
        job = {
            "id": "11111111-1111-1111-1111-111111111111",
            "identity": "movie:42",
            "mediaType": "movie",
            "title": "Test",
            "year": "",
            "imdbId": "",
            "tmdbId": "42",
            "tvdbId": "",
            "guid": "",
            "season": None,
            "episode": None,
            "status": "downloading",
            "stage": "downloading",
            "percent": 10,
            "etaSeconds": 60,
            "message": "go",
            "nzbgetId": 9,
            "releaseTitle": "x",
            "error": None,
            "createdAt": 0,
            "updatedAt": 0,
            "lastSeen": 0,
        }
        store._jobs[job["id"]] = job
        again = store.create(body)
        self.assertEqual(again["id"], job["id"])

    def test_tv_requires_episode(self):
        store = JobStore(settings_from_env({"NZBFINDER_API_KEY": "x"}))
        with self.assertRaises(ValueError):
            store.create({"mediaType": "show", "title": "X", "tmdbId": "1"})


if __name__ == "__main__":
    unittest.main()
