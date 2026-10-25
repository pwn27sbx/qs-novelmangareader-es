// Omarchy version guard (Plan C, R-C2), pure JS so `node --test` covers it.
//
// The app is written against one Omarchy major.minor line: its QML imports
// `qs.Commons` and `qs.Ui` from `/usr/share/omarchy/shell`, and those modules
// move between minors (4.0 → 4.5 changed the bar and component APIs). A patch
// release is expected to keep working, so only major.minor is compared.
//
// `omarchy version` prints the pacman pkgver on a release install and
// "dev[ (hash)]" when OMARCHY_PATH points at a checkout, so a dev build is
// always reported as unsupported rather than guessed.
//
// Top-level functions only: QML imports this file with
// `import "omarchy_version.js" as Core` and calls `Core.parseVersion(...)`,
// while `node --test` reads the guarded `module.exports` at the bottom (the
// same shape as services/anime_links.js).

// "4.0.6-1" -> "4.0"; "dev (a1b2c3d)" -> "dev"; anything else -> "".
function parseVersion(raw) {
    var text = String(raw === undefined || raw === null ? "" : raw).trim()
    if (text.length === 0) return ""
    if (/^dev\b/i.test(text)) return "dev"
    var match = text.match(/^v?(\d+)\.(\d+)/)
    if (!match) return ""
    return match[1] + "." + match[2]
}

function isSupported(supported, running) {
    return String(running || "") === String(supported || "")
}

function warningMessage(supported, running) {
    var shown = String(running || "") || "unknown"
    return "Omarchy " + shown + " is not the supported " + supported
        + ": qs.Commons/qs.Ui may have changed. Check the panels against the"
        + " Omarchy upgrade notes and update SUPPORTED_OMARCHY (see the"
        + " README, Updating Omarchy)."
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        parseVersion: parseVersion,
        isSupported: isSupported,
        warningMessage: warningMessage
    };
}
