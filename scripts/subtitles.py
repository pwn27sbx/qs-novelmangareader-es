"""Subtitle-track selection for the ZokoAnime embed (stdlib only).

The embed lists several subtitle tracks and marks English as ``default``. Its
``lang`` field is a constant ``"en"`` (verified across shows — useless), so
tracks are matched by the human-readable ``label`` (e.g.
``"Spanish (Spanish - [Full])"``).

Preferred languages come from ``scripts/content_lang.py`` (``QS_CONTENT_LANG``,
default ``"es"``). For a Spanish preference the generic / Latin American track
is preferred over the Castilian one; when nothing matches, the ``default``
(English) track is returned so playback keeps working.
"""

import re

import content_lang

# label keyword per bare language code; falls back to the code itself.
_LABEL_KEYWORDS = {
    "es": "spanish",
    "en": "english",
    "pt": "portuguese",
    "fr": "french",
    "de": "german",
    "it": "italian",
    "ja": "japanese",
    "ko": "korean",
    "zh": "chinese",
    "ar": "arabic",
    "ru": "russian",
    "tr": "turkish",
    "pl": "polish",
    "nl": "dutch",
    "sv": "swedish",
    "da": "danish",
    "fi": "finnish",
    "no": "norwegian",
    "id": "indonesian",
    "vi": "vietnamese",
    "th": "thai",
    "hi": "hindi",
    "he": "hebrew",
    "cs": "czech",
    "el": "greek",
    "hu": "hungarian",
    "ro": "romanian",
    "uk": "ukrainian",
}


def base_lang(tag):
    """Bare language code of a tag: "es-419" -> "es", "pt_BR" -> "pt"."""
    return re.split(r"[-_]", (tag or "").strip().lower(), maxsplit=1)[0]


def label_keyword(tag):
    """Keyword to look for inside a subtitle label for this tag."""
    base = base_lang(tag)
    return _LABEL_KEYWORDS.get(base, base)


def label_matches(label, tag):
    """True when the subtitle ``label`` names the language of ``tag``."""
    keyword = label_keyword(tag)
    return bool(keyword) and keyword in (label or "").lower()


def is_castilian(label):
    return "castilian" in (label or "").lower()


def pick_subtitle(subtitles, langs=None):
    """Return the best subtitle entry for the preferred content languages.

    ``langs`` defaults to ``content_lang.content_langs()`` (QS_CONTENT_LANG).
    For Spanish preferences a non-Castilian (generic / Latin American) track is
    chosen in preference to the Castilian one. Unknown languages fall back to
    the entry marked ``default`` (or the first entry).
    """
    subs = [s for s in (subtitles or []) if isinstance(s, dict)]
    if not subs:
        return None

    prefs = langs if langs is not None else content_lang.content_langs()
    for tag in prefs:
        matches = [s for s in subs if label_matches(s.get("label", ""), tag)]
        if not matches:
            continue
        if base_lang(tag) == "es":
            generic = [s for s in matches if not is_castilian(s.get("label", ""))]
            if generic:
                return generic[0]
        return matches[0]

    default = next((s for s in subs if s.get("default")), None)
    return default if default is not None else subs[0]
