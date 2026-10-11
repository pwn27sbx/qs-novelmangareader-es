"use strict";

// Guard for the Fase R1 UI tokenization: no view may hard-code a radius,
// spacing, motion duration or font size instead of asking `qs.Commons.Style`.
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const lint = require("../tools/lint-style.js");

test("no raw style tokens in the UI", () => {
    const { violations } = lint.check();
    assert.deepEqual(violations, [],
        "raw tokens found:\n" + JSON.stringify(violations, null, 2));
});
