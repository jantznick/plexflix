import base64
import json
import unittest

from multiview import feedurl, relay as relay_module
from multiview.feedurl import Upstream, encode_proxy_payload, parse_feed_url, rewrite_manifest, unwrap_goat
from multiview.hls import choose_variant, filter_master, parse_master
from multiview.ingest import build_command
from multiview.relay import Relay, decode_token, source_for

PROXY = "http://192.168.1.50:8787"
MASTER = """#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="English",DEFAULT=YES,URI="audio/en.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aud",NAME="Spanish",DEFAULT=NO,URI="audio/es.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,AUDIO="aud"
hi/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1280x720,AUDIO="aud",SUBTITLES="subs"
mid/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=640x360
lo/index.m3u8
"""
MEDIA = """#EXTM3U
#EXT-X-TARGETDURATION:4
#EXT-X-MEDIA-SEQUENCE:7
#EXT-X-KEY:METHOD=AES-128,URI="key.bin"
#EXTINF:4.0,
seg7.ts
#EXTINF:4.0,
https://other.cdn/seg8.ts?sig=abc
"""


def proxy_url(url, referer="https://embed.example/", headers=None, embed="", direct_ok=False):
    return f"{PROXY}/proxy/" + encode_proxy_payload(url, referer, headers, embed, direct_ok)


class FeedUrlTests(unittest.TestCase):
    def test_payload_bytes_match_the_proxy(self):
        # Reference values from roku-feed's encodeProxyPayload()
        self.assertEqual(
            encode_proxy_payload("https://cdn.example/live/index.m3u8?t=1", "https://embed.example/",
                                 {"cookie": "a=b"}, "https://embed.example/watch/1", True),
            "eyJ1IjoiaHR0cHM6Ly9jZG4uZXhhbXBsZS9saXZlL2luZGV4Lm0zdTg/dD0xIiwiciI6Imh0dHBzOi8vZW1iZWQuZXhh"
            "bXBsZS8iLCJlIjoiaHR0cHM6Ly9lbWJlZC5leGFtcGxlL3dhdGNoLzEiLCJkIjoxLCJoIjp7ImNvb2tpZSI6ImE9YiJ9fQ==",
        )
        self.assertEqual(
            encode_proxy_payload("https://cdn.example/seg-1.ts", "https://embed.example/"),
            "eyJ1IjoiaHR0cHM6Ly9jZG4uZXhhbXBsZS9zZWctMS50cyIsInIiOiJodHRwczovL2VtYmVkLmV4YW1wbGUvIn0=",
        )

    def test_proxy_urls_decode_to_the_upstream_even_with_slashes_in_the_payload(self):
        url = proxy_url("https://cdn.example/live/index.m3u8?t=1", headers={"cookie": "a=b"},
                        embed="https://embed.example/watch/1", direct_ok=True)
        self.assertIn("/", url.split("/proxy/", 1)[1])
        upstream = parse_feed_url(url)
        self.assertEqual(upstream.url, "https://cdn.example/live/index.m3u8?t=1")
        self.assertEqual(upstream.referer, "https://embed.example/")
        self.assertEqual(upstream.headers, {"cookie": "a=b"})
        self.assertTrue(upstream.direct_ok)
        self.assertEqual(upstream.proxy_url, url)

    def test_legacy_and_plain_urls(self):
        legacy = f"{PROXY}/proxy/" + base64.b64encode(b"https://cdn.example/x.m3u8").decode()
        upstream = parse_feed_url(legacy)
        self.assertEqual(upstream.url, "https://cdn.example/x.m3u8")
        self.assertEqual(upstream.referer, feedurl.DEFAULT_REFERER)
        self.assertFalse(upstream.direct_ok)
        plain = parse_feed_url("https://tv.example/live.m3u8")
        self.assertEqual((plain.url, plain.proxy_url, plain.direct_ok), ("https://tv.example/live.m3u8", "", True))

    def test_header_sets_mirror_the_proxy(self):
        headers = feedurl.manifest_headers("https://embed.example/page", {"Cookie": "a=b"})
        self.assertEqual(headers["Origin"], "https://embed.example")
        self.assertEqual(headers["cookie"], "a=b")
        self.assertIn("Chrome/148", headers["User-Agent"])
        seg = feedurl.segment_headers("https://embed.example/page", {"cookie": "a=b", "accept": "x"})
        self.assertEqual(set(seg), {"User-Agent", "Referer", "Origin", "Cookie"})

    def test_goat_png_wrapper_is_stripped(self):
        ts = b"\x47" + bytes(187)
        wrapped = feedurl.PNG_SIGNATURE + b"\x00\x00\x00\x00IHDRxxxx" + b"\x00\x00\x00\x00IEND\xae\x42\x60\x82" + ts
        self.assertEqual(unwrap_goat(wrapped), ts)
        self.assertEqual(unwrap_goat(ts), ts)

    def test_rewrite_keeps_context_and_points_everything_local(self):
        context = parse_feed_url(proxy_url("https://cdn.example/live/index.m3u8", headers={"cookie": "a=b"},
                                           direct_ok=True))
        seen = []

        def local(upstream, is_manifest):
            seen.append((upstream, is_manifest))
            return f"local{len(seen)}"

        text = rewrite_manifest(MEDIA + "#EXT-X-PROGRAM-DATE-TIME:x\nnot a segment line\n",
                                "https://cdn.example/live/index.m3u8", context, local)
        self.assertIn('URI="local1"', text)
        self.assertNotIn("not a segment line", text)
        self.assertEqual([u.url for u, _ in seen], [
            "https://cdn.example/live/key.bin",
            "https://cdn.example/live/seg7.ts",
            "https://other.cdn/seg8.ts?sig=abc",
        ])
        segment = seen[1][0]
        self.assertEqual(segment.headers, {"cookie": "a=b"})
        self.assertEqual(parse_feed_url(segment.proxy_url).url, "https://cdn.example/live/seg7.ts")

    def test_segments_the_proxy_already_rewrote_are_unwrapped(self):
        context = parse_feed_url(proxy_url("https://cdn.example/live/index.m3u8"))
        segment = proxy_url("https://strmd.st/seg1.ts")
        seen = []
        rewrite_manifest(f"#EXTM3U\n#EXTINF:4,\n{segment}\n", context.proxy_url, context,
                         lambda u, m: seen.append(u) or "x")
        self.assertEqual(seen[0].url, "https://strmd.st/seg1.ts")
        self.assertEqual(seen[0].proxy_url, segment)


class HlsTests(unittest.TestCase):
    def test_variant_choice(self):
        variants = parse_master(MASTER, "https://cdn.example/m.m3u8")
        self.assertEqual(variants[1]["url"], "https://cdn.example/mid/index.m3u8")
        self.assertEqual(choose_variant(variants, 270)["height"], 360)
        self.assertEqual(choose_variant(variants, 720)["height"], 720)
        self.assertEqual(choose_variant(variants, 2160)["height"], 1080)

    def test_master_is_cut_to_one_variant_and_its_default_audio(self):
        text = filter_master(MASTER, 720)
        self.assertEqual(text.count("#EXT-X-STREAM-INF"), 1)
        self.assertIn("mid/index.m3u8", text)
        self.assertNotIn("hi/index.m3u8", text)
        self.assertNotIn("SUBTITLES", text)
        self.assertIn("audio/en.m3u8", text)
        self.assertNotIn("audio/es.m3u8", text)
        lo = filter_master(MASTER, 360)
        self.assertNotIn("EXT-X-MEDIA", lo)


class FakeFetch:
    def __init__(self, routes):
        self.routes = routes
        self.calls = []

    def __call__(self, url, headers, timeout):
        self.calls.append((url, headers))
        result = self.routes.get(url)
        if isinstance(result, Exception):
            raise result
        if result is None:
            return 404, b"", url
        status, body = result
        return status, body, url


class RelayTests(unittest.TestCase):
    def make(self, routes):
        fetch = FakeFetch(routes)
        self.now = [0.0]
        relay = Relay(fetch=fetch, clock=lambda: self.now[0])
        relay.port = 9999
        return relay, fetch

    def token(self, url):
        return url.split("/r/", 1)[1].rsplit(".", 1)[0]

    def test_direct_payload_skips_the_proxy_for_manifests(self):
        feed = proxy_url("https://cdn.example/live/index.m3u8", direct_ok=True)
        relay, fetch = self.make({"https://cdn.example/live/index.m3u8": (200, MEDIA.encode())})
        _, body = relay.handle(self.token(source_for({"url": feed}, relay)))
        self.assertEqual([url for url, _ in fetch.calls], ["https://cdn.example/live/index.m3u8"])
        self.assertEqual(fetch.calls[0][1]["Referer"], "https://embed.example/")
        lines = [line for line in body.decode().splitlines() if line.startswith("http")]
        self.assertTrue(all(line.startswith("http://127.0.0.1:9999/r/") for line in lines))
        self.assertTrue(lines[0].endswith(".ts"))
        self.assertEqual(relay.snapshot(), {"manifest_direct": 1})

    def test_browser_only_payload_gets_its_manifest_from_the_proxy(self):
        feed = proxy_url("https://cdn.example/live/index.m3u8")
        proxied = f"#EXTM3U\n#EXTINF:4,\n{proxy_url('https://cdn.example/live/seg7.ts')}\n"
        relay, fetch = self.make({feed: (200, proxied.encode())})
        _, body = relay.handle(self.token(source_for({"url": feed}, relay)))
        self.assertEqual([url for url, _ in fetch.calls], [feed])
        segment_url = [line for line in body.decode().splitlines() if line.startswith("http")][0]
        upstream, kind = decode_token(self.token(segment_url))
        self.assertEqual((upstream.url, kind), ("https://cdn.example/live/seg7.ts", "s"))

    def test_failed_direct_manifest_falls_back_to_the_proxy(self):
        feed = proxy_url("https://cdn.example/live/index.m3u8", direct_ok=True)
        relay, fetch = self.make({"https://cdn.example/live/index.m3u8": (403, b""), feed: (200, MEDIA.encode())})
        relay.handle(self.token(source_for({"url": feed}, relay)))
        self.assertEqual(relay.snapshot(), {"manifest_proxy": 1})

    def test_top_level_master_is_filtered(self):
        relay, fetch = self.make({"https://tv.example/m.m3u8": (200, MASTER.encode())})
        _, body = relay.handle(self.token(source_for({"url": "https://tv.example/m.m3u8"}, relay)))
        self.assertEqual(body.decode().count("#EXT-X-STREAM-INF"), 1)

    def test_segments_go_direct_first_and_unwrap(self):
        seg = Upstream(url="https://cdn.example/seg7.ts", referer="https://embed.example/",
                       proxy_url=proxy_url("https://cdn.example/seg7.ts"))
        wrapped = feedurl.PNG_SIGNATURE + b"IEND\x00\x00\x00\x00" + b"\x47tsdata"
        relay, fetch = self.make({seg.url: (200, wrapped)})
        self.assertEqual(relay.segment(seg), b"\x47tsdata")
        self.assertEqual(fetch.calls[0][1]["Origin"], "https://embed.example")
        self.assertEqual(relay.snapshot(), {"segment_direct": 1})

    def test_host_that_keeps_failing_direct_goes_proxy_first_for_a_while(self):
        seg = Upstream(url="https://cdn.example/seg7.ts", proxy_url=proxy_url("https://cdn.example/seg7.ts"))
        relay, fetch = self.make({seg.url: (403, b""), seg.proxy_url: (200, b"\x47ok")})
        for _ in range(relay_module.DIRECT_FAILURES_BEFORE_PROXY_FIRST):
            self.assertEqual(relay.segment(seg), b"\x47ok")
        fetch.calls.clear()
        relay.segment(seg)
        self.assertEqual([url for url, _ in fetch.calls], [seg.proxy_url])
        self.now[0] = relay_module.PROXY_FIRST_SECONDS + 1
        fetch.calls.clear()
        relay.segment(seg)
        self.assertEqual(fetch.calls[0][0], seg.url)

    def test_html_error_pages_are_not_segments(self):
        seg = Upstream(url="https://cdn.example/seg7.ts")
        relay, _ = self.make({seg.url: (200, b"<!DOCTYPE html><html>blocked</html>")})
        with self.assertRaises(relay_module.RelayError):
            relay.segment(seg)

    def test_tokens_round_trip(self):
        relay, _ = self.make({})
        up = Upstream(url="https://x/a.m3u8?b=1", referer="r", headers={"cookie": "c"}, proxy_url="p")
        url = relay.url_for(up, "feed")
        self.assertTrue(url.endswith(".m3u8"))
        back, kind = decode_token(self.token(url))
        self.assertEqual((back, kind), (up, "feed"))
        self.assertEqual(decode_token("not-a-token"), (None, None))
        self.assertEqual(json.loads(base64.urlsafe_b64decode(self.token(url) + "==="))["k"], "feed")


class IngestCommandTests(unittest.TestCase):
    def test_audio_goes_to_its_own_pipe_and_can_be_left_out(self):
        cmd = build_command("ffmpeg", "http://127.0.0.1:1/r/x.m3u8", 7, 30)
        self.assertIn("pipe:7", cmd)
        self.assertIn("-rw_timeout", cmd)
        self.assertEqual(cmd[cmd.index("-live_start_index") + 1], "-3")
        silent = build_command("ffmpeg", "/tmp/feed.m3u8", None, 30)
        self.assertNotIn("0:a:0", silent)
        self.assertNotIn("-rw_timeout", silent)


if __name__ == "__main__":
    unittest.main()
