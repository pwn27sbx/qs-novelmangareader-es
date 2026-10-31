"""Regression probes for the QSNMR follow-ups.

  U1 = QSNMR-01 (ManhwaWeb page shape), U2 = QSNMR-04 (canary trust),
  U3 = QSNMR-05 (reporter edges), U4 = QSNMR-02 (image Referer).

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import error_report  # noqa: E402
import manga_chain  # noqa: E402
import manga_server  # noqa: E402
import manhwaweb_source  # noqa: E402
import source_canary  # noqa: E402

WEBP = b"RIFF" + (2048).to_bytes(4, "little") + b"WEBPVP8 " + b"\x00" * 2048


class U1ManhwawebPagesTest(unittest.TestCase):
    """QSNMR-01: every source answers {page, img}; the reader reads p.img."""

    def test_map_pages_returns_page_and_img_dicts(self):
        pages = manhwaweb_source.map_pages({"chapter": {"img": ["a.webp", "b.webp"]}})
        self.assertEqual([p["page"] for p in pages], [1, 2])
        for page in pages:
            self.assertTrue(page["img"].startswith("http://127.0.0.1:5150/image?url="))

    def test_an_empty_chapter_is_still_an_empty_list(self):
        self.assertEqual(manhwaweb_source.map_pages({"chapter": {"img": []}}), [])

    def test_the_chain_keeps_the_shared_shape_for_a_manhwaweb_chapter(self):
        old_modules = manga_chain._MODULES
        manhwaweb_source.clear_cache()
        original_get = manhwaweb_source._get_json
        manga_chain._MODULES = {**old_modules, "manhwaweb": manhwaweb_source}
        manhwaweb_source._get_json = lambda path: {"chapter": {"img": ["https://img1mw.xyz/a.webp"]}}
        try:
            pages = manga_chain.pages("manhwaweb:glory_hole_1679782381480-151.5_01")
        finally:
            manhwaweb_source._get_json = original_get
            manhwaweb_source.clear_cache()
            manga_chain._MODULES = old_modules
        self.assertEqual(pages[0]["page"], 1)
        self.assertTrue(pages[0]["img"].startswith("http://127.0.0.1:5150/image?url="))


class U2CanaryRetryTest(unittest.TestCase):
    """QSNMR-04(a): one transient fetch must not mark the source broken."""

    def test_one_transient_failure_is_retried_then_reported_ok(self):
        calls = []

        def flaky(url):
            calls.append(url)
            if len(calls) == 1:
                raise TimeoutError("transient")
            return WEBP

        problems = source_canary.check_image("https://cdn.example/x.webp", flaky,
                                             sleep=lambda seconds: None)
        self.assertEqual(problems, [])
        self.assertEqual(len(calls), 2)

    def test_two_failures_are_still_a_problem(self):
        def broken(url):
            raise TimeoutError("down")

        problems = source_canary.check_image("https://cdn.example/x.webp", broken,
                                             sleep=lambda seconds: None)
        self.assertEqual(len(problems), 1)
        self.assertIn("TimeoutError", problems[0])


class U2CanaryFailFlagTest(unittest.TestCase):
    """QSNMR-04(b): --fail must not run the probes (README: 'no consulta nada')."""

    def test_fail_does_not_call_run(self):
        called = []
        original = source_canary.run
        source_canary.run = lambda *args, **kwargs: called.append(1) or (["ok   x"], 0)
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out):
                code = source_canary.main(["--fail", "zonatmo", "--no-report",
                                           "--env-file", os.devnull])
        finally:
            source_canary.run = original
        self.assertEqual(code, 1)
        self.assertEqual(called, [])
        self.assertIn("FAIL zonatmo: forced failure", out.getvalue())


class U3DsnSchemeTest(unittest.TestCase):
    """QSNMR-05.1: http is only for loopback; a public host must not leak."""

    def test_plain_http_to_a_public_host_is_refused_or_upgraded(self):
        parsed = error_report.parse_dsn("http://key@sentry.example.com/7")
        self.assertTrue(parsed is None or parsed[0].startswith("https://"), parsed)

    def test_plain_http_to_loopback_still_works(self):
        for host in ("localhost:9000", "127.0.0.1:9000", "[::1]:9000"):
            self.assertIsNotNone(error_report.parse_dsn(f"http://key@{host}/9"), host)


class U3ScrubTest(unittest.TestCase):
    """QSNMR-05.2: fragment and scheme-relative URLs must lose their secrets."""

    def test_a_fragment_is_cut(self):
        cleaned = error_report.scrub("GET https://x/y#access_token=SECRET failed")
        self.assertNotIn("SECRET", cleaned)

    def test_a_scheme_relative_url_loses_its_query(self):
        cleaned = error_report.scrub("GET //cdn.example/x?q=solo+leveling failed")
        self.assertNotIn("solo+leveling", cleaned)


class U3BackoffTest(unittest.TestCase):
    """QSNMR-05.3: a failed delivery must not be retried on every error."""

    def setUp(self):
        error_report._sent.clear()
        failed = getattr(error_report, "_failed", None)
        if failed is not None:
            failed.clear()

    def test_two_failures_produce_one_post(self):
        posts = []

        def failing(url, payload):
            posts.append(url)
            return False

        for now in (1000, 1001):
            error_report.report(RuntimeError("x"), "zonatmo", "info",
                                dsn="https://k@o1.ingest.sentry.io/7",
                                sink=failing, now=now)
        self.assertEqual(len(posts), 1)

    def test_the_backoff_expires(self):
        posts = []

        def failing(url, payload):
            posts.append(url)
            return False

        for now in (1000, 1000 + 301):
            error_report.report(RuntimeError("x"), "zonatmo", "hot",
                                dsn="https://k@o1.ingest.sentry.io/7",
                                sink=failing, now=now)
        self.assertEqual(len(posts), 2)

    def test_a_successful_delivery_keeps_the_one_hour_ttl(self):
        posts = []

        def ok(url, payload):
            posts.append(url)
            return True

        for now in (1000, 1001, 1000 + error_report.DEDUPE_TTL):
            error_report.report(RuntimeError("x"), "zonatmo", "pages",
                                dsn="https://k@o1.ingest.sentry.io/7",
                                sink=ok, now=now)
        self.assertEqual(len(posts), 2)


class U4RefererTest(unittest.TestCase):
    """QSNMR-02: MangaDex nodes need the site Referer; lookalikes must not."""

    def test_a_mangadex_node_gets_the_site_referer(self):
        headers = manga_server.image_headers(
            "https://cmdxd98sb0x3yprd.mangadex.network/data-saver/h/1.webp")
        self.assertEqual(headers.get("Referer"), "https://mangadex.org/")

    def test_a_lookalike_host_gets_none(self):
        for url in ("https://evilmangadex.network/x.jpg",
                    "https://notmangadex.network.evil.example/x.jpg"):
            self.assertNotIn("Referer", manga_server.image_headers(url), url)

    def test_the_canonical_fallback_host_keeps_no_referer(self):
        self.assertNotIn("Referer",
                         manga_server.image_headers("https://uploads.mangadex.org/x.jpg"))

    def test_the_manhwaweb_referers_still_work(self):
        self.assertEqual(
            manga_server.image_headers("https://img1mw.xyz/x.jpg").get("Referer"),
            "https://manhwaweb.com/")


if __name__ == "__main__":
    unittest.main()
