import base64
import os
import unittest

from multiview.feedurl import encode_proxy_payload, parse_feed_url
from multiview.relay import Relay, rewrite_to_local_proxy, source_for

PROXY = "http://192.168.1.50:8787"


def proxy_url(url, referer="https://embed.example/", headers=None, embed="", direct_ok=False):
    return f"{PROXY}/proxy/" + encode_proxy_payload(url, referer, headers, embed, direct_ok)


class VendoredProxyRoutingTests(unittest.TestCase):
    def test_proxy_payload_urls_are_rewritten_to_the_in_container_proxy(self):
        feed = proxy_url("https://cdn.example/live/index.m3u8", direct_ok=True)
        os.environ["MULTIVIEW_PROXY_URL"] = "http://127.0.0.1:18787"
        self.assertEqual(
            rewrite_to_local_proxy(feed),
            "http://127.0.0.1:18787/proxy/" + feed.split("/proxy/", 1)[1],
        )
        relay = Relay()
        self.assertEqual(source_for({"url": feed}, relay), rewrite_to_local_proxy(feed))
        self.assertEqual(relay.snapshot()["via_vendored_proxy"], 1)

    def test_plain_urls_pass_through(self):
        self.assertEqual(rewrite_to_local_proxy("https://cdn.example/x.m3u8"), "https://cdn.example/x.m3u8")
        self.assertEqual(source_for({"url": "https://cdn.example/x.m3u8"}), "https://cdn.example/x.m3u8")

    def test_payload_still_decodes(self):
        url = proxy_url("https://cdn.example/live/index.m3u8?t=1", headers={"cookie": "a=b"},
                        embed="https://embed.example/watch/1", direct_ok=True)
        upstream = parse_feed_url(url)
        self.assertEqual(upstream.url, "https://cdn.example/live/index.m3u8?t=1")
        legacy = f"{PROXY}/proxy/" + base64.b64encode(b"https://cdn.example/x.m3u8").decode()
        self.assertEqual(parse_feed_url(legacy).url, "https://cdn.example/x.m3u8")


if __name__ == "__main__":
    unittest.main()
