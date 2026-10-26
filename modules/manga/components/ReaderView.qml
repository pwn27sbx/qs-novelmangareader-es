import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.components
import "../../../components/wheel_scroll.js" as WheelScroll

Item {
    id: readerView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property string fontDisplay: Style.font.family
    readonly property string fontBody:    Style.font.family

    // Emitted when the user navigates back
    signal backRequested()

    // ── Internal state ───────────────────────────────────────────────────────
    property bool headerVisible: true

    // Called by the parent to reset state when re-entering this view
    function reset() {
        headerVisible = true
    }

    // ── Ink-black background ─────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#08080a" }

    // ── Reader header ────────────────────────────────────────────────────────
    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54
        color: Qt.rgba(0.05, 0.05, 0.08, 0.95)
        z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

        // Bottom hairline
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Style.spacing.md; rightMargin: Style.space(16) }
            spacing: Style.spacing.xxs

            // Back button
            Item {
                width: 44; height: 44

                Rectangle {
                    anchors.centerIn: parent
                    width: 34; height: 34; radius: Style.cornerRadius
                    color: readerBackArea.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.1)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.base } }
                }
                StyledText {
                    anchors.centerIn: parent
                    text: "←"
                    font.pixelSize: Style.font.iconLarge
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
                MouseArea {
                    id: readerBackArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Manga.clearChapterPages()
                        readerView.backRequested()
                    }
                }
            }

            // Title
            StyledText {
                Layout.fillWidth: true
                text: Manga.currentManga ? Manga.currentManga.title : ""
                font.family: readerView.fontDisplay
                font.pixelSize: Style.font.subtitle
                color: Qt.rgba(1, 1, 1, 0.85)
                elide: Text.ElideRight
            }

            // Page counter badge
            Rectangle {
                visible: Manga.chapterPages.length > 0
                height: 24
                width: pageCountText.implicitWidth + 18
                radius: Style.cornerRadius
                color: Qt.rgba(1, 1, 1, 0.09)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                StyledText {
                    id: pageCountText
                    anchors.centerIn: parent
                    text: (readerView.visiblePage + 1) + " / " + Manga.chapterPages.length
                    font.family: readerView.fontBody
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.5
                    color: Qt.rgba(1, 1, 1, 0.65)
                }
            }
        }
    }

    // ── Fetching pages overlay ───────────────────────────────────────────────
    LoadingState {
        anchors.fill: parent
        z: 8
        active: Manga.isFetchingPages
        color: "#08080a"
        textColor: "white"
        spinnerSize: 40
        label: I18n.t("manga.loadingPages")
        detail: Manga.currentManga ? Manga.currentManga.title : ""
        bodyFont: readerView.fontBody
    }

    // ── Pages error overlay ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#08080a"
        visible: Manga.pagesError.length > 0 && !Manga.isFetchingPages
        z: 7

        Column {
            anchors.centerIn: parent
            spacing: Style.spacing.xl

            StyledText {
                text: "⚠"
                font.pixelSize: 32 // style-ignore — bespoke size
                color: Colors.error
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.85
            }
            StyledText {
                text: Manga.pagesError
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: Style.font.bodySmall
                font.family: readerView.fontBody
                wrapMode: Text.Wrap
                width: 260
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    // ── Page list ────────────────────────────────────────────────────────────
    // Which page the viewport is on. `currentIndex` is no use here: the wheel
    // handler moves `contentY` directly, and a programmatic scroll does NOT
    // update it (measured: contentY 2100 -> currentIndex 0 while indexAt said
    // 3), so the indicator used to sit on "1" forever.
    readonly property int visiblePage: {
        const index = pageListView.indexAt(pageListView.width / 2, pageListView.contentY + 1)
        return index < 0 ? Math.max(0, pageListView.currentIndex) : index
    }

    ListView {
        id: pageListView
        anchors {
            fill: parent
            topMargin: readerView.headerVisible ? Style.space(54) : 0
        }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Manga.chapterPages
        // Pages load asynchronously and their real height differs from the
        // placeholder ratio, so a page created above the viewport can change
        // height after you scrolled past it — everything then shifts under the
        // eye ("the scroll jumps back to something I already read"). A bigger
        // cache preloads them, and the delegate compensates the shift.
        cacheBuffer: height * 2
        spacing: Style.spacing.xs
        Behavior on anchors.topMargin { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

        // Wheel speed is a preference, not a constant: Qt's default notch is a
        // few dozen pixels, which crawls through a full page. `scrollFactor`
        // (settings.json, default 2) multiplies it.
        WheelHandler {
            blocking: true
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                const limit = Math.max(0, pageListView.contentHeight - pageListView.height)
                pageListView.contentY = WheelScroll.nextContentY(
                    pageListView.contentY, event.angleDelta.y, event.pixelDelta.y,
                    UiPrefs.scrollFactor, limit)
                event.accepted = true
            }
        }

        // Tap anywhere to toggle header
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: {
                readerView.headerVisible = !readerView.headerVisible
                mouse.accepted = false
            }
        }

        delegate: Item {
            width: pageListView.width
            height: pageImg.implicitHeight > 0
                ? pageImg.implicitHeight * (pageListView.width / pageImg.implicitWidth)
                : pageListView.width * 1.42

            // While this page sits entirely above the viewport, its height
            // change must move the content back by the same amount, or the
            // reading position drifts.
            property real _lastHeight: 0
            onHeightChanged: {
                if (_lastHeight > 0 && y + height <= pageListView.contentY)
                    pageListView.contentY += (height - _lastHeight)
                _lastHeight = height
            }

            Image {
                id: pageImg
                anchors.fill: parent
                source: modelData.url || ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.slow } }

            }

            // Loading placeholder. Beside the page, not inside it: the page
            // sits at opacity 0 until it's ready, which would hide a child.
            Rectangle {
                anchors.fill: parent
                z: -1
                color: "#111115"
                visible: pageImg.status !== Image.Ready

                Column {
                    anchors.centerIn: parent
                    spacing: Style.spacing.xxl

                    Spinner {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pageImg.status !== Image.Error
                        width: 22
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        arcColor: Qt.rgba(1, 1, 1, 0.45)
                        duration: Motion.loop
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pageImg.status === Image.Error
                        text: "⊘"
                        font.pixelSize: 22 // style-ignore — bespoke size
                        color: Qt.rgba(1, 1, 1, 0.3)
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("page", { 1: modelData.index + 1 })
                            + (pageImg.status === Image.Error ? "  ·  " + I18n.t("manga.pageFailed") : "")
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: Style.font.caption
                        font.family: readerView.fontBody
                        font.letterSpacing: 1.5
                    }

                    // Download progress, once the image reports any
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pageImg.status === Image.Loading && pageImg.progress > 0
                        width: 96; height: 2; radius: height / 2 // style-ignore — progress
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: parent.width * pageImg.progress
                            height: parent.height; radius: height / 2 // style-ignore — progress
                            color: Colors.primary
                            Behavior on width { NumberAnimation { duration: Motion.base } }
                        }
                    }
                }
            }
        }

        ScrollBar.vertical: StyledScrollBar {
            thickness: 2
            handleOpacity: 0.35
            handleRadius: 1
        }
    }

    // ── Reading progress bar (bottom) ─────────────────────────────────────────
    Item {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 3
        z: 9
        visible: Manga.chapterPages.length > 0

        // Track
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // Fill
        Rectangle {
            width: Manga.chapterPages.length > 0
                ? parent.width * ((readerView.visiblePage + 1) / Manga.chapterPages.length)
                : 0
            height: parent.height
            color: Colors.primary
            Behavior on width { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }
        }
    }
}
