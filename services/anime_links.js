// Pure parsing/selection of the anime /links response for services/Anime.qml.
// Extracted so it can be unit-tested (tests/anime_links.test.js) and so the
// selected subtitle label read can never touch a null selectedLink.

function toLink(link) {
    return {
        url: link.url || "",
        quality: link.quality || "?",
        type: link.type || "mp4",
        provider: link.provider || "",
        referer: link.referer || "",
        subtitle: link.subtitle || "",
        subtitle_label: link.subtitle_label || ""
    };
}

// Parse a /links JSON body into:
//   { streamLinks, selectedLink, subtitleLabel }            on success
//   { empty: true, streamLinks: [], selectedLink: null, subtitleLabel: "" }
//                                                           when no link is usable
//   { error: "<backend error>", ... }                       when the body is an error
// Throws only on invalid JSON (the caller reports the parse error).
function parseStreamLinks(json) {
    const data = JSON.parse(json);

    if (data && data.error) {
        return { error: data.error, streamLinks: [], selectedLink: null, subtitleLabel: "" };
    }

    const all = (data && data.all_links) || [];
    const valid = all.filter(function (link) {
        return link && !link.error && link.url && link.url.length > 0;
    });
    const streamLinks = valid.map(toLink);

    if (streamLinks.length === 0) {
        return { empty: true, streamLinks: [], selectedLink: null, subtitleLabel: "" };
    }

    let selected = data.selected;
    if (selected && (selected.error || !selected.url || selected.url.length === 0)) {
        selected = null;
    }
    const selectedLink = selected ? toLink(selected) : streamLinks[0];

    return {
        streamLinks: streamLinks,
        selectedLink: selectedLink,
        // Null-safe: selectedLink is always set here, but read defensively anyway.
        subtitleLabel: (selectedLink && selectedLink.subtitle_label) ? selectedLink.subtitle_label : "",
        error: ""
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseStreamLinks: parseStreamLinks };
}
