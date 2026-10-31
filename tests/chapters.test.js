"use strict";

// Tests for services/chapters.js — locating "the chapter where I left off".
//
// The library stores lastReadChapterNum as the string the reader saved
// ("105"), while a source may list the same chapter as "105.00"
// (zonatmo.org) or "Capítulo 105". After the 2026-10-27 source switch the
// stored lastReadChapterId stopped matching any row, so the "Last: Ch. N"
// badge had to compare numbers instead of ids.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const chapters = require("../services/chapters.js");

test("formatChapter keeps the digits and an optional decimal", () => {
    assert.equal(chapters.formatChapter("Capítulo 105.00"), "105.00");
    assert.equal(chapters.formatChapter("105"), "105");
    assert.equal(chapters.formatChapter("?45"), "45");
    assert.equal(chapters.formatChapter(""), "?");
    assert.equal(chapters.formatChapter(null), "?");
    assert.equal(chapters.formatChapter("extra"), "extra");
});

test("a stored 105 reaches the row listed as 105.00", () => {
    const list = [{ chapter: "106.00" }, { chapter: "105.00" }, { chapter: "104.00" }];
    assert.equal(chapters.chapterIndex(list, "105"), 1);
});

test("a decimal chapter never matches its integer neighbour", () => {
    const list = [{ chapter: "105" }, { chapter: "105.5" }];
    assert.equal(chapters.chapterIndex(list, "105.5"), 1);
    assert.equal(chapters.chapterIndex(list, "105"), 0);
});

test("an empty or missing list has no index", () => {
    assert.equal(chapters.chapterIndex([], "105"), -1);
    assert.equal(chapters.chapterIndex(null, "105"), -1);
    assert.equal(chapters.chapterIndex([{ chapter: "1" }], ""), -1);
});

test("the first matching row wins", () => {
    const list = [{ chapter: "7.00" }, { chapter: "7.0" }, { chapter: "8" }];
    assert.equal(chapters.chapterIndex(list, "7"), 0);
});
