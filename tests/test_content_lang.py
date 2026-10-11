"""Tests for scripts/content_lang.py.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import content_lang  # noqa: E402


class ContentLangsTest(unittest.TestCase):
    def test_default_is_spanish(self):
        self.assertEqual(content_lang.content_langs(""), ["es"])

    def test_env_default_when_unset(self):
        old = os.environ.pop("QS_CONTENT_LANG", None)
        try:
            self.assertEqual(content_lang.content_langs(), ["es"])
        finally:
            if old is not None:
                os.environ["QS_CONTENT_LANG"] = old

    def test_ordered_list(self):
        self.assertEqual(content_lang.content_langs("es-419,es"), ["es-419", "es"])

    def test_entries_are_trimmed_and_blanks_dropped(self):
        self.assertEqual(content_lang.content_langs(" es , , en "), ["es", "en"])

    def test_english_only(self):
        self.assertEqual(content_lang.content_langs("en"), ["en"])

    def test_content_lang_is_first(self):
        self.assertEqual(content_lang.content_lang("es-419,es"), "es-419")

    def test_content_lang_default(self):
        self.assertEqual(content_lang.content_lang(""), "es")


if __name__ == "__main__":
    unittest.main()
