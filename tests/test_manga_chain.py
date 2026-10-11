"""Tests for scripts/manga_chain.py (source chain + language fall-through).

The source modules are replaced with fakes so the chain logic is exercised
without the network. Run: python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import manga_chain  # noqa: E402


class FakeSource:
    def __init__(self, found=True, chapters=True):
        self.found = found
        self.chapters = chapters

    def search(self, query, mtype=None, offset=0, sort="Best Match"):
        results = [{"id": "S-" + query, "title": query}] if self.found else []
        return {"results": results, "hasMore": False, "nextOffset": 0}

    def latest(self, page=1):
        return {"results": [{"id": "L"}] if self.found else [], "hasMore": False, "nextPage": page + 1}

    def hot(self):
        return [{"id": "H"}] if self.found else []

    def info(self, manga_id):
        chapters = [{"id": "CH", "chapter": "1"}] if self.chapters else []
        return {"id": manga_id, "title": "Foo", "chapters": chapters}

    def pages(self, chapter_id):
        return [{"page": 1, "img": "img:" + chapter_id}]


class ActiveChainTest(unittest.TestCase):
    def test_spanish_uses_the_chain(self):
        self.assertEqual(manga_chain.active_chain("", ["es-419", "es"]), ["mangadex", "inmanga"])

    def test_english_uses_weebcentral(self):
        self.assertEqual(manga_chain.active_chain("", ["en"]), ["weebcentral"])

    def test_forced_source(self):
        self.assertEqual(manga_chain.active_chain("inmanga", ["en"]), ["inmanga"])
        self.assertEqual(manga_chain.active_chain("mangadex", ["es"]), ["mangadex"])


class ChainTest(unittest.TestCase):
    def setUp(self):
        self._old_env = os.environ.get("QS_CONTENT_LANG")
        os.environ["QS_CONTENT_LANG"] = "es"
        self._old_modules = manga_chain._MODULES

    def tearDown(self):
        manga_chain._MODULES = self._old_modules
        if self._old_env is None:
            os.environ.pop("QS_CONTENT_LANG", None)
        else:
            os.environ["QS_CONTENT_LANG"] = self._old_env

    def set_modules(self, mangadex, inmanga):
        manga_chain._MODULES = {"mangadex": mangadex, "inmanga": inmanga}

    def test_search_uses_first_source_with_results(self):
        self.set_modules(FakeSource(found=True), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "mangadex:S-bleach")

    def test_search_falls_through_when_first_is_empty(self):
        self.set_modules(FakeSource(found=False), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "inmanga:S-bleach")

    def test_info_keeps_source_when_it_has_chapters(self):
        self.set_modules(FakeSource(chapters=True), FakeSource(chapters=True))
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data["id"], "mangadex:x")
        self.assertEqual(data["chapters"][0]["id"], "mangadex:CH")

    def test_info_falls_through_to_inmanga(self):
        self.set_modules(FakeSource(chapters=False), FakeSource(found=True, chapters=True))
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data["id"], "inmanga:S-Foo")
        self.assertEqual(data["chapters"][0]["id"], "inmanga:CH")

    def test_none_has_spanish(self):
        self.set_modules(FakeSource(chapters=False), FakeSource(found=True, chapters=False))
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data.get("error"), "Sin capítulos en español")

    def test_pages_routes_by_prefix(self):
        self.set_modules(FakeSource(), FakeSource())
        pages = manga_chain.pages("inmanga:manga/CH")
        self.assertEqual(pages[0]["img"], "img:manga/CH")


if __name__ == "__main__":
    unittest.main()
