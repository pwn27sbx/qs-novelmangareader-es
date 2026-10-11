"""Opt-in live tests for scripts/inmanga_source.py (real network).

The fixture suite never touches the network. These run only with
``INMANGA_LIVE_TESTS=1``:

    INMANGA_LIVE_TESTS=1 python3 -m unittest discover -s tests -p "test_*.py"

They guard exactly the reported regression: a query that exists must return
results, and different queries must return different result sets.
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import inmanga_source  # noqa: E402

LIVE = os.environ.get("INMANGA_LIVE_TESTS") == "1"


@unittest.skipUnless(LIVE, "set INMANGA_LIVE_TESTS=1 to hit the live InManga API")
class InMangaLiveSearchTest(unittest.TestCase):
    def test_existing_query_returns_results(self):
        self.assertGreater(len(inmanga_source.search("naruto")["results"]), 0)

    def test_different_queries_differ(self):
        naruto = [r["id"] for r in inmanga_source.search("naruto")["results"]]
        onepiece = [r["id"] for r in inmanga_source.search("one piece")["results"]]
        self.assertTrue(naruto and onepiece)
        self.assertNotEqual(naruto, onepiece)


if __name__ == "__main__":
    unittest.main()
