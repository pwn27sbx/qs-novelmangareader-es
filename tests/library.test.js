"use strict";

// Tests for services/library.js — which key names a title's library entry.
//
// A review of this change caught the bug these tests exist for: folding the
// "write key" fallback into the membership lookup made every open title report
// as already in the library, so the add button became unreachable.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const library = require("../services/library.js");

test("no entry means no key, not a fallback", () => {
    assert.equal(library.entryKey(["other:1"], ["zonatmo:x", "zonatmo_org:y"]), "");
});

test("the opened id wins when both keys exist", () => {
    assert.equal(library.entryKey(["zonatmo:x", "zonatmo_org:y"], ["zonatmo:x", "zonatmo_org:y"]),
                 "zonatmo:x");
});

test("an entry stored under the answering source is still found", () => {
    assert.equal(library.entryKey(["zonatmo_org:y"], ["zonatmo:x", "zonatmo_org:y"]),
                 "zonatmo_org:y");
});

test("empty or missing inputs are tolerated", () => {
    assert.equal(library.entryKey(null, null), "");
    assert.equal(library.entryKey([], ["a"]), "");
    assert.equal(library.entryKey(["a"], [""]), "");
});
