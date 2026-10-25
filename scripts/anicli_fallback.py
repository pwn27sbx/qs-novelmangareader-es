"""ani-cli-mx as the anime backup provider (WU-10).

Behind the same contract as the other sources: give it a title and an episode,
get one link dict back (or ``{"error": ...}``). It is only called when the
primary chain (hianime -> JKAnime) comes back empty, because it is the last
resort and it shells out.

The CLI is invoked in its documented non-interactive mode:

    ani-cli-mx --debug -t anime -S 1 -e <episode> --quality <q> "<title>"

``--debug`` prints "Todos los enlaces:" / "Enlace seleccionado:" without
starting a player, so no terminal is needed (verified on ani-cli-mx 3.0.10:
without ``-e`` the CLI opens its episode menu and fails on a pipe).

Environment:
    QS_ANIME_CLI   off/0 disables the fallback; a path forces that binary.
                   Otherwise ani-cli-mx is preferred and ani-cli accepted.

Parsing text output is what makes this fragile, so it lives here, alone, with
tests on recorded output (tests/fixtures/anicli/debug_output.txt) and a timeout
on the subprocess.
"""

import os
import re
import shutil
import subprocess
import threading
import time

CACHE_TTL = 300  # seconds; one resolution per episode per session is enough
DEFAULT_TIMEOUT = 45
PROVIDER = "ani-cli-mx"

_ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b[78]")

_cache: dict[tuple, tuple[float, dict]] = {}
_lock = threading.Lock()


def _clean(text: str) -> str:
    return _ANSI.sub("", str(text or ""))


def available(binary: str | None = None) -> str | None:
    """Path of the CLI to use, or None when the fallback is off/not installed."""
    if binary:
        return binary if os.path.exists(binary) else None
    override = str(os.environ.get("QS_ANIME_CLI", "") or "").strip()
    if override.lower() in ("off", "0", "no", "false"):
        return None
    if override:
        return override if os.path.exists(override) else None
    for name in ("ani-cli-mx", "ani-cli"):
        found = shutil.which(name)
        if found:
            return found
    return None


def build_command(binary: str, title: str, episode: str | int, quality: str = "720",
                  mode: str = "sub") -> list[str]:
    """The documented non-interactive invocation.

    `--dub` selects the dubbed version; sub is the CLI's default, so it is not
    passed. The mode must travel with the request: the caller labels the link
    with the mode it asked for, and a sub stream returned as "dub" is a lie.
    """
    cmd = [
        binary, "--debug", "-t", "anime",
        "-S", "1", "-e", str(episode),
        "--quality", str(quality or "720"),
    ]
    if str(mode or "").strip().lower().startswith("dub"):
        cmd.append("--dub")
    cmd.append(str(title))
    return cmd


def parse_output(text: str) -> dict:
    """Pick the selected link and its metadata out of the CLI's debug output."""
    lines = [_clean(line).strip() for line in _clean(text).splitlines()]

    url = ""
    for i, line in enumerate(lines):
        if line.lower().startswith("enlace seleccionado"):
            for follow in lines[i + 1:]:
                if follow.startswith("http"):
                    url = follow
                    break
            break
    if not url:
        return {"error": "ani-cli-mx: no link in the output"}

    def tail_of(prefix: str) -> str:
        for line in lines:
            if line.lower().startswith(prefix):
                parts = [p.strip() for p in line.split(">") if p.strip()]
                # "referrer ><url>><page>" / "site ><url>AnimeAV1"
                if len(parts) >= 2:
                    last = parts[-1]
                    if last.startswith("http") or " " not in last:
                        return last
        return ""

    source = tail_of("source >") or tail_of("source")
    site = tail_of("site >") or tail_of("site")
    quality = ""
    for line in lines:
        match = re.match(r"^(\d{3,4})\s*>", line)
        if match:
            quality = match.group(1)
            break

    kind = "m3u8" if "hls" in source.lower() or "m3u8" in url else "mp4"
    return {
        "url": url,
        "referer": tail_of("referrer"),
        "site": site or PROVIDER,
        "type": kind,
        "quality": quality or "best",
    }


def _cached(key: tuple) -> dict | None:
    with _lock:
        hit = _cache.get(key)
    if hit and (time.time() - hit[0]) < CACHE_TTL:
        return dict(hit[1])
    return None


def _store(key: tuple, value: dict) -> None:
    with _lock:
        _cache[key] = (time.time(), dict(value))


def clear_cache() -> None:
    with _lock:
        _cache.clear()


def fetch(title: str, episode: str | int, binary: str | None = None,
          timeout: int = DEFAULT_TIMEOUT, quality: str = "720",
          mode: str = "sub") -> dict:
    """Resolve one link through the CLI: a link dict, or {"error": ...}."""
    title = str(title or "").strip()
    episode = str(episode or "").strip()
    if not title or not episode:
        return {"error": "ani-cli-mx: missing title or episode"}

    cli = available(binary)
    if not cli:
        return {"error": "ani-cli-mx: not installed or disabled"}

    mode = str(mode or "sub").strip().lower() or "sub"
    key = (cli, title.lower(), episode, str(quality), mode)
    hit = _cached(key)
    if hit is not None:
        return hit

    try:
        done = subprocess.run(
            build_command(cli, title, episode, quality, mode),
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return {"error": f"ani-cli-mx: timeout after {timeout}s"}
    except FileNotFoundError:
        return {"error": "ani-cli-mx: not installed"}
    except OSError as exc:
        return {"error": f"ani-cli-mx: {exc}"}

    parsed = parse_output((done.stdout or "") + "\n" + (done.stderr or ""))
    if "error" in parsed:
        tail = _clean(done.stderr or "").strip().splitlines()[-1:] or [""]
        return {"error": f"{parsed['error']} (exit {done.returncode}: {tail[0][:120]})"}

    link = {
        "url": parsed["url"],
        "mode": mode,
        "quality": parsed["quality"],
        "type": parsed["type"],
        "referer": parsed["referer"],
        "subtitle": "",
        # No subtitle track is known here: the CLI's site name is a source, not
        # a language, and the panel prints whatever this says after
        # "Subtítulos:". Keep it empty so the row stays hidden.
        "subtitle_label": "",
        "source_site": parsed["site"],
        "provider": PROVIDER,
    }
    _store(key, link)
    return dict(link)
