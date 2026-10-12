pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "i18n.js" as Core

// Central i18n singleton. Quickshell module pattern (pragma Singleton +
// Singleton {} + `import qs.services`), so there is NO qmldir involved.
// Tables / t() / tn() / tData() live in services/i18n.js (unit-tested by
// tests/i18n.test.js).
//
// UI language precedence: QS_LANG (env) -> settings.json -> LANG -> "en".
// By default the UI follows the system locale; the small panel toggle writes
// <config>/qs-novelmangareader/settings.json and changes `lang` LIVE.
//
// The CONTENT language is separate — QS_CONTENT_LANG, see content_lang.py.
//
// Must NOT import qs.services nor reference Anime/Manga/Novel (plan §14.3).
Singleton {
    id: root

    readonly property string settingsDir: {
        const base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
        return base + "/qs-novelmangareader"
    }
    readonly property string settingsPath: root.settingsDir + "/settings.json"

    // Highest priority: explicit env override (never persisted back).
    readonly property string envLang: Core.normalizeLang(Quickshell.env("QS_LANG"))
    // Loaded from settings.json; "" until loaded or when unset/invalid.
    property string settingsLang: ""
    readonly property string systemLang: Core.normalizeLang(Quickshell.env("LANG"))

    // Reactive UI language: the panel toggle changes it live via setLanguage().
    property string lang: Core.resolveLang(root.envLang, root.settingsLang, root.systemLang)

    function t(key, params) {
        return Core.t(lang, key, params)
    }

    function tn(key, n, params) {
        return Core.tn(lang, key, n, params)
    }

    // Localize a status/type data value returned by a source (e.g. "Ongoing",
    // "Movie"); unknown values are returned unchanged.
    function tData(value) {
        return Core.tData(lang, value);
    }

    // Display label for a manga source id (e.g. "zonatmo_org" -> "ZonaTMO
    // (.org)"); unknown ids are returned unchanged.
    function tSource(id) {
        return Core.tSource(id);
    }

    // Switch language live and persist it to settings.json.
    function setLanguage(code) {
        const next = Core.normalizeLang(code) === "es" ? "es" : "en"
        root.lang = next
        root.settingsLang = next
        settingsWriter.setText(Core.settingsJson(next))
        settingsWriter.save()
    }

    function toggleLanguage() {
        root.setLanguage(root.lang === "es" ? "en" : "es")
    }

    // Read settings.json at startup.
    FileView {
        id: settingsReader
        path: root.settingsPath
        onLoaded: root.settingsLang = Core.settingsLanguage(settingsReader.text())
        onLoadFailed: root.settingsLang = ""
    }

    // Write settings.json on toggle.
    FileView {
        id: settingsWriter
        path: root.settingsPath
    }

    // The config dir may not exist on a fresh setup; create it before writing.
    Process {
        id: ensureDir
        command: ["mkdir", "-p", root.settingsDir]
    }

    Component.onCompleted: {
        ensureDir.running = true
        settingsReader.reload()
    }
}
