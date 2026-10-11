"""Title normalisation/matching shared by the manga sources and the chain.

Cross-source titles differ in case, punctuation and spacing, so compare a
normalised form (lowercase, alphanumerics only, single spaces).
"""

import re


def normalize_title(value):
    return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()


def titles_match(query, candidate):
    """True when the two titles refer to the same work (normalised equal or one
    contains the other), so a fall-through never adopts an unrelated series."""
    a = normalize_title(query)
    b = normalize_title(candidate)
    if not a or not b:
        return False
    return a == b or a in b or b in a
