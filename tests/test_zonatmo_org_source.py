"""Tests for scripts/zonatmo_org_source.py using recorded zonatmo.org fixtures.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"

Fixtures under tests/fixtures/zonatmo_org/ were captured from the live site
(suggest JSON API + series/chapter/biblioteca HTML fragments); the tests never
touch the network.
"""

import json
import os
import sys
import unittest
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import zonatmo_org_source  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "zonatmo_org")


def load_json(name):
    with open(os.path.join(FIX, name), encoding="utf-8") as f:
        return json.load(f)


def load_text(name):
    with open(os.path.join(FIX, name), encoding="utf-8") as f:
        return f.read()


class ParseSuggestTest(unittest.TestCase):
    def setUp(self):
        self.items = zonatmo_org_source.parse_suggest(load_json("suggest.json"))

    def test_items(self):
        self.assertEqual(len(self.items), 3)

    def test_spanish_manhwa_item(self):
        item = self.items[0]
        self.assertEqual(item["id"], "library/manhwa/6426/solo-leveling")
        self.assertEqual(item["title"], "Solo Leveling")
        self.assertEqual(item["type"], "MANHWA")
        self.assertEqual(item["status"], "Finalizado")
        self.assertTrue(item["image"].startswith("http://127.0.0.1:5150/image?url="))
        self.assertIn("storage2.zonatmo.org", urllib.parse.unquote(item["image"]))

    def test_novel_item_type(self):
        novel = [i for i in self.items if i["type"] == "NOVEL"]
        self.assertTrue(novel)
        self.assertEqual(novel[0]["id"], "library/novel/29782/solo-leveling-ragnarok-1")


class ParseBibliotecaTest(unittest.TestCase):
    def setUp(self):
        self.items = zonatmo_org_source.parse_biblioteca(load_text("biblioteca.html"))

    def test_items(self):
        self.assertEqual(len(self.items), 3)

    def test_first_item(self):
        item = self.items[0]
        self.assertEqual(item["id"], "library/manhwa/31352/la-ventura-del-caballero-blanco")
        self.assertEqual(item["title"], "La Ventura Del Caballero Blanco")
        self.assertEqual(item["type"], "MANHWA")
        self.assertEqual(item["status"], "En emisión")
        self.assertEqual(item["chapter"], "31")
        self.assertIn("storage/covers", urllib.parse.unquote(item["image"]))


class ParseSeriesTest(unittest.TestCase):
    def setUp(self):
        self.info = zonatmo_org_source.parse_series(load_text("series.html"), "library/manhwa/6426/solo-leveling")

    def test_top_level(self):
        self.assertEqual(self.info["title"], "Solo Leveling")
        self.assertTrue(self.info["description"])
        self.assertIn("Sung Jin-Woo", self.info["description"])
        self.assertEqual(self.info["status"], "Finalizado")
        self.assertEqual(self.info["type"], "MANHWA")
        self.assertIn("aad1b611e20cedfe4a8fa93d0325c85b.webp", urllib.parse.unquote(self.info["image"]))
        self.assertIn("jang", self.info["authors"])
        self.assertIn("sung-rak", self.info["authors"])
        self.assertIn("Acción", self.info["tags"])

    def test_chapters_sorted_ascending(self):
        numbers = [float(c["chapter"]) for c in self.info["chapters"]]
        self.assertEqual(numbers, sorted(numbers))
        self.assertEqual(len(self.info["chapters"]), 3)

    def test_chapter_fields(self):
        last = self.info["chapters"][-1]  # chapter 201
        self.assertEqual(last["chapter"], "201")
        self.assertEqual(last["id"], "969671")
        self.assertEqual(last["group"], "TMO Bot")
        self.assertEqual(last["publishAt"], "27/05/2026")


class ParseChapterTest(unittest.TestCase):
    def test_pages_deduped_and_ordered(self):
        pages = zonatmo_org_source.parse_chapter(load_text("chapter.html"), "969671")
        numbers = [p["page"] for p in pages]
        self.assertEqual(numbers, [1, 2, 3, 4, 5, 6])
        url = urllib.parse.unquote(pages[0]["img"])
        self.assertIn("storage.zonatmo.org/chapters/969671/1.webp", url)
        self.assertTrue(pages[0]["img"].startswith("http://127.0.0.1:5150/image?url="))


class ProxyTest(unittest.TestCase):
    def test_empty_url(self):
        self.assertEqual(zonatmo_org_source.proxy_url(""), "")

    def test_encoding(self):
        url = zonatmo_org_source.proxy_url("https://x/a b.jpg")
        self.assertIn("url=https%3A%2F%2Fx%2Fa%20b.jpg", url)


class ApiTest(unittest.TestCase):
    """The public API with a faked transport (deterministic, no network)."""

    def setUp(self):
        zonatmo_org_source._cache.clear()
        self.urls = []
        self.original = zonatmo_org_source._request

        def fake(url):
            self.urls.append(url)
            if "/api/search/suggest" in url:
                return json.dumps(load_json("suggest.json"))
            if "/view_uploads/" in url:
                return load_text("chapter.html")
            if "/biblioteca" in url:
                return load_text("biblioteca.html")
            return load_text("series.html")

        zonatmo_org_source._request = fake

    def tearDown(self):
        zonatmo_org_source._request = self.original
        zonatmo_org_source._cache.clear()

    def test_search(self):
        result = zonatmo_org_source.search("Solo Leveling")
        self.assertEqual(result["results"][0]["id"], "library/manhwa/6426/solo-leveling")
        self.assertIn("q=Solo", self.urls[0])

    def test_search_type_filter(self):
        result = zonatmo_org_source.search("Solo Leveling", mtype="Novel")
        self.assertTrue(result["results"])
        self.assertTrue(all(i["type"] == "NOVEL" for i in result["results"]))

    def test_latest(self):
        result = zonatmo_org_source.latest(1)
        self.assertEqual(len(result["results"]), 3)
        self.assertTrue(result["hasMore"])
        self.assertTrue(any("page=1" in u for u in self.urls))

    def test_hot(self):
        items = zonatmo_org_source.hot()
        self.assertEqual(items[0]["id"], "library/manhwa/31352/la-ventura-del-caballero-blanco")

    def test_info(self):
        data = zonatmo_org_source.info("library/manhwa/6426/solo-leveling")
        self.assertEqual(data["title"], "Solo Leveling")
        self.assertEqual(len(data["chapters"]), 3)

    def test_pages(self):
        pages = zonatmo_org_source.pages("969671")
        self.assertEqual(len(pages), 6)


if __name__ == "__main__":
    unittest.main()
