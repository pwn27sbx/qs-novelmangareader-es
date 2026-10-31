// Which id names the open title's library entry.
//
// A library entry is stored under the id the title was added with. That used
// to be whichever source answered, and is now the id the user opened
// (`originId`), so the same work can exist under either key in a library
// written across both schemes.
//
// Two questions, deliberately separate:
//   * `entryKey` — does an entry ALREADY exist, and under which key? Returns ""
//     when there is none, so it can gate an "in library" badge.
//   * the caller's write key — the existing key, or the opened id for a new
//     entry. Folding that fallback into `entryKey` once made every title look
//     "in library" and made adding impossible.

function entryKey(available, wanted) {
    // No prototype: a key named "constructor" must not read as present.
    var have = Object.create(null);
    var list = available || [];
    var candidates = wanted || [];
    for (var i = 0; i < list.length; i++) have[list[i]] = true;
    for (var j = 0; j < candidates.length; j++) {
        if (candidates[j] && have[candidates[j]]) return candidates[j];
    }
    return "";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { entryKey: entryKey };
}
