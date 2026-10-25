// Pure helpers for <config>/qs-novelmangareader/settings.json.
//
// The file holds the user's preferences and is shared by the language toggle
// and the readers:
//
//   {
//     "language": "es",       // UI language (WU-11)
//     "scrollFactor": 2       // reader wheel speed, 1..10
//   }
//
// Every writer must preserve the keys it does not own: the language toggle
// used to serialise `{language}` alone, which would drop a scrollFactor the
// user had set. `withLanguage()` merges into whatever is already there.

var DEFAULT_SCROLL_FACTOR = 2;
var MIN_SCROLL_FACTOR = 1;
var MAX_SCROLL_FACTOR = 10;

function parseSettings(text) {
    try {
        var data = JSON.parse(String(text || ""));
        return (data && typeof data === "object" && !Array.isArray(data)) ? data : {};
    } catch (e) {
        return {};
    }
}

// A usable wheel multiplier: numbers and numeric strings accepted, clamped.
function normalizeScrollFactor(value) {
    var number = Number(value);
    if (!isFinite(number) || number <= 0)
        return DEFAULT_SCROLL_FACTOR;
    return Math.min(MAX_SCROLL_FACTOR, Math.max(MIN_SCROLL_FACTOR, number));
}

// Same document with ONE key set and everything else left alone. This is the
// only writer shape the app uses: the language row and the scroll slider each
// own their key, and neither may drop the other's.
function withSetting(text, key, value) {
    var data = parseSettings(text);
    data[String(key)] = value;
    return JSON.stringify(data, null, 2) + "\n";
}

// Kept as the language-shaped call site of withSetting().
function withLanguage(text, lang) {
    return withSetting(text, "language", String(lang || "en"));
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        DEFAULT_SCROLL_FACTOR: DEFAULT_SCROLL_FACTOR,
        MIN_SCROLL_FACTOR: MIN_SCROLL_FACTOR,
        MAX_SCROLL_FACTOR: MAX_SCROLL_FACTOR,
        parseSettings: parseSettings,
        normalizeScrollFactor: normalizeScrollFactor,
        withSetting: withSetting,
        withLanguage: withLanguage
    };
}
