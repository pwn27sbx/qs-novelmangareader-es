// Pure helpers for <config>/qs-novelmangareader/settings.json.
//
// The file holds the user's preferences and is shared by the language toggle
// and the readers:
//
//   {
//     "language": "es",       // UI language (WU-11)
//     "scrollFactor": 2,      // reader wheel speed, 0.5..5
//     "viewMode": "grid"      // manga Browse/Library layout: "grid" | "list"
//   }
//
// Every writer must preserve the keys it does not own: the language toggle
// used to serialise `{language}` alone, which would drop a scrollFactor the
// user had set. `withLanguage()` merges into whatever is already there.

var DEFAULT_SCROLL_FACTOR = 2;
// 0.5 is half the fastest "slow" a reader wants on a long strip; 5 already
// moves ~1.3 notches per page, so 10 was a jump bigger than a page.
var MIN_SCROLL_FACTOR = 0.5;
var MAX_SCROLL_FACTOR = 5;

// The manga Browse/Library layout. Grid is what every user had before the
// toggle existed, so it is the default when the key is missing or unreadable.
var DEFAULT_VIEW_MODE = "grid";
var VIEW_MODES = ["grid", "list"];

function parseSettings(text) {
    try {
        var data = JSON.parse(String(text || ""));
        return (data && typeof data === "object" && !Array.isArray(data)) ? data : {};
    } catch (e) {
        return {};
    }
}

// A usable wheel multiplier: numbers and numeric strings accepted, clamped and
// rounded to one decimal (a slider with step 0.1 accumulates 1.2000000001).
function normalizeScrollFactor(value) {
    var number = Number(value);
    if (!isFinite(number) || number <= 0)
        return DEFAULT_SCROLL_FACTOR;
    var clamped = Math.min(MAX_SCROLL_FACTOR, Math.max(MIN_SCROLL_FACTOR, number));
    return Math.round(clamped * 10) / 10;
}

// The single place the UI language is coerced: anything Spanish-ish ("es",
// "es-419", "ES") becomes "es"; everything else becomes "en".
function normalizeLanguage(value) {
    return String(value || "").trim().toLowerCase().indexOf("es") === 0 ? "es" : "en";
}

// "grid" | "list", and nothing else: a hand-edited settings.json, an older
// file without the key, or an object where a string belongs all fall back to
// the default instead of leaving the views with a layout they cannot build.
function normalizeViewMode(value) {
    var mode = String(value === undefined || value === null ? "" : value).trim().toLowerCase();
    return VIEW_MODES.indexOf(mode) >= 0 ? mode : DEFAULT_VIEW_MODE;
}

// Same document with ONE key set and everything else left alone. This is the
// only writer shape the app uses: the language row and the scroll slider each
// own their key, and neither may drop the other's.
function withSetting(text, key, value) {
    var data = parseSettings(text);
    data[String(key)] = value;
    return JSON.stringify(data, null, 2) + "\n";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        DEFAULT_SCROLL_FACTOR: DEFAULT_SCROLL_FACTOR,
        MIN_SCROLL_FACTOR: MIN_SCROLL_FACTOR,
        MAX_SCROLL_FACTOR: MAX_SCROLL_FACTOR,
        parseSettings: parseSettings,
        normalizeScrollFactor: normalizeScrollFactor,
        withSetting: withSetting,
        normalizeLanguage: normalizeLanguage,
        DEFAULT_VIEW_MODE: DEFAULT_VIEW_MODE,
        normalizeViewMode: normalizeViewMode
    };
}
