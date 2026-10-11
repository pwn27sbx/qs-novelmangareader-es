"""Content-language preference, independent from the UI language.

The UI language follows the system locale (see services/I18n.qml:
QS_LANG -> LANG -> en). The language of the CONTENT the app fetches — anime
subtitles (WU-7) and MangaDex chapters (WU-8) — is a separate preference so the
content can be Spanish even while the UI is English.

Environment variable:
    QS_CONTENT_LANG   ordered, comma-separated list of language tags
                      (first language the source offers wins).
                      Default: "es".

Examples:
    QS_CONTENT_LANG="es-419,es"   -> ["es-419", "es"]
    QS_CONTENT_LANG="en"          -> ["en"]
    QS_CONTENT_LANG=""            -> ["es"]   (default)
"""

import os

DEFAULT_CONTENT_LANG = "es"


def content_langs(raw=None):
    """Return the ordered list of preferred content languages.

    ``raw`` defaults to the ``QS_CONTENT_LANG`` environment variable. Blank
    entries are dropped; when nothing remains, ``DEFAULT_CONTENT_LANG`` is used.
    """
    if raw is None:
        raw = os.environ.get("QS_CONTENT_LANG", "")
    langs = [part.strip() for part in str(raw).split(",")]
    langs = [lang for lang in langs if lang]
    return langs or [DEFAULT_CONTENT_LANG]


def content_lang(raw=None):
    """Return the most preferred content language (the first of ``content_langs``)."""
    return content_langs(raw)[0]
