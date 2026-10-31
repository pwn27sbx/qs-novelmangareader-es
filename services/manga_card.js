// Pure composition rules for the manga card (plan Fase 2).
//
// No QML/Quickshell dependency on purpose: "chapter · status" and its
// orphan-separator rules are unit-tested from tests/manga_card.test.js without
// a Wayland session.
//
// `chapter` must be treated as optional. The listings of MangaDex / zonatmo /
// zonatmo.org / ManhwaWeb carry it; the searches of zonatmo.org / WeebCentral /
// InManga do not, and library entries store no work metadata at all. A missing
// half drops its segment AND the separator that would otherwise dangle.

var SEPARATOR = " · ";

// null / undefined / whitespace-only all mean "no value".
function clean(value) {
    if (value === undefined || value === null) return "";
    return String(value).trim();
}

// metaLine("105", "Ongoing", t) -> t("ch|105") + " · Ongoing"
//
// `t` is called once per chapter segment and receives the whole "ch|105"
// string, so the module needs no language table: the caller maps that segment
// to "Ch. 105" / "Cap. 105" (see tSegment below). `status` is expected to be
// display-ready (already through I18n.tData); an unknown status passes through
// unchanged, like every other data value in this app.
function metaLine(chapter, status, t) {
    var parts = [];
    var ch = clean(chapter);
    var st = clean(status);
    if (ch !== "") parts.push(t("ch|" + ch));
    if (st !== "") parts.push(st);
    return parts.join(SEPARATOR);
}

// Adapt an I18n.t-style t(key, params) to metaLine's one-segment translator:
// "ch|105" -> t("ch", { 1: "105" }); anything without a value is a plain key.
function tSegment(t) {
    return function (segment) {
        var raw = String(segment);
        var cut = raw.indexOf("|");
        if (cut < 0) return t(raw);
        return t(raw.slice(0, cut), { 1: raw.slice(cut + 1) });
    };
}

// Exposed for the Node test runner only; QML's import ignores `module`.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        metaLine: metaLine,
        tSegment: tSegment
    };
}
