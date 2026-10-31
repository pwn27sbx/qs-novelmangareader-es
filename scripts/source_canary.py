"""Contract canary for the Spanish sources.

The reader depends on third-party sites whose API can change under us. On
2026-10-27 zonatmo.net answered HTTP 200 with an empty `items` list and 404 on
its detail/reader endpoints: no exception anywhere, so nothing reported the
break; the owner found it by opening a title.

This canary asks each source a fixed, cheap question and fails loudly when the
answer stops looking like content:

    python3 scripts/source_canary.py                    # every active ES source
    python3 scripts/source_canary.py --source zonatmo_org
    python3 scripts/source_canary.py --json

Exit codes: 0 all good, 1 at least one source broke, 2 the canary could not run.

It never trusts the local image proxy: a module's `img` field points at
127.0.0.1:5150, which only exists while the app runs, so the origin URL is
fetched directly (use --via-proxy to go through the proxy instead).
"""

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import urllib.error

QUERY = "solo leveling"          # manhwa sources: cheap and always present
MIN_IMAGE_BYTES = 1024           # a real scan is far bigger than a placeholder
PROBE_DETAIL_TRIES = 5           # detail the first N hits until one has Spanish chapters
TIMEOUT = 30
USER_AGENT = "qs-nmr-canary/1.0 (+https://github.com/pwn27sbx/qs-novelmangareader-es)"
# Image CDNs answer 403 to a bare client: the app's proxy sends the same
# browser UA and per-host Referer (see manga_server.IMAGE_REFERERS).
BROWSER_UA = "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
IMAGE_REFERERS = {
    "img1mw.xyz": "https://manhwaweb.com/",
    "img2mw.xyz": "https://manhwaweb.com/",
    "uploads.manhwaweb.com": "https://manhwaweb.com/",
}
# MangaDex's at-home nodes answer 404 without the site Referer, and the node
# host is per-user (cmdxd98sb0x3yprd.mangadex.network), so match by suffix.
REFERER_SUFFIXES = (".mangadex.network",)
REFERER_DEFAULTS = {"mangadex.network": "https://mangadex.org/"}


def referer_for(host):
    """The Referer an image CDN insists on, or "" when it needs none."""
    host = (host or "").lower()
    if host in IMAGE_REFERERS:
        return IMAGE_REFERERS[host]
    for suffix, referer in REFERER_DEFAULTS.items():
        if host == suffix or host.endswith("." + suffix):
            return referer
    return ""

SOURCES = ("mangadex", "inmanga", "zonatmo", "zonatmo_org", "manhwaweb")

# One fixed query per source: "solo leveling" does not exist on MangaDex with a
# Spanish translation, nor on InManga, so a single global query would report
# those two as broken forever.
PROBE_QUERY = {
    "mangadex": "naruto",
    "inmanga": "naruto",
    "zonatmo": QUERY,
    "zonatmo_org": QUERY,
    "manhwaweb": QUERY,
}


def image_origin(img_url):
    """Origin URL behind a module's `img` field (the local proxy is unwrapped)."""
    parsed = urllib.parse.urlsplit(str(img_url or ""))
    if parsed.path.endswith("/image"):
        raw = urllib.parse.parse_qs(parsed.query).get("url")
        if raw and raw[0]:
            return raw[0]
    return str(img_url or "")


def sniff_image(data):
    """Image format from magic bytes, or "" when it is not an image."""
    head = bytes(data or b"")[:16]
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if head[:3] == b"\xff\xd8\xff":
        return "jpeg"
    if head[:4] == b"GIF8":
        return "gif"
    if head[4:12] == b"ftypavif":
        return "avif"
    return ""


def fetch_bytes(url, timeout=TIMEOUT):
    """GET `url` and return the body (raises on 4xx/5xx)."""
    host = (urllib.parse.urlsplit(url).hostname or "").lower()
    headers = {
        "User-Agent": BROWSER_UA,
        "Accept": "image/avif,image/webp,image/*,*/*;q=0.8",
    }
    referer = referer_for(host)
    if referer:
        headers["Referer"] = referer
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def check_image(url, fetch=fetch_bytes):
    """Problems with the first page of a chapter, judged from its bytes."""
    if not url:
        return ["image: no url"]
    try:
        body = fetch(url)
    except Exception as error:  # noqa: BLE001 — the canary reports, never raises
        status = getattr(getattr(error, "response", None), "status", None)
        return [f"image: {type(error).__name__}{'' if status is None else ' ' + str(status)}"]
    kind = sniff_image(body)
    if not kind:
        return ["image: not an image (html or placeholder)"]
    if len(body) < MIN_IMAGE_BYTES:
        return [f"image: too small ({len(body)} bytes)"]
    return []


def page_image(page):
    """Image URL of one page entry.

    Most sources answer ``{"page": 1, "img": "..."}``; manhwaweb answers a bare
    URL string. The canary accepts both so one module's shape cannot decide
    whether the *site* is broken (that mismatch is reported separately).
    """
    if isinstance(page, dict):
        return page.get("img") or ""
    return page if isinstance(page, str) else ""


def probe(module, fetch=fetch_bytes, query=QUERY):
    """(problems, stats, first item id) for one source module."""
    problems = []
    stats = {"search": 0, "chapters": 0, "pages": 0, "image": ""}

    try:
        found = module.search(query, None, 0, "Best Match")
    except Exception as error:  # noqa: BLE001
        return [f"search: {type(error).__name__}"], stats, ""
    items = (found or {}).get("results") or []
    stats["search"] = len(items)
    if not items:
        return ["search: no results"], stats, ""
    first_id = (items[0] or {}).get("id") or ""
    if not first_id:
        problems.append("search: item without id")

    # The top hit is not always the one with Spanish chapters (MangaDex's
    # "Naruto" has none, its coloured edition has 82), so the canary asks the
    # first few: the question is whether the source can serve Spanish at all.
    data = {}
    item_id = ""
    for candidate in items[:PROBE_DETAIL_TRIES]:
        candidate_id = (candidate or {}).get("id") or ""
        if not candidate_id:
            continue
        try:
            candidate_data = module.info(candidate_id) or {}
        except Exception as error:  # noqa: BLE001
            return problems + [f"detail: {type(error).__name__}"], stats, candidate_id
        if candidate_data.get("chapters"):
            data, item_id = candidate_data, candidate_id
            break

    if not item_id:
        return (problems + [f"detail: no chapters in the first {PROBE_DETAIL_TRIES} results"],
                stats, first_id)
    if not data.get("title"):
        problems.append("detail: no title")
    chapters = data.get("chapters") or []
    stats["chapters"] = len(chapters)

    chapter_id = (chapters[0] or {}).get("id") or ""
    try:
        pages = module.pages(chapter_id) or []
    except Exception as error:  # noqa: BLE001
        return problems + [f"pages: {type(error).__name__}"], stats, item_id
    stats["pages"] = len(pages)
    if not pages:
        return problems + ["pages: no images"], stats, item_id

    image_url = page_image(pages[0])
    image_problems = check_image(image_origin(image_url), fetch)
    problems.extend(image_problems)
    stats["image"] = "" if image_problems else "ok"
    return problems, stats, item_id


def check_source(name, module, fetch=fetch_bytes):
    """Every problem found for one source (empty list when it is healthy)."""
    return probe(module, fetch)[0]


def check_chain(name, item_id, info=None):
    """The same source routed through the chain, so wiring regressions show up."""
    if info is None:
        import manga_chain
        info = manga_chain.info
    previous = os.environ.get("QS_MANGA_SOURCE")
    os.environ["QS_MANGA_SOURCE"] = name
    try:
        data = info(f"{name}:{item_id}") or {}
    except Exception as error:  # noqa: BLE001
        return [f"chain: {type(error).__name__}"]
    finally:
        if previous is None:
            os.environ.pop("QS_MANGA_SOURCE", None)
        else:
            os.environ["QS_MANGA_SOURCE"] = previous
    if data.get("error"):
        return [f"chain: {data['error']}"]
    if not (data.get("chapters") or []):
        return ["chain: no chapters"]
    return []


def run(sources, modules, fetch=fetch_bytes, chain=True):
    """(lines, exit code) for the requested sources."""
    lines = []
    broken = 0
    for name in sources:
        module = modules.get(name)
        if module is None:
            lines.append(f"FAIL {name}: unknown source")
            broken += 1
            continue
        problems, stats, item_id = probe(module, fetch, PROBE_QUERY.get(name, QUERY))
        if not problems and chain and item_id:
            problems = check_chain(name, item_id)
        if problems:
            broken += 1
            lines.append(f"FAIL {name}: " + "; ".join(problems))
        else:
            lines.append(
                f"ok   {name}: search={stats['search']} chapters={stats['chapters']} "
                f"pages={stats['pages']} image=ok"
            )
    return lines, (1 if broken else 0)


ENV_FILE = "~/.config/qs-nmr/canary.env"


def load_env_file(path=ENV_FILE):
    """KEY=VALUE pairs from the secret file (comments and blanks skipped)."""
    values = {}
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                name, _, value = line.partition("=")
                values[name.strip()] = value.strip()
    except FileNotFoundError:
        return {}
    return values


def post_json(url, payload, timeout=TIMEOUT):
    """(status, body) for one JSON POST; never raises."""
    request = urllib.request.Request(
        url, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": USER_AGENT},
        method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()
    except Exception as error:  # noqa: BLE001 — the canary reports, never raises
        return None, str(error).encode()


def notify(webhook, text, post=post_json):
    """Post one message to the Discord webhook. False when it did not arrive."""
    if not webhook:
        return False
    url = webhook + ("&" if "?" in webhook else "?") + "wait=true"
    status, _ = post(url, {"content": str(text)[:1900], "allowed_mentions": {"parse": []}})
    return status is not None and 200 <= status < 300


def checkin(checkin_url, status, duration=None, post=post_json):
    """Report one run to the Sentry cron monitor. False when it was rejected.

    The state goes in the JSON body: this endpoint answers
    "422 missing field 'status'" to the ?status=... form the docs show.
    """
    if not checkin_url:
        return False
    payload = {"status": status}
    if duration is not None:
        payload["duration"] = round(float(duration), 3)
    code, _ = post(checkin_url, payload)
    return code is not None and 200 <= code < 300


def report(code, lines, elapsed, webhook="", checkin_url="", post=post_json):
    """Send the run's outcome to Sentry and, only on failure, to Discord.

    Returns (checkin_sent, notified) so the caller can log both without
    printing any secret.
    """
    checkin_sent = checkin(checkin_url, "ok" if code == 0 else "error", elapsed, post)
    notified = False
    if code != 0:
        title = "⚠ qs-nmr canary: una fuente rompió su contrato"
        notified = notify(webhook, title + "\n```\n" + "\n".join(lines) + "\n```", post)
    return checkin_sent, notified


def load_modules():
    """The real source modules, imported only when the canary actually runs."""
    import inmanga_source
    import manga_sources
    import manhwaweb_source
    import zonatmo_org_source
    import zonatmo_source

    return {
        "mangadex": manga_sources,
        "inmanga": inmanga_source,
        "zonatmo": zonatmo_source,
        "zonatmo_org": zonatmo_org_source,
        "manhwaweb": manhwaweb_source,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description="Contract canary for the Spanish sources.")
    parser.add_argument("--source", action="append", choices=SOURCES,
                        help="only check this source (repeatable)")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--no-chain", action="store_true",
                        help="skip the routing check through manga_chain")
    parser.add_argument("--no-report", action="store_true",
                        help="do not send the Sentry check-in or the Discord alert")
    parser.add_argument("--fail", metavar="SOURCE",
                        help="pretend this source broke (tests the alert path)")
    parser.add_argument("--env-file", default=ENV_FILE,
                        help="secrets file with QS_SENTRY_CHECKIN / QS_DISCORD_WEBHOOK")
    args = parser.parse_args(argv)

    try:
        modules = load_modules()
    except Exception as error:  # noqa: BLE001 — the canary itself is broken
        print(f"canary could not load the sources: {type(error).__name__}", file=sys.stderr)
        return 2

    sources = args.source or list(SOURCES)
    started = time.monotonic()
    lines, code = run(sources, modules, fetch_bytes, chain=not args.no_chain)
    if args.fail:
        lines.append(f"FAIL {args.fail}: forced failure (--fail)")
        code = 1
    elapsed = time.monotonic() - started

    if args.json:
        print(json.dumps({
            "sources": sources,
            "ok": code == 0,
            "results": [{"line": line} for line in lines],
        }, ensure_ascii=False))
    else:
        for line in lines:
            print(line)

    if args.no_report:
        return code
    env = load_env_file(args.env_file)
    sent, notified = report(code, lines, elapsed,
                            env.get("QS_DISCORD_WEBHOOK", ""),
                            env.get("QS_SENTRY_CHECKIN", ""))
    print(f"reported: checkin={'yes' if sent else 'no'} discord={'yes' if notified else 'no'}",
          file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
