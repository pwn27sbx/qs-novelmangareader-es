pragma Singleton
import QtQuick
import Quickshell
import "i18n.js" as Core

// Central i18n singleton. Follows the repo's Quickshell module pattern
// (pragma Singleton + Singleton {} + `import qs.services`), so there is NO
// qmldir involved. The translation tables and t()/tn() logic live in
// services/i18n.js (pure JS, unit-tested by tests/i18n.test.js).
//
// Usage from a view:
//     text: I18n.t("tab.browse")
//     text: I18n.t("last.ep", { 1: modelData.number })
//     text: I18n.tn("count.chapter", model.count)
//
// This singleton must NOT import qs.services nor reference Anime/Manga/Novel
// (avoids a dependency cycle — see plan §14.3).
Singleton {
    id: root

    // UI language: QS_LANG (explicit override) -> derived from LANG (es_* ->
    // "es") -> "en". The UI follows the system locale: on this machine
    // (LANG=en_US.UTF-8) it is ENGLISH by default. Force Spanish with
    // QS_LANG=es. Normalised to a bare code so "es_419"/"en_US.UTF-8" resolve.
    //
    // This is the UI language ONLY. The language of the CONTENT the app fetches
    // (anime subtitles, MangaDex chapters) is a separate preference —
    // QS_CONTENT_LANG, default "es"; see scripts/content_lang.py.
    //
    // Fixed at startup: t()/tn() are functions, so a runtime language change
    // is not reflected live. The language is chosen at launch (plan §C2).
    readonly property string lang: {
        const raw = Quickshell.env("QS_LANG") || Quickshell.env("LANG") || ""
        const code = raw.split(/[_.@-]/)[0].toLowerCase()
        return code === "" ? "en" : code
    }

    function t(key, params) {
        return Core.t(lang, key, params)
    }

    function tn(key, n, params) {
        return Core.tn(lang, key, n, params)
    }

    // Localize a status/type data value returned by a source (e.g. "Ongoing",
    // "Movie"); unknown values are returned unchanged.
    function tData(value) {
        return Core.tData(lang, value)
    }
}
