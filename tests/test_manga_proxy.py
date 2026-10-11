"""Tests for the manga image proxy error mapping (manga_server.proxy_image).

manga_server imports curl_cffi/requests, so these run only where one of them is
installed (the app venv); otherwise they are skipped.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

try:
    import manga_server
    HAVE_SERVER = True
except Exception:  # noqa: BLE001 — curl_cffi/requests not installed
    HAVE_SERVER = False


@unittest.skipUnless(HAVE_SERVER, "manga_server requires curl_cffi or requests")
class ProxyImageTest(unittest.TestCase):
    class FakeHandler:
        def __init__(self):
            self.errors = []

        def send_error(self, code, *a, **k):
            self.errors.append(code)

    def _with_raw_get(self, raiser):
        original = manga_server._raw_get
        manga_server._raw_get = lambda *a, **k: raiser()
        return original

    def test_upstream_404_maps_to_404(self):
        class Upstream404(Exception):
            class response:
                status_code = 404

        handler = self.FakeHandler()
        original = self._with_raw_get(lambda: (_ for _ in ()).throw(Upstream404()))
        try:
            manga_server.proxy_image(handler, "https://x/nope.jpg")
        finally:
            manga_server._raw_get = original
        self.assertEqual(handler.errors, [404])

    def test_generic_error_maps_to_502(self):
        handler = self.FakeHandler()
        original = self._with_raw_get(lambda: (_ for _ in ()).throw(RuntimeError("boom")))
        try:
            manga_server.proxy_image(handler, "https://x/nope.jpg")
        finally:
            manga_server._raw_get = original
        self.assertEqual(handler.errors, [502])


if __name__ == "__main__":
    unittest.main()
