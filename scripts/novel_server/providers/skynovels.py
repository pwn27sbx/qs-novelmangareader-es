"""
SkyNovels provider  –  https://skynovels.net  (Spanish light/web novels)

Uses the site's JSON API (base https://api.skynovels.net/api), discovered from
the Angular SSR state — no HTML scraping:

  list/search  GET /novels?page=<n>&q=<query>      -> {novels, total, totalPages}
  info         GET /novels/<id>/base  +  /novels/<id>/volumes
               GET /volumes/<nvl>/<vol>/chapters?page=<n>   -> {items, pagination}
  chapter      GET /chapters/<id>                  -> {chapter:{chp_title, chp_content}}
  image        GET /get-image/<file>/novels/true

Chapters are in Spanish. `q` is the search parameter (not `search`).
"""

import json
import re
from urllib.parse import quote, urlencode

from .base import NovelProvider
from .utils import fetch, fetch_bytes, cached, clean_text

API = "https://api.skynovels.net/api"
SITE = "https://www.skynovels.net"

TTL_HOT = 300
TTL_LATEST = 120
TTL_SEARCH = 600
TTL_INFO = 1800
TTL_CHAP = 86400

_API_HEADERS = {
    "Accept": "application/json",
    "Origin": SITE,
    "Referer": SITE + "/",
}


def _paragraphs(html: str) -> list:
    text = re.sub(r"(?i)</p\s*>|<br\s*/?>", "\n", html or "")
    parts = [clean_text(part) for part in text.split("\n")]
    return [part for part in parts if part]


class SkynovelsProvider(NovelProvider):
    name = "skynovels"
    label = "SkyNovels"

    # ── Internal helpers ──────────────────────────────────────────────────

    def _key(self, *parts) -> str:
        return f"{self.name}:" + ":".join(str(p) for p in parts)

    def _api(self, path: str, params: dict | None = None) -> dict:
        url = API + path
        if params:
            url += "?" + urlencode(params)
        return json.loads(fetch(url, extra_headers=_API_HEADERS))

    @staticmethod
    def _proxy(image: str, port: int = 5151) -> str:
        if not image:
            return ""
        full = image if image.startswith("http") else f"{API}/get-image/{image}/novels/true"
        return f"http://127.0.0.1:{port}/image?url={quote(full, safe='')}"

    @staticmethod
    def _card(novel: dict) -> dict:
        return {
            "id": str(novel.get("id", "")),
            "title": novel.get("nvl_title") or novel.get("nvl_name") or "",
            "image": SkynovelsProvider._proxy(novel.get("image", "")),
            "author": novel.get("nvl_writer") or "",
            "latestChapter": str(novel.get("nvl_chapters") or ""),
        }

    def _chapter_list(self, novel_id: str) -> list:
        volumes = self._api(f"/novels/{novel_id}/volumes").get("volumes", [])
        chapters = []
        for volume in volumes:
            page = 1
            while True:
                data = self._api(f"/volumes/{novel_id}/{volume.get('id')}/chapters", {"page": page})
                for item in data.get("items", []):
                    number = item.get("chp_number")
                    chapters.append({
                        "id": str(item.get("id", "")),
                        "title": item.get("chp_title") or item.get("chp_index_title") or "",
                        "chapter": str(number if number is not None else ""),
                        "_n": number or 0,
                    })
                pagination = data.get("pagination") or {}
                last = pagination.get("lastPage") or pagination.get("last_page") or 1
                if page >= int(last):
                    break
                page += 1
        chapters.sort(key=lambda c: c["_n"])
        for chapter in chapters:
            chapter.pop("_n", None)
        return chapters

    # ── NovelProvider interface ───────────────────────────────────────────

    def search(self, query, genre=None, status="All", page=1) -> dict:
        def load():
            data = self._api("/novels", {"page": page, "q": query})
            results = [self._card(n) for n in data.get("novels", [])]
            total_pages = int(data.get("totalPages") or 1)
            return {"results": results, "hasMore": page < total_pages, "nextPage": page + 1}

        return cached(self._key("search", query, genre, status, page), TTL_SEARCH, load)

    def info(self, novel_id: str) -> dict:
        def load():
            base = self._api(f"/novels/{novel_id}/base").get("novel", {})
            return {
                "id": str(base.get("id", novel_id)),
                "title": base.get("nvl_title") or base.get("nvl_name") or "",
                "description": clean_text(base.get("nvl_content") or ""),
                "status": base.get("nvl_status") or "",
                "author": base.get("nvl_author") or "",
                "image": self._proxy(base.get("image", "")),
                "genres": [],
                "chapters": self._chapter_list(novel_id),
            }

        return cached(self._key("info", novel_id), TTL_INFO, load)

    def chapter(self, chapter_id: str) -> dict:
        def load():
            chapter = self._api(f"/chapters/{chapter_id}").get("chapter", {})
            paragraphs = _paragraphs(chapter.get("chp_content") or "")
            prev_id = next_id = ""
            novel_id = chapter.get("nvl_id")
            if novel_id:
                try:
                    siblings = self._chapter_list(str(novel_id))
                    index = next((i for i, c in enumerate(siblings) if c["id"] == str(chapter_id)), -1)
                    if index > 0:
                        prev_id = siblings[index - 1]["id"]
                    if 0 <= index < len(siblings) - 1:
                        next_id = siblings[index + 1]["id"]
                except Exception:  # noqa: BLE001 — neighbours are best effort
                    pass
            return {
                "id": str(chapter.get("id", chapter_id)),
                "title": chapter.get("chp_title") or "",
                "paragraphs": paragraphs,
                "wordCount": sum(len(p.split()) for p in paragraphs),
                "prevId": prev_id,
                "nextId": next_id,
            }

        return cached(self._key("chapter", chapter_id), TTL_CHAP, load)

    def hot(self) -> list:
        return cached(self._key("hot"), TTL_HOT,
                      lambda: [self._card(n) for n in self._api("/novels", {"page": 1}).get("novels", [])])

    def latest(self, page: int = 1) -> dict:
        def load():
            data = self._api("/novels", {"page": page})
            results = [self._card(n) for n in data.get("novels", [])]
            total_pages = int(data.get("totalPages") or 1)
            return {"results": results, "hasMore": page < total_pages, "nextPage": page + 1}

        return cached(self._key("latest", page), TTL_LATEST, load)

    def fetch_image(self, url: str) -> tuple[bytes, str]:
        return fetch_bytes(url)
