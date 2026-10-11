"""JKAnime source (Spanish, jkanime.net) for the anime chain.

Provides search / episode list / stream links with the SAME shape anime_server
uses (search items, episode numbers, links with url/quality/type/referer and a
subtitle label). JKAnime streams are Spanish-subtitled (hardsubbed), so there is
no separate subtitle file: ``subtitle_label`` is "Español (hardsub)".

Scraping pattern (verified; mirrors ani-cli-mx):
  search   GET  /buscar?q=<query>                       -> result blocks
  page     GET  /<slug>/                                -> anime_id + csrf-token
  episodes POST /ajax/episodes/<anime_id>/<page> (_token) -> Laravel paginator
  stream   GET  /<slug>/<ep>/                           -> video[N] iframes
           GET  <player>                                -> <source src='...'> (m3u8)

curl_cffi is used when installed (form fields passed as a dict), else urllib.
Rate limited and short-cached; parsers are pure and fixture-tested.
"""

import json
import os
import re
import threading
import time
import urllib.parse
import urllib.request

BASE = "https://jkanime.net"
USER_AGENT = "qs-novelmangareader-es/0.1 (+https://github.com/dhrruvsharma/qs-novelmangareader)"

try:
    from curl_cffi.requests import Session as _CffiSession
    _HAVE_CFFI = True
except Exception:  # noqa: BLE001
    _CffiSession = None
    _HAVE_CFFI = False

_lock = threading.Lock()
_last = [0.0]
INTERVAL = 0.4  # ~2.5 req/s (JKAnime throttles)

_cache = {}
_cache_lock = threading.Lock()
TTL_SEARCH = 600
TTL_EPISODES = 1800
TTL_LINKS = 300

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


def _fetch(url, params=None, data=None, referer=None, ajax=False):
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params, doseq=True)
    headers = {"User-Agent": USER_AGENT, "Accept-Language": "es-ES,es;q=0.9"}
    if referer:
        headers["Referer"] = referer
    if ajax:
        headers["X-Requested-With"] = "XMLHttpRequest"
    _rate_limit()
    if _HAVE_CFFI:
        session = getattr(_cffi_local, "session", None)
        if session is None:
            session = _CffiSession(impersonate="firefox")
            _cffi_local.session = session
        resp = session.request("POST" if data else "GET", url, data=data, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.text
    body = urllib.parse.urlencode(data, doseq=True).encode() if data else None
    request = urllib.request.Request(url, headers=headers, data=body)
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "replace")


# ── pure parsers (fixture-tested) ──────────────────────────────────────────

def parse_search(html):
    """Result blocks -> anime_server search items (raw slug ids)."""
    results = []
    for block in re.split(r'(?=<div class="col-lg-2 col-md-6 col-sm-6")', html)[1:]:
        slug = re.search(r'<a\s+href="https://jkanime\.net/([^"/]+)/"', block)
        if not slug:
            continue
        title = re.search(r"<h5[^>]*>\s*<a\b[^>]*>([^<]+)</a>", block)
        cover = re.search(r'data-setbg="([^"]+)"', block)
        name = title.group(1).strip() if title else ""
        results.append({
            "id": slug.group(1),
            "name": name,
            "english_name": name,
            "native_name": "",
            "thumbnail": cover.group(1) if cover else "",
            "score": None,
            "episode_count": "",
            "available_episodes": {"sub": 1, "dub": 0, "raw": 0},
        })
    return results


def parse_anime_id(html):
    match = re.search(r"anime_checks\('[^']*',\s*'([0-9]+)'", html)
    return match.group(1) if match else ""


def parse_csrf(html):
    match = re.search(r'<meta name="csrf-token" content="([^"]+)"', html)
    return match.group(1) if match else ""


def parse_episodes(raw):
    """A Laravel paginator page -> list of episode number strings."""
    data = json.loads(raw)
    numbers = []
    for item in data.get("data", []):
        number = item.get("number")
        if number is not None:
            numbers.append(str(number))
    return numbers


def parse_iframes(html):
    return re.findall(r"video\[\d+\]\s*=\s*'<iframe[^']*src=\"([^\"]+)\"", html)


def parse_source(player_html):
    match = re.search(r"<source src='([^']+)'", player_html) or re.search(r"url:\s*'([^']+)'", player_html)
    return match.group(1) if match else ""


# ── public API ─────────────────────────────────────────────────────────────

def search(query):
    html = _cached(f"jk-search:{query}", TTL_SEARCH,
                   lambda: _fetch(f"{BASE}/buscar", params={"q": query}))
    return parse_search(html)


def episodes(slug):
    def load():
        page = _fetch(f"{BASE}/{slug}/")
        anime_id = parse_anime_id(page)
        csrf = parse_csrf(page)
        if not anime_id or not csrf:
            return []
        numbers = []
        current = 1
        while True:
            raw = _fetch(f"{BASE}/ajax/episodes/{anime_id}/{current}",
                         data={"_token": csrf}, referer=f"{BASE}/{slug}/", ajax=True)
            numbers.extend(parse_episodes(raw))
            try:
                last = int(json.loads(raw).get("last_page") or 1)
            except Exception:  # noqa: BLE001
                last = 1
            if current >= last:
                break
            current += 1
        return sorted(set(numbers), key=lambda n: float(n))

    return _cached(f"jk-eps:{slug}", TTL_EPISODES, load)


def links(slug, ep):
    def load():
        page = _fetch(f"{BASE}/{slug}/{ep}/")
        out = []
        for player in parse_iframes(page):
            player_url = BASE + player if player.startswith("/") else player
            try:
                player_html = _fetch(player_url, referer=f"{BASE}/{slug}/{ep}/")
            except Exception:  # noqa: BLE001
                continue
            source = parse_source(player_html)
            if source:
                out.append({
                    "quality": "best",
                    "url": source,
                    "type": "m3u8",
                    "provider": "JKAnime",
                    "referer": player_url,
                    "subtitle": "",
                    "subtitle_label": "Español (hardsub)",
                })
        return out

    return _cached(f"jk-links:{slug}:{ep}", TTL_LINKS, load)
