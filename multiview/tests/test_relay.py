import base64
import unittest

from multiview import feedurl
from multiview.feedurl import Upstream, encode_proxy_payload, parse_feed_url, rewrite_manifest, unwrap_goat
from multiview.hls import choose_variant, filter_master, parse_master
from multiview.ingest import build_command
from multiview.relay import Relay, source_for

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
        self.assertEqual(
            encode_proxy_payload("https://cdn.example/live/index.m3u8?t=1", "https://embed.example/",
                                 {"cookie": "a=b"}, "https://embed.example/watch/1", True),
            "eyJ1IjoiaHR0cHM6Ly9jZG4uZXhhbXBsZS9saXZlL2luZGV4Lm0zdTg/dD0xIiwiciI6Imh0dHBzOi8vZW1iZWQuZXhh"
            "bXBsZS8iLCJlIjoiaHR0cHM6Ly9lbWJlZC5leGFtcGxlL3dhdGNoLzEiLCJkIjoxLCJoIjp7ImNvb2tpZSI6ImE9YiJ9fQ==",
        )

    def test_proxy_urls_decode_to_the_upstream_even_with_slashes_in_the_payload(self):
        url = proxy_url("https://cdn.example/live/index.m3u8?t=1", headers={"cookie": "a=b"},
                        embed="https://embed.example/watch/1", direct_ok=True)
        upstream = parse_feed_url(url)
        self.assertEqual(upstream.url, "https://cdn.example/live/index.m3u8?t=1")
        self.assertEqual(upstream.headers, {"cookie": "a=b"})

    def test_legacy_and_plain_urls(self):
        legacy = f"{PROXY}/proxy/" + base64.b64encode(b"https://cdn.example/x.m3u8").decode()
        upstream = parse_feed_url(legacy)
        self.assertEqual(upstream.url, "https://cdn.example/x.m3u8")
        plain = parse_feed_url("https://tv.example/live.m3u8")
        self.assertEqual(plain.url, "https://tv.example/live.m3u8")

    def test_goat_png_wrapper_is_stripped(self):
        ts = b"\x47" + bytes(187)
        wrapped = feedurl.PNG_SIGNATURE + b"\x00\x00\x00\x00IHDRxxxx" + b"\x00\x00\x00\x00IEND\xae\x42\x60\x82" + ts
        self.assertEqual(unwrap_goat(wrapped), ts)

    def test_goat_webp_wrapper_is_stripped(self):
        # Tiny VP8L chunk, then MPEG-TS — same shape as the TikTok CDN segments
        ts = b"\x47" + bytes(187) + b"\x47" + bytes(187) + b"\x47" + bytes(187)
        vp8l = b"VP8L" + (4).to_bytes(4, "little") + b"\x2f\x00\x00\x00"
        riff_payload = b"WEBP" + vp8l + ts
        wrapped = b"RIFF" + (len(riff_payload)).to_bytes(4, "little") + riff_payload
        self.assertEqual(unwrap_goat(wrapped), ts)

    def test_rewrite_keeps_context_and_points_everything_local(self):
        context = parse_feed_url(proxy_url("https://cdn.example/live/index.m3u8", headers={"cookie": "a=b"},
                                           direct_ok=True))
        seen = []
        text = rewrite_manifest(MEDIA, "https://cdn.example/live/index.m3u8", context,
                                lambda u, m: seen.append((u, m)) or f"local{len(seen)}")
        self.assertEqual([u.url for u, _ in seen], [
            "https://cdn.example/live/key.bin",
            "https://cdn.example/live/seg7.ts",
            "https://other.cdn/seg8.ts?sig=abc",
        ])


class HlsTests(unittest.TestCase):
    def test_variant_choice(self):
        variants = parse_master(MASTER, "https://cdn.example/m.m3u8")
        self.assertEqual(choose_variant(variants, 720)["height"], 720)

    def test_master_is_cut_to_one_variant_and_its_default_audio(self):
        text = filter_master(MASTER, 720)
        self.assertEqual(text.count("#EXT-X-STREAM-INF"), 1)
        self.assertIn("mid/index.m3u8", text)


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

    def test_proxy_feed_url_is_unwrapped_and_fetched_from_the_cdn(self):
        # d=0 payloads used to go to the proxy; they must hit the CDN themselves
        feed = proxy_url("https://cdn.example/live/index.m3u8")
        relay, fetch = self.make({"https://cdn.example/live/index.m3u8": (200, MEDIA.encode())})
        _, body = relay.handle(self.token(source_for({"url": feed}, relay)))
        self.assertEqual([url for url, _ in fetch.calls], ["https://cdn.example/live/index.m3u8"])
        self.assertNotIn(feed, [url for url, _ in fetch.calls])
        self.assertEqual(fetch.calls[0][1]["Referer"], "https://embed.example/")
        self.assertEqual(relay.snapshot()["manifest_direct"], 1)
        self.assertNotIn("manifest_proxy", relay.snapshot())

    def test_never_fetches_the_roku_feed_proxy(self):
        feed = proxy_url("https://cdn.example/live/index.m3u8", direct_ok=True)
        relay, fetch = self.make({
            "https://cdn.example/live/index.m3u8": (403, b""),
            feed: (200, MEDIA.encode()),
        })
        with self.assertRaises(Exception):
            relay.handle(self.token(source_for({"url": feed}, relay)))
        self.assertEqual([url for url, _ in fetch.calls], ["https://cdn.example/live/index.m3u8"])

    def test_top_level_master_is_resolved_to_its_media_playlist(self):
        relay, fetch = self.make({
            "https://tv.example/m.m3u8": (200, MASTER.encode()),
            "https://tv.example/mid/index.m3u8": (200, MEDIA.encode()),
        })
        _, body = relay.handle(self.token(source_for({"url": "https://tv.example/m.m3u8"}, relay)))
        self.assertNotIn("#EXT-X-STREAM-INF", body.decode())
        self.assertEqual(relay.snapshot()["manifest_resolved"], 1)

    def test_manifest_cache_avoids_a_second_cdn_hit(self):
        relay, fetch = self.make({"https://cdn.example/live/index.m3u8": (200, MEDIA.encode())})
        token = self.token(source_for({"url": "https://cdn.example/live/index.m3u8"}, relay))
        relay.handle(token)
        relay.handle(token)
        self.assertEqual(len(fetch.calls), 1)
        self.assertEqual(relay.snapshot().get("manifest_cache"), 1)

    def test_segment_cache_and_unwrap(self):
        seg = Upstream(url="https://cdn.example/seg7.ts", referer="https://embed.example/")
        wrapped = feedurl.PNG_SIGNATURE + b"IEND\x00\x00\x00\x00" + b"\x47tsdata"
        relay, fetch = self.make({seg.url: (200, wrapped)})
        self.assertEqual(relay.segment(seg), b"\x47tsdata")
        self.assertEqual(relay.segment(seg), b"\x47tsdata")
        self.assertEqual(len(fetch.calls), 1)
        self.assertEqual(relay.snapshot()["segment_cache"], 1)

    def test_soft_blocked_segment_fails_without_calling_the_proxy(self):
        seg = Upstream(url="https://cdn.example/seg7.ts",
                       proxy_url=proxy_url("https://cdn.example/seg7.ts"))
        junk = b"Forbidden: enable cookies to continue watching"
        relay, fetch = self.make({
            seg.url: (200, junk),
            seg.proxy_url: (200, b"\x47" + bytes(187)),
        })
        with self.assertRaises(Exception):
            relay.segment(seg)
        self.assertEqual([url for url, _ in fetch.calls], [seg.url])

    def test_html_error_pages_are_not_segments(self):
        seg = Upstream(url="https://cdn.example/seg7.ts")
        relay, _ = self.make({seg.url: (200, b"<!DOCTYPE html><html>blocked</html>")})
        with self.assertRaises(Exception):
            relay.segment(seg)

    def test_tokens_are_stable_across_rewrites(self):
        relay, _ = self.make({})
        up = Upstream(url="https://x/a.ts", referer="r", headers={"cookie": "c"})
        a = relay.url_for(up, "s")
        b = relay.url_for(up, "s")
        self.assertEqual(a, b)


class IngestCommandTests(unittest.TestCase):
    def test_audio_goes_to_its_own_pipe_and_can_be_left_out(self):
        cmd = build_command("ffmpeg", "http://127.0.0.1:1/r/x.m3u8", 7, 30)
        self.assertIn("pipe:7", cmd)
        self.assertNotIn("-re", cmd)


if __name__ == "__main__":
    unittest.main()
