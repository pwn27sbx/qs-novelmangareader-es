// Pure helpers for following the live Omarchy theme.
//
// Omarchy writes ~/.local/state/omarchy/current/theme.name once per theme
// change, AFTER the new colors.toml/shell.toml are in place. Watching that one
// file is what lets a separate Quickshell instance (our panels) re-read the
// palette; Commons.Color itself only loads it at startup.

// "everforest\n" -> "everforest"
function themeName(raw) {
    return String(raw === null || raw === undefined ? "" : raw).replace(/^\s+|\s+$/g, "");
}

// A reload is only needed when a real, different theme arrived. A blank name
// means the file was being rewritten, not that the theme went away.
function shouldReload(previous, next) {
    var name = themeName(next);
    return name !== "" && name !== themeName(previous);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        themeName: themeName,
        shouldReload: shouldReload
    };
}
