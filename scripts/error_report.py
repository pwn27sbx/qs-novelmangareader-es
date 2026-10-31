"""Minimal Sentry reporter for the backend, without the SDK.

Why not `sentry-sdk`: it requires `urllib3>=1.26.11` and `certifi`, and the venv
it would land in is shared by the anime, manga and novel servers — a bumped
urllib3 can take all three down. The store endpoint is plain HTTP, so this
module gives what the project actually needs: what broke, in which source and
operation, and a short traceback.

Rules this module keeps:

* Disabled unless `QS_SENTRY_DSN` is set: no DSN, no import cost, no network.
* Never raises into the caller: a reporter that breaks the reader is worse than
  the error it was reporting.
* Deduplicated per (source, op, exception type) with a TTL, so one dead site
  cannot burn the free plan's 5k events while the user browses.
* Privacy by construction: only the exception class, message, source, op and a
  traceback of OUR frames. No locals, no request bodies, no titles.
"""

import json
import os
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request

DEDUPE_TTL = 3600          # one event per (source, op, type) per hour
TIMEOUT = 5                # the reader must not wait on an alert
MAX_MESSAGE = 500
MAX_TRACEBACK = 2000
USER_AGENT = "qs-nmr-backend/1.0 (+https://github.com/pwn27sbx/qs-novelmangareader-es)"

_sent = {}


def parse_dsn(dsn):
    """(host, project_id, public_key) from a DSN, or None when unusable."""
    try:
        parts = urllib.parse.urlsplit(str(dsn or "").strip())
        key = parts.username or ""
        project = (parts.path or "").strip("/")
        if parts.scheme not in ("http", "https") or not parts.hostname or not key or not project:
            return None
        return parts.hostname, project, key
    except Exception:  # noqa: BLE001 — a broken DSN means "reporting off"
        return None


def should_send(source, op, kind, now, sent=None, ttl=DEDUPE_TTL):
    """True when this (source, op, kind) was not reported within the TTL."""
    sent = _sent if sent is None else sent
    key = (source, op, kind)
    last = sent.get(key)
    if last is not None and now - last < ttl:
        return False
    sent[key] = now
    return True


def build_event(error, source="", op="", module="manga_chain"):
    """The event Sentry receives: what broke, where, and a bounded traceback."""
    kind = type(error).__name__
    detail = str(error)[:MAX_MESSAGE]
    trace = "".join(traceback.format_exception(type(error), error, error.__traceback__))
    return {
        "message": f"{source or 'chain'}:{op or '?'} {kind}: {detail}"[:MAX_MESSAGE],
        "level": "error",
        "platform": "python",
        "logger": module,
        # Group by source/operation/type instead of by message text, so a
        # changing chapter title cannot create a new issue every hour.
        "fingerprint": [source or "chain", op or "?", kind],
        "tags": {"source": source or "chain", "op": op or "?"},
        "extra": {"traceback": trace[-MAX_TRACEBACK:]},
    }


def _post(url, payload):
    """(delivered) for one store request; never raises."""
    request = urllib.request.Request(
        url, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": USER_AGENT},
        method="POST")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return 200 <= response.status < 300
    except urllib.error.HTTPError:
        return False
    except Exception:  # noqa: BLE001 — offline, DNS, timeout: stay quiet
        return False


def report(error, source="", op="", dsn=None, sink=None, now=None):
    """Send one event. False when it was skipped or could not be delivered."""
    dsn = os.environ.get("QS_SENTRY_DSN", "") if dsn is None else dsn
    parsed = parse_dsn(dsn)
    if not parsed:
        return False
    host, project, key = parsed
    if not should_send(source, op, type(error).__name__, time.time() if now is None else now):
        return False
    url = f"https://{host}/api/{project}/store/?sentry_key={key}&sentry_version=7"
    try:
        return bool((sink or _post)(url, build_event(error, source, op)))
    except Exception:  # noqa: BLE001 — reporting never breaks the caller
        return False
