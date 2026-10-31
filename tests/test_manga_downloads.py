"""Tests for the download page resolver in scripts/manga_server.py.

The worker used to call the WeebCentral scraper for every chapter, so a
Spanish chapter downloaded English pages or nothing at all. These tests pin the
routing without downloading anything.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import manga_chain  # noqa: E402
import manga_server  # noqa: E402


class DownloadPagesTest(unittest.TestCase):
    def setUp(self):
        self.original_chain = manga_chain.pages
        self.original_scraper = manga_server._pages
        self.asked = []

    def tearDown(self):
        manga_chain.pages = self.original_chain
        manga_server._pages = self.original_scraper

    def test_a_prefixed_id_goes_through_the_chain(self):
        manga_chain.pages = lambda cid: self.asked.append(("chain", cid)) or [{"page": 1, "img": "x"}]
        manga_server._pages = lambda cid: self.asked.append(("scraper", cid)) or []

        pages = manga_server._download_pages("manhwaweb:abc-1")

        self.assertEqual(pages, [{"page": 1, "img": "x"}])
        self.assertEqual(self.asked, [("chain", "manhwaweb:abc-1")])

    def test_a_legacy_id_keeps_the_old_scraper(self):
        manga_chain.pages = lambda cid: self.asked.append(("chain", cid)) or []
        manga_server._pages = lambda cid: self.asked.append(("scraper", cid)) or [{"page": 1, "img": "y"}]

        pages = manga_server._download_pages("legacyid")

        self.assertEqual(pages, [{"page": 1, "img": "y"}])
        self.assertEqual(self.asked, [("scraper", "legacyid")])

    def test_a_failing_chain_falls_back_instead_of_breaking_the_job(self):
        def boom(cid):
            raise RuntimeError("chain down")

        manga_chain.pages = boom
        manga_server._pages = lambda cid: [{"page": 1, "img": "z"}]

        self.assertEqual(manga_server._download_pages("zonatmo:x"), [{"page": 1, "img": "z"}])


if __name__ == "__main__":
    unittest.main()
