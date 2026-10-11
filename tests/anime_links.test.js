"use strict";

// Tests for services/anime_links.js — the /links parsing used by Anime.qml.
// Run with: node --test

const test = require("node:test");
const assert = require("node:assert/strict");

const links = require("../services/anime_links.js");

const VALID = {
    url: "https://x/1.m3u8",
    quality: "1080p",
    type: "m3u8",
    provider: "ZokoAnime",
    referer: "https://x/",
    subtitle: "https://x/s.vtt",
    subtitle_label: "Spanish (Spanish - [Full])"
};

test("no `selected` -> uses the first link and its subtitle label", () => {
    const r = links.parseStreamLinks(JSON.stringify({ all_links: [VALID], selected: null }));
    assert.equal(r.streamLinks.length, 1);
    assert.equal(r.selectedLink.url, VALID.url);
    assert.equal(r.subtitleLabel, "Spanish (Spanish - [Full])");
    assert.equal(r.error, "");
});

test("`selected` wins when valid", () => {
    const r = links.parseStreamLinks(JSON.stringify({
        all_links: [VALID],
        selected: { url: "https://x/2.m3u8", subtitle_label: "English" }
    }));
    assert.equal(r.selectedLink.url, "https://x/2.m3u8");
    assert.equal(r.subtitleLabel, "English");
});

test("empty all_links -> clean empty fallback, no selectedLink", () => {
    const r = links.parseStreamLinks(JSON.stringify({ all_links: [], selected: null }));
    assert.equal(r.empty, true);
    assert.deepEqual(r.streamLinks, []);
    assert.equal(r.selectedLink, null);
    assert.equal(r.subtitleLabel, "");
});

test("links without url / with error are filtered -> empty", () => {
    const r = links.parseStreamLinks(JSON.stringify({
        all_links: [{ url: "", quality: "1080p" }, { error: "nope" }]
    }));
    assert.equal(r.empty, true);
    assert.equal(r.selectedLink, null);
});

test("invalid `selected` falls back to the first link", () => {
    const r = links.parseStreamLinks(JSON.stringify({
        all_links: [VALID],
        selected: { error: "bad" }
    }));
    assert.equal(r.selectedLink.url, VALID.url);
    assert.equal(r.subtitleLabel, "Spanish (Spanish - [Full])");

    const r2 = links.parseStreamLinks(JSON.stringify({
        all_links: [VALID],
        selected: { url: "" }
    }));
    assert.equal(r2.selectedLink.url, VALID.url);
});

test("missing optional fields get safe defaults", () => {
    const r = links.parseStreamLinks(JSON.stringify({ all_links: [{ url: "https://x/y" }] }));
    assert.equal(r.selectedLink.quality, "?");
    assert.equal(r.selectedLink.type, "mp4");
    assert.equal(r.selectedLink.subtitle_label, "");
    assert.equal(r.subtitleLabel, "");
});

test("backend error is propagated", () => {
    const r = links.parseStreamLinks(JSON.stringify({ error: "Missing required param: id" }));
    assert.equal(r.error, "Missing required param: id");
    assert.equal(r.selectedLink, null);
    assert.equal(r.subtitleLabel, "");
});

test("invalid JSON throws (caller reports a parse error)", () => {
    assert.throws(() => links.parseStreamLinks("not json"));
});
