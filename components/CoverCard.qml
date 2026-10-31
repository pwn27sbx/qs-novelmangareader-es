import QtQuick
import qs.Commons
import qs.app

// The poster tile shared by the manga / anime / novel grids: cover art with a
// placeholder and bottom fade, an optional type badge and metadata line, a
// two-line title bar, and press/hover feedback.
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
    property string meta: ""
    // Title bar padding. Browse's old inline delegate used 18 px and this card
    // used 10, so unifying them without this prop would move the cover 8 px.
    property int titlePadding: 10
    property int gradientHeight: 48
    property int footerHeight: 0

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
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.height - titleBar.height - root.footerHeight
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
        // decides the casing, so Browse keeps the uppercased look it had.
        Rectangle {
            visible: root.typeBadge !== ""
            anchors { top: parent.top; right: parent.right; topMargin: Style.spacing.lg; rightMargin: Style.spacing.lg }
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

    // Metadata line, drawn over the cover's bottom gradient so the title bar
    // keeps its height and the poster does not shrink (Library's cellHeight is
    // fixed and its footer already carries the progress bar).
    StyledText {
        id: metaText
        visible: root.meta !== ""
        anchors {
            bottom: titleBar.top
            left: parent.left
            right: parent.right
            leftMargin: Style.spacing.xl
            rightMargin: Style.spacing.xl
            bottomMargin: Style.spacing.xs
        }
        text: root.meta
        font.family: root.bodyFont
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.3
        color: Colors.on_surface_variant
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Rectangle {
        id: titleBar
        anchors {
            bottom: parent.bottom
            bottomMargin: root.footerHeight
            left: parent.left
            right: parent.right
        }
        height: titleText.implicitHeight + root.titlePadding
        color: Colors.surface_container

        StyledText {
            id: titleText
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Style.spacing.xl; rightMargin: Style.spacing.xl
            }
            text: root.title
            font.family: root.bodyFont
            font.pixelSize: Style.font.bodySmall
            font.letterSpacing: 0.2
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.3
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
