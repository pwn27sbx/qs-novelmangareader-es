"""Tests for scripts/titles.py title matching.

The chain adopts a series from a fall-through source only when the titles refer
to the SAME work, so a sequel must never be adopted by accident.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import titles  # noqa: E402


class TitlesMatchTest(unittest.TestCase):
    def test_exact_match(self):
        self.assertTrue(titles.titles_match("Solo Leveling", "Solo Leveling"))

    def test_case_and_punctuation_insensitive(self):
        self.assertTrue(titles.titles_match("solo-leveling", "Solo  Leveling"))

    def test_edition_parenthetical_matches(self):
        self.assertTrue(titles.titles_match("Naruto", "Naruto (Official Colored)"))

    def test_edition_year_matches(self):
        self.assertTrue(titles.titles_match("Naruto", "Naruto (2020)"))

    def test_edition_word_without_parens_matches(self):
        self.assertTrue(titles.titles_match("Naruto", "Naruto Digital"))

    def test_sequel_subtitle_is_rejected(self):
        # The whole point of the fix: "Solo Leveling" must NOT resolve to its
        # sequel "Solo Leveling: Ragnarok".
        self.assertFalse(titles.titles_match("Solo Leveling", "Solo Leveling: Ragnarok"))

    def test_sequel_subtitle_is_rejected_symmetrically(self):
        self.assertFalse(titles.titles_match("Solo Leveling: Ragnarok", "Solo Leveling"))

    def test_season_suffix_is_rejected(self):
        self.assertFalse(titles.titles_match("Naruto", "Naruto Shippuden"))

    def test_empty_titles_never_match(self):
        self.assertFalse(titles.titles_match("", "Solo Leveling"))
        self.assertFalse(titles.titles_match("Solo Leveling", ""))
        self.assertFalse(titles.titles_match(None, "Solo Leveling"))


if __name__ == "__main__":
    unittest.main()
