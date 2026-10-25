"""Tests for scripts/anicli_fallback.py (WU-10, the ani-cli-mx backup provider).

`ani-cli-mx --debug` prints the resolved link and its metadata without starting
a player, which is what the backend parses. The fixtures are real output from
ani-cli-mx 3.0.10; the fake CLI scripts keep the tests off the network.

Run: python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import pathlib
import stat
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import anicli_fallback  # noqa: E402

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "anicli")

SAMPLE = """\x1b[2K\x1b[1;34mBuscando animes...\x1b[0m
\x1b[2K\x1b[1;34mBuscando episodios...\x1b[0m
\x1b[1;32mAnimeAV1 HLS\x1b[0m Links Fetched
Fuente elegida: AnimeAV1
La calidad especificada no existe, usando la mejor disponible
Todos los enlaces:
970 >https://player.zilla-networks.com/m3u8/abc123
referrer >https://player.zilla-networks.com/m3u8/abc123>https://player.zilla-networks.com/play/abc123
source >https://player.zilla-networks.com/m3u8/abc123>HLS
site >https://player.zilla-networks.com/m3u8/abc123>AnimeAV1
Fuente seleccionada:
AnimeAV1 / HLS
Enlace seleccionado:
https://player.zilla-networks.com/m3u8/abc123
"""


def write_fake_cli(directory, body, name="ani-cli-mx"):
    """An executable that stands in for the real CLI."""
    path = pathlib.Path(directory) / name
    path.write_text("#!/bin/sh\n" + body + "\n")
    path.chmod(path.stat().st_mode | stat.S_IEXEC)
    return str(path)


class ParseTest(unittest.TestCase):
    def test_parses_the_selected_link_and_its_metadata(self):
        parsed = anicli_fallback.parse_output(SAMPLE)
        self.assertEqual(parsed["url"], "https://player.zilla-networks.com/m3u8/abc123")
        self.assertEqual(parsed["referer"], "https://player.zilla-networks.com/play/abc123")
        self.assertEqual(parsed["site"], "AnimeAV1")
        self.assertEqual(parsed["type"], "m3u8")
        self.assertEqual(parsed["quality"], "970")

    def test_strips_ansi_and_trailing_blank_lines(self):
        parsed = anicli_fallback.parse_output(SAMPLE + "\n\n")
        self.assertNotIn("\x1b", parsed["url"])

    def test_reports_an_error_when_nothing_was_selected(self):
        parsed = anicli_fallback.parse_output("Buscando animes...\nno results\n")
        self.assertIn("error", parsed)
        self.assertNotIn("url", parsed)


class CommandTest(unittest.TestCase):
    def test_builds_the_documented_non_interactive_invocation(self):
        cmd = anicli_fallback.build_command("/usr/bin/ani-cli-mx", "naruto", "1", "720")
        self.assertEqual(cmd[0], "/usr/bin/ani-cli-mx")
        self.assertIn("--debug", cmd)
        self.assertEqual(cmd[cmd.index("-t") + 1], "anime")
        self.assertEqual(cmd[cmd.index("-e") + 1], "1")
        self.assertEqual(cmd[cmd.index("-S") + 1], "1")
        self.assertEqual(cmd[cmd.index("--quality") + 1], "720")
        self.assertEqual(cmd[-1], "naruto")

    def test_episode_is_passed_as_a_string(self):
        cmd = anicli_fallback.build_command("ani-cli-mx", "naruto", 12)
        self.assertEqual(cmd[cmd.index("-e") + 1], "12")


class FetchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def test_returns_a_link_dict_from_the_cli_output(self):
        binary = write_fake_cli(self.tmp, "cat <<'EOF'\n" + SAMPLE + "EOF")
        link = anicli_fallback.fetch("naruto", "1", binary=binary)
        self.assertEqual(link["url"], "https://player.zilla-networks.com/m3u8/abc123")
        self.assertEqual(link["provider"], "ani-cli-mx")
        self.assertEqual(link["referer"], "https://player.zilla-networks.com/play/abc123")
        self.assertEqual(link["type"], "m3u8")
        self.assertEqual(link["subtitle_label"], "")
        self.assertEqual(link["source_site"], "AnimeAV1")

    def test_missing_binary_is_an_error_not_a_crash(self):
        link = anicli_fallback.fetch("naruto", "1", binary=os.path.join(self.tmp, "nope"))
        self.assertIn("error", link)

    def test_a_failing_cli_is_an_error(self):
        binary = write_fake_cli(self.tmp, "echo 'boom' >&2\nexit 1")
        link = anicli_fallback.fetch("naruto", "1", binary=binary)
        self.assertIn("error", link)

    def test_a_slow_cli_times_out(self):
        binary = write_fake_cli(self.tmp, "sleep 30")
        link = anicli_fallback.fetch("naruto", "1", binary=binary, timeout=1)
        self.assertIn("error", link)
        self.assertIn("timeout", link["error"].lower())

    def test_disabled_by_env(self):
        with mock.patch.dict(os.environ, {"QS_ANIME_CLI": "off"}):
            self.assertIsNone(anicli_fallback.available())

    def test_binary_comes_from_the_env_override(self):
        binary = write_fake_cli(self.tmp, "cat <<'EOF'\n" + SAMPLE + "EOF")
        with mock.patch.dict(os.environ, {"QS_ANIME_CLI": binary}):
            self.assertEqual(anicli_fallback.available(), binary)


class CacheTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def test_a_second_call_for_the_same_episode_does_not_run_the_cli(self):
        counter = pathlib.Path(self.tmp) / "count"
        binary = write_fake_cli(
            self.tmp,
            f'echo x >> "{counter}"\ncat <<\'EOF\'\n{SAMPLE}EOF',
        )
        anicli_fallback.clear_cache()
        anicli_fallback.fetch("naruto", "1", binary=binary)
        anicli_fallback.fetch("naruto", "1", binary=binary)
        self.assertEqual(counter.read_text().count("x"), 1)


class ParseFixtureTest(unittest.TestCase):
    def test_recorded_fixture_still_parses(self):
        with open(os.path.join(FIX, "debug_output.txt"), encoding="utf-8") as f:
            parsed = anicli_fallback.parse_output(f.read())
        self.assertEqual(parsed["site"], "AnimeAV1")
        self.assertTrue(parsed["url"].startswith("https://"))


if __name__ == "__main__":
    unittest.main()
