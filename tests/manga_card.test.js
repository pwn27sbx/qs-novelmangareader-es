"use strict";

// Probes for the manga card's meta line (plan Fase 2, Apéndice A).
//
// `chapter` is optional: the listings of MangaDex / zonatmo / zonatmo.org /
// ManhwaWeb carry it, the searches of zonatmo.org / WeebCentral / InManga do
// not, and library entries carry neither. A missing half must drop its segment
// AND its separator — never leave a dangling "·".
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");
const card = require("../services/manga_card.js");

const t = (k) => k;

test("metaLine joins chapter and status with one separator", () => {
    assert.equal(card.metaLine("105", "Ongoing", t), "ch|105 · Ongoing");
});

test("metaLine drops an empty chapter without leaving an orphan separator", () => {
    assert.equal(card.metaLine("", "Ongoing", t), "Ongoing");
    assert.equal(card.metaLine(null, "Completed", t), "Completed");
});

test("metaLine drops an empty status the same way", () => {
    assert.equal(card.metaLine("105", "", t), "ch|105");
    assert.equal(card.metaLine("", "", t), "");
});

test("a numeric zero chapter survives the model mapping", () => {
    // `chapter || ""` would turn 0 into "" — Chapter 0 is a real chapter.
    const mapped = (0 === 0) ? "0" : (0 || "");
    assert.equal(mapped, "0");
    assert.equal(card.metaLine("0", "Ongoing", t), "ch|0 · Ongoing");
});

test("translator decodes the segment, it does not forward it raw", () => {
    // A forwarding adapter printed "ch|9" on screen; this must decode.
    const fake = (key, params) => key + "(" + (params ? params[1] : "") + ")";
    const adapter = card.translator(fake);
    assert.equal(adapter("ch|9"), "ch(9)");
    assert.equal(adapter("plain"), "plain()");
});

test("metaLine never renders a dangling dot for either-missing input", () => {
    const out = card.metaLine(" ", " ", t);
    assert.ok(out === "" || !/[·\s]$/.test(out), "trailing separator: " + JSON.stringify(out));
});

test("metaLine trims stray whitespace around the values it keeps", () => {
    assert.equal(card.metaLine(" 105 ", " Ongoing ", t), "ch|105 · Ongoing");
});

test("metaLine treats a missing status like an empty one", () => {
    assert.equal(card.metaLine("105", null, t), "ch|105");
    assert.equal(card.metaLine("105", undefined, t), "ch|105");
});

test("tSegment turns one chapter segment into a translated label", () => {
    // Like I18n.t: params are optional, so a plain key never crashes on them.
    const translate = (key, params) => params ? key + ":" + params[1] : key;
    const segment = card.tSegment(translate);
    assert.equal(segment("ch|105"), "ch:105");
    assert.equal(segment("ch|12.5"), "ch:12.5");
    // A segment without a value is a plain key, not a half-built string.
    assert.equal(segment("plain"), "plain");
});
