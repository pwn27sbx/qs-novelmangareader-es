import QtQuick
import qs.Commons
import qs.app
import "../services/list_metrics.js" as ListMetrics

// One row of a manga list view: a small cover, the title, the work's metadata
// line and — when the caller has one — the reader's own progress.
//
// It is the row twin of CoverCard, and it takes the SAME `meta` string instead
// of composing it: both views build it with services/manga_card.js, so the
// "chapter · status" rules (and their missing-chapter fallbacks) keep exactly
// one implementation. `progress` is the other thing: Library owns "Cap. N",
// Browse passes nothing and the slot collapses.
//
// Signals and press feedback match CoverCard, so a grid and its list are
// interchangeable from the view's point of view.
ClickableRect {
    id: root

    property url source: ""
    property string title: ""
    // Already localized by the caller (manga_card.metaLine).
    property string meta: ""
    // The reader's progress for this entry ("Cap. 12"); empty hides the slot.
    property string progress: ""
    // True once the entry has been read at least once: colours the progress.
    property bool progressActive: false
    property string bodyFont: ""
    // Horizontal padding for the cover, the text and the progress label. The
    // caller matches it to its own header/grid inset (Browse uses xl, Library
    // lg, like the two grids do).
    property int inset: Style.spacing.xl

    // Qt caches a FAILED image load per URL for the engine's lifetime (see
    // CoverCard): one request that lands while the local backend restarts
    // would leave the row broken until the shell restarts. Same cache-busting
    // retry, one attempt per failure.
    property int _attempt: 0
    readonly property string _coverUrl: {
        const base = String(root.source || "")
        if (base === "") return ""
        if (root._attempt === 0) return base
        return base + (base.indexOf("?") >= 0 ? "&" : "?") + "retry=" + root._attempt
    }

    // Shared with the skeleton that stands in for these rows while loading.
    implicitHeight: Style.space(ListMetrics.ROW_HEIGHT_BASE)
    color: "transparent"

    // Hover/press tint behind the content. Declared first so it stays under
    // the cover and the text; the rows themselves have no fill of their own.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Colors.primary
        opacity: root.pressed ? Style.pressedFillAlpha : (root.hovered ? Style.hoverFillAlpha : 0)
        Behavior on opacity { NumberAnimation { duration: Motion.base } }
    }

    Rectangle {
        id: coverBox
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: root.inset
            topMargin: Style.spacing.sm
            bottomMargin: Style.spacing.sm
        }
        width: Math.round(height * 0.7)
        radius: root.radius
        color: Colors.surface_container
        clip: true

        Image {
            id: cover
            anchors.fill: parent
            source: root._coverUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.slow } }

            onStatusChanged: {
                if (status === Image.Error && root._attempt < 2)
                    coverRetry.restart()
            }
        }

        Timer {
            id: coverRetry
            interval: 1500
            onTriggered: root._attempt += 1
        }
    }

    // Outside the cover: the cover is transparent until the image is ready,
    // which would hide a child placeholder too. The glyph is scaled down to the
    // thumbnail: the default suits a full-size poster tile.
    CoverPlaceholder {
        anchors.fill: coverBox
        status: cover.status
        glyphSize: Style.font.title
    }

    // Title + metadata, centred as one block against the cover. `right` stops
    // before the progress label when the caller passes one, so a long title
    // never runs underneath it.
    Column {
        id: textColumn
        anchors {
            left: coverBox.right
            right: progressText.visible ? progressText.left : parent.right
            leftMargin: root.inset
            rightMargin: root.inset
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.spacing.xs

        StyledText {
            width: parent.width
            text: root.title
            font.family: root.bodyFont
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 0.2
            color: Colors.on_surface
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        StyledText {
            width: parent.width
            visible: root.meta !== ""
            text: root.meta
            font.family: root.bodyFont
            font.pixelSize: Style.font.caption
            font.letterSpacing: 0.3
            color: Colors.on_surface_variant
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    StyledText {
        id: progressText
        anchors {
            right: parent.right
            rightMargin: root.inset
            verticalCenter: parent.verticalCenter
        }
        visible: root.progress !== ""
        text: root.progress
        font.family: root.bodyFont
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.4
        color: root.progressActive ? Colors.primary : Colors.on_surface_variant
        opacity: root.progressActive ? 0.9 : 0.5
    }
}
