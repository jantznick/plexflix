import base64
import os
import unittest

from multiview.feedurl import encode_proxy_payload, parse_feed_url
from multiview.relay import Relay, rewrite_to_local_proxy, source_for

PROXY = "http://192.168.1.50:8787"


def proxy_url(url, referer="https://embed.example/", headers=None, embed="", direct_ok=False):
    return f"{PROXY}/proxy/" + encode_proxy_payload(url, referer, headers, embed, direct_ok)


class FakeFetch:
    def __init__(self, routes):
        self.routes = routes
        self.calls = []

    def __call__(self, url, timeout):
        self.calls.append(url)
        result = self.routes.get(url)
        if result is None:
            return 404, b"", ""
        status, body = result
        return status, body, "application/vnd.apple.mpegurl"


class VendoredProxyRoutingTests(unittest.TestCase):
    def test_proxy_payload_urls_are_rewritten_to_the_in_container_proxy(self):
        feed = proxy_url("https://cdn.example/live/index.m3u8", direct_ok=True)
        os.environ["MULTIVIEW_PROXY_URL"] = "http://127.0.0.1:18787"
        self.assertEqual(
            rewrite_to_local_proxy(feed),
            "http://127.0.0.1:18787/proxy/" + feed.split("/proxy/", 1)[1],
        )

    def test_cache_front_rewrites_playlist_proxy_urls_and_avoids_second_hit(self):
        os.environ["MULTIVIEW_PROXY_URL"] = "http://127.0.0.1:18787"
        feed = rewrite_to_local_proxy(proxy_url("https://cdn.example/live/index.m3u8"))
        seg = "http://127.0.0.1:18787/proxy/aaa"
        playlist = f"#EXTM3U\n#EXTINF:4,\n{seg}\n"
        fetch = FakeFetch({feed: (200, playlist.encode())})
        relay = Relay(fetch=fetch)
        relay.port = 9999
        local = source_for({"url": proxy_url("https://cdn.example/live/index.m3u8")}, relay)
        token = local.split("/r/", 1)[1].rsplit(".", 1)[0]
        _, body = relay.handle(token)
        text = body.decode()
        self.assertIn("http://127.0.0.1:9999/r/", text)
        self.assertNotIn("127.0.0.1:18787", text)
        relay.handle(token)
        self.assertEqual(len(fetch.calls), 1)
        self.assertEqual(relay.snapshot().get("manifest_cache"), 1)

    def test_payload_still_decodes(self):
        url = proxy_url("https://cdn.example/live/index.m3u8?t=1", headers={"cookie": "a=b"},
                        embed="https://embed.example/watch/1", direct_ok=True)
        upstream = parse_feed_url(url)
        self.assertEqual(upstream.url, "https://cdn.example/live/index.m3u8?t=1")
        legacy = f"{PROXY}/proxy/" + base64.b64encode(b"https://cdn.example/x.m3u8").decode()
        self.assertEqual(parse_feed_url(legacy).url, "https://cdn.example/x.m3u8")


if __name__ == "__main__":
    unittest.main()
