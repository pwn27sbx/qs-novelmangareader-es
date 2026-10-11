"""InManga source (Spanish, inmanga.com) — same JSON contract as manga_server.py.

Verified structure (2026-10):
  search   POST /manga/getMangasConsultResult  (filter[queryString]/[skip]/[take]/[sortby])  -> HTML
  chapters GET  /chapter/getall?mangaIdentification=<mangaUuid>   (+ Referer)  -> {"data":"<json>"}
  pages    GET  /chapter/chapterIndexControls?identification=<chapterIdent> (+ Referer) -> HTML
  image    https://cdn1.intomanga.com/i/m/<mangaUuid>/c/<chapterIdLower>/o/<pageId>.jpg

The page ids come from the reader page's <select id="PageList"> options. InManga
is Spanish-only by nature, so "has Spanish chapters" == "has chapters".

Plain urllib works for these endpoints; curl_cffi is used when installed (as in
manga_server.py) for robustness. Parsers are pure and fixture-tested (no network).
"""

import json
import re
import threading
import time
import urllib.parse
import urllib.request

BASE = "https://inmanga.com"
IMG_CDN = "https://cdn1.intomanga.com/i/m"
PROXY_PORT = 5150
PAGE_LIMIT = 32
USER_AGENT = "qs-novelmangareader-es/0.1 (+https://github.com/dhrruvsharma/qs-novelmangareader)"

try:  # optional browser-grade TLS (used by manga_server.py); urllib is the fallback
    from curl_cffi.requests import Session as _CffiSession  # noqa: F401
    _HAVE_CFFI = True
except Exception:  # noqa: BLE001
    _HAVE_CFFI = False

# ── rate limit + TTL cache (plan §15.5) ────────────────────────────────────
_lock = threading.Lock()
_last = [0.0]
INTERVAL = 0.25  # ~4 req/s

_cache = {}
_cache_lock = threading.Lock()
TTL_SEARCH = 600
TTL_INFO = 1800
TTL_PAGES = 3600
TTL_LIST = 300

_cffi_local = threading.local()


def _cached(key, ttl, fn):
    with _cache_lock:
        entry = _cache.get(key)
    if entry and time.monotonic() < entry[1]:
        return entry[0]
    value = fn()
    with _cache_lock:
        _cache[key] = (value, time.monotonic() + ttl)
    return value


def _rate_limit():
    with _lock:
        wait = _last[0] + INTERVAL - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        _last[0] = time.monotonic()


def _fetch(url, data=None, referer=None):
    """GET/POST returning text. curl_cffi when available, else urllib."""
    body = urllib.parse.urlencode(data, doseq=True) if data else None
    headers = {
        "User-Agent": USER_AGENT,
        "Accept-Language": "es-ES,es;q=0.9",
        "X-Requested-With": "XMLHttpRequest",
    }
    if referer:
        headers["Referer"] = referer
    _rate_limit()
    if _HAVE_CFFI:
        session = getattr(_cffi_local, "session", None)
        if session is None:
            session = _CffiSession(impersonate="firefox")
            _cffi_local.session = session
        resp = session.request("POST" if body else "GET", url, data=body, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.text
    request = urllib.request.Request(url, headers=headers, data=(body.encode() if body else None))
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "replace")


def proxy_url(img_url):
    if not img_url:
        return ""
    return f"http://127.0.0.1:{PROXY_PORT}/image?url={urllib.parse.quote(img_url, safe='')}"


# ── pure parsers (fixture-tested) ──────────────────────────────────────────

def _strip_tags(html):
    return re.sub(r"<[^>]+>", "", html or "").replace("&nbsp;", " ").strip()


def parse_search(html):
    """Parse a getMangasConsultResult fragment into contract list items."""
    results = []
    for part in re.split(r'(?=<a\s+href="/ver/manga/)', html)[1:]:
        match = re.match(r'<a\s+href="/ver/manga/([^"/]+)/([^"]+)"', part)
        if not match:
            continue
        slug, manga_uuid = match.group(1), match.group(2)
        window = part[:part.find("</a>")] if "</a>" in part else part[:1500]
        title = _strip_tags((re.search(r"<h4[^>]*>([\s\S]*?)</h4>", window) or [None, ""])[1])
        cover = re.search(r'<img[^>]*data-src="([^"]+)"', window)
        results.append({
            "id": f"{slug}/{manga_uuid}",
            "title": title,
            "image": proxy_url(cover.group(1) if cover else ""),
            "status": "",
            "year": "",
            "type": "",
            "tags": [],
        })
    return results


def _clean_number(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value).strip()
    return str(int(number)) if number == int(number) else str(number)


def parse_chapters(raw, manga_uuid):
    """Parse the getall body ({"data": "<json>"}) into contract chapters."""
    outer = json.loads(raw)
    payload = json.loads(outer["data"]) if isinstance(outer.get("data"), str) else outer
    items = payload.get("result") or []
    chapters = []
    for item in items:
        identification = item.get("Identification") or ""
        if not identification:
            continue
        number = _clean_number(item.get("Number"))
        chapters.append({
            "_number": item.get("Number") or 0,
            "id": f"{manga_uuid}/{identification}",
            "chapter": number,
            "title": item.get("FriendlyChapterNumber") or (f"Chapter {number}" if number else "Chapter"),
            "group": "",
            "publishAt": item.get("RegistrationDate") or "",
        })
    chapters.sort(key=lambda c: c["_number"])
    for chapter in chapters:
        chapter.pop("_number", None)
    return chapters


def _input_value(html, input_id):
    match = re.search(r'<input[^>]*id="' + re.escape(input_id) + r'"[^>]*>', html)
    if not match:
        return ""
    value = re.search(r'value="([^"]*)"', match.group(0))
    return value.group(1) if value else ""


def parse_pages(html, manga_uuid, chapter_ident):
    """Parse chapterIndexControls into [{page, img}] (CDN page images)."""
    select = re.search(r'<select[^>]*id="PageList"[\s\S]*?</select>', html)
    if not select:
        return []
    page_ids = re.findall(r'<option[^>]*value="([^"]+)"', select.group(0))
    chapter_lower = (chapter_ident or "").lower()
    pages = []
    for index, page_id in enumerate(page_ids):
        url = f"{IMG_CDN}/{manga_uuid}/c/{chapter_lower}/o/{page_id}.jpg"
        pages.append({"page": index + 1, "img": proxy_url(url)})
    return pages


def parse_info(detail_html, chapters_raw, manga_uuid):
    """Build the contract info object from the detail page + chapter list."""
    title_match = re.search(r"<title>(.*?)</title>", detail_html or "", re.S)
    title = _strip_tags(title_match.group(1)) if title_match else ""
    title = re.sub(r"\s*Manga Online.*$", "", title).strip()
    description = ""
    meta = re.search(r'<meta\s+name="description"\s+content="([^"]*)"', detail_html or "")
    if meta:
        description = meta.group(1).strip()
    cover = f"{IMG_CDN}/{manga_uuid}/t/o/{manga_uuid}.jpg"
    return {
        "id": manga_uuid,
        "title": title,
        "description": description,
        "status": "",
        "image": proxy_url(cover),
        "authors": [],
        "tags": [],
        "chapters": parse_chapters(chapters_raw, manga_uuid),
    }


# ── public API (mirrors manga_server.py) ───────────────────────────────────

def _search_html(query, offset, sortby):
    data = {
        "filter[queryString]": query,
        "filter[skip]": str(offset),
        "filter[take]": str(PAGE_LIMIT),
        "filter[sortby]": str(sortby),
        "filter[broadcastStatus]": "0",
        "filter[onlyFavorites]": "false",
    }
    return _fetch(f"{BASE}/manga/getMangasConsultResult", data=data, referer=f"{BASE}/")


def search(query, mtype=None, offset=0, sort="Best Match"):
    key = f"in-search:{query}:{offset}:{sort}"
    html = _cached(key, TTL_SEARCH, lambda: _search_html(query, offset, -1))
    results = parse_search(html)
    return {"results": results, "hasMore": len(results) >= PAGE_LIMIT, "nextOffset": offset + len(results)}


def latest(page=1):
    page = max(int(page or 1), 1)
    offset = (page - 1) * PAGE_LIMIT

    def load():
        return parse_search(_search_html("", offset, -1))

    results = _cached(f"in-latest:{page}", TTL_LIST, load)
    return {"results": results, "hasMore": len(results) >= PAGE_LIMIT, "nextPage": page + 1}


def hot():
    def load():
        return parse_search(_search_html("", 0, 5))

    return _cached("in-hot", TTL_LIST, load)


def info(manga_id):
    slug, _, manga_uuid = manga_id.partition("/")
    referer = f"{BASE}/ver/manga/{slug}/{manga_uuid}"
    detail = _cached(f"in-detail:{manga_uuid}", TTL_INFO, lambda: _fetch(referer, referer=BASE))
    chapters_raw = _cached(f"in-chapters:{manga_uuid}", TTL_INFO,
                           lambda: _fetch(f"{BASE}/chapter/getall?mangaIdentification={manga_uuid}", referer=referer))
    return parse_info(detail, chapters_raw, manga_uuid)


def pages(chapter_id):
    manga_uuid, _, chapter_ident = chapter_id.partition("/")
    referer = f"{BASE}/ver/manga/{manga_uuid}/"

    def load():
        html = _fetch(f"{BASE}/chapter/chapterIndexControls?identification={chapter_ident}", referer=referer)
        return parse_pages(html, manga_uuid, chapter_ident)

    return _cached(f"in-pages:{chapter_id}", TTL_PAGES, load)
