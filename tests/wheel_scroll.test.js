"use strict";

// Tests for components/wheel_scroll.js — the reader wheel arithmetic.
//
// The bug this pins: a touchpad sends only pixelDelta, and the first version
// negated it, so a two-finger scroll went backwards. Mouse (angleDelta) and
// touchpad (pixelDelta) must move the same way for the same gesture.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const wheel = require("../components/wheel_scroll.js");

test("stepOf() reads the mouse angle when present", () => {
    assert.equal(wheel.stepOf(120, 0), 120);
    assert.equal(wheel.stepOf(-120, 0), -120);
});

test("stepOf() falls back to the touchpad pixels", () => {
    assert.equal(wheel.stepOf(0, 25), 25);
    assert.equal(wheel.stepOf(0, -25), -25);
});

test("a wheel notch down moves the page forward, notch up moves it back", () => {
    assert.equal(wheel.nextContentY(1000, -120, 0, 2, 5000), 1240);
    assert.equal(wheel.nextContentY(1000, 120, 0, 2, 5000), 760);
});

test("a touchpad swipe follows the same direction as the wheel", () => {
    // Swipe up (content should move down) carries a negative pixelDelta.
    assert.equal(wheel.nextContentY(1000, 0, -25, 2, 5000), 1050);
    assert.equal(wheel.nextContentY(1000, 0, 25, 2, 5000), 950);
});

test("the factor multiplies, and 1 is the raw step", () => {
    assert.equal(wheel.nextContentY(500, -120, 0, 1, 5000), 620);
    assert.equal(wheel.nextContentY(500, -120, 0, 4, 5000), 980);
});

test("it stops at both ends instead of overshooting", () => {
    assert.equal(wheel.nextContentY(10, 120, 0, 2, 5000), 0);
    assert.equal(wheel.nextContentY(4990, -120, 0, 2, 5000), 5000);
});

test("a missing or impossible limit becomes zero, never negative", () => {
    assert.equal(wheel.nextContentY(300, -120, 0, 2, -5), 0);
    assert.equal(wheel.nextContentY(300, -120, 0, 2, undefined), 0);
});
