"""zonatmo.net source (Spanish manhwa/manga) — same JSON contract as manga_server.py.

zonatmo.net is a post-takedown Spanish aggregator (WordPress + a JSON API under
``https://zonatmo.net/wp-api/api``). It is Spanish-only, so a series exists only
when it has Spanish chapters. Endpoints (verified 2026-10):

    listing    GET /listing/manga?search=QUERY&page=N          -> data.items[] (+ pagination)
    listing    GET /listing/manga?page=N&type=ID               -> default (newest) order
    detail     GET /single/manga/SLUG
    chapters   GET /single/manga/SLUG/chapters?page=N          -> data.items[] (+ pagination)
    reader     GET /single/manga/SLUG/CHAPTER-SLUG             -> data.chapter.{jit,images[]}
    image      https://cdn.zonatmo.to/manga/<jit>/<image_url>
    cover      https://zonatmo.net/wp-content/uploads<cover>

Notes:
  * listing ``order=``/``sort=`` are ignored by the API, so latest()/hot() use the
    listing's own default (newest) order, as the API provides no ordering knob.
  * a chapter slug already carries the manga slug (``solo-leveling-capitulo-1``),
    so a chapter id is ``<manga-slug>/<chapter-slug>`` — exactly what the reader
    needs, and it keeps info()/pages() routable through the chain prefix.
  * ``types``/``status``/``years``/``genres`` arrive as taxonomy ids; the maps
    below were captured from the site's own reference dictionary.

The parsers are pure and fixture-tested; the tests never touch the network.
"""

import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://zonatmo.net/wp-api/api"
CDN = "https://cdn.zonatmo.to/manga"
UPLOADS = "https://zonatmo.net/wp-content/uploads"
PROXY_PORT = 5150  # same image proxy as manga_server.py
USER_AGENT = "qs-novelmangareader-es/0.1 (+https://github.com/dhrruvsharma/qs-novelmangareader)"
PAGE_LIMIT = 12           # /listing/manga default per_page
CHAPTER_PAGE_LIMIT = 25   # /single/manga/.../chapters default per_page
MAX_CHAPTER_PAGES = 40    # safety cap on chapter pagination

# ── taxonomy maps (captured from the site's reference dictionary) ──────────
_TYPE = {
    "14": "MANGA", "87": "MANHWA", "31": "MANHUA", "214": "NOVELA",
    "207": "DOUJINSHI", "976": "OEL", "12920": "novel",
    "12919": "one_shot", "12312": "ONE SHOT",
}
_STATUS = {
    "12": "Publicándose", "19": "Finalizado", "198": "Cancelado", "174": "Pausado",
    "12917": "desconocido", "12922": "en pausa", "12856": "En curso",
    "12869": "publishing", "12874": "Completado", "12866": "OnGoing",
}
_YEAR = {
    "1145": "2020", "1674": "2021", "3639": "2022", "1098": "2019", "25": "2016",
    "1182": "2018", "2040": "2017", "3523": "2023", "6113": "2024", "63": "2015",
    "11": "2014", "30": "2013", "43": "2012", "35": "2011", "5724": "2025",
    "52": "2009", "58": "2010", "94": "2008", "66": "2007", "70": "2006",
    "318": "1998", "98": "2005", "78": "2004", "1781": "2037", "143": "1997",
    "124": "2003", "92": "1999", "114": "2002", "86": "2001", "106": "2000",
    "18": "1996", "12314": "2026", "179": "1992", "752": "1991", "232": "1990",
    "127": "1995", "1051": "1993", "273": "1994", "587": "1983", "226": "1989",
    "544": "1984", "898": "1988", "84": "1987", "230": "1985", "448": "1982",
    "1653": "1986", "314": "1972", "1418": "1980", "2606": "1978", "547": "1975",
}
_GENRE = {
    "16": "Romance", "4": "Comedia", "15": "Drama", "5": "Fantasia", "2": "Acción",
    "103": "Boys Love", "33": "Recuentos de la vida", "23": "Vida Escolar",
    "3": "Aventura", "32": "Ecchi", "7": "Sobrenatural", "60": "Reencarnación",
    "8": "Harem", "6": "Magia", "36": "Psicológico", "40": "Misterio",
    "26": "Artes Marciales", "21": "Ciencia Ficción", "22": "Girls Love",
    "46": "Tragedia", "81": "Historia", "88": "Demonios", "116": "Superpoderes",
    "82": "Horror", "112": "Supervivencia", "181": "Gore", "1027": "Familia",
    "183": "Género Bender", "861": "Apocalíptico", "41": "Crimen", "49": "Thriller",
    "37": "Deporte", "147": "Realidad", "342": "Militar", "1109": "Guerra",
    "820": "Parodia", "345": "Vampiros", "403": "Musica", "219": "Niños",
    "27": "Realidad Virtual", "144": "Mecha", "111": "Policiaco", "470": "Telenovela",
    "12868": "Sistema de Niveles", "99": "Samurái", "6198": "Animación",
    "356": "Ciberpunk", "1168": "Extranjero", "12915": "Academia", "12891": "Venganza",
}
_DEMO = {"13": "shounen", "20": "shoujo", "45": "seinen", "55": "josei", "633": "kodomo"}

_TYPE_PARAM = {"manga": "14", "manhwa": "87", "manhua": "31", "novela": "214", "novel": "214"}

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


def proxy_url(img_url):
    if not img_url:
        return ""
    return f"http://127.0.0.1:{PROXY_PORT}/image?url={urllib.parse.quote(img_url, safe='')}"


def type_param(mtype):
    """Map a UI type filter ("Manga"/"Manhwa"/"Manhua") to the API ``type`` id."""
    if not mtype:
        return None
    return _TYPE_PARAM.get(str(mtype).strip().lower())


# ── pure mappers (fixture-tested) ──────────────────────────────────────────

def _name(mapping, values):
    for value in values or []:
        name = mapping.get(str(value))
        if name:
            return name
    return ""


def _tags(item):
    out = []
    for gid in item.get("genres") or []:
        name = _GENRE.get(str(gid))
        if name and name not in out:
            out.append(name)
    for did in item.get("demography") or []:
        name = _DEMO.get(str(did))
        if name and name not in out:
            out.append(name)
    return out


def _cover(item):
    cover = item.get("cover") or ""
    return f"{UPLOADS}{cover}" if cover else ""


def _list_item(item):
    return {
        "id": item.get("slug", ""),
        "title": item.get("title", ""),
        "image": proxy_url(_cover(item)),
        "status": _name(_STATUS, item.get("status")),
        "year": _name(_YEAR, item.get("years")),
        "type": _name(_TYPE, item.get("types")),
        "chapter": str(item.get("total_chapters") or ""),
        "updatedAt": item.get("updated_at", ""),
        "tags": _tags(item),
    }


def parse_listing(payload):
    """Map a /listing/manga payload to contract list items."""
    data = payload.get("data") or {}
    return [_list_item(item) for item in data.get("items") or []]


def _pagination(payload):
    return (payload.get("data") or {}).get("pagination") or {}


def map_search(payload, offset=0):
    results = parse_listing(payload)
    return {
        "results": results,
        "hasMore": bool(_pagination(payload).get("has_next")),
        "nextOffset": int(offset or 0) + len(results),
    }


def map_latest(payload, page):
    results = parse_listing(payload)
    return {
        "results": results,
        "hasMore": bool(_pagination(payload).get("has_next")),
        "nextPage": page + 1,
    }


def map_hot(payload):
    return parse_listing(payload)


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


def parse_chapters(payload, manga_slug):
    """Map a /chapters payload to contract chapters (ascending by number)."""
    data = payload.get("data") or {}
    chapters = []
    for item in data.get("items") or []:
        slug = item.get("slug") or ""
        if not slug:
            continue
        number = _clean_number(item.get("chapter_number"))
        chapters.append({
            "_sort": _sort_key(item.get("chapter_number")),
            "id": f"{manga_slug}/{slug}",
            "chapter": number,
            "title": item.get("title") or (f"Capítulo {number}" if number else "Capítulo"),
            "group": (item.get("group") or {}).get("name") or "",
            "publishAt": item.get("release_date") or "",
        })
    chapters.sort(key=lambda c: c["_sort"])
    for chapter in chapters:
        chapter.pop("_sort", None)
    return chapters


def parse_reader(payload):
    """Map a reader payload to [{page, img}] through the image proxy."""
    chapter = (payload.get("data") or {}).get("chapter") or {}
    jit = chapter.get("jit") or ""
    pages = []
    for image in chapter.get("images") or []:
        name = image.get("image_url") or ""
        if not jit or not name:
            continue
        url = f"{CDN}/{jit}/{name}"
        pages.append({"page": int(image.get("page_number") or len(pages) + 1), "img": proxy_url(url)})
    pages.sort(key=lambda page: page["page"])
    return pages


def parse_info(detail, chapters, manga_slug):
    """Build the contract info object from the detail + chapter payloads."""
    data = detail.get("data") or {}
    authors = []
    for author in data.get("author") or []:
        name = (author.get("name") or "").strip()
        if name and name not in authors:
            authors.append(name)
    return {
        "id": manga_slug,
        "title": data.get("title", ""),
        "description": data.get("overview", ""),
        "status": _name(_STATUS, data.get("status")),
        "image": proxy_url(_cover(data)),
        "authors": authors,
        "tags": _tags(data),
        "chapters": parse_chapters(chapters, manga_slug),
    }


# ── HTTP (rate limited + cached) ───────────────────────────────────────────

def _http_json(path, params=None):
    url = BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    last_error = None
    for attempt in range(3):
        _rate_limit()
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


def _slug(value):
    return urllib.parse.quote(str(value or ""), safe="")


def _all_chapters(manga_slug):
    """Fetch every chapter page and return one merged payload."""
    items = []
    page = 1
    while page <= MAX_CHAPTER_PAGES:
        payload = _http_json(f"/single/manga/{_slug(manga_slug)}/chapters", {"page": page})
        data = payload.get("data") or {}
        items.extend(data.get("items") or [])
        if not (data.get("pagination") or {}).get("has_next"):
            break
        page += 1
    return {"data": {"items": items}}


# ── public API (mirrors manga_server.py) ───────────────────────────────────

def search(query, mtype=None, offset=0, sort="Best Match"):
    offset = int(offset or 0)
    params = {"search": query, "page": offset // PAGE_LIMIT + 1}
    tparam = type_param(mtype)
    if tparam:
        params["type"] = tparam
    key = "zt-search:" + urllib.parse.urlencode(sorted(params.items()))
    payload = _cached(key, TTL_SEARCH, lambda: _http_json("/listing/manga", params))
    return map_search(payload, offset)


def latest(page=1):
    page = max(int(page or 1), 1)
    payload = _cached(f"zt-latest:{page}", TTL_LIST,
                      lambda: _http_json("/listing/manga", {"page": page}))
    return map_latest(payload, page)


def hot():
    payload = _cached("zt-hot", TTL_LIST, lambda: _http_json("/listing/manga", {"page": 1}))
    return map_hot(payload)


def info(manga_slug):
    slug = _slug(manga_slug)
    detail = _cached(f"zt-detail:{manga_slug}", TTL_INFO,
                     lambda: _http_json(f"/single/manga/{slug}"))
    chapters = _cached(f"zt-chapters:{manga_slug}", TTL_INFO, lambda: _all_chapters(manga_slug))
    return parse_info(detail, chapters, manga_slug)


def pages(chapter_id):
    manga_slug, _, chapter_slug = str(chapter_id or "").partition("/")
    if not manga_slug or not chapter_slug:
        return []
    payload = _cached(f"zt-reader:{chapter_id}", TTL_PAGES,
                      lambda: _http_json(f"/single/manga/{_slug(manga_slug)}/{_slug(chapter_slug)}"))
    return parse_reader(payload)
