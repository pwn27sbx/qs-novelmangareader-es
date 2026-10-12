"""Manga source chain (Spanish): MangaDex -> InManga -> zonatmo -> zonatmo_org.

Every endpoint returns the same JSON contract as manga_server.py, with item ids
prefixed by the source (``mangadex:<id>`` / ``inmanga:<id>`` / ``zonatmo:<id>`` /
``zonatmo_org:<id>``) so info()/pages() can route back to the source that
produced them.

Language fall-through: MangaDex (es-la / es) is tried first; when it has no
chapters in the preferred language, InManga (Spanish-only) is tried by title,
then the two zonatmo backends (zonatmo.net JSON API, then zonatmo.org HTML).
When none has Spanish, info() returns {"error": "Sin capitulos en espanol"}
(decision (b): never fall back to English content).

Failover / mirrors: zonatmo.net and zonatmo.org are two INDEPENDENT backends for
the same Spanish catalogue (different protocols), so they are not identical
mirrors. Failover happens through the chain order — a source that raises (dead
domain, timeout) is skipped and the next is tried — and each provider
short-caches a dead domain so a burst does not hammer it. ``SOURCE_MIRRORS``
records the alternate domain per backend.

Source selection: QS_MANGA_SOURCE = mangadex | inmanga | zonatmo | zonatmo_org |
weebcentral | auto. auto uses the content language (QS_CONTENT_LANG): Spanish ->
the chain, otherwise WeebCentral (handled by manga_server.py).
"""

import os

import content_lang
import inmanga_source
import manga_sources
import titles
import zonatmo_org_source
import zonatmo_source

NO_SPANISH_MESSAGE = "Sin capítulos en español"

_MODULES = {
    "mangadex": manga_sources,
    "inmanga": inmanga_source,
    "zonatmo": zonatmo_source,
    "zonatmo_org": zonatmo_org_source,
}
_FORCED = ("mangadex", "inmanga", "zonatmo", "zonatmo_org", "weebcentral", "mangaplus")

# Alternate domain per zonatmo backend (for diagnostics / health reporting).
SOURCE_MIRRORS = {
    "zonatmo": ("zonatmo.net",),
    "zonatmo_org": ("zonatmo.org",),
}


def mirrors_for(source):
    """Alternate domains recorded for `source` (empty when it has none)."""
    return SOURCE_MIRRORS.get(source, ())


def spanish_sources(env=None, langs=None):
    """The Spanish sources the chain tries, in order.

    WeebCentral is the English fallback (plan decision (b)), not a Spanish
    source, so it is excluded — the UI notice names only the ES sources that
    were actually consulted (plan §F3).
    """
    return [name for name in active_chain(env, langs) if name != "weebcentral"]


def active_chain(env=None, langs=None):
    """Ordered list of source names to try for the current configuration."""
    forced = (env if env is not None else os.environ.get("QS_MANGA_SOURCE", "")).strip().lower()
    if forced in _FORCED:
        return [forced]
    preferred = content_lang.content_langs() if langs is None else langs
    for tag in preferred:
        base = str(tag).strip().lower().split("-", 1)[0].split("_", 1)[0]
        if base == "es":
            return ["mangadex", "inmanga", "zonatmo", "zonatmo_org"]
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


def _try(call, default=None):
    """Run `call`, returning `default` when a source raises.

    A dead domain (DNS/timeout) or a flaky parser must never break the whole
    chain: the source is skipped and the next one is tried.
    """
    try:
        return call()
    except Exception:  # noqa: BLE001 — a dead/flaky source must not break the chain
        return default


def _first_match(module, title):
    """Best matching series id in `module` for `title`, or "".

    Only a title that actually matches is accepted, so a fall-through never
    adopts an unrelated series.
    """
    try:
        result = module.search(title, None, 0, "Best Match")
    except Exception:  # noqa: BLE001 — a flaky source must not break the chain
        return ""
    for item in result.get("results") or []:
        if titles.titles_match(title, item.get("title", "")):
            return item.get("id", "")
    return ""


def search(query, mtype=None, offset=0, sort="Best Match"):
    for name in active_chain():
        module = _MODULES.get(name)
        if module is None:
            continue
        result = _try(lambda: module.search(query, mtype, offset, sort), None)
        if result and result.get("results"):
            return {**result, "results": _prefix_list(name, result["results"])}
    return {"results": [], "hasMore": False, "nextOffset": offset}


def latest(page=1):
    for name in active_chain():
        module = _MODULES.get(name)
        if module is None:
            continue
        result = _try(lambda: module.latest(page), None)
        if result and result.get("results"):
            return {**result, "results": _prefix_list(name, result["results"])}
    return {"results": [], "hasMore": False, "nextPage": page + 1}


def hot():
    for name in active_chain():
        module = _MODULES.get(name)
        if module is None:
            continue
        items = _try(lambda: module.hot(), None)
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
            data = _try(lambda: module.info(raw), None)
        else:
            if not title:
                break
            match = _first_match(module, title)
            if not match:
                continue
            data = _try(lambda: module.info(match), None)
        if not data:
            continue
        title = title or data.get("title", "")
        if data.get("chapters"):
            return _prefix_info(policy, data)
    return {"error": NO_SPANISH_MESSAGE, "title": title}


def pages(prefixed_chapter_id):
    name, raw = split_id(prefixed_chapter_id)
    module = _MODULES.get(name)
    if module is None:
        return []
    return module.pages(raw)
