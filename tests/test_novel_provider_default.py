"""Tests for the novel provider default (content-language aware).

Run: python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.join(ROOT, "scripts", "novel_server"))

from providers import _default_provider_name, active_name  # noqa: E402


class DefaultProviderTest(unittest.TestCase):
    def test_spanish_content_uses_skynovels(self):
        self.assertEqual(_default_provider_name("es"), "skynovels")
        self.assertEqual(_default_provider_name("es-419,es"), "skynovels")
        self.assertEqual(_default_provider_name(""), "skynovels")  # default is es

    def test_english_content_uses_freewebnovel(self):
        self.assertEqual(_default_provider_name("en"), "freewebnovel")
        self.assertEqual(_default_provider_name("en_US"), "freewebnovel")

    def test_active_default_matches_content_language(self):
        self.assertEqual(active_name(), _default_provider_name())

    def test_active_default_is_skynovels_without_env(self):
        if not os.environ.get("QS_CONTENT_LANG"):
            self.assertEqual(active_name(), "skynovels")


if __name__ == "__main__":
    unittest.main()
