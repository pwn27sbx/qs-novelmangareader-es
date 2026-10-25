"""ManhwaWeb (manhwaweb.com) — Spanish manhwa source, +18 catalogue.

The site is a Vite single-page app: the HTML has no content, everything comes
from its JSON API. These are the endpoints it calls, read out of its bundle and
checked live (2026-10-25):

    GET /manhwa/library?buscar=<q>&estado=&tipo=&erotico=&demografia=
        &order_item=alfabetic&page=<0-based>     -> {"data": [item], "next": bool}
    GET /manhwa/see/<manga id>                   -> series + "chapters": [...]
    GET /chapters/see/<manga id>-<chapter label> -> {"chapter": {"img": [url]}}

`order_item` is accepted but ignored by the API (popular, nuevos and alfabetic
return the same page), so `latest()` and `hot()` both use the default listing:
the source has no independent ordering to offer.

Chapter ids stay inside this module as ``<manga id>-<label>`` (label looks like
``1_01`` or ``151.5_01``) because the pages endpoint needs both halves; the
chain only round-trips the string. A manga id may contain hyphens, so the label
is matched from the end.

Every image lives on ``img1mw.xyz`` and answers **403 without a referer**, so
covers and pages go through the app's image proxy, which attaches
``Referer: https://manhwaweb.com/`` for that host (see manga_server).
"""

import json
import re
import threading
import time
import urllib.parse
import urllib.request

BASE = "https://api.manhwaweb.com"
REFERER = "https://manhwaweb.com/"
PROXY_PORT = 5150
PAGE = 30
AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"
TIMEOUT = 25

TTL_SEARCH = 300
TTL_INFO = 300
TTL_PAGES = 300

_LABEL = re.compile(r"^(?P<manga>.+)-(?P<label>\d+(?:\.\d+)?_\d+)$")
_CHAPTER_NUMBER = re.compile(r"^(\d+(?:\.\d+)?)")

_lock = threading.Lock()
_last_call = [0.0]
_cache: dict[str, tuple[float, object]] = {}


def proxy_url(img_url):
    if not img_url:
        return ""
    return f"http://127.0.0.1:{PROXY_PORT}/image?url={urllib.parse.quote(img_url, safe='')}"


def _rate_limit():
    """One request every 300 ms: the API is small and shared."""
    with _lock:
        wait = 0.3 - (time.time() - _last_call[0])
        if wait > 0:
            time.sleep(wait)
        _last_call[0] = time.time()


def _get_json(path):
    _rate_limit()
    request = urllib.request.Request(
        BASE + path,
        headers={"User-Agent": AGENT, "Referer": REFERER, "Origin": REFERER.rstrip("/")},
    )
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return json.loads(response.read().decode("utf-8", "replace"))


CACHE_LIMIT = 200


def _cached(key, ttl, fn):
    with _lock:
        hit = _cache.get(key)
    # A hit honours the shorter of the TTL it was stored with and the one asked
    # for now, so a later short-TTL call can never read a stale value.
    if hit and (time.time() - hit[0]) < min(hit[2], ttl):
        return hit[1]
    value = fn()
    now = time.time()
    with _lock:
        # A long-lived server would otherwise keep every expired search page.
        # Each entry carries its own TTL, so a short-lived entry cannot evict a
        # still-valid long-lived one.
        if len(_cache) >= CACHE_LIMIT:
            for stale in [k for k, (at, _, entry_ttl) in _cache.items() if (now - at) >= entry_ttl]:
                _cache.pop(stale, None)
            while len(_cache) >= CACHE_LIMIT:
                _cache.pop(next(iter(_cache)), None)
        _cache[key] = (now, value, ttl)
    return value


def clear_cache():
    with _lock:
        _cache.clear()


def _library(query="", page=0):
    params = urllib.parse.urlencode({
        "buscar": query or "",
        "estado": "",
        "tipo": "",
        "erotico": "",
        "demografia": "",
        "order_item": "alfabetic",
        "page": str(page),
    })
    return _get_json("/manhwa/library?" + params)


# ── pure mappers (fixture-tested) ──────────────────────────────────────────

def _status(value):
    return {"finalizado": "Completed", "en curso": "Ongoing", "pausado": "Hiatus"}.get(
        str(value or "").strip().lower(), str(value or "").capitalize()
    )


def map_item(raw):
    """One library/search row -> the chain's list item."""
    return {
        "id": raw.get("real_id") or raw.get("_id", ""),
        "title": raw.get("name_esp") or raw.get("the_real_name") or raw.get("name_raw") or "",
        "image": proxy_url(raw.get("_imagen", "")),
        "status": _status(raw.get("_status")),
        "type": "Manhwa" if str(raw.get("_tipo", "")).lower() == "manhwa" else str(raw.get("_tipo", "")).capitalize(),
        "chapter": str(raw.get("_numero_cap") or ""),
        "tags": [v for pair in (raw.get("_categoris") or []) if isinstance(pair, dict) for v in pair.values()
                 if isinstance(v, str)],
    }


def chapter_id(manga_id, link):
    """``.../leer/<manga id>-<label>`` -> ``<manga id>-<label>``."""
    prefix = f"{REFERER}leer/{manga_id}-"
    if link and link.startswith(prefix):
        return f"{manga_id}-{link[len(prefix):]}"
    return ""


def split_chapter_id(chapter_id):
    match = _LABEL.match(str(chapter_id or ""))
    return (match.group("manga"), match.group("label")) if match else ("", "")


def map_info(raw):
    """Series document -> the chain's info object."""
    manga_id = raw.get("real_id") or raw.get("_id", "")
    chapters = []
    for entry in raw.get("chapters") or []:
        cid = chapter_id(manga_id, entry.get("link", ""))
        if not cid:
            continue
        label = cid.split("-")[-1]
        number = _CHAPTER_NUMBER.match(label)
        created = entry.get("create")
        chapters.append({
            "id": cid,
            "chapter": number.group(1) if number else "",
            "title": "",
            "publishAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(created / 1000)) if created else "",
        })
    chapters.sort(key=lambda c: float(c["chapter"] or 0), reverse=True)
    tags = [v for pair in (raw.get("_categoris") or []) if isinstance(pair, dict) for v in pair.values()
            if isinstance(v, str)]
    # `autor` / `artista` are arrays of {"_id", "name"} objects, but a bare
    # string is accepted too: iterating it blindly would split the name into
    # characters.
    authors = []
    for field in ("autor", "artista"):
        value = raw.get(field)
        people = [value] if isinstance(value, str) else (value or [])
        for person in people:
            name = person.get("name") if isinstance(person, dict) else person
            if name and name not in authors:
                authors.append(name)
    return {
        "id": manga_id,
        "title": raw.get("name_esp") or raw.get("the_real_name") or "",
        "description": raw.get("_sinopsis") or "",
        "status": _status(raw.get("_status")),
        "image": proxy_url(raw.get("_imagen", "")),
        "authors": authors,
        "tags": tags,
        "chapters": chapters,
    }


def map_pages(raw):
    """Chapter document -> image URLs behind the app's proxy."""
    chapter = (raw or {}).get("chapter") or {}
    images = chapter.get("img") or (raw or {}).get("img") or []
    return [proxy_url(url) for url in images if url]


# ── public API (mirrors manga_server.py) ───────────────────────────────────

def search(query, mtype=None, offset=0, sort="Best Match"):
    page = max(0, int(offset or 0) // PAGE)
    payload = _cached(f"mweb-search:{query}:{page}", TTL_SEARCH, lambda: _library(query, page))
    results = [map_item(item) for item in payload.get("data") or []]
    # The API's own `tipo` filter answers empty for every value, so a type-scoped
    # search is filtered here instead of being silently ignored.
    if mtype:
        wanted = str(mtype).strip().lower()
        results = [item for item in results if item["type"].lower() == wanted]
    more = bool(payload.get("next"))
    return {"results": results, "hasMore": more, "nextOffset": (page + 1) * PAGE}


def latest(page=1):
    index = max(0, int(page or 1) - 1)
    payload = _cached(f"mweb-latest:{index}", TTL_SEARCH, lambda: _library("", index))
    results = [map_item(item) for item in payload.get("data") or []]
    return {"results": results, "hasMore": bool(payload.get("next")), "nextPage": index + 2}


def hot():
    payload = _cached("mweb-hot", TTL_SEARCH, lambda: _library("", 0))
    return [map_item(item) for item in payload.get("data") or []]


def info(manga_id):
    raw = _cached(f"mweb-info:{manga_id}", TTL_INFO, lambda: _get_json(f"/manhwa/see/{manga_id}"))
    return map_info(raw)


def pages(chapter_id):
    manga_id, label = split_chapter_id(chapter_id)
    if not manga_id:
        return []
    raw = _cached(f"mweb-pages:{chapter_id}", TTL_PAGES,
                  lambda: _get_json(f"/chapters/see/{manga_id}-{label}"))
    return map_pages(raw)
