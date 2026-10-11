"""Manga source chain (Spanish): MangaDex -> InManga.

Every endpoint returns the same JSON contract as manga_server.py, with item ids
prefixed by the source (``mangadex:<id>`` / ``inmanga:<id>``) so info()/pages()
can route back to the source that produced them.

Language fall-through: MangaDex (es-la / es) is tried first; when it has no
chapters in the preferred language, InManga (Spanish-only) is tried by title.
When neither has Spanish, info() returns {"error": "Sin capitulos en espanol"}
(decision (b): never fall back to English content).

Source selection: QS_MANGA_SOURCE = mangadex | inmanga | weebcentral | auto.
auto uses the content language (QS_CONTENT_LANG): Spanish -> the chain,
otherwise WeebCentral (handled by manga_server.py, which owns that scraper).
"""

import os

import content_lang
import inmanga_source
import manga_sources

NO_SPANISH_MESSAGE = "Sin capítulos en español"

_MODULES = {
    "mangadex": manga_sources,
    "inmanga": inmanga_source,
}
_FORCED = ("mangadex", "inmanga", "weebcentral", "mangaplus")


def active_chain(env=None, langs=None):
    """Ordered list of source names to try for the current configuration."""
    forced = (env if env is not None else os.environ.get("QS_MANGA_SOURCE", "")).strip().lower()
    if forced in _FORCED:
        return [forced]
    preferred = content_lang.content_langs() if langs is None else langs
    for tag in preferred:
        base = str(tag).strip().lower().split("-", 1)[0].split("_", 1)[0]
        if base == "es":
            return ["mangadex", "inmanga"]
    return ["weebcentral"]


def split_id(prefixed):
    """``"mangadex:abc"`` -> ``("mangadex", "abc")``."""
    name, _, raw = (prefixed or "").partition(":")
    return (name, raw) if raw else ("", prefixed or "")


def _prefix_item(name, item):
    return {**item, "id": f"{name}:{item.get('id', '')}"}


def _prefix_list(name, items):
    return [_prefix_item(name, item) for item in items]


def _prefix_info(name, data):
    return {
        **data,
        "id": f"{name}:{data.get('id', '')}",
        "chapters": [{**c, "id": f"{name}:{c.get('id', '')}"} for c in data.get("chapters", [])],
    }


def _first_match(module, title):
    try:
        result = module.search(title, None, 0, "Best Match")
    except Exception:  # noqa: BLE001 — a flaky source must not break the chain
        return ""
    results = result.get("results") or []
    return results[0].get("id", "") if results else ""


def search(query, mtype=None, offset=0, sort="Best Match"):
    for name in active_chain():
        module = _MODULES.get(name)
        if module is None:
            continue
        result = module.search(query, mtype, offset, sort)
        if result.get("results"):
            return {**result, "results": _prefix_list(name, result["results"])}
    return {"results": [], "hasMore": False, "nextOffset": offset}


def latest(page=1):
    for name in active_chain():
        module = _MODULES.get(name)
        if module is None:
            continue
        result = module.latest(page)
        if result.get("results"):
            return {**result, "results": _prefix_list(name, result["results"])}
    return {"results": [], "hasMore": False, "nextPage": page + 1}


def hot():
    for name in active_chain():
        module = _MODULES.get(name)
        if module is None:
            continue
        items = module.hot()
        if items:
            return _prefix_list(name, items)
    return []


def info(prefixed_id):
    name, raw = split_id(prefixed_id)
    if name not in _MODULES:
        # Legacy / unprefixed id: best effort with the first source in the chain.
        chain = active_chain()
        name, raw = (chain[0] if chain else ""), prefixed_id
    else:
        chain = active_chain()
    if name not in chain:
        chain = [name] + list(chain)
    start = chain.index(name)

    title = ""
    for policy in chain[start:]:
        module = _MODULES.get(policy)
        if module is None:
            continue
        if policy == name:
            data = module.info(raw)
        else:
            if not title:
                break
            match = _first_match(module, title)
            if not match:
                continue
            data = module.info(match)
        title = title or data.get("title", "")
        if data.get("chapters"):
            return _prefix_info(policy, data)
    return {"error": NO_SPANISH_MESSAGE}


def pages(prefixed_chapter_id):
    name, raw = split_id(prefixed_chapter_id)
    module = _MODULES.get(name)
    if module is None:
        return []
    return module.pages(raw)
