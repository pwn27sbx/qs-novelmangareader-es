"""Tests for the SkyNovels provider (JSON API) using recorded fixtures.

Run: python3 -m unittest discover -s tests -p "test_*.py"
Fixtures under tests/fixtures/skynovels/ were captured from the live API; the
provider's HTTP layer is replaced with a fixture lookup (no network).
"""

import json
import os
import sys
import unittest

ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.join(ROOT, "scripts", "novel_server"))

from providers.skynovels import SkynovelsProvider, _paragraphs  # noqa: E402
from providers import utils  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "skynovels")


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return json.load(f)


class FakeAPI:
    def __call__(self, path, params=None):
        if path == "/novels":
            return load("novels.json")
        if path.endswith("/base"):
            return load("base.json")
        if path.endswith("/volumes"):
            return load("volumes.json")
        if path.startswith("/volumes/"):
            return load("chapters.json")
        if path.startswith("/chapters/"):
            return load("chapter.json")
        return {}


class SkynovelsTest(unittest.TestCase):
    def setUp(self):
        utils._cache.clear()
        self.provider = SkynovelsProvider()
        self.provider._api = FakeAPI()

    def test_search_maps_cards(self):
        data = self.provider.search("naruto")
        self.assertGreater(len(data["results"]), 0)
        first = data["results"][0]
        self.assertTrue(first["id"])
        self.assertTrue(first["title"])
        self.assertTrue(first["image"].startswith("http://127.0.0.1:5151/image?url="))
        self.assertIn("get-image", first["image"])

    def test_info_flattens_volume_chapters(self):
        info = self.provider.info("1")
        self.assertTrue(info["title"])
        self.assertEqual(info["chapters"][0]["chapter"], "1")
        self.assertTrue(info["chapters"][0]["id"])
        numbers = [float(c["chapter"]) for c in info["chapters"]]
        self.assertEqual(numbers, sorted(numbers))

    def test_chapter_paragraphs(self):
        chapter = self.provider.chapter("27605")
        self.assertTrue(chapter["paragraphs"])
        self.assertGreater(chapter["wordCount"], 0)

    def test_paragraphs_splitter(self):
        parts = _paragraphs("<p>Uno</p><p>Dos</p><br>Tres")
        self.assertEqual(parts, ["Uno", "Dos", "Tres"])


if __name__ == "__main__":
    unittest.main()
