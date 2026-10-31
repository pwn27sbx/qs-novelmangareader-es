"use strict";

// Tests for services/theme.js — deciding when the panel must re-read the
// Omarchy palette.
//
// Omarchy's Commons/Color.qml loads colors.toml and shell.toml once
// (`watchChanges: false`) and pushes live theme switches through its own shell
// IPC, which only the main shell receives. Our panels are a separate
// Quickshell instance, so they kept the palette they started with; they follow
// ~/.local/state/omarchy/current/theme.name instead.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const theme = require("../services/theme.js");

test("themeName drops the trailing newline the theme setter writes", () => {
    assert.equal(theme.themeName("everforest\n"), "everforest");
    assert.equal(theme.themeName("  gruvbox  "), "gruvbox");
    assert.equal(theme.themeName(""), "");
    assert.equal(theme.themeName(null), "");
});

test("a different theme asks for a reload", () => {
    assert.equal(theme.shouldReload("gruvbox", "everforest"), true);
});

test("the same theme does not", () => {
    assert.equal(theme.shouldReload("everforest", "everforest"), false);
});

test("a blank name never triggers a reload", () => {
    assert.equal(theme.shouldReload("everforest", ""), false);
    assert.equal(theme.shouldReload("", ""), false);
});
