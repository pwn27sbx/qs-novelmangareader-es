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
        "ch": "Cap. %1",
        "chapter": "Capítulo %1",
        "last.ep": "Último: Ep. %1",
        "last.ch": "Último: Cap. %1",
        "page": "pág. %1",
        "words": "%1 mil palabras",
        "count.episode": { one: "%1 episodio", other: "%1 episodios" },
        "count.chapter": { one: "%1 capítulo", other: "%1 capítulos" },

        // ── List controls (shared) ──────────────────────────────────────
        "filterChapters": "Filtrar capítulos…",
        "sort.ascending": "Orden: Ascendente",
        "sort.descending": "Orden: Descendente",

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
        "anime.subtitles": "Subtítulos: %1",
        "anime.mpvTitle": "Anime",

        // ── Manga ───────────────────────────────────────────────────────
        "panel.manga": "manga",
        "manga.search": "Buscar títulos…",
        "manga.filter.hot": "Tendencias",
        "manga.filter.latest": "Recientes",
        "manga.library.hint": "Abre cualquier manga y toca  + Biblioteca",
        "manga.loadingPages": "cargando páginas",
        "manga.invalidResponse": "Respuesta no válida",
        "manga.noPages": "No se encontraron páginas para este capítulo",
        "manga.pageFailed": "no se pudo cargar",
        "manga.noSpanishNotice": "No se encontraron capítulos en español para este título",
        "manga.sourcesTried": "Fuentes consultadas: %1",
        "manga.searchOtherSources": "Buscar en otras fuentes",

        // ── Novel ───────────────────────────────────────────────────────
        "panel.novel": "novelas",
        "novel.search": "Buscar novelas…",
        "novel.filter.hot": "Tendencias",
        "novel.filter.latest": "Recientes",
        "novel.library.hint": "Abre cualquier novela y toca  + Biblioteca",
        "novel.listIncomplete": "· lista incompleta — toca para cargar el resto",
        "novel.nextChapter": "Siguiente capítulo",
        "novel.loadFailed": "No se pudo cargar esta novela"
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
        "ch": "Ch. %1",
        "chapter": "Chapter %1",
        "last.ep": "Last: Ep. %1",
        "last.ch": "Last: Ch. %1",
        "page": "p. %1",
        "words": "%1k words",
        "count.episode": { one: "%1 episode", other: "%1 episodes" },
        "count.chapter": { one: "%1 chapter", other: "%1 chapters" },

        // ── List controls (shared) ──────────────────────────────────────
        "filterChapters": "Filter chapters…",
        "sort.ascending": "Sort: Ascending",
        "sort.descending": "Sort: Descending",

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
        "anime.subtitles": "Subtitles: %1",
        "anime.mpvTitle": "Anime",

        // ── Manga ───────────────────────────────────────────────────────
        "panel.manga": "manga",
        "manga.search": "Search titles…",
        "manga.filter.hot": "Hot",
        "manga.filter.latest": "Latest",
        "manga.library.hint": "Open any manga and tap  + Library",
        "manga.loadingPages": "loading pages",
        "manga.invalidResponse": "Invalid response",
        "manga.noPages": "No pages found for this chapter",
        "manga.pageFailed": "failed to load",
        "manga.noSpanishNotice": "No Spanish chapters found for this title",
        "manga.sourcesTried": "Sources checked: %1",
        "manga.searchOtherSources": "Search other sources",

        // ── Novel ───────────────────────────────────────────────────────
        "panel.novel": "novels",
        "novel.search": "Search novels…",
        "novel.filter.hot": "Hot",
        "novel.filter.latest": "Latest",
        "novel.library.hint": "Open any novel and tap  + Library",
        "novel.listIncomplete": "· list incomplete — tap to load the rest",
        "novel.nextChapter": "Next Chapter",
        "novel.loadFailed": "Couldn't load this novel"
    }
};

// Known data values that the sources return and the UI renders verbatim
// (status / type badges). Keyed by the raw English value; lookups are
// case-insensitive so "OnGoing" also matches. Unknown values fall back to the
// original string, so unfamiliar statuses never disappear.
var display = {
    es: {
        "Ongoing": "En curso",
        "Completed": "Completada",
        "Hiatus": "En pausa",
        "Cancelled": "Cancelada",
        "Movie": "Película",
        "Special": "Especial",
        "TV": "TV",
        "OVA": "OVA",
        "ONA": "ONA"
    },
    en: {
        "Ongoing": "Ongoing",
        "Completed": "Completed",
        "Hiatus": "Hiatus",
        "Cancelled": "Cancelled",
        "Movie": "Movie",
        "Special": "Special",
        "TV": "TV",
        "OVA": "OVA",
        "ONA": "ONA"
    }
};

// Display labels for the manga source ids the backend reports in
// `sourcesTried` (plan §F3). Brand names read the same in English and Spanish,
// so a single map is enough; unknown ids fall back to the raw id.
var sources = {
    "mangadex": "MangaDex",
    "inmanga": "InManga",
    "zonatmo": "ZonaTMO (.net)",
    "zonatmo_org": "ZonaTMO (.org)",
    "weebcentral": "WeebCentral"
};

// tSource("zonatmo_org") -> "ZonaTMO (.org)"; unknown id -> the id itself.
function tSource(id) {
    var key = String(id === undefined || id === null ? "" : id);
    return sources[key] !== undefined ? sources[key] : key;
}

// Replace %1, %2, … with the matching entry of `params` (1-based).
function interpolate(str, params) {    if (!params || typeof str !== "string") {
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

// Display a known status/type data value; fall back to the raw value.
// tData("es", "Ongoing") -> "En curso"; tData("es", "Whatever") -> "Whatever".
function tData(lang, value) {
    if (value === undefined || value === null || value === "") {
        return value;
    }
    var table = display[lang] || display.en;
    var raw = String(value);
    if (table[raw] !== undefined) {
        return table[raw];
    }
    var lower = raw.toLowerCase();
    for (var key in table) {
        if (key.toLowerCase() === lower) {
            return table[key];
        }
    }
    return value;
}

// ── Language resolution & settings (WU-11) ─────────────────────────────────

// "es_419" / "es-419" / "en_US.UTF-8" -> "es" / "es" / "en".
function normalizeLang(code) {
    return String(code === undefined || code === null ? "" : code)
        .split(/[_.@-]/)[0]
        .toLowerCase();
}

// UI language precedence: QS_LANG (env) -> settings.json -> LANG -> "en".
function resolveLang(envLang, settingsLang, systemLang) {
    var env = normalizeLang(envLang);
    if (env) {
        return env;
    }
    var settings = normalizeLang(settingsLang);
    if (settings) {
        return settings;
    }
    var system = normalizeLang(systemLang);
    return system === "" ? "en" : system;
}

// Language stored in settings.json: "en" | "es" | "" (unset / invalid).
function settingsLanguage(text) {
    try {
        var data = JSON.parse(text);
        var code = normalizeLang(data && data.language);
        return (code === "en" || code === "es") ? code : "";
    } catch (e) {
        return "";
    }
}

// Serialised settings.json contents for a language.
function settingsJson(lang) {
    return JSON.stringify({ language: normalizeLang(lang) === "es" ? "es" : "en" }, null, 2) + "\n";
}

// Exposed for the Node test runner only; QML's import ignores `module`.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        tables: tables,
        display: display,
        sources: sources,
        t: t,
        tn: tn,
        tData: tData,
        tSource: tSource,
        normalizeLang: normalizeLang,
        resolveLang: resolveLang,
        settingsLanguage: settingsLanguage,
        settingsJson: settingsJson
    };
}
