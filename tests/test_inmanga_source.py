"""Tests for scripts/inmanga_source.py using recorded InManga fixtures.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"

Fixtures under tests/fixtures/inmanga/ were captured from the live site; the
tests never touch the network.
"""

import json
import os
import sys
import unittest
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import inmanga_source  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "inmanga")
MANGA_UUID = "dfc7ecb5-e9b3-4aa5-a61b-a498993cd935"
CHAPTER_IDENT = "B9C9F061-4400-4813-A70A-9256FC102E05"


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return f.read()


class ParseSearchTest(unittest.TestCase):
    def setUp(self):
        self.items = inmanga_source.parse_search(load("search.html"))

    def test_items(self):
        self.assertGreaterEqual(len(self.items), 1)
        first = self.items[0]
        self.assertTrue(first["id"].endswith(MANGA_UUID))
        self.assertIn("One Piece", first["title"])
        self.assertIn("cdn1.intomanga.com", urllib.parse.unquote(first["image"]))
        self.assertTrue(first["image"].startswith("http://127.0.0.1:5150/image?url="))


class ParseChaptersTest(unittest.TestCase):
    def setUp(self):
        self.chapters = inmanga_source.parse_chapters(load("chapters.json"), MANGA_UUID)

    def test_chapters_are_mapped_and_sorted(self):
        self.assertGreaterEqual(len(self.chapters), 1)
        numbers = [float(c["chapter"]) for c in self.chapters]
        self.assertEqual(numbers, sorted(numbers))
        first = self.chapters[0]
        self.assertTrue(first["id"].startswith(MANGA_UUID + "/"))
        self.assertEqual(first["chapter"], "1")
        self.assertTrue(first["publishAt"])


class ParsePagesTest(unittest.TestCase):
    def test_pages_from_page_list(self):
        pages = inmanga_source.parse_pages(load("pages.html"), MANGA_UUID, CHAPTER_IDENT)
        self.assertEqual(len(pages), 3)
        self.assertEqual(pages[0]["page"], 1)
        url = urllib.parse.unquote(pages[0]["img"])
        self.assertIn(f"cdn1.intomanga.com/i/m/{MANGA_UUID}/c/{CHAPTER_IDENT.lower()}/o/", url)
        self.assertTrue(url.endswith(".jpg"))


class ParseInfoTest(unittest.TestCase):
    def test_info(self):
        info = inmanga_source.parse_info(load("detail.html"), load("chapters.json"), MANGA_UUID)
        self.assertIn("One Piece", info["title"])
        self.assertTrue(info["image"].startswith("http://127.0.0.1:5150/image?url="))
        self.assertGreaterEqual(len(info["chapters"]), 1)


if __name__ == "__main__":
    unittest.main()
