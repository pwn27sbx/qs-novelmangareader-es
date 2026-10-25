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
    assert.equal(prefs.normalizeScrollFactor(0), prefs.DEFAULT_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(-4), prefs.DEFAULT_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor("abc"), prefs.DEFAULT_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(99), prefs.MAX_SCROLL_FACTOR);
    assert.equal(prefs.normalizeScrollFactor(0.2), prefs.MIN_SCROLL_FACTOR);
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

test("withLanguage() keeps the reader's scrollFactor", () => {
    const before = JSON.stringify({ language: "en", scrollFactor: 4 });
    const after = JSON.parse(prefs.withLanguage(before, "es"));
    assert.equal(after.language, "es");
    assert.equal(after.scrollFactor, 4);
});

test("withLanguage() starts from an empty document when the file is broken", () => {
    assert.deepEqual(JSON.parse(prefs.withLanguage("}{", "es")), { language: "es" });
});

test("withLanguage() writes a trailing newline", () => {
    assert.ok(prefs.withLanguage("", "es").endsWith("\n"));
});
