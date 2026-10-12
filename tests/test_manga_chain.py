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
        self.assertEqual(manga_chain.active_chain("", ["es-419", "es"]),
                         ["mangadex", "inmanga", "zonatmo", "zonatmo_org"])

    def test_english_uses_weebcentral(self):
        self.assertEqual(manga_chain.active_chain("", ["en"]), ["weebcentral"])

    def test_forced_source(self):
        self.assertEqual(manga_chain.active_chain("inmanga", ["en"]), ["inmanga"])
        self.assertEqual(manga_chain.active_chain("mangadex", ["es"]), ["mangadex"])
        self.assertEqual(manga_chain.active_chain("zonatmo", ["en"]), ["zonatmo"])
        self.assertEqual(manga_chain.active_chain("zonatmo_org", ["en"]), ["zonatmo_org"])

    def test_mirrors_for(self):
        self.assertEqual(manga_chain.mirrors_for("zonatmo"), ("zonatmo.net",))
        self.assertEqual(manga_chain.mirrors_for("zonatmo_org"), ("zonatmo.org",))
        self.assertEqual(manga_chain.mirrors_for("mangadex"), ())


class RaisingSource(FakeSource):
    """A source whose domain is dead: every call raises."""

    def search(self, *args, **kwargs):
        raise RuntimeError("domain dead")

    def latest(self, *args, **kwargs):
        raise RuntimeError("domain dead")

    def hot(self, *args, **kwargs):
        raise RuntimeError("domain dead")

    def info(self, *args, **kwargs):
        raise RuntimeError("domain dead")


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

    def set_modules(self, mangadex, inmanga, zonatmo=None, zonatmo_org=None):
        manga_chain._MODULES = {
            "mangadex": mangadex,
            "inmanga": inmanga,
            "zonatmo": zonatmo if zonatmo is not None else FakeSource(),
            "zonatmo_org": zonatmo_org if zonatmo_org is not None else FakeSource(),
        }

    def test_search_uses_first_source_with_results(self):
        self.set_modules(FakeSource(found=True), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "mangadex:S-bleach")

    def test_search_falls_through_when_first_is_empty(self):
        self.set_modules(FakeSource(found=False), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "inmanga:S-bleach")

    def test_search_falls_through_to_zonatmo(self):
        self.set_modules(FakeSource(found=False), FakeSource(found=False), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "zonatmo:S-bleach")

    def test_search_falls_through_to_zonatmo_org(self):
        self.set_modules(FakeSource(found=False), FakeSource(found=False),
                         FakeSource(found=False), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "zonatmo_org:S-bleach")

    def test_search_skips_a_dead_source(self):
        self.set_modules(RaisingSource(), FakeSource(found=True))
        result = manga_chain.search("bleach")
        self.assertEqual(result["results"][0]["id"], "inmanga:S-bleach")

    def test_latest_skips_a_dead_source(self):
        self.set_modules(RaisingSource(), FakeSource(found=True))
        result = manga_chain.latest(1)
        self.assertEqual(result["results"][0]["id"], "inmanga:L")

    def test_hot_skips_a_dead_source(self):
        self.set_modules(RaisingSource(), FakeSource(found=True))
        self.assertEqual(manga_chain.hot()[0]["id"], "inmanga:H")

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

    def test_info_falls_through_to_zonatmo(self):
        self.set_modules(
            FakeSource(chapters=False),
            FakeSource(found=False, chapters=False),
            FakeSource(found=True, chapters=True),
        )
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data["id"], "zonatmo:S-Foo")
        self.assertEqual(data["chapters"][0]["id"], "zonatmo:CH")

    def test_info_falls_through_to_zonatmo_org(self):
        self.set_modules(
            FakeSource(chapters=False),
            FakeSource(found=False, chapters=False),
            FakeSource(found=False, chapters=False),
            FakeSource(found=True, chapters=True),
        )
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data["id"], "zonatmo_org:S-Foo")
        self.assertEqual(data["chapters"][0]["id"], "zonatmo_org:CH")

    def test_info_skips_a_dead_fallthrough_source(self):
        # The primary has no chapters but provides the title; the next source
        # is dead and must be skipped so the live one is reached.
        self.set_modules(
            FakeSource(chapters=False),            # mangadex: title "Foo", no chapters
            RaisingSource(),                       # inmanga: dead
            FakeSource(found=True, chapters=True),  # zonatmo: alive
        )
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data["id"], "zonatmo:S-Foo")

    def test_info_skips_source_whose_info_raises(self):
        class HalfDead(FakeSource):
            def info(self, *args, **kwargs):
                raise RuntimeError("info dead")

        self.set_modules(
            FakeSource(chapters=False),
            HalfDead(found=True, chapters=True),   # search works, info raises
            FakeSource(found=True, chapters=True),
        )
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data["id"], "zonatmo:S-Foo")

    def test_none_has_spanish(self):
        self.set_modules(FakeSource(chapters=False), FakeSource(found=True, chapters=False),
                         FakeSource(found=True, chapters=False), FakeSource(found=True, chapters=False))
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data.get("error"), "Sin capítulos en español")
        # The title is carried so the server can fall back to the English source.
        self.assertEqual(data.get("title"), "Foo")

    def test_fallthrough_rejects_non_matching_title(self):
        # The fall-through source answers with an unrelated series: it must NOT
        # be adopted; the chain reports "no Spanish" instead.
        class Wrong(FakeSource):
            def search(self, query, mtype=None, offset=0, sort="Best Match"):
                return {"results": [{"id": "x", "title": "Aoi - Hikaru"}], "hasMore": False, "nextOffset": 0}

        self.set_modules(FakeSource(chapters=False), Wrong(found=True, chapters=True),
                         FakeSource(found=False, chapters=False), FakeSource(found=False, chapters=False))
        data = manga_chain.info("mangadex:x")
        self.assertEqual(data.get("error"), "Sin capítulos en español")

    def test_pages_routes_by_prefix(self):
        self.set_modules(FakeSource(), FakeSource())
        pages = manga_chain.pages("inmanga:manga/CH")
        self.assertEqual(pages[0]["img"], "img:manga/CH")

    def test_pages_routes_to_zonatmo(self):
        self.set_modules(FakeSource(), FakeSource(), FakeSource())
        pages = manga_chain.pages("zonatmo:solo-leveling/solo-leveling-capitulo-1")
        self.assertEqual(pages[0]["img"], "img:solo-leveling/solo-leveling-capitulo-1")

    def test_pages_routes_to_zonatmo_org(self):
        self.set_modules(FakeSource(), FakeSource(), FakeSource(), FakeSource())
        pages = manga_chain.pages("zonatmo_org:969671")
        self.assertEqual(pages[0]["img"], "img:969671")


if __name__ == "__main__":
    unittest.main()
