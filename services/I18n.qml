pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "i18n.js" as Core

// Central i18n singleton. Quickshell module pattern (pragma Singleton +
// Singleton {} + `import qs.services`), so there is NO qmldir involved.
// Tables / t() / tn() / tData() live in services/i18n.js (unit-tested by
// tests/i18n.test.js).
//
// UI language precedence: QS_LANG (env) -> settings.json -> LANG -> "en".
// By default the UI follows the system locale; the panel toggle and the
// settings view write <config>/qs-novelmangareader/settings.json and change
// `lang` LIVE.
//
// The settings file has a single writer (services/UiPrefs.qml): this singleton
// reads `UiPrefs.language` and asks it to store a new one, so the language and
// the readers' `scrollFactor` can never clobber each other. `import
// qs.services` is therefore allowed here, and only for UiPrefs: the old rule
// (plan §14.3) was about not depending on the data services (Anime/Manga/
// Novel), which still holds — nothing else from qs.services is referenced.
//
// The CONTENT language is separate — QS_CONTENT_LANG, see content_lang.py.
Singleton {
    id: root

    // Highest priority: explicit env override (never persisted back).
    readonly property string envLang: Core.normalizeLang(Quickshell.env("QS_LANG"))
    // From settings.json, through its single writer; "" when unset/invalid.
    readonly property string settingsLang: UiPrefs.language
    readonly property string systemLang: Core.normalizeLang(Quickshell.env("LANG"))

    // Reactive UI language: the toggle and the settings view change it live.
    readonly property string lang: Core.resolveLang(root.envLang, root.settingsLang, root.systemLang)

    // True when QS_LANG pins the language: the settings row cannot win then.
    readonly property bool pinnedByEnv: root.envLang !== ""

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

    // Switch language live and persist it (through the single writer).
    function setLanguage(code) {
        UiPrefs.setLanguage(code)
    }

    function toggleLanguage() {
        root.setLanguage(root.lang === "es" ? "en" : "es")
    }
}
