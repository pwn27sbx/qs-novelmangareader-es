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

test("tData() localizes known status values to Spanish", () => {
    assert.equal(i18n.tData("es", "Ongoing"), "En curso");
    assert.equal(i18n.tData("es", "Completed"), "Completada");
    assert.equal(i18n.tData("es", "Hiatus"), "En pausa");
    assert.equal(i18n.tData("es", "Cancelled"), "Cancelada");
});

test("tData() localizes known type values to Spanish", () => {
    assert.equal(i18n.tData("es", "Movie"), "Película");
    assert.equal(i18n.tData("es", "Special"), "Especial");
    assert.equal(i18n.tData("es", "TV"), "TV");
    assert.equal(i18n.tData("es", "OVA"), "OVA");
    assert.equal(i18n.tData("es", "ONA"), "ONA");
});

test("tData() keeps canonical English values", () => {
    assert.equal(i18n.tData("en", "Ongoing"), "Ongoing");
    assert.equal(i18n.tData("en", "Movie"), "Movie");
});

test("tData() falls back to the raw value when unknown", () => {
    assert.equal(i18n.tData("es", "Weird"), "Weird");
    assert.equal(i18n.tData("es", "Unknown Status"), "Unknown Status");
    assert.equal(i18n.tData("es", ""), "");
    assert.equal(i18n.tData("es", undefined), undefined);
});

test("tData() matches known values case-insensitively", () => {
    assert.equal(i18n.tData("es", "OnGoing"), "En curso");
    assert.equal(i18n.tData("es", "COMPLETED"), "Completada");
});

test("normalizeLang() reduces locale strings to a bare code", () => {
    assert.equal(i18n.normalizeLang("es_419"), "es");
    assert.equal(i18n.normalizeLang("es-419"), "es");
    assert.equal(i18n.normalizeLang("en_US.UTF-8"), "en");
    assert.equal(i18n.normalizeLang(""), "");
    assert.equal(i18n.normalizeLang(null), "");
});

test("resolveLang() precedence: env -> settings -> system -> en", () => {
    assert.equal(i18n.resolveLang("es", "en", "en_US.UTF-8"), "es");
    assert.equal(i18n.resolveLang("", "es", "en_US.UTF-8"), "es");
    assert.equal(i18n.resolveLang("", "", "es_ES.UTF-8"), "es");
    assert.equal(i18n.resolveLang("", "", "en_US.UTF-8"), "en");
    assert.equal(i18n.resolveLang("", "", ""), "en");
});

test("settingsLanguage() reads the language key safely", () => {
    assert.equal(i18n.settingsLanguage('{"language":"es"}'), "es");
    assert.equal(i18n.settingsLanguage('{"language":"ES"}'), "es");
    assert.equal(i18n.settingsLanguage('{"language":"fr"}'), "");
    assert.equal(i18n.settingsLanguage('{"other":true}'), "");
    assert.equal(i18n.settingsLanguage("not json"), "");
});

// The settings writer lives in services/prefs.js now (tests/prefs.test.js):
// it has to keep the keys the language toggle does not own.

test("es and en expose the exact same key set", () => {
    const es = Object.keys(i18n.tables.es).sort();
    const en = Object.keys(i18n.tables.en).sort();
    assert.deepEqual(es, en);
});

test("t() translates the no-Spanish notice keys", () => {
    assert.equal(i18n.t("es", "manga.searchOtherSources"), "Buscar en otras fuentes");
    assert.equal(i18n.t("en", "manga.searchOtherSources"), "Search other sources");
    assert.equal(i18n.t("es", "manga.sourcesTried", { 1: "MangaDex" }), "Fuentes consultadas: MangaDex");
    assert.equal(i18n.t("en", "manga.sourcesTried", { 1: "MangaDex" }), "Sources checked: MangaDex");
});

test("t() labels the section headers above the grids", () => {
    assert.equal(i18n.t("es", "header.results"), "Resultados");
    assert.equal(i18n.t("en", "header.results"), "Results");
});

test("tn() pluralizes the loaded-results count", () => {
    assert.equal(i18n.tn("es", "header.loaded", 1), "1 cargado");
    assert.equal(i18n.tn("es", "header.loaded", 7), "7 cargados");
    assert.equal(i18n.tn("en", "header.loaded", 0), "0 loaded");
    assert.equal(i18n.tn("en", "header.loaded", 7), "7 loaded");
});

test("t() names each panel's header brand", () => {
    assert.equal(i18n.t("es", "brand.manga"), "Manga");
    assert.equal(i18n.t("es", "brand.anime"), "Anime");
    assert.equal(i18n.t("es", "brand.novel"), "Novela");
    assert.equal(i18n.t("en", "brand.manga"), "Manga");
    assert.equal(i18n.t("en", "brand.anime"), "Anime");
    assert.equal(i18n.t("en", "brand.novel"), "Novel");
});

test("tSource() labels the known manga sources", () => {
    assert.equal(i18n.tSource("mangadex"), "MangaDex");
    assert.equal(i18n.tSource("inmanga"), "InManga");
    assert.equal(i18n.tSource("zonatmo"), "ZonaTMO (.net)");
    assert.equal(i18n.tSource("zonatmo_org"), "ZonaTMO (.org)");
});

test("tSource() falls back to the raw id when unknown", () => {
    assert.equal(i18n.tSource("mystery"), "mystery");
    assert.equal(i18n.tSource(""), "");
    assert.equal(i18n.tSource(undefined), "");
});
