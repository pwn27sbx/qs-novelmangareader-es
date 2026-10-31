"""Tests for scripts/manhwaweb_source.py (ManhwaWeb, the +18 manhwa source).

The fixtures under tests/fixtures/manhwaweb/ are the API's real answers for
"glory hole" (search, series, one chapter), captured 2026-10-25 through the
same endpoints the module calls. Nothing here touches the network.

Run: python3 -m unittest discover -s tests -p "test_*.py"
"""

import json
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import manhwaweb_source  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "manhwaweb")


def load(name):
    with open(os.path.join(FIX, name), encoding="utf-8") as f:
        return json.load(f)


SEARCH = load("search.json")
INFO = load("info.json")
CHAPTER = load("chapter.json")


class MappingTest(unittest.TestCase):
    def test_search_row_becomes_a_list_item(self):
        item = manhwaweb_source.map_item(SEARCH["data"][0])
        self.assertEqual(item["id"], "glory_hole_1679782381480")
        self.assertEqual(item["title"], "La Tienda del Placer")
        self.assertEqual(item["status"], "Completed")
        self.assertEqual(item["type"], "Manhwa")
        self.assertEqual(item["chapter"], "151.5")
        # The library rows carry category *ids*, not names: the card shows none,
        # and the series document (below) is where the names live.
        self.assertEqual(item["tags"], [])
        self.assertTrue(item["image"].startswith("http://127.0.0.1:5150/image?url="))

    def test_a_row_without_optional_fields_does_not_crash(self):
        item = manhwaweb_source.map_item({"_id": "x_1"})
        self.assertEqual(item["id"], "x_1")
        self.assertEqual(item["image"], "")
        self.assertEqual(item["tags"], [])

    def test_series_becomes_an_info_object(self):
        data = manhwaweb_source.map_info(INFO)
        self.assertEqual(data["id"], "glory_hole_1679782381480")
        self.assertEqual(data["title"], "La Tienda del Placer")
        self.assertEqual(len(data["chapters"]), 152)
        self.assertEqual(data["status"], "Completed")
        self.assertIn("Drama", data["tags"])
        self.assertTrue(data["description"].startswith("Tras heredar"))

    def test_a_scalar_author_is_not_split_into_characters(self):
        data = manhwaweb_source.map_info({"_id": "x_1", "autor": "Kimtuk", "chapters": []})
        self.assertEqual(data["authors"], ["Kimtuk"])

    def test_authors_are_names_not_objects(self):
        data = manhwaweb_source.map_info(INFO)
        self.assertTrue(data["authors"])
        for author in data["authors"]:
            self.assertIsInstance(author, str)
            self.assertTrue(author.strip())

    def test_chapters_are_newest_first_and_keep_their_label(self):
        data = manhwaweb_source.map_info(INFO)
        first = data["chapters"][0]
        self.assertEqual(first["chapter"], "151.5")
        self.assertTrue(first["id"].endswith("-151.5_01"))
        self.assertRegex(first["publishAt"], r"^\d{4}-\d{2}-\d{2}T")
        self.assertEqual(data["chapters"][-1]["chapter"], "1")

    def test_chapter_pages_are_proxied(self):
        pages = manhwaweb_source.map_pages(CHAPTER)
        self.assertGreater(len(pages), 0)
        self.assertEqual([page["page"] for page in pages], list(range(1, len(pages) + 1)))
        for page in pages:
            self.assertTrue(page["img"].startswith("http://127.0.0.1:5150/image?url="))
        self.assertIn("img1mw.xyz", pages[0]["img"])


class CacheTest(unittest.TestCase):
    def setUp(self):
        manhwaweb_source.clear_cache()

    def test_a_short_lived_entry_does_not_evict_a_valid_one(self):
        with manhwaweb_source._lock:
            manhwaweb_source._cache["valid"] = (__import__("time").time(), {"ok": 1}, 600)
            for i in range(manhwaweb_source.CACHE_LIMIT):
                manhwaweb_source._cache[f"short:{i}"] = (0.0, {"x": i}, 1)
        manhwaweb_source._cached("fresh", 1, lambda: {"ok": 2})
        # The retained entry is still usable, and asking for it does not reload.
        self.assertEqual(manhwaweb_source._cached("valid", 600, lambda: {"ok": 0}), {"ok": 1})

    def test_a_shorter_ttl_call_cannot_read_a_stale_entry(self):
        import time
        # Ten seconds old: still fresh under its stored 600s TTL, stale under
        # the 5s the caller asks for now — the only age that tells the two
        # behaviours apart.
        with manhwaweb_source._lock:
            manhwaweb_source._cache["k"] = (time.time() - 10, {"old": True}, 600)
        self.assertEqual(manhwaweb_source._cached("k", 5, lambda: {"old": False}), {"old": False})

    def test_the_cache_drops_expired_entries_instead_of_growing_forever(self):
        with manhwaweb_source._lock:
            for i in range(manhwaweb_source.CACHE_LIMIT + 10):
                manhwaweb_source._cache[f"old:{i}"] = (0.0, {"x": i}, 300)
        manhwaweb_source._cached("fresh", 300, lambda: {"ok": True})
        self.assertLessEqual(len(manhwaweb_source._cache), manhwaweb_source.CACHE_LIMIT)


class ChapterIdTest(unittest.TestCase):
    def test_builds_and_splits_the_chapter_id(self):
        link = INFO["chapters"][0]["link"]
        cid = manhwaweb_source.chapter_id("glory_hole_1679782381480", link)
        self.assertEqual(cid, "glory_hole_1679782381480-1_01")
        self.assertEqual(
            manhwaweb_source.split_chapter_id(cid),
            ("glory_hole_1679782381480", "1_01"),
        )

    def test_a_manga_id_with_hyphens_still_splits(self):
        cid = "jibakusha-the-earthbound_1792557948156-12.5_02"
        self.assertEqual(
            manhwaweb_source.split_chapter_id(cid),
            ("jibakusha-the-earthbound_1792557948156", "12.5_02"),
        )

    def test_an_unknown_shape_is_not_guessed(self):
        self.assertEqual(manhwaweb_source.split_chapter_id("nonsense"), ("", ""))
        self.assertEqual(manhwaweb_source.chapter_id("id", "https://elsewhere/x"), "")


class EndpointTest(unittest.TestCase):
    def setUp(self):
        manhwaweb_source.clear_cache()

    def test_search_asks_the_library_endpoint_and_reports_more(self):
        with mock.patch.object(manhwaweb_source, "_get_json", return_value=SEARCH) as get:
            result = manhwaweb_source.search("glory hole")
        path = get.call_args[0][0]
        self.assertTrue(path.startswith("/manhwa/library?"))
        self.assertIn("buscar=glory+hole", path)
        self.assertIn("page=0", path)
        self.assertEqual(len(result["results"]), 1)
        self.assertFalse(result["hasMore"])
        self.assertEqual(result["nextOffset"], 30)

    def test_a_type_scoped_search_filters_locally(self):
        with mock.patch.object(manhwaweb_source, "_get_json", return_value=SEARCH):
            self.assertEqual(manhwaweb_source.search("glory hole", mtype="manga")["results"], [])
            self.assertEqual(len(manhwaweb_source.search("glory hole", mtype="Manhwa")["results"]), 1)

    def test_offset_maps_to_a_library_page(self):
        with mock.patch.object(manhwaweb_source, "_get_json", return_value=SEARCH) as get:
            manhwaweb_source.search("x", offset=60)
        self.assertIn("page=2", get.call_args[0][0])

    def test_pages_calls_the_chapter_endpoint_by_id_and_label(self):
        with mock.patch.object(manhwaweb_source, "_get_json", return_value=CHAPTER) as get:
            urls = manhwaweb_source.pages("glory_hole_1679782381480-1_01")
        self.assertEqual(get.call_args[0][0], "/chapters/see/glory_hole_1679782381480-1_01")
        self.assertGreater(len(urls), 0)

    def test_pages_with_a_broken_id_returns_nothing_without_calling(self):
        with mock.patch.object(manhwaweb_source, "_get_json") as get:
            self.assertEqual(manhwaweb_source.pages("nonsense"), [])
        get.assert_not_called()

    def test_info_reads_the_series_document(self):
        with mock.patch.object(manhwaweb_source, "_get_json", return_value=INFO) as get:
            data = manhwaweb_source.info("glory_hole_1679782381480")
        self.assertEqual(get.call_args[0][0], "/manhwa/see/glory_hole_1679782381480")
        self.assertEqual(len(data["chapters"]), 152)


if __name__ == "__main__":
    unittest.main()
