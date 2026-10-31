import QtQuick
import qs.Commons
import qs.app

// The poster tile shared by the manga / anime / novel grids: cover art with a
// placeholder and bottom fade, an optional type badge, a solid info block with
// the metadata line and a two-line title, and press/hover feedback.
//
// Anything else the grid needs — a score badge, the progress strip — is added as
// an ordinary child. Tell the card how tall the bottom strip is via `footerHeight`
// so the cover and title bar size around it. The hover tint keeps a high `z` so it
// still sits above those children, as it did when it was declared last.
ClickableRect {
    id: root

    property url source: ""
    property string title: ""
    property string bodyFont: ""
    // Display text for the type badge ("MANHWA", "MANGA", …). Callers pass it
    // already localized and cased; an empty string hides the badge.
    property string typeBadge: ""
    // The work's own metadata ("Cap. 105 · En curso"), never the reader's
    // progress: Library's CoverProgressBar owns that and lives in the footer.
    // It sits in the info block, under the title — painting it over the artwork
    // was unreadable, because the cover is a photo, not a backdrop.
    property string meta: ""
    // Title bar padding. Browse's old inline delegate used 18 px and this card
    // used 10, so unifying them without this prop would move the cover 8 px.
    property int titlePadding: 10
    property int gradientHeight: 48
    property int footerHeight: 0
    // Cover inset inside the card. `0` keeps the original poster tiles, where
    // the artwork reaches the card's edges; a positive value turns the cover
    // into a picture inside a panel, with this card's own surface showing
    // around it.
    property int inset: 0
    // Which top corner carries the type badge. `false` is the original
    // top-right slot (anime and the novel panel); `true` moves it to the
    // leading corner, above the title.
    property bool badgeLeading: false

    // Qt caches a FAILED image load per URL for the engine's lifetime, so one
    // request that lands while the local backend is restarting would leave the
    // tile broken until the shell restarts. Retry with a cache-busting token.
    property int _attempt: 0
    readonly property string _coverUrl: {
        const base = String(root.source || "")
        if (base === "") return ""
        if (root._attempt === 0) return base
        return base + (base.indexOf("?") >= 0 ? "&" : "?") + "retry=" + root._attempt
    }

    anchors.margins: Style.space(5)
    radius: Style.cornerRadius
    color: Colors.surface_container
    clip: true

    // Beside the cover, not inside it: the cover sits at opacity 0 until it's
    // ready, which would hide a child placeholder too.
    CoverPlaceholder {
        anchors.fill: cover
        status: cover.status
    }

    Image {
        id: cover
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.inset
            leftMargin: root.inset
            rightMargin: root.inset
        }
        // The inset is taken off the cover as well, so its bottom edge still
        // meets the info block; with `inset: 0` this is the original height.
        height: root.height - root.inset - infoBlock.height - root.footerHeight
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

        // One retry per failure, two in total: a backend that is briefly down
        // heals itself, a cover that is genuinely gone stops hammering.
        Timer {
            id: coverRetry
            interval: 1500
            onTriggered: root._attempt += 1
        }

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: root.gradientHeight
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Colors.surface_container }
            }
        }

        // Type badge (Manga / Manhwa / Manhua). Verbatim text: the caller
        // decides the casing, so Browse keeps the uppercased look it had. The
        // leading corner belongs to Browse's inset tile; the trailing one is
        // what anime and the novel panel have always shown.
        Rectangle {
            visible: root.typeBadge !== ""
            anchors {
                top: parent.top
                left: root.badgeLeading ? parent.left : undefined
                right: root.badgeLeading ? undefined : parent.right
                topMargin: Style.spacing.lg
                leftMargin: Style.spacing.lg
                rightMargin: Style.spacing.lg
            }
            height: 20
            radius: Style.cornerRadius
            width: badgeText.implicitWidth + 14
            color: Qt.rgba(0, 0, 0, 0.7)

            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: root.typeBadge
                font.family: root.bodyFont
                font.pixelSize: 8 // style-ignore — bespoke size
                font.letterSpacing: 1
                font.bold: true
                color: Colors.primary_fixed_dim
            }
        }
    }

    // The solid info block under the cover: the title, then the metadata line.
    // Its height is the content's own, so an empty `meta` adds nothing and the
    // anime / novel tiles keep the exact title bar they have today. Library's
    // `cellHeight` is fixed, so a card that does carry metadata takes the
    // height from the cover, never from its neighbors.
    Rectangle {
        id: infoBlock
        anchors {
            bottom: parent.bottom
            bottomMargin: root.footerHeight
            left: parent.left
            right: parent.right
        }
        height: infoColumn.implicitHeight + root.titlePadding
        color: Colors.surface_container

        Column {
            id: infoColumn
            anchors {
                left: parent.left
                leftMargin: Style.spacing.xl
                verticalCenter: parent.verticalCenter
            }
            width: infoBlock.width - 2 * Style.spacing.xl
            // Order is title first, metadata second — the reference layout.
            // `spacing` only applies BETWEEN visible children, so with `meta`
            // empty the block is title + padding and does not grow.
            spacing: Style.spacing.xs

            StyledText {
                id: titleText
                width: parent.width
                text: root.title
                font.family: root.bodyFont
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 0.2
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: 1.3
            }

            StyledText {
                id: metaText
                visible: root.meta !== ""
                width: parent.width
                text: root.meta
                font.family: root.bodyFont
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.3
                color: Colors.on_surface_variant
                elide: Text.ElideRight
                maximumLineCount: 1
            }

        }
    }

    Rectangle {
        z: 10
        anchors.fill: parent
        radius: root.radius
        color: Colors.primary
        opacity: root.pressed ? Style.pressedFillAlpha : (root.hovered ? Style.hoverFillAlpha : 0)
        Behavior on opacity { NumberAnimation { duration: Motion.base } }
    }

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.pressed ? 0.97 : 1.0
        yScale: root.pressed ? 0.97 : 1.0
        Behavior on xScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
        Behavior on yScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
    }
}
