"""Title normalisation/matching shared by the sources and the chain.

Cross-source titles differ in case, punctuation and spacing, so compare a
normalised form (lowercase, alphanumerics only, single spaces).

Matching rule — a fall-through may only adopt the SAME work:

  * two titles match when their normalised forms are EQUAL;
  * harmless edition qualifiers are ignored first, so "Naruto" matches
    "Naruto (Official Colored)", "Naruto (2020)" or "Naruto Digital";
  * a title that carries an extra MEANINGFUL word — a real subtitle such as
    "Solo Leveling: Ragnarok" or "Naruto Shippuden" — is a DIFFERENT work and
    must NOT match. The old substring ("a in b") rule is gone: it is exactly
    what let a sequel be adopted when the first source had no Spanish chapters.
"""

import re

# Edition/marketing qualifiers that do not change which work a title refers to.
_EDITION_WORDS = {
    "official", "colored", "coloured", "color", "colour", "digital",
    "remastered", "remaster", "scan", "scans", "oficial",
}

_YEAR = re.compile(r"^(?:19|20)\d{2}$")
_GROUP = re.compile(r"[\(\[\{][^)\]\}]*[\)\]\}]")


def normalize_title(value):
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def _drop_edition_group(match):
    """Drop a bracketed group when it is only edition qualifiers / a year.

    "(Official Colored)" and "(2020)" disappear; "(Ragnarok)" stays, so its
    word keeps two different works apart.
    """
    tokens = normalize_title(match.group(0)).split()
    if tokens and all(token in _EDITION_WORDS or _YEAR.match(token) for token in tokens):
        return " "
    return match.group(0)


def _core_title(value):
    """Normalised title with harmless edition qualifiers removed."""
    text = _GROUP.sub(_drop_edition_group, str(value or "").lower())
    words = [
        word for word in re.findall(r"[a-z0-9]+", text)
        if word not in _EDITION_WORDS and not _YEAR.match(word)
    ]
    return " ".join(words)


def titles_match(query, candidate):
    """True when both titles refer to the SAME work.

    Exact normalised equality after dropping harmless edition qualifiers, so a
    sequel ("Solo Leveling: Ragnarok") never matches its predecessor.
    """
    a = _core_title(query)
    b = _core_title(candidate)
    if not a or not b:
        return False
    return a == b
