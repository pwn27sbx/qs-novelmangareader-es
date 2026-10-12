"""Tests for scripts/zonatmo_source.py using recorded zonatmo.net fixtures.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"

Fixtures under tests/fixtures/zonatmo/ were captured from the live zonatmo.net
JSON API; the tests never touch the network.
"""

import io
import json
import os
import sys
import time
import unittest
import urllib.error
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import zonatmo_source  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "zonatmo")


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return json.load(f)


def _find(items, item_id):
    for item in items:
        if item["id"] == item_id:
            return item
    return None


class ParseListingTest(unittest.TestCase):
    def setUp(self):
        self.items = zonatmo_source.parse_listing(load("search.json"))

    def test_items(self):
        self.assertEqual(len(self.items), 2)

    def test_spanish_manhwa_item(self):
        item = _find(self.items, "solo-leveling")
        self.assertIsNotNone(item)
        self.assertEqual(item["title"], "Solo Leveling")
        self.assertEqual(item["type"], "MANHWA")
        self.assertEqual(item["status"], "Finalizado")
        self.assertEqual(item["year"], "2017")
        self.assertTrue(item["image"].startswith("http://127.0.0.1:5150/image?url="))
        self.assertIn("wp-content/uploads", urllib.parse.unquote(item["image"]))

    def test_novel_item_type(self):
        item = _find(self.items, "solo-leveling-ragnarok")
        self.assertIsNotNone(item)
        self.assertEqual(item["type"], "NOVELA")


class MapSearchTest(unittest.TestCase):
    def test_results_and_paging(self):
        page = zonatmo_source.map_search(load("search.json"), 0)
        self.assertEqual(len(page["results"]), 2)
        self.assertEqual(page["nextOffset"], 2)
        self.assertFalse(page["hasMore"])


class MapLatestTest(unittest.TestCase):
    def test_results_and_paging(self):
        page = zonatmo_source.map_latest(load("list.json"), 1)
        self.assertEqual(len(page["results"]), 12)
        self.assertTrue(page["hasMore"])
        self.assertEqual(page["nextPage"], 2)


class MapHotTest(unittest.TestCase):
    def test_returns_a_list(self):
        items = zonatmo_source.map_hot(load("list.json"))
        self.assertIsInstance(items, list)
        self.assertEqual(len(items), 12)
        self.assertEqual(items[0]["id"], "alt-account-trap")
        self.assertEqual(items[0]["title"], "Alt Account Trap")


class ParseChaptersTest(unittest.TestCase):
    def setUp(self):
        self.chapters = zonatmo_source.parse_chapters(load("chapters.json"), "solo-leveling")

    def test_chapters_are_mapped_and_sorted(self):
        self.assertEqual(len(self.chapters), 25)
        numbers = [float(c["chapter"]) for c in self.chapters]
        self.assertEqual(numbers, sorted(numbers))

    def test_first_chapter(self):
        first = self.chapters[0]
        self.assertEqual(first["id"], "solo-leveling/solo-leveling-capitulo-177")
        self.assertEqual(first["chapter"], "177")
        self.assertEqual(first["group"], "Lectorxd_com")
        self.assertTrue(first["publishAt"])


class ParseReaderTest(unittest.TestCase):
    def setUp(self):
        self.pages = zonatmo_source.parse_reader(load("reader.json"))
        jit = load("reader.json")["data"]["chapter"]["jit"]

    def test_pages_from_images(self):
        self.assertEqual(len(self.pages), 17)
        self.assertEqual(self.pages[0]["page"], 1)
        url = urllib.parse.unquote(self.pages[0]["img"])
        self.assertIn("cdn.zonatmo.to/manga/", url)
        self.assertIn("/page_0001.webp", url)
        self.assertTrue(self.pages[0]["img"].startswith("http://127.0.0.1:5150/image?url="))


class ParseInfoTest(unittest.TestCase):
    def setUp(self):
        self.info = zonatmo_source.parse_info(load("detail.json"), load("chapters.json"), "solo-leveling")

    def test_top_level(self):
        self.assertEqual(self.info["title"], "Solo Leveling")
        self.assertTrue(self.info["description"])
        self.assertEqual(self.info["status"], "Finalizado")
        self.assertIn("jang, sung-rak", self.info["authors"])
        self.assertIn("Acción", self.info["tags"])
        self.assertIn("5c2efcd42cd5e.webp", urllib.parse.unquote(self.info["image"]))

    def test_chapters(self):
        self.assertEqual(len(self.info["chapters"]), 25)
        self.assertTrue(self.info["chapters"][0]["id"].startswith("solo-leveling/"))


class TypeParamTest(unittest.TestCase):
    def test_known_types(self):
        self.assertEqual(zonatmo_source.type_param("Manga"), "14")
        self.assertEqual(zonatmo_source.type_param("Manhwa"), "87")
        self.assertEqual(zonatmo_source.type_param("Manhua"), "31")

    def test_unknown_type(self):
        self.assertIsNone(zonatmo_source.type_param("Bogus"))
        self.assertIsNone(zonatmo_source.type_param(None))


class ProxyTest(unittest.TestCase):
    def test_empty_url(self):
        self.assertEqual(zonatmo_source.proxy_url(""), "")

    def test_encoding(self):
        url = zonatmo_source.proxy_url("https://x/a b.jpg")
        self.assertIn("url=https%3A%2F%2Fx%2Fa%20b.jpg", url)


class ApiTest(unittest.TestCase):
    """The public API with a faked transport (deterministic, no network)."""

    def setUp(self):
        zonatmo_source._cache.clear()
        self.calls = []
        self.original = zonatmo_source._http_json
        fixtures = {
            "/listing/manga": load("list.json"),
            "/single/manga/solo-leveling": load("detail.json"),
            "/single/manga/solo-leveling/chapters": load("chapters.json"),
        }
        self.reader = load("reader.json")

        def fake(path, params=None):
            self.calls.append((path, params or {}))
            if path == "/listing/manga" and (params or {}).get("search"):
                return load("search.json")
            if path.endswith("/chapters"):
                page = int((params or {}).get("page") or 1)
                if page > 1:  # the fixture is page 1; stop pagination
                    return {"error": False, "message": "", "data": {"items": [], "pagination": {"has_next": False}}}
                return fixtures["/single/manga/solo-leveling/chapters"]
            if path.startswith("/single/manga/solo-leveling/"):
                return self.reader
            if path.startswith("/single/manga/"):
                return fixtures["/single/manga/solo-leveling"]
            return fixtures.get(path, {})

        zonatmo_source._http_json = fake

    def tearDown(self):
        zonatmo_source._http_json = self.original
        zonatmo_source._cache.clear()

    def test_search(self):
        result = zonatmo_source.search("Solo Leveling")
        self.assertEqual(len(result["results"]), 2)
        self.assertEqual(self.calls[0][0], "/listing/manga")
        self.assertEqual(self.calls[0][1].get("search"), "Solo Leveling")

    def test_search_has_more_across_pages(self):
        result = zonatmo_source.search("Solo Leveling", offset=12)
        self.assertEqual(self.calls[0][1].get("page"), 2)

    def test_latest(self):
        result = zonatmo_source.latest(1)
        self.assertEqual(len(result["results"]), 12)
        self.assertTrue(result["hasMore"])

    def test_hot(self):
        items = zonatmo_source.hot()
        self.assertEqual(items[0]["id"], "alt-account-trap")

    def test_info(self):
        data = zonatmo_source.info("solo-leveling")
        self.assertEqual(data["title"], "Solo Leveling")
        self.assertEqual(len(data["chapters"]), 25)

    def test_pages(self):
        pages = zonatmo_source.pages("solo-leveling/solo-leveling-capitulo-1")
        self.assertEqual(len(pages), 17)
        self.assertIn("page_0001.webp", urllib.parse.unquote(pages[0]["img"]))


class AllChaptersPaginationTest(unittest.TestCase):
    """info() must fetch every chapter page, not just the first."""

    def setUp(self):
        zonatmo_source._cache.clear()
        self.original = zonatmo_source._http_json
        self.pages_requested = []

        def fake(path, params=None):
            if path.endswith("/chapters"):
                page = int((params or {}).get("page") or 1)
                self.pages_requested.append(page)
                if page == 1:
                    return load("chapters.json")  # 25 items, has_next True
                if page == 2:
                    return {"error": False, "message": "", "data": {
                        "items": [{"slug": "solo-leveling-capitulo-2", "chapter_number": "2",
                                   "title": "Capítulo 2", "release_date": "2026-01-01", "group": {}}],
                        "pagination": {"has_next": False}}}
                return {"error": False, "message": "", "data": {"items": [], "pagination": {"has_next": False}}}
            return load("detail.json")

        zonatmo_source._http_json = fake

    def tearDown(self):
        zonatmo_source._http_json = self.original
        zonatmo_source._cache.clear()

    def test_merges_all_pages(self):
        data = zonatmo_source.info("solo-leveling")
        self.assertEqual(self.pages_requested, [1, 2])
        self.assertEqual(len(data["chapters"]), 26)
        self.assertNotIn("truncated", data)


class CacheEvictionTest(unittest.TestCase):
    """R3-CacheGrowth fix: expired entries must not accumulate."""

    def setUp(self):
        zonatmo_source._cache.clear()

    def tearDown(self):
        zonatmo_source._cache.clear()

    def test_expired_entries_are_evicted_on_a_miss(self):
        now = time.monotonic()
        zonatmo_source._cache["old"] = ("v", now - 1)
        zonatmo_source._cache["live"] = ("v2", now + 100)
        zonatmo_source._cached("new", 10, lambda: "v3")
        self.assertNotIn("old", zonatmo_source._cache)
        self.assertIn("live", zonatmo_source._cache)
        self.assertIn("new", zonatmo_source._cache)


class ServerErrorRetryTest(unittest.TestCase):
    """R3-NoRetryForServerErrors fix: retry 5xx with backoff, not only 429."""

    class _Resp:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def read(self):
            return b'{"ok": true}'

    def _patch(self, fake_urlopen):
        self.calls = {"n": 0}
        self._orig = (zonatmo_source.urllib.request.urlopen, zonatmo_source.time.sleep,
                      zonatmo_source._rate_limit)
        zonatmo_source.urllib.request.urlopen = fake_urlopen
        zonatmo_source.time.sleep = lambda *a: None
        zonatmo_source._rate_limit = lambda: None

    def _restore(self):
        (zonatmo_source.urllib.request.urlopen, zonatmo_source.time.sleep,
         zonatmo_source._rate_limit) = self._orig

    def test_retries_5xx_then_succeeds(self):
        def fake(request, timeout=None):
            self.calls["n"] += 1
            if self.calls["n"] < 3:
                raise urllib.error.HTTPError("u", 503, "boom", {}, io.BytesIO(b""))
            return self._Resp()

        self._patch(fake)
        try:
            result = zonatmo_source._http_json("/x")
        finally:
            self._restore()
        self.assertEqual(result, {"ok": True})
        self.assertEqual(self.calls["n"], 3)

    def test_4xx_is_not_retried(self):
        def fake(request, timeout=None):
            self.calls["n"] += 1
            raise urllib.error.HTTPError("u", 404, "nf", {}, io.BytesIO(b""))

        self._patch(fake)
        try:
            with self.assertRaises(urllib.error.HTTPError):
                zonatmo_source._http_json("/x")
        finally:
            self._restore()
        self.assertEqual(self.calls["n"], 1)


class ChapterTruncationTest(unittest.TestCase):
    """R3-ChapterTruncation fix: hitting the page cap must be signalled."""

    def setUp(self):
        zonatmo_source._cache.clear()
        self._orig_http = zonatmo_source._http_json
        self._orig_max = zonatmo_source.MAX_CHAPTER_PAGES
        zonatmo_source.MAX_CHAPTER_PAGES = 2

        def fake(path, params=None):
            if path.endswith("/chapters"):
                page = (params or {}).get("page")
                return {"error": False, "message": "", "data": {
                    "items": [{"slug": f"solo-leveling-cap-{page}", "chapter_number": str(page),
                               "title": f"Capítulo {page}", "release_date": "2026-01-01", "group": {}}],
                    "pagination": {"has_next": True}}}
            return load("detail.json")

        zonatmo_source._http_json = fake

    def tearDown(self):
        zonatmo_source._http_json = self._orig_http
        zonatmo_source.MAX_CHAPTER_PAGES = self._orig_max
        zonatmo_source._cache.clear()

    def test_truncation_is_signalled(self):
        with self.assertWarns(UserWarning):
            data = zonatmo_source.info("solo-leveling")
        self.assertTrue(data.get("truncated"))
        self.assertEqual(len(data["chapters"]), 2)

    def test_no_truncation_flag_when_complete(self):
        def fake(path, params=None):
            if path.endswith("/chapters"):
                page = (params or {}).get("page")
                return {"error": False, "message": "", "data": {
                    "items": [{"slug": "solo-leveling-cap-1", "chapter_number": "1",
                               "title": "Capítulo 1", "release_date": "2026-01-01", "group": {}}],
                    "pagination": {"has_next": False}}}
            return load("detail.json")

        zonatmo_source._http_json = fake
        data = zonatmo_source.info("solo-leveling")
        self.assertNotIn("truncated", data)


if __name__ == "__main__":
    unittest.main()
