"""Tests for scripts/subtitles.py — ZokoAnime subtitle-track selection.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import subtitles  # noqa: E402

LATAM = "Spanish (Spanish - [Full])"          # generic / Latin American
CASTILIAN = "Spanish (- Castilian [Full])"    # Spain
PORTUGUESE = "Portuguese (Portuguese - Brazilian [Full])"
ENGLISH = "English"


def track(label, default=False):
    return {"label": label, "lang": "en", "default": default,
            "src": "https://x/" + label.replace(" ", "_").replace("/", "") + ".vtt"}


class PickSubtitleTest(unittest.TestCase):
    def test_prefers_generic_spanish_over_castilian(self):
        subs = [track(PORTUGUESE), track(CASTILIAN), track(LATAM), track(ENGLISH, default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["es-419", "es"])["label"], LATAM)

    def test_generic_spanish_wins_regardless_of_order(self):
        subs = [track(LATAM), track(CASTILIAN), track(ENGLISH, default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["es"])["label"], LATAM)

    def test_castilian_used_when_only_spanish_available(self):
        subs = [track(CASTILIAN), track(ENGLISH, default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["es"])["label"], CASTILIAN)

    def test_falls_back_to_default_when_no_spanish(self):
        subs = [track(PORTUGUESE), track(ENGLISH, default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["es"])["label"], ENGLISH)

    def test_falls_back_to_default_when_no_match(self):
        subs = [track(ENGLISH, default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["es"])["label"], ENGLISH)

    def test_english_preference(self):
        subs = [track(LATAM), track(ENGLISH, default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["en"])["label"], ENGLISH)

    def test_case_insensitive_label(self):
        subs = [track("SPANISH (Spanish - [Full])", default=True)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["es"])["label"],
                         "SPANISH (Spanish - [Full])")

    def test_no_subtitles_returns_none(self):
        self.assertIsNone(subtitles.pick_subtitle([], ["es"]))
        self.assertIsNone(subtitles.pick_subtitle(None, ["es"]))

    def test_first_preference_wins(self):
        subs = [track(LATAM), track(PORTUGUESE)]
        self.assertEqual(subtitles.pick_subtitle(subs, ["pt", "es"])["label"], PORTUGUESE)

    def test_uses_env_default_es(self):
        old = os.environ.pop("QS_CONTENT_LANG", None)
        try:
            subs = [track(ENGLISH, default=True), track(LATAM)]
            self.assertEqual(subtitles.pick_subtitle(subs)["label"], LATAM)
        finally:
            if old is not None:
                os.environ["QS_CONTENT_LANG"] = old

    def test_env_override_to_english(self):
        old = os.environ.get("QS_CONTENT_LANG")
        os.environ["QS_CONTENT_LANG"] = "en"
        try:
            subs = [track(LATAM), track(ENGLISH, default=True)]
            self.assertEqual(subtitles.pick_subtitle(subs)["label"], ENGLISH)
        finally:
            if old is None:
                os.environ.pop("QS_CONTENT_LANG", None)
            else:
                os.environ["QS_CONTENT_LANG"] = old


if __name__ == "__main__":
    unittest.main()
