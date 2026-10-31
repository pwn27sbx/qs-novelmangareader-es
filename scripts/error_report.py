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
import re
import time
import traceback
import urllib.error
import warnings
import urllib.parse
import urllib.request

DEDUPE_TTL = 3600          # one event per (source, op, type) per hour
FAILED_BACKOFF = 300       # after a failed send, wait before trying that key again
TIMEOUT = 2                # the reader must not wait on an alert
MAX_MESSAGE = 500
MAX_TRACEBACK = 2000
USER_AGENT = "qs-nmr-backend/1.0 (+https://github.com/pwn27sbx/qs-novelmangareader-es)"

_sent = {}
_failed = {}
_warned_insecure = False
_LOOPBACK = {"localhost", "127.0.0.1", "::1"}

# Exception messages raised while scraping carry the request URL, and its query
# holds what the user was looking for. The query never leaves the machine.
_URL = re.compile(r"(?:https?:)?//[^\s'\"<>]+")


def _without_secrets(url):
    """Cut the query and the fragment: both carry tokens and search terms."""
    for separator in ("?", "#"):
        url = url.split(separator, 1)[0]
    return url


def scrub(text):
    """Drop the query and fragment of every URL in `text`, absolute or not."""
    return _URL.sub(lambda match: _without_secrets(match.group(0)), str(text or ""))


def parse_dsn(dsn):
    """(base_url, project_id, public_key) from a DSN, or None when unusable.

    `base_url` keeps the scheme and any explicit port, so a self-hosted or
    plain-HTTP install is not silently sent to https://host without its port.
    """
    try:
        parts = urllib.parse.urlsplit(str(dsn or "").strip())
        key = parts.username or ""
        project = (parts.path or "").strip("/")
        if parts.scheme not in ("http", "https") or not parts.hostname or not key or not project:
            return None
        # hostname + port, never netloc: netloc still carries "key@".
        scheme = parts.scheme
        if scheme == "http" and parts.hostname not in _LOOPBACK:
            # Cleartext to a public host would ship the key and the traceback in
            # the open. A self-hosted Sentry on localhost keeps http; anything
            # else is upgraded, with one warning.
            global _warned_insecure
            if not _warned_insecure:
                warnings.warn("QS_SENTRY_DSN uses http for a non-loopback host; "
                              "reporting over https instead", RuntimeWarning)
                _warned_insecure = True
            scheme = "https"
        port = f":{parts.port}" if parts.port else ""
        return f"{scheme}://{parts.hostname}{port}", project, key
    except Exception:  # noqa: BLE001 — a broken DSN means "reporting off"
        return None


def should_send(source, op, kind, now, sent=None, ttl=DEDUPE_TTL):
    """True when this (source, op, kind) was not DELIVERED within the TTL.

    Recording happens in `mark_sent`, after a successful delivery: an attempt
    that failed (offline, DNS, timeout) must not silence the next one for an
    hour, which is exactly the outage the reporter exists for.
    """
    sent = _sent if sent is None else sent
    last = sent.get((source, op, kind))
    return last is None or now - last >= ttl


def mark_sent(source, op, kind, now, sent=None):
    sent = _sent if sent is None else sent
    sent[(source, op, kind)] = now


def build_event(error, source="", op="", module="manga_chain"):
    """The event Sentry receives: what broke, where, and a bounded traceback."""
    kind = type(error).__name__
    detail = scrub(error)[:MAX_MESSAGE]
    trace = scrub("".join(traceback.format_exception(type(error), error, error.__traceback__)))
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
    base_url, project, key = parsed
    kind = type(error).__name__
    stamp = time.time() if now is None else now
    if not should_send(source, op, kind, stamp):
        return False
    dedupe_key = (source, op, kind)
    last_failure = _failed.get(dedupe_key)
    if last_failure is not None and stamp - last_failure < FAILED_BACKOFF:
        return False  # a burst must not turn one broken site into N requests
    url = f"{base_url}/api/{project}/store/?sentry_key={key}&sentry_version=7"
    try:
        delivered = bool((sink or _post)(url, build_event(error, source, op)))
    except Exception:  # noqa: BLE001 — reporting never breaks the caller
        return False
    if delivered:
        mark_sent(source, op, kind, stamp)
        _failed.pop(dedupe_key, None)
    else:
        _failed[dedupe_key] = stamp
    return delivered
