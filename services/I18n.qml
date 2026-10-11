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

    // Language: QS_LANG wins; otherwise derived from LANG (es_* -> "es").
    // Normalised to a bare code so "es_ES", "es-419" and "en_US.UTF-8" all
    // resolve. Unknown codes fall back to English tables inside the core.
    //
    // Fixed at startup: t()/tn() are functions, so a runtime language change
    // is not reflected live. This is acceptable — the language is chosen at
    // launch (documented limitation, plan §C2).
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
}
