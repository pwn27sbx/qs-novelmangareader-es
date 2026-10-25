"""Integration of the ani-cli-mx backup into scripts/anime_server.py (WU-10).

The primary chain (hianime -> JKAnime) is stubbed, so these tests pin only the
wiring: the CLI is asked exactly when both sources come back empty, its link
reaches `all_links` with its provider name, and a failed CLI call is not an
exception but the usual "no stream" error.

anime_server imports flask/requests, so these run only in the app venv
(~/.local/share/qs-novelmangareader/venv); elsewhere they are skipped.

Run: python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

try:
    import anime_server
    import anicli_fallback
except Exception as exc:  # flask/requests missing
    anime_server = None
    SKIP = f"anime_server unavailable: {exc}"
else:
    SKIP = ""

LINK = {
    "url": "https://player.example/m3u8/abc",
    "quality": "970",
    "type": "m3u8",
    "referer": "https://player.example/play/abc",
    "subtitle": "",
    "subtitle_label": "",
    "source_site": "AnimeAV1",
    "provider": "ani-cli-mx",
}

META = {"name": "Naruto", "englishName": "Naruto", "malId": ""}


@unittest.skipIf(anime_server is None, SKIP)
class FallbackWiringTest(unittest.TestCase):
    def setUp(self):
        anicli_fallback.clear_cache()

    def _resolve(self, backup, zoko=None, jkanime=None, mode="sub"):
        with mock.patch.object(anime_server, "_show_meta", return_value=dict(META)), \
             mock.patch.object(anime_server, "_hianime_embed", return_value=None), \
             mock.patch.object(anime_server, "_zoko_links", return_value=zoko or []), \
             mock.patch.object(anime_server, "_jkanime_fallback", return_value=jkanime or []), \
             mock.patch.object(anime_server.anicli_fallback, "fetch", return_value=backup) as fetch:
            result = anime_server.get_episode_links("show-1", "1", mode)
        return result, fetch

    def test_the_cli_link_is_used_when_both_sources_are_empty(self):
        result, fetch = self._resolve(dict(LINK))
        fetch.assert_called_once()
        self.assertEqual(result["all_links"][0]["provider"], "ani-cli-mx")
        self.assertEqual(result["all_links"][0]["url"], LINK["url"])
        self.assertIn("ani-cli-mx", result["providers"])

    def test_the_cli_is_asked_with_the_show_title_and_episode(self):
        _, fetch = self._resolve(dict(LINK))
        args, _ = fetch.call_args
        self.assertEqual(args[0], "Naruto")
        self.assertEqual(args[1], "1")

    def test_the_requested_mode_reaches_the_cli(self):
        result, fetch = self._resolve(dict(LINK), mode="dub")
        _, kwargs = fetch.call_args
        self.assertEqual(kwargs.get("mode"), "dub")
        self.assertEqual(result["mode"], "dub")

    def test_a_failed_cli_call_is_the_usual_no_stream_error(self):
        result, _ = self._resolve({"error": "ani-cli-mx: not installed"})
        self.assertIn("error", result)
        self.assertIn("No sub stream found", result["error"])

    def test_the_cli_is_not_asked_when_the_chain_works(self):
        working = [{"url": "https://x/a.m3u8", "quality": "1080",
                    "type": "m3u8", "referer": "", "subtitle": "",
                    "subtitle_label": "Español (hardsub)"}]
        result, fetch = self._resolve({"error": "should not be called"}, jkanime=working)
        fetch.assert_not_called()
        self.assertEqual(result["all_links"][0]["url"], "https://x/a.m3u8")


if __name__ == "__main__":
    unittest.main()
