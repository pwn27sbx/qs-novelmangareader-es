// Pure translation core for services/I18n.qml.
//
// No QML/Quickshell dependency on purpose:
//   * English is the source language — every key is an English id and the
//     `en` table mirrors the original wording, so wrapping a string never
//     destroys the English text (keeps rebases against upstream clean).
//   * Keeping the tables and the t()/tn() logic in plain JS makes them
//     unit-testable from tests/i18n.test.js without a Wayland session.
//
// Keys follow the plan inventory (§6): "<area>.<thing>", e.g. "tab.browse".

var tables = {
    es: {
        // ── Shared chrome ───────────────────────────────────────────────
        "tab.browse": "Explorar",
        "tab.library": "Biblioteca",
        "state.loading": "cargando",
        "state.loadingMore": "cargando más…",
        "state.notStarted": "Sin empezar",
        "empty.library": "Tu biblioteca está vacía",
        "action.retry": "Reintentar",
        "action.prev": "Anterior",
        "action.next": "Siguiente",
        "action.continue": "Continuar",
        "error.request": "La solicitud falló: %1",
        "error.parse": "Error de análisis: %1",
        "error.server": "Error del servidor: %1",

        // ── Interpolation / counts (plan §6, F1-7) ──────────────────────
        "ep": "Ep. %1",
        "episode": "Episodio %1",
        "last.ep": "Último: Ep. %1",
        "last.ch": "Último: Cap. %1",
        "page": "pág. %1",
        "words": "%1 mil palabras",
        "count.episode": { one: "%1 episodio", other: "%1 episodios" },
        "count.chapter": { one: "%1 capítulo", other: "%1 capítulos" },

        // ── Anime ───────────────────────────────────────────────────────
        "panel.anime": "anime",
        "anime.search": "Buscar anime…",
        "anime.filter.popular": "Popular",
        "anime.filter.latest": "Recientes",
        "anime.filter.japan": "Japón",
        "anime.filter.china": "China",
        "anime.filter.korea": "Corea",
        "anime.library.title": "Biblioteca de anime",
        "anime.library.hint": "Abre cualquier anime y toca  + Biblioteca",
        "anime.fetching": "cargando el video",
        "anime.noStream": "No se encontró una transmisión para este episodio",
        "anime.epCount": "%1 ep",
        "anime.mpvTitle": "Anime"
    },

    en: {
        // ── Shared chrome ───────────────────────────────────────────────
        "tab.browse": "Browse",
        "tab.library": "Library",
        "state.loading": "loading",
        "state.loadingMore": "more is on its way",
        "state.notStarted": "Not started",
        "empty.library": "Your library is empty",
        "action.retry": "Retry",
        "action.prev": "Prev",
        "action.next": "Next",
        "action.continue": "Continue",
        "error.request": "Request failed: %1",
        "error.parse": "Parse error: %1",
        "error.server": "Server error: %1",

        // ── Interpolation / counts (plan §6, F1-7) ──────────────────────
        "ep": "Ep. %1",
        "episode": "Episode %1",
        "last.ep": "Last: Ep. %1",
        "last.ch": "Last: Ch. %1",
        "page": "p. %1",
        "words": "%1k words",
        "count.episode": { one: "%1 episode", other: "%1 episodes" },
        "count.chapter": { one: "%1 chapter", other: "%1 chapters" },

        // ── Anime ───────────────────────────────────────────────────────
        "panel.anime": "anime",
        "anime.search": "Search anime…",
        "anime.filter.popular": "Popular",
        "anime.filter.latest": "Latest",
        "anime.filter.japan": "Japan",
        "anime.filter.china": "China",
        "anime.filter.korea": "Korea",
        "anime.library.title": "Anime Library",
        "anime.library.hint": "Open any anime and tap  + Library",
        "anime.fetching": "fetching stream",
        "anime.noStream": "No working stream found for this episode",
        "anime.epCount": "%1 ep",
        "anime.mpvTitle": "Anime"
    }
};

// Replace %1, %2, … with the matching entry of `params` (1-based).
function interpolate(str, params) {
    if (!params || typeof str !== "string") {
        return str;
    }
    return str.replace(/%(\d+)/g, function (_, n) {
        var value = params[n];
        return (value === undefined || value === null) ? "" : String(value);
    });
}

// Look a key up in `lang`, then English, then return the key itself.
function lookup(lang, key) {
    var table = tables[lang];
    if (table && table[key] !== undefined) {
        return table[key];
    }
    if (tables.en[key] !== undefined) {
        return tables.en[key];
    }
    return key;
}

// A plural entry is an object { one, other }; collapse it to a string.
function asString(entry) {
    if (entry && typeof entry === "object") {
        return (entry.other !== undefined) ? entry.other : entry.one;
    }
    return entry;
}

// t("es", "tab.browse")            -> "Explorar"
// t("es", "page", { 1: 7 })        -> "pág. 7"
function t(lang, key, params) {
    return interpolate(asString(lookup(lang, key)), params);
}

// tn("es", "count.chapter", 1) -> "1 capítulo"
// tn("es", "count.chapter", 3) -> "3 capítulos"
// In tn(), %1 is always the count.
function tn(lang, key, n, params) {
    var entry = lookup(lang, key);
    var merged = {};
    if (params) {
        for (var k in params) {
            merged[k] = params[k];
        }
    }
    merged[1] = n;

    if (entry && typeof entry === "object") {
        var form = (n === 1 && entry.one !== undefined) ? entry.one : entry.other;
        entry = (form !== undefined) ? form : entry.one;
    }
    return interpolate(entry, merged);
}

// Exposed for the Node test runner only; QML's import ignores `module`.
if (typeof module !== "undefined" && module.exports) {
    module.exports = { tables: tables, t: t, tn: tn };
}
