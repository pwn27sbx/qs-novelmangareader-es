"""MangaDex source for the manga backend (stdlib only, fixture-testable).

Serves the SAME JSON contract as the WeebCentral scraper in manga_server.py so
the Quickshell UI is unchanged:

    search() -> {results:[{id,title,image,status,year,type,tags}], hasMore, nextOffset}
    latest() -> {results:[{id,title,image,status,type,chapter,updatedAt}], hasMore, nextPage}
    hot()    -> [{id,title,image,status,type,chapter,updatedAt}]
    info()   -> {id,title,description,status,image,authors,tags,chapters:[{id,chapter,title,group,publishAt}]}
    pages()  -> [{page,img}]

Content language comes from scripts/content_lang.py (QS_CONTENT_LANG, default
"es"): a Spanish preference maps to translatedLanguage[] es-la + es.

MangaDex rules honoured (plan §15.5): identifiable User-Agent, rate limiting
(~5 req/s general, ~40/min for at-home), local TTL cache, contentRating
safe+suggestive, scanlation_group credits, external chapters filtered out and
data-saver images by default.
"""

import json
import os
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

import content_lang

BASE = "https://api.mangadex.org"
UPLOADS = "https://uploads.mangadex.org"
PROXY_PORT = 5150  # same image proxy as manga_server.py
USER_AGENT = "qs-novelmangareader-es/0.1 (+https://github.com/dhrruvsharma/qs-novelmangareader)"
PAGE_LIMIT = 32
FEED_LIMIT = 500  # MangaDex max

_ORIGIN_TYPE = {"ja": "Manga", "ko": "Manhwa", "zh": "Manhua"}
_TYPE_ORIGIN = {"Manga": "ja", "Manhwa": "ko", "Manhua": "zh"}
_TITLE_PRIORITY = ["es-la", "es", "en", "ja-ro"]
_DESC_PRIORITY = ["es-la", "es", "en"]

# ── Rate limiting (plan §15.5) ─────────────────────────────────────────────
_general_lock = threading.Lock()
_general_last = [0.0]
GENERAL_INTERVAL = 0.21   # ~5 req/s

_athome_lock = threading.Lock()
_athome_last = [0.0]
ATHOME_INTERVAL = 1.5     # ~40 req/min

# ── TTL cache ──────────────────────────────────────────────────────────────
_cache = {}
_cache_lock = threading.Lock()
TTL_SEARCH = 600
TTL_INFO = 1800
TTL_FEED = 600
TTL_LIST = 300


def active_source(env_value=None, langs=None):
    """Which manga source to use: "mangadex" or "weebcentral".

    QS_MANGA_SOURCE wins when it is one of those two. Otherwise the source is
    chosen from the content language: Spanish -> MangaDex (es-la chapters),
    anything else -> WeebCentral (English).
    """
    forced = (env_value if env_value is not None
              else os.environ.get("QS_MANGA_SOURCE", "")).strip().lower()
    if forced in ("mangadex", "weebcentral"):
        return forced
    preferred = langs if langs is not None else content_lang.content_langs()
    for tag in preferred:
        if re.split(r"[-_]", str(tag).strip().lower(), maxsplit=1)[0] == "es":
            return "mangadex"
    return "weebcentral"


def mangadex_langs(langs=None):
    """MangaDex language codes for the content-language preference list."""
    preferred = langs if langs is not None else content_lang.content_langs()
    out = []
    for tag in preferred:
        base = re.split(r"[-_]", str(tag).strip().lower(), maxsplit=1)[0]
        codes = ["es-la", "es"] if base == "es" else [base]
        for code in codes:
            if code and code not in out:
                out.append(code)
    return out or ["en"]


def proxy_url(img_url):
    if not img_url:
        return ""
    return f"http://127.0.0.1:{PROXY_PORT}/image?url={urllib.parse.quote(img_url, safe='')}"


# ── Mapping helpers (pure) ─────────────────────────────────────────────────

def _pick_title(attributes):
    merged = {}
    for source in [attributes.get("title") or {}] + (attributes.get("altTitles") or []):
        for key, value in source.items():
            if value and key not in merged:
                merged[key] = value
    for key in _TITLE_PRIORITY:
        if merged.get(key):
            return merged[key]
    for value in merged.values():
        if value:
            return value
    return ""


def _pick_description(attributes):
    description = attributes.get("description") or {}
    for key in _DESC_PRIORITY:
        if description.get(key):
            return description[key]
    for value in description.values():
        if value:
            return value
    return ""


def _cover_url(manga):
    for rel in manga.get("relationships", []):
        if rel.get("type") == "cover_art":
            filename = (rel.get("attributes") or {}).get("fileName")
            if filename:
                return f"{UPLOADS}/covers/{manga['id']}/{filename}.256.jpg"
    return ""


def _authors(manga):
    out = []
    for rel in manga.get("relationships", []):
        if rel.get("type") in ("author", "artist"):
            name = ((rel.get("attributes") or {}).get("name") or "").strip()
            if name and name not in out:
                out.append(name)
    return out


def _group(chapter):
    for rel in chapter.get("relationships", []):
        if rel.get("type") == "scanlation_group":
            return ((rel.get("attributes") or {}).get("name") or "").strip()
    return ""


def _tags(attributes):
    out = []
    for tag in attributes.get("tags", []):
        name = ((tag.get("attributes") or {}).get("name") or {}).get("en")
        if name and name not in out:
            out.append(name)
    return out


def _capitalize(value):
    text = str(value or "")
    return text[:1].upper() + text[1:]


def _list_item(manga):
    attributes = manga.get("attributes", {})
    return {
        "id": manga.get("id", ""),
        "title": _pick_title(attributes),
        "image": proxy_url(_cover_url(manga)),
        "status": _capitalize(attributes.get("status")),
        "year": str(attributes.get("year") or ""),
        "type": _ORIGIN_TYPE.get(attributes.get("originalLanguage"), ""),
        "chapter": str(attributes.get("lastChapter") or ""),
        "updatedAt": attributes.get("updatedAt", ""),
        "tags": _tags(attributes),
    }


def map_search(page):
    results = [_list_item(m) for m in page.get("data", [])]
    total = page.get("total") or 0
    offset = page.get("offset") or 0
    return {
        "results": results,
        "hasMore": (offset + len(results)) < total,
        "nextOffset": offset + len(results),
    }


def map_latest(page, page_number):
    results = [_list_item(m) for m in page.get("data", [])]
    return {
        "results": results,
        "hasMore": len(results) >= PAGE_LIMIT,
        "nextPage": page_number + 1,
    }


def map_hot(page):
    return [_list_item(m) for m in page.get("data", [])]


def map_info(manga, feed):
    data = manga.get("data") or {}
    attributes = data.get("attributes", {})
    chapters = []
    for chapter in feed.get("data", []):
        chapter_attributes = chapter.get("attributes", {})
        # External chapters (official sites) have no hosted pages — drop them.
        if chapter_attributes.get("externalUrl"):
            continue
        number = chapter_attributes.get("chapter") or ""
        title = chapter_attributes.get("title") or (f"Chapter {number}" if number else "Chapter")
        chapters.append({
            "id": chapter.get("id", ""),
            "chapter": number,
            "title": title,
            "group": _group(chapter),
            "publishAt": chapter_attributes.get("publishAt", ""),
        })
    return {
        "id": data.get("id", ""),
        "title": _pick_title(attributes),
        "description": _pick_description(attributes),
        "status": _capitalize(attributes.get("status")),
        "image": proxy_url(_cover_url(data)),
        "authors": _authors(data),
        "tags": _tags(attributes),
        "chapters": chapters,
    }


def map_pages(at_home, data_saver=True):
    base = (at_home.get("baseUrl") or "").rstrip("/")
    chapter = at_home.get("chapter") or {}
    chapter_hash = chapter.get("hash") or ""
    mode = "data-saver" if data_saver else "data"
    files = chapter.get("dataSaver" if data_saver else "data") or []
    return [
        {"page": index + 1, "img": proxy_url(f"{base}/{mode}/{chapter_hash}/{name}")}
        for index, name in enumerate(files)
    ]


# ── HTTP (rate limited + cached) ───────────────────────────────────────────

def _rate_limit(athome):
    lock, box, interval = (
        (_athome_lock, _athome_last, ATHOME_INTERVAL) if athome
        else (_general_lock, _general_last, GENERAL_INTERVAL)
    )
    with lock:
        wait = box[0] + interval - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        box[0] = time.monotonic()


def _cached(key, ttl, fn):
    with _cache_lock:
        entry = _cache.get(key)
    if entry and time.monotonic() < entry[1]:
        return entry[0]
    value = fn()
    with _cache_lock:
        _cache[key] = (value, time.monotonic() + ttl)
    return value


def _http_json(path, params, athome=False):
    url = BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    last_error = None
    for attempt in range(3):
        _rate_limit(athome)
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code == 429:
                time.sleep(1.5 * (attempt + 1))
                last_error = error
                continue
            raise
        except Exception as error:  # noqa: BLE001 — connection reset, timeout…
            last_error = error
            time.sleep(0.5 * (attempt + 1))
    raise last_error


# ── Public API (mirrors manga_server.py) ───────────────────────────────────

def search(query, mtype=None, offset=0, sort="Best Match", langs=None):
    params = [
        ("title", query),
        ("limit", PAGE_LIMIT),
        ("offset", offset),
        ("includes[]", "cover_art"),
        ("contentRating[]", "safe"),
        ("contentRating[]", "suggestive"),
    ]
    for lang in mangadex_langs(langs):
        params.append(("availableTranslatedLanguage[]", lang))
    if mtype in _TYPE_ORIGIN:
        params.append(("originalLanguage[]", _TYPE_ORIGIN[mtype]))
    order = "followedCount" if str(sort).lower() in ("popularity",) else "relevance"
    params.append((f"order[{order}]", "desc"))
    key = "search:" + urllib.parse.urlencode(params)
    return map_search(_cached(key, TTL_SEARCH, lambda: _http_json("/manga", params)))


def latest(page=1, langs=None):
    page = max(int(page or 1), 1)
    params = _list_params(langs, "latestUploadedChapter", offset=(page - 1) * PAGE_LIMIT)
    key = "latest:" + urllib.parse.urlencode(params)
    return map_latest(_cached(key, TTL_LIST, lambda: _http_json("/manga", params)), page)


def hot(langs=None):
    params = _list_params(langs, "followedCount", offset=0)
    key = "hot:" + urllib.parse.urlencode(params)
    return map_hot(_cached(key, TTL_LIST, lambda: _http_json("/manga", params)))


def info(manga_id, langs=None):
    detail_params = [("includes[]", "cover_art"), ("includes[]", "author"), ("includes[]", "artist")]
    detail = _cached(f"manga:{manga_id}", TTL_INFO,
                     lambda: _http_json(f"/manga/{manga_id}", detail_params))
    feed_params = [
        ("order[chapter]", "asc"),
        ("includes[]", "scanlation_group"),
        ("contentRating[]", "safe"),
        ("contentRating[]", "suggestive"),
        ("limit", FEED_LIMIT),
    ]
    for lang in mangadex_langs(langs):
        feed_params.append(("translatedLanguage[]", lang))
    feed = _cached(f"feed:{manga_id}:" + urllib.parse.urlencode(feed_params), TTL_FEED,
                   lambda: _http_json(f"/manga/{manga_id}/feed", feed_params))
    return map_info(detail, feed)


def pages(chapter_id, data_saver=True):
    # MangaDex's at-home response is temporary — the CDN node and the file URLs
    # are meant to be used immediately, so fetch it fresh on every chapter open
    # instead of caching it (a stale baseUrl/hash yields 404s on the images).
    data = _http_json(f"/at-home/server/{chapter_id}", [], athome=True)
    return map_pages(data, data_saver)


def _list_params(langs, order, offset=0):
    params = [
        ("limit", PAGE_LIMIT),
        ("offset", offset),
        ("includes[]", "cover_art"),
        ("contentRating[]", "safe"),
        ("contentRating[]", "suggestive"),
        (f"order[{order}]", "desc"),
    ]
    for lang in mangadex_langs(langs):
        params.append(("availableTranslatedLanguage[]", lang))
    return params
