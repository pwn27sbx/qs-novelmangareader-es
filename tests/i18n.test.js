"use strict";

// Unit tests for the pure i18n core used by services/I18n.qml.
// Run with:  node --test tests/
//
// The core has no QML/Quickshell dependency, so it can be exercised here
// without launching a Wayland session. Language detection (QS_LANG/LANG)
// lives in the QML singleton and is covered by the visual QA (WU-6).

const test = require("node:test");
const assert = require("node:assert/strict");

const i18n = require("../services/i18n.js");

test("t() translates a known key to Spanish", () => {
    assert.equal(i18n.t("es", "tab.browse"), "Explorar");
    assert.equal(i18n.t("es", "tab.library"), "Biblioteca");
});

test("t() keeps English as the source language", () => {
    assert.equal(i18n.t("en", "tab.browse"), "Browse");
    assert.equal(i18n.t("en", "tab.library"), "Library");
});

test("t() interpolates %1 style placeholders", () => {
    assert.equal(i18n.t("es", "page", { 1: 7 }), "pág. 7");
    assert.equal(i18n.t("es", "last.ep", { 1: 3 }), "Último: Ep. 3");
    assert.equal(i18n.t("en", "error.request", { 1: "HTTP 500" }), "Request failed: HTTP 500");
});

test("t() falls back to English for an unknown language", () => {
    assert.equal(i18n.t("fr", "tab.browse"), "Browse");
});

test("t() returns the raw key when it is missing everywhere", () => {
    assert.equal(i18n.t("es", "no.such.key"), "no.such.key");
});

test("tn() picks the singular form for n === 1", () => {
    assert.equal(i18n.tn("es", "count.chapter", 1), "1 capítulo");
    assert.equal(i18n.tn("en", "count.episode", 1), "1 episode");
});

test("tn() picks the plural form for n !== 1", () => {
    assert.equal(i18n.tn("es", "count.chapter", 3), "3 capítulos");
    assert.equal(i18n.tn("es", "count.chapter", 0), "0 capítulos");
    assert.equal(i18n.tn("en", "count.episode", 2), "2 episodes");
});

test("tn() works on plain string entries too", () => {
    assert.equal(i18n.tn("es", "tab.browse", 1), "Explorar");
});

test("es and en expose the exact same key set", () => {
    const es = Object.keys(i18n.tables.es).sort();
    const en = Object.keys(i18n.tables.en).sort();
    assert.deepEqual(es, en);
});
