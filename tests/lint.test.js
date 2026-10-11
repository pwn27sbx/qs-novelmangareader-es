"use strict";

// Guards for the i18n migration:
//   1. no raw English literal left in a UI text property (must be I18n.t(...)),
//   2. every key referenced by I18n.t()/tn() exists in the es/en tables.
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const lint = require("../tools/lint-i18n.js");

test("no raw English literals in UI text properties", () => {
    const violations = lint.checkLiterals();
    assert.deepEqual(violations, [],
        "raw literals found:\n" + JSON.stringify(violations, null, 2));
});

test("every I18n.t/tn key used in QML exists in the table", () => {
    const violations = lint.checkUsedKeys();
    assert.deepEqual(violations, [],
        "unknown keys found:\n" + JSON.stringify(violations, null, 2));
});
