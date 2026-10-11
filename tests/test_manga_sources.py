"""Tests for scripts/manga_sources.py using recorded MangaDex fixtures.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"

Fixtures were captured from the live MangaDex API (plan §15.5) and are stored
under tests/fixtures/mangadex/; the tests never touch the network.
"""

import json
import os
import sys
import unittest
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import manga_sources  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "mangadex")


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return json.load(f)


class LangsTest(unittest.TestCase):
    def test_spanish_expands_to_latam_and_spain(self):
        self.assertEqual(manga_sources.mangadex_langs(["es-419", "es"]), ["es-la", "es"])

    def test_plain_spanish(self):
        self.assertEqual(manga_sources.mangadex_langs(["es"]), ["es-la", "es"])

    def test_english(self):
        self.assertEqual(manga_sources.mangadex_langs(["en"]), ["en"])

    def test_empty_falls_back_to_english(self):
        self.assertEqual(manga_sources.mangadex_langs([]), ["en"])


class ActiveSourceTest(unittest.TestCase):
    def test_explicit_mangadex(self):
        self.assertEqual(manga_sources.active_source("mangadex", ["en"]), "mangadex")

    def test_explicit_weebcentral(self):
        self.assertEqual(manga_sources.active_source("weebcentral", ["es"]), "weebcentral")

    def test_auto_spanish_uses_mangadex(self):
        self.assertEqual(manga_sources.active_source("", ["es-419", "es"]), "mangadex")

    def test_auto_english_uses_weebcentral(self):
        self.assertEqual(manga_sources.active_source("", ["en"]), "weebcentral")

    def test_unknown_env_falls_back_to_auto(self):
        self.assertEqual(manga_sources.active_source("bogus", ["es"]), "mangadex")


class MapSearchTest(unittest.TestCase):
    def setUp(self):
        self.page = manga_sources.map_search(load("search.json"))

    def test_results_and_paging(self):
        self.assertEqual(len(self.page["results"]), 2)
        self.assertEqual(self.page["nextOffset"], 2)
        self.assertIsInstance(self.page["hasMore"], bool)

    def test_first_item_fields(self):
        item = self.page["results"][0]
        self.assertIn("Blue Lock", item["title"])
        self.assertTrue(item["image"].startswith("http://127.0.0.1:5150/image?url="))
        self.assertIn("uploads.mangadex.org/covers/", urllib.parse.unquote(item["image"]))
        self.assertEqual(item["status"], "Ongoing")
        self.assertEqual(item["type"], "Manga")
        self.assertTrue(item["tags"])


class MapInfoTest(unittest.TestCase):
    def setUp(self):
        self.info = manga_sources.map_info(load("manga.json"), load("feed.json"))

    def test_top_level(self):
        self.assertIn("Blue Lock", self.info["title"])
        self.assertTrue(self.info["description"])
        self.assertEqual(self.info["status"], "Ongoing")
        self.assertIn("Kaneshiro Muneyuki", self.info["authors"])

    def test_external_chapters_are_filtered(self):
        # feed.json has one hosted + one external chapter -> only the hosted one
        self.assertEqual(len(self.info["chapters"]), 1)
        chapter = self.info["chapters"][0]
        self.assertEqual(chapter["chapter"], "297")
        self.assertEqual(chapter["group"], "El Scan Semanal")
        self.assertTrue(chapter["id"])


class MapPagesTest(unittest.TestCase):
    def test_data_saver_by_default(self):
        athome = load("athome.json")
        pages = manga_sources.map_pages(athome, data_saver=True)
        self.assertEqual(len(pages), len(athome["chapter"]["dataSaver"]))
        self.assertEqual(pages[0]["page"], 1)
        self.assertTrue(pages[0]["img"].startswith("http://127.0.0.1:5150/image?url="))
        self.assertIn("/data-saver/", urllib.parse.unquote(pages[0]["img"]))

    def test_full_quality(self):
        pages = manga_sources.map_pages(load("athome.json"), data_saver=False)
        decoded = urllib.parse.unquote(pages[0]["img"])
        self.assertIn("/data/", decoded)
        self.assertNotIn("/data-saver/", decoded)


class ProxyTest(unittest.TestCase):
    def test_empty_url(self):
        self.assertEqual(manga_sources.proxy_url(""), "")

    def test_encoding(self):
        url = manga_sources.proxy_url("https://x/a b.jpg")
        self.assertIn("url=https%3A%2F%2Fx%2Fa%20b.jpg", url)


class AtHomeCacheTest(unittest.TestCase):
    def setUp(self):
        manga_sources._at_home.clear()
        manga_sources._retry_refresh.clear()
        self.calls = []
        self.original = manga_sources._http_json

        def fake(path, params, athome=False):
            self.calls.append(path)
            return {"baseUrl": "https://cdn.example",
                    "chapter": {"hash": "h", "dataSaver": ["a.jpg"], "data": ["a.jpg"]}}

        manga_sources._http_json = fake

    def tearDown(self):
        manga_sources._http_json = self.original
        manga_sources._at_home.clear()
        manga_sources._retry_refresh.clear()

    def test_pages_uses_short_cache(self):
        manga_sources.pages("cid")
        manga_sources.pages("cid")
        self.assertEqual(len(self.calls), 1)  # cached within the short TTL

    def test_at_home_fresh_refreshes_the_node(self):
        manga_sources.pages("cid")  # populate cache
        manga_sources.at_home_fresh("cid", min_age=0)
        self.assertEqual(len(self.calls), 2)  # forced a new at-home request

    def test_at_home_fresh_is_throttled_after_the_first_refresh(self):
        manga_sources.pages("cid")
        manga_sources.at_home_fresh("cid", min_age=60)   # first 404 -> refresh
        manga_sources.at_home_fresh("cid", min_age=60)   # burst -> reuse
        self.assertEqual(len(self.calls), 2)

    def test_map_pages_carries_chapter_and_page(self):
        data = {"baseUrl": "https://cdn.example", "chapter": {"hash": "h", "dataSaver": ["a.jpg"]}}
        pages = manga_sources.map_pages(data, True, "the-chapter")
        self.assertIn("chapter=the-chapter", pages[0]["img"])
        self.assertIn("page=1", pages[0]["img"])


if __name__ == "__main__":
    unittest.main()
