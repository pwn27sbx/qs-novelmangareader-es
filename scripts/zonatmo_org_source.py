"""zonatmo.org source (Spanish manhwa/manga) — same JSON contract as manga_server.py.

zonatmo.org is the sibling of zonatmo.net but a DIFFERENT backend: a Laravel site
with an HTML catalogue plus one JSON endpoint. It is Spanish-only. Endpoints
(verified 2026-10):

    search    GET /api/search/suggest?q=QUERY           -> JSON [id,title,slug,url,cover_url,type,status,rating,authors]
    listing   GET /biblioteca?page=N                    -> HTML catalogue grid (24 series/page)
    series    GET /library/<type>/<id>/<slug>           -> HTML (title, synopsis, status, authors, genres, chapters)
    reader    GET /view_uploads/<uploadId>              -> HTML with the page images
    image     https://storage.zonatmo.org/chapters/<uploadId>/<n>.webp
    cover     absolute in the HTML (storage.zonatmo.org / zonatmo.org/storage/...)

Notes:
  * the JSON suggest endpoint has no pagination and a single query param, so
    search() returns hasMore=False.
  * /biblioteca has no honored order/sort param (like zonatmo.net), so
    latest()/hot() use the site's default order.
  * a chapter id is the numeric upload id (the reader is /view_uploads/<id>),
    and a series id is the /library/... path (so info() can fetch the page).
  * a dead domain is short-cached (negative cache) so a burst of requests does
    not hammer it while it is down — the chain then falls through to the next
    source.

The parsers are pure and fixture-tested; the tests never touch the network.
"""

import json
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from html import unescape as _html_unescape

BASE = "https://zonatmo.org"
PROXY_PORT = 5150  # same image proxy as manga_server.py
USER_AGENT = "qs-novelmangareader-es/0.1 (+https://github.com/dhrruvsharma/qs-novelmangareader)"
PAGE_LIMIT = 24  # /biblioteca per_page

NEGATIVE_TTL = 60  # seconds a dead domain is short-cached

_STATUS = {
    "completed": "Finalizado",
    "ongoing": "En emisión",
    "cancelled": "Cancelado",
    "canceled": "Cancelado",
    "hiatus": "Pausado",
    "dropped": "Cancelado",
}

# ── rate limit + TTL cache ─────────────────────────────────────────────────
_lock = threading.Lock()
_last = [0.0]
INTERVAL = 0.25  # ~4 req/s

_cache = {}
_cache_lock = threading.Lock()
TTL_SEARCH = 600
TTL_INFO = 1800
TTL_PAGES = 3600
TTL_LIST = 300

# ── dead-domain negative cache ─────────────────────────────────────────────
_dead_until = [0.0]
_dead_lock = threading.Lock()


class SourceUnavailable(Exception):
    """zonatmo.org is short-cached as down; callers should fail over."""


def _mark_dead():
    with _dead_lock:
        _dead_until[0] = time.monotonic() + NEGATIVE_TTL


def _mark_alive():
    with _dead_lock:
        _dead_until[0] = 0.0


def _check_alive():
    with _dead_lock:
        until = _dead_until[0]
    if time.monotonic() < until:
        raise SourceUnavailable("zonatmo.org marked unavailable after a recent failure")


def _prune_cache(now):
    """Drop every expired entry so the cache does not grow without bound."""
    for key in [k for k, (_, expires) in _cache.items() if now >= expires]:
        _cache.pop(key, None)


def _cached(key, ttl, fn):
    now = time.monotonic()
    with _cache_lock:
        entry = _cache.get(key)
        if entry is not None and now >= entry[1]:
            del _cache[key]
            entry = None
        if entry is None:
            _prune_cache(now)
    if entry is not None:
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


def proxy_url(img_url):
    if not img_url:
        return ""
    return f"http://127.0.0.1:{PROXY_PORT}/image?url={urllib.parse.quote(img_url, safe='')}"


# ── pure parsers (fixture-tested) ──────────────────────────────────────────

def _strip_tags(text):
    return _html_unescape(re.sub(r"<[^>]+>", "", text or "")).replace("\xa0", " ").strip()


def _origin_path(url):
    url = str(url or "").strip()
    for prefix in ("https://zonatmo.org", "http://zonatmo.org"):
        if url.startswith(prefix):
            url = url[len(prefix):]
    return url.lstrip("/")


def _type_from_path(path):
    parts = str(path or "").strip("/").split("/")
    if len(parts) >= 2 and parts[0] == "library":
        return parts[1].upper()
    return ""


def _status(value):
    text = str(value or "").strip()
    return _STATUS.get(text.lower(), text)


def _clean_number(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value).strip()
    return str(int(number)) if number == int(number) else str(number)


def _sort_key(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return float("inf")


def parse_suggest(payload):
    """Map the /api/search/suggest JSON to contract list items."""
    items = []
    for entry in payload or []:
        path = _origin_path(entry.get("url"))
        if not path:
            continue
        items.append({
            "id": path,
            "title": entry.get("title") or "",
            "image": proxy_url(entry.get("cover_url") or entry.get("cover") or ""),
            "status": _status(entry.get("status")),
            "year": "",
            "type": (entry.get("type") or _type_from_path(path)).upper(),
            "chapter": "",
            "updatedAt": "",
            "tags": [],
        })
    return items


def parse_biblioteca(html):
    """Map a /biblioteca grid page to contract list items."""
    items = []
    for block in re.split(r'(?=<div class="element col-)', html or ""):
        href = re.search(r'<a href="(https://zonatmo\.org/library/[^"]+)"', block)
        if not href:
            continue
        path = _origin_path(href.group(1))
        title = (re.search(r'<h4[^>]*title="([^"]*)"', block)
                 or re.search(r"<h4[^>]*>([\s\S]*?)</h4>", block) or [None, ""])[1]
        cover = re.search(r'<img[^>]*src="([^"]+)"', block)
        badge = re.search(r'<span class="book-type badge[^"]*">\s*([^<]+?)\s*</span>', block)
        status = re.search(r'<span class="book-meta-status[^"]*">\s*([^<]+?)\s*</span>', block)
        caps = re.search(r'title="(\d+)\s*cap', block)
        items.append({
            "id": path,
            "title": _strip_tags(title),
            "image": proxy_url(_html_unescape(cover.group(1)) if cover else ""),
            "status": _status(_strip_tags(status.group(1)) if status else ""),
            "year": "",
            "type": (badge.group(1).strip().upper() if badge else _type_from_path(path)),
            "chapter": caps.group(1) if caps else "",
            "updatedAt": "",
            "tags": [],
        })
    return items


def _meta(html, name):
    match = re.search(r'<meta (?:property|name)="' + re.escape(name) + r'" content="([^"]*)"', html or "")
    return _html_unescape(match.group(1)) if match else ""


def _genres(html):
    section = re.search(r'element-subtitle">Géneros</h5>([\s\S]*?)(?:<h5 class="element-subtitle)', html or "")
    if not section:
        return []
    names = re.findall(r'href="https://zonatmo\.org/tag/[^"]+">\s*([^<]+?)\s*</a>', section.group(1))
    return [name.strip() for name in names if name.strip()]


def _demography(html):
    match = re.search(r'<div class="manga-meta-bar">[\s\S]*?<i class="fas fa-users"></i>\s*([^<]+?)\s*</span>', html or "")
    return [match.group(1).strip()] if match and match.group(1).strip() else []


def _series_status(html):
    """The series status label, unwrapping the nested status-dot span."""
    match = re.search(r'<span class="book-status[^"]*">([\s\S]*?)</span>', html or "")
    if not match:
        return ""
    inner = match.group(1)
    if not _strip_tags(inner):
        # Real markup nests an empty <span class="status-dot ..."></span>; the
        # label follows it and closes the outer span.
        rest = (html or "")[match.end():]
        inner = rest[:300].split("</span>", 1)[0]
    return _strip_tags(inner)


def _chapters(html):
    # The series page splits chapters between #chapters-list (visible) and
    # #chapters-hidden (the rest), so scan the whole document for chapter rows.
    chapters = []
    for block in re.split(r'(?=<li class="list-group-item[^"]*upload-link)', html or ""):
        number = re.search(r'data-chapter-number="([^"]+)"', block)
        upload = re.search(r'view_uploads/(\d+)', block)
        if not number or not upload:
            continue
        raw = number.group(1)
        title = re.search(r'<span class="chapter-number[^"]*"[^>]*>([\s\S]*?)</span>', block)
        group = re.search(r'/groups/\d+/[^"]*"[^>]*>([\s\S]*?)</a>', block)
        date = re.search(r'<i class="far fa-calendar fa-fw"></i>\s*([0-9/]+)', block)
        chapters.append({
            "_sort": _sort_key(raw),
            "id": upload.group(1),
            "chapter": _clean_number(raw),
            "title": _strip_tags(title.group(1)) if title else f"Capítulo {_clean_number(raw)}",
            "group": _strip_tags(group.group(1)) if group else "",
            "publishAt": date.group(1) if date else "",
        })
    chapters.sort(key=lambda chapter: chapter["_sort"])
    for chapter in chapters:
        chapter.pop("_sort", None)
    return chapters


def parse_series(html, series_path):
    """Build the contract info object from the series HTML page."""
    title = re.search(r'<h1 class="element-title[^"]*"[^>]*>([\s\S]*?)</h1>', html or "")
    description = re.search(r'id="manga-synopsis"[^>]*>([\s\S]*?)</p>', html or "")
    cover = _meta(html, "og:image")
    if not cover:
        thumb = re.search(r'<img class="book-thumbnail"[^>]*src="([^"]+)"', html or "")
        cover = _html_unescape(thumb.group(1)) if thumb else ""
    authors = []
    for name in (_strip_tags(a) for a in re.findall(r'filter_by=author[^"]*">([\s\S]*?)</a>', html or "")):
        if name and name not in authors:
            authors.append(name)
    tags = _genres(html) + _demography(html)
    return {
        "id": series_path,
        "title": _strip_tags(title.group(1)) if title else _meta(html, "og:title"),
        "description": (_strip_tags(description.group(1)) if description else "")
                       or _meta(html, "og:description") or _meta(html, "description"),
        "status": _status(_series_status(html)),
        "image": proxy_url(cover),
        "authors": authors,
        "tags": tags,
        "type": _type_from_path(series_path),
        "chapters": _chapters(html),
    }


_PAGE_MARK = re.compile(r'data-page="(\d+)"')
_PAGE_IMAGE = re.compile(
    r"https://storage\d*\.zonatmo\.org/chapters/\d+/([^\"'\s>]+?\.(?:webp|jpe?g|png|avif))",
    re.IGNORECASE,
)


def _page_number(position, filename, markers):
    """Page number for an image, or None when it carries no usable order.

    The live page wraps every scan in ``<div class="reader-img-wrap"
    data-page="N">``; the image file itself is a content hash now (it used to
    be ``N.webp``), so the wrapper is authoritative and a numeric filename is
    only the fallback for older uploads.
    """
    number = None
    for start, page in markers:
        if start > position:
            break
        number = page
    if number is not None:
        return number
    stem = filename.rsplit(".", 1)[0]
    return int(stem) if stem.isdigit() else None


def parse_chapter(html, upload_id):
    """Map a /view_uploads page to [{page, img}] through the image proxy.

    ``<link rel=preload>`` repeats the same URLs before the reader markup, so
    entries are de-duplicated by URL and ordered by their page number.
    """
    text = html or ""
    markers = [(m.start(), int(m.group(1))) for m in _PAGE_MARK.finditer(text)]
    by_page = {}
    seen = set()
    for match in _PAGE_IMAGE.finditer(text):
        url = match.group(0)
        if url in seen:
            continue
        number = _page_number(match.start(), match.group(1), markers)
        if number is None:
            continue
        seen.add(url)
        by_page.setdefault(number, url)
    return [{"page": number, "img": proxy_url(url)} for number, url in sorted(by_page.items())]


# ── HTTP (rate limited + cached, dead-domain aware) ────────────────────────

def _request(url):
    _check_alive()
    request = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/json, text/html;q=0.9",
        "Accept-Language": "es-ES,es;q=0.9",
    })
    last_error = None
    for attempt in range(3):
        _rate_limit()
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                text = response.read().decode("utf-8", "replace")
            _mark_alive()
            return text
        except urllib.error.HTTPError as error:
            if error.code == 429 or 500 <= error.code < 600:
                time.sleep(1.5 * (attempt + 1))
                last_error = error
                continue
            _mark_alive()  # a 4xx means the domain answered; not dead
            raise
        except Exception as error:  # noqa: BLE001 — DNS/connection reset/timeout
            last_error = error
            time.sleep(0.5 * (attempt + 1))
    _mark_dead()
    raise last_error


def _get_json(url):
    return json.loads(_request(url))


def _get_html(url):
    return _request(url)


def _slug(value):
    return urllib.parse.quote(str(value or ""), safe="")


# ── public API (mirrors manga_server.py) ───────────────────────────────────

def search(query, mtype=None, offset=0, sort="Best Match"):
    url = f"{BASE}/api/search/suggest?" + urllib.parse.urlencode({"q": query})
    payload = _cached(f"zo-search:{query}", TTL_SEARCH, lambda: _get_json(url))
    results = parse_suggest(payload)
    if mtype:
        wanted = str(mtype).strip().upper()
        results = [item for item in results if item["type"] == wanted]
    return {"results": results, "hasMore": False, "nextOffset": int(offset or 0) + len(results)}


def latest(page=1):
    page = max(int(page or 1), 1)
    html = _cached(f"zo-list:{page}", TTL_LIST, lambda: _get_html(f"{BASE}/biblioteca?page={page}"))
    results = parse_biblioteca(html)
    return {"results": results, "hasMore": f"page={page + 1}" in html, "nextPage": page + 1}


def hot():
    html = _cached("zo-hot", TTL_LIST, lambda: _get_html(f"{BASE}/biblioteca?page=1"))
    return parse_biblioteca(html)


def info(series_path):
    path = str(series_path or "").strip().lstrip("/")
    html = _cached(f"zo-series:{path}", TTL_INFO, lambda: _get_html(f"{BASE}/{path}"))
    return parse_series(html, path)


def pages(chapter_id):
    upload = str(chapter_id or "").strip()
    if not upload:
        return []
    html = _cached(f"zo-chapter:{upload}", TTL_PAGES,
                   lambda: _get_html(f"{BASE}/view_uploads/{_slug(upload)}"))
    return parse_chapter(html, upload)
