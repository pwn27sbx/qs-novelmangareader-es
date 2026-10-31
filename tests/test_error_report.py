"""Tests for scripts/error_report.py and the chain instrumentation.

The reporter replaces sentry-sdk on purpose: the SDK requires urllib3 and
certifi inside a venv shared with the anime and novel servers. These tests pin
what it must do (report once, never raise, stay off without a DSN) and that
manga_chain reports the errors it used to swallow.

Run from the repo root:
    python3 -m unittest discover -s tests -p "test_*.py"
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))

import error_report  # noqa: E402
import manga_chain  # noqa: E402

DSN = "https://abc123@o42.ingest.us.sentry.io/77"


class ParseDsnTest(unittest.TestCase):
    def test_a_normal_dsn_is_split(self):
        self.assertEqual(error_report.parse_dsn(DSN),
                         ("https://o42.ingest.us.sentry.io", "77", "abc123"))

    def test_an_explicit_port_survives(self):
        base, project, key = error_report.parse_dsn("http://key@localhost:9000/9")
        self.assertEqual(base, "http://localhost:9000")
        self.assertEqual((project, key), ("9", "key"))

    def test_a_missing_or_broken_dsn_is_none(self):
        for value in ("", None, "nonsense", "https://host/no-key"):
            self.assertIsNone(error_report.parse_dsn(value), value)


class ScrubTest(unittest.TestCase):
    def test_a_url_loses_its_query(self):
        text = "GET https://cdn.example/a.webp?token=SECRET&q=solo+leveling failed"
        cleaned = error_report.scrub(text)
        self.assertIn("https://cdn.example/a.webp", cleaned)
        self.assertNotIn("SECRET", cleaned)
        self.assertNotIn("solo+leveling", cleaned)

    def test_the_event_message_is_scrubbed(self):
        error = RuntimeError("boom https://x/y?q=user-search")
        event = error_report.build_event(error, "zonatmo", "search")
        self.assertNotIn("user-search", event["message"])
        self.assertNotIn("user-search", event["extra"]["traceback"])


class EventTest(unittest.TestCase):
    def test_the_event_names_the_source_operation_and_type(self):
        event = error_report.build_event(ValueError("boom"), "zonatmo", "info")
        self.assertIn("zonatmo:info", event["message"])
        self.assertIn("ValueError", event["message"])
        self.assertEqual(event["tags"], {"source": "zonatmo", "op": "info"})
        self.assertEqual(event["fingerprint"], ["zonatmo", "info", "ValueError"])
        self.assertEqual(event["level"], "error")
        self.assertIn("traceback", event["extra"])

    def test_the_traceback_is_bounded(self):
        try:
            raise RuntimeError("x" * 5000)
        except RuntimeError as error:
            event = error_report.build_event(error, "a", "b")
        self.assertLessEqual(len(event["extra"]["traceback"]), error_report.MAX_TRACEBACK)


class DedupeTest(unittest.TestCase):
    def test_one_event_per_source_operation_and_type_per_hour(self):
        sent = {}
        self.assertTrue(error_report.should_send("zonatmo", "info", "HTTPError", 1000, sent))
        error_report.mark_sent("zonatmo", "info", "HTTPError", 1000, sent)
        self.assertFalse(error_report.should_send("zonatmo", "info", "HTTPError", 1001, sent))
        self.assertTrue(error_report.should_send("zonatmo", "info", "HTTPError", 1000 + 3601, sent))
        self.assertTrue(error_report.should_send("zonatmo", "pages", "HTTPError", 1002, sent))


class ReportTest(unittest.TestCase):
    def setUp(self):
        error_report._sent.clear()

    def test_without_a_dsn_nothing_is_sent(self):
        called = []
        self.assertFalse(error_report.report(ValueError("x"), "s", "o", dsn="", sink=lambda *a: called.append(a)))
        self.assertEqual(called, [])

    def test_a_dsn_sends_one_event_and_then_stays_quiet(self):
        made = []

        def sink(url, payload):
            made.append((url, payload))
            return True

        self.assertTrue(error_report.report(ValueError("x"), "zonatmo", "info", dsn=DSN, sink=sink, now=10))
        self.assertFalse(error_report.report(ValueError("x"), "zonatmo", "info", dsn=DSN, sink=sink, now=11))
        self.assertEqual(len(made), 1)
        self.assertIn("sentry_key=abc123", made[0][0])
        self.assertIn("/api/77/store/", made[0][0])

    def test_a_failing_sink_is_false_and_does_not_raise(self):
        def sink(url, payload):
            raise OSError("offline")

        self.assertFalse(error_report.report(ValueError("x"), "s", "o", dsn=DSN, sink=sink, now=1))
        self.assertFalse(error_report.report(ValueError("y"), "s", "o", dsn=DSN, sink=lambda u, p: False, now=2))

    def test_a_failed_delivery_does_not_silence_the_next_one(self):
        error_report._sent.clear()
        self.assertFalse(error_report.report(ValueError("x"), "s", "o", dsn=DSN,
                                             sink=lambda u, p: False, now=1))
        self.assertTrue(error_report.report(ValueError("x"), "s", "o", dsn=DSN,
                                            sink=lambda u, p: True, now=2))


class ChainInstrumentationTest(unittest.TestCase):
    def setUp(self):
        error_report._sent.clear()
        self.original = manga_chain._report
        self.seen = []
        manga_chain._report = lambda error, source="", op="": self.seen.append((type(error).__name__, source, op))

    def tearDown(self):
        manga_chain._report = self.original

    def test_a_dead_source_is_reported_before_the_default(self):
        def boom():
            raise OSError("dead")

        self.assertIsNone(manga_chain._try(boom, None, source="zonatmo", op="info"))
        self.assertEqual(self.seen, [("OSError", "zonatmo", "info")])

    def test_a_healthy_call_reports_nothing(self):
        self.assertEqual(manga_chain._try(lambda: 7, None, source="zonatmo", op="info"), 7)
        self.assertEqual(self.seen, [])

    def test_pages_reports_and_still_raises(self):
        class Broken:
            def pages(self, chapter_id):
                raise KeyError("images")

        modules = dict(manga_chain._MODULES)
        manga_chain._MODULES = {**modules, "zonatmo": Broken()}
        try:
            with self.assertRaises(KeyError):
                manga_chain.pages("zonatmo:x")
        finally:
            manga_chain._MODULES = modules
        self.assertEqual(self.seen, [("KeyError", "zonatmo", "pages")])


if __name__ == "__main__":
    unittest.main()
