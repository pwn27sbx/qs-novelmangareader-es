"use strict";

// Tests for services/prefs.js — the shared settings.json helpers.
//
// Two writers touch one file: the EN/ES toggle owns `language`, the readers own
// `scrollFactor`. Neither may drop the other's key, which is why the merge
// lives here instead of in either caller.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const prefs = require("../services/prefs.js");

test("parseSettings() returns an object only for real JSON objects", () => {
    assert.deepEqual(prefs.parseSettings('{"language":"es"}'), { language: "es" });
    assert.deepEqual(prefs.parseSettings("[1,2]"), {});
    assert.deepEqual(prefs.parseSettings(""), {});
    assert.deepEqual(prefs.parseSettings("not json"), {});
});

test("normalizeScrollFactor() clamps and falls back", () => {
    assert.equal(prefs.normalizeScrollFactor(2), 2);
    assert.equal(prefs.normalizeScrollFactor("3"), 3);
    assert.equal(prefs.normalizeScrollFactor("1.5"), 1.5);
    assert.equal(prefs.normalizeScrollFactor(0), prefs.DEFAULT_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(-4), prefs.DEFAULT_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor("abc"), prefs.DEFAULT_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(99), prefs.MAX_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(0.2), prefs.MIN_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(0.5), 0.5);
    assert.equal(prefs.normalizeScrollFactor(1.24), 1.2);
    assert.equal(prefs.normalizeScrollFactor(1.26), 1.3);
    assert.equal(prefs.normalizeScrollFactor(5.4), prefs.MAX_SCROLL_FACTOR);
});

test("withSetting() writes one key and keeps the rest", () => {
    const before = JSON.stringify({ language: "en", scrollFactor: 4 });
    const after = JSON.parse(prefs.withSetting(before, "scrollFactor", 7));
    assert.equal(after.scrollFactor, 7);
    assert.equal(after.language, "en");
});

test("withSetting() adds the key when the document is empty", () => {
    assert.deepEqual(JSON.parse(prefs.withSetting("", "scrollFactor", 3)), { scrollFactor: 3 });
});

test("normalizeLanguage() accepts every Spanish spelling and nothing else", () => {
    assert.equal(prefs.normalizeLanguage("es"), "es");
    assert.equal(prefs.normalizeLanguage("es-419"), "es");
    assert.equal(prefs.normalizeLanguage("ES"), "es");
    assert.equal(prefs.normalizeLanguage("en"), "en");
    assert.equal(prefs.normalizeLanguage("fr"), "en");
    assert.equal(prefs.normalizeLanguage(""), "en");
});

test("withSetting() keeps the reader's scrollFactor when the language changes", () => {
    const before = JSON.stringify({ language: "en", scrollFactor: 4 });
    const after = JSON.parse(prefs.withSetting(before, "language", "es"));
    assert.equal(after.language, "es");
    assert.equal(after.scrollFactor, 4);
});

test("withSetting() starts from an empty document when the file is broken", () => {
    assert.deepEqual(JSON.parse(prefs.withSetting("}{", "language", "es")), { language: "es" });
});

test("normalizeViewMode() defaults to grid and accepts only the two modes", () => {
    assert.equal(prefs.DEFAULT_VIEW_MODE, "grid");
    assert.equal(prefs.normalizeViewMode(undefined), "grid");
    assert.equal(prefs.normalizeViewMode(null), "grid");
    assert.equal(prefs.normalizeViewMode(""), "grid");
    assert.equal(prefs.normalizeViewMode("garbage"), "grid");
    assert.equal(prefs.normalizeViewMode(42), "grid");
    assert.equal(prefs.normalizeViewMode("grid"), "grid");
    assert.equal(prefs.normalizeViewMode("list"), "list");
    // Tolerant of case and stray whitespace from a hand-edited settings.json.
    assert.equal(prefs.normalizeViewMode(" LIST "), "list");
});

test("withSetting() persists viewMode without dropping the other keys", () => {
    const before = JSON.stringify({ language: "es", scrollFactor: 4, viewMode: "grid" });
    const after = JSON.parse(prefs.withSetting(before, "viewMode", "list"));
    assert.equal(after.viewMode, "list");
    assert.equal(after.language, "es");
    assert.equal(after.scrollFactor, 4);
});
