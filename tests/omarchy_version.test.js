"use strict";

// Omarchy version guard (Plan C, R-C2). `omarchy version` prints the pacman
// pkgver on a release install ("4.0.6-1") and "dev[ (hash)]" for a checkout
// pointed at by OMARCHY_PATH. The guard compares major.minor against the line
// the app is written against, so a 4.0.7 patch stays quiet and a 4.5 or a dev
// checkout warns that qs.Commons/qs.Ui may have moved.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const guard = require("../services/omarchy_version.js");

test("parseVersion() reduces a release version to major.minor", () => {
    assert.equal(guard.parseVersion("4.0.6-1"), "4.0");
    assert.equal(guard.parseVersion("4.5.0-1\n"), "4.5");
    assert.equal(guard.parseVersion("10.12.3"), "10.12");
});

test("parseVersion() reports a dev checkout as dev", () => {
    assert.equal(guard.parseVersion("dev"), "dev");
    assert.equal(guard.parseVersion("dev (a1b2c3d)"), "dev");
});

test("parseVersion() returns an empty line for unknown output", () => {
    assert.equal(guard.parseVersion(""), "");
    assert.equal(guard.parseVersion("   \n"), "");
    assert.equal(guard.parseVersion("garbage"), "");
});

test("isSupported() matches the declared major.minor only", () => {
    assert.equal(guard.isSupported("4.0", "4.0"), true);
    assert.equal(guard.isSupported("4.0", "4.5"), false);
    assert.equal(guard.isSupported("4.0", "3.9"), false);
    assert.equal(guard.isSupported("4.0", "dev"), false);
    assert.equal(guard.isSupported("4.0", ""), false);
});

test("warningMessage() names both versions and how to update", () => {
    const message = guard.warningMessage("4.0", "4.5");
    assert.match(message, /Omarchy 4\.5/);
    assert.match(message, /4\.0/);
    assert.match(message, /README/);
});

test("warningMessage() says unknown when the command failed", () => {
    assert.match(guard.warningMessage("4.0", ""), /unknown/);
});
