"""Tests for scripts/source_canary.py (contract canary, no network).

The canary exists because a source can break WITHOUT raising: zonatmo.net
answered HTTP 200 with an empty items list on 2026-10-27 and the reader showed
no chapters. These tests pin the checks with fake modules and a fake transport.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import source_canary  # noqa: E402

WEBP = b"RIFF" + (2048).to_bytes(4, "little") + b"WEBPVP8 " + b"\x00" * 2048


class FakeSource:
    def __init__(self, results=True, title="Solo Leveling", chapters=True, pages=True):
        self.results = results
        self.title = title
        self.chapters = chapters
        self.pages_ok = pages
        self.asked = []

    def search(self, query, mtype=None, offset=0, sort="Best Match"):
        self.asked.append(("search", query))
        items = [{"id": "S-1", "title": self.title}] if self.results else []
        return {"results": items, "hasMore": False, "nextOffset": 0}

    def info(self, manga_id):
        self.asked.append(("info", manga_id))
        chapters = [{"id": "CH-1", "chapter": "1"}] if self.chapters else []
        return {"id": manga_id, "title": self.title, "chapters": chapters}

    def pages(self, chapter_id):
        self.asked.append(("pages", chapter_id))
        if not self.pages_ok:
            return []
        return [{"page": 1, "img": "http://127.0.0.1:5150/image?url=https%3A%2F%2Fcdn.example%2F1.webp"}]


def ok_fetch(url):
    return WEBP


class CheckSourceTest(unittest.TestCase):
    def check(self, module, fetch=ok_fetch):
        return source_canary.check_source("zonatmo", module, fetch)

    def test_a_healthy_source_reports_nothing(self):
        self.assertEqual(self.check(FakeSource()), [])

    def test_an_empty_search_is_a_problem(self):
        problems = self.check(FakeSource(results=False))
        self.assertTrue(any("search" in p for p in problems), problems)

    def test_a_source_without_chapters_is_a_problem(self):
        problems = self.check(FakeSource(chapters=False))
        self.assertTrue(any("chapters" in p for p in problems), problems)

    def test_a_source_without_pages_is_a_problem(self):
        problems = self.check(FakeSource(pages=False))
        self.assertTrue(any("pages" in p for p in problems), problems)

    def test_a_source_that_raises_is_a_problem_not_a_crash(self):
        class Dead(FakeSource):
            def search(self, *args, **kwargs):
                raise OSError("domain dead")

        problems = self.check(Dead())
        self.assertTrue(any("search" in p for p in problems), problems)

    def test_html_served_as_an_image_is_a_problem(self):
        problems = self.check(FakeSource(), lambda url: b"<!doctype html><html>blocked</html>")
        self.assertTrue(any("image" in p for p in problems), problems)

    def test_a_placeholder_sized_image_is_a_problem(self):
        problems = self.check(FakeSource(), lambda url: WEBP[:64])
        self.assertTrue(any("small" in p for p in problems), problems)


class ConfigTest(unittest.TestCase):
    def test_every_source_has_its_own_probe_query(self):
        # A single global query marks MangaDex/InManga as broken forever:
        # "solo leveling" has no Spanish translation on either.
        for name in source_canary.SOURCES:
            self.assertTrue(source_canary.PROBE_QUERY.get(name), name)

    def test_a_query_that_returns_nothing_is_still_a_problem(self):
        problems, _, _ = source_canary.probe(FakeSource(results=False), ok_fetch, "naruto")
        self.assertTrue(any("search" in p for p in problems), problems)


class RefererTest(unittest.TestCase):
    def test_a_mangadex_node_needs_the_site_referer(self):
        self.assertEqual(source_canary.referer_for("cmdxd98sb0x3yprd.mangadex.network"),
                         "https://mangadex.org/")

    def test_a_manhwaweb_image_needs_its_own_referer(self):
        self.assertEqual(source_canary.referer_for("img2mw.xyz"), "https://manhwaweb.com/")

    def test_a_plain_host_needs_none(self):
        self.assertEqual(source_canary.referer_for("cdn.zonatmo.to"), "")


class PageImageTest(unittest.TestCase):
    def test_a_dict_page_uses_its_img_field(self):
        self.assertEqual(
            source_canary.page_image({"page": 1, "img": "https://cdn/x.webp"}),
            "https://cdn/x.webp")

    def test_a_bare_url_page_is_accepted(self):
        # manhwaweb answers a list of URL strings instead of page objects.
        self.assertEqual(source_canary.page_image("https://cdn/y.webp"), "https://cdn/y.webp")

    def test_anything_else_is_empty(self):
        self.assertEqual(source_canary.page_image(None), "")
        self.assertEqual(source_canary.page_image({"page": 1}), "")


class ImageOriginTest(unittest.TestCase):
    def test_the_local_proxy_is_unwrapped(self):
        proxied = "http://127.0.0.1:5150/image?url=https%3A%2F%2Fcdn.example%2F1.webp"
        self.assertEqual(source_canary.image_origin(proxied), "https://cdn.example/1.webp")

    def test_a_plain_url_is_kept(self):
        self.assertEqual(source_canary.image_origin("https://cdn.example/2.jpg"), "https://cdn.example/2.jpg")

    def test_empty_is_empty(self):
        self.assertEqual(source_canary.image_origin(""), "")


class SniffTest(unittest.TestCase):
    def test_webp(self):
        self.assertEqual(source_canary.sniff_image(WEBP), "webp")

    def test_png(self):
        self.assertEqual(source_canary.sniff_image(b"\x89PNG\r\n\x1a\n" + b"\x00" * 32), "png")

    def test_jpeg(self):
        self.assertEqual(source_canary.sniff_image(b"\xff\xd8\xff\xe0" + b"\x00" * 32), "jpeg")

    def test_html_is_not_an_image(self):
        self.assertEqual(source_canary.sniff_image(b"<!doctype html>"), "")


class RunTest(unittest.TestCase):
    def test_a_healthy_run_exits_zero(self):
        lines, code = source_canary.run(["zonatmo"], {"zonatmo": FakeSource()}, ok_fetch, chain=False)
        self.assertEqual(code, 0)
        self.assertTrue(lines[0].startswith("ok"), lines)

    def test_one_broken_source_fails_the_run_and_is_named(self):
        lines, code = source_canary.run(
            ["zonatmo", "zonatmo_org"],
            {"zonatmo": FakeSource(pages=False), "zonatmo_org": FakeSource()},
            ok_fetch,
            chain=False,
        )
        self.assertEqual(code, 1)
        self.assertTrue(any(line.startswith("FAIL zonatmo:") for line in lines), lines)
        self.assertTrue(any(line.startswith("ok   zonatmo_org") for line in lines), lines)

    def test_an_unknown_source_is_reported_not_ignored(self):
        lines, code = source_canary.run(["nope"], {"zonatmo": FakeSource()}, ok_fetch, chain=False)
        self.assertEqual(code, 1)
        self.assertIn("unknown source", lines[0])


class NotifyTest(unittest.TestCase):
    def calls(self):
        made = []

        def post(url, payload, timeout=None):
            made.append((url, payload))
            return 200, b""

        return made, post

    def test_a_message_carries_the_text_and_no_mentions(self):
        made, post = self.calls()
        self.assertTrue(source_canary.notify("https://discord/hook", "hola", post))
        url, payload = made[0]
        self.assertIn("wait=true", url)
        self.assertEqual(payload["content"], "hola")
        self.assertEqual(payload["allowed_mentions"], {"parse": []})

    def test_no_webhook_means_no_request(self):
        made, post = self.calls()
        self.assertFalse(source_canary.notify("", "hola", post))
        self.assertEqual(made, [])

    def test_a_rejected_message_is_false(self):
        self.assertFalse(source_canary.notify("https://discord/hook", "hola", lambda *a: (403, b"")))


class CheckinTest(unittest.TestCase):
    def test_the_state_goes_in_the_json_body(self):
        made = []

        def post(url, payload, timeout=None):
            made.append((url, payload))
            return 202, b""

        self.assertTrue(source_canary.checkin("https://sentry/cron/x/", "ok", 1.5, post))
        url, payload = made[0]
        self.assertEqual(url, "https://sentry/cron/x/")
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["duration"], 1.5)

    def test_a_rejected_checkin_is_false(self):
        self.assertFalse(source_canary.checkin("https://sentry/cron/x/", "ok", None, lambda *a: (422, b"")))

    def test_no_url_means_no_request(self):
        called = []
        self.assertFalse(source_canary.checkin("", "ok", None, lambda *a: called.append(a)))
        self.assertEqual(called, [])


class ReportTest(unittest.TestCase):
    def test_a_healthy_run_reports_ok_and_stays_quiet_on_discord(self):
        made = []

        def post(url, payload, timeout=None):
            made.append((url, payload))
            return 202, b""

        sent, notified = source_canary.report(0, ["ok   zonatmo: x"], 1.0, "https://discord", "https://sentry", post)
        self.assertTrue(sent)
        self.assertFalse(notified)
        self.assertEqual([p["status"] for _, p in made], ["ok"])

    def test_a_broken_run_reports_error_and_names_the_source(self):
        made = []

        def post(url, payload, timeout=None):
            made.append((url, payload))
            return 202, b""

        sent, notified = source_canary.report(1, ["FAIL zonatmo: pages: no images"], 1.0,
                                              "https://discord", "https://sentry", post)
        self.assertTrue(sent)
        self.assertTrue(notified)
        statuses = [p["status"] for u, p in made if "sentry" in u]
        self.assertEqual(statuses, ["error"])
        discord = [p for u, p in made if "discord" in u]
        self.assertEqual(len(discord), 1)
        self.assertIn("zonatmo", discord[0]["content"])


class EnvFileTest(unittest.TestCase):
    def test_keys_are_read_and_comments_skipped(self):
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".env", delete=False) as handle:
            handle.write("# comentario\nQS_DISCORD_WEBHOOK=https://x\n\nQS_SENTRY_CHECKIN=https://y?=\n")
            name = handle.name
        values = source_canary.load_env_file(name)
        self.assertEqual(values["QS_DISCORD_WEBHOOK"], "https://x")
        self.assertEqual(values["QS_SENTRY_CHECKIN"], "https://y?=")
        self.assertEqual(len(values), 2)

    def test_a_missing_file_is_empty(self):
        self.assertEqual(source_canary.load_env_file("/nope/does-not-exist.env"), {})


if __name__ == "__main__":
    unittest.main()
