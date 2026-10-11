"""Tests for scripts/jkanime_source.py using recorded JKAnime fixtures.

Run: python3 -m unittest discover -s tests -p "test_*.py"
The fixtures under tests/fixtures/jkanime/ were captured from the live site; the
tests never touch the network.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import jkanime_source  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "jkanime")


def load(name):
    with open(os.path.join(FIX, name)) as f:
        return f.read()


class ParseSearchTest(unittest.TestCase):
    def setUp(self):
        self.items = jkanime_source.parse_search(load("search.html"))

    def test_items(self):
        self.assertEqual(len(self.items), 3)
        ids = [item["id"] for item in self.items]
        self.assertIn("naruto", ids)
        for item in self.items:
            self.assertTrue(item["name"])
            self.assertTrue(item["thumbnail"].startswith("http"))
            self.assertEqual(item["available_episodes"]["sub"], 1)


class ParseShowTest(unittest.TestCase):
    def test_anime_id_and_csrf(self):
        html = load("show.html")
        self.assertEqual(jkanime_source.parse_anime_id(html), "2034")
        self.assertTrue(jkanime_source.parse_csrf(html))


class ParseEpisodesTest(unittest.TestCase):
    def test_numbers(self):
        self.assertEqual(jkanime_source.parse_episodes(load("episodes.json")), ["1", "2", "3"])


class ParseSourceTest(unittest.TestCase):
    def test_player_source(self):
        source = jkanime_source.parse_source(load("player.html"))
        self.assertIn("playmudos.com", source)
        self.assertIn(".m3u8", source)


if __name__ == "__main__":
    unittest.main()
