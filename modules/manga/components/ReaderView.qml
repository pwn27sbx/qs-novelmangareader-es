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
        _lastPage = 0
    }

    // A new chapter starts at page 1, whatever the previous one left behind.
    Connections {
        target: Manga
        function onChapterPagesChanged() { readerView._lastPage = 0 }
    }

    // Tapping hides the header (tap again to bring it back). Leaving the reader
    // with it hidden and opening another chapter used to leave the chrome gone,
    // because the same instance is reused: any entry shows it again.
    onVisibleChanged: if (visible) headerVisible = true

    // ── Ink-black background ─────────────────────────────────────────────────
    // The reading canvas stays near-black on purpose: it is the mat under the
    // pages, like a video player, so a light theme does not glare around them.
    Rectangle { anchors.fill: parent; color: "#08080a" }

    // ── Reader header ────────────────────────────────────────────────────────
    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54
        color: Util.alpha(Colors.surface_container_low, 0.96)
        z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

        // Bottom hairline
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Util.alpha(Colors.text, 0.07)
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
                        ? Util.alpha(Colors.text, 0.1)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.base } }
                }
                StyledText {
                    anchors.centerIn: parent
                    text: "←"
                    font.pixelSize: Style.font.iconLarge
                    color: Util.alpha(Colors.text, 0.7)
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
                color: Util.alpha(Colors.text, 0.85)
                elide: Text.ElideRight
            }

            // Page counter badge
            Rectangle {
                visible: Manga.chapterPages.length > 0
                height: 24
                width: pageCountText.implicitWidth + 18
                radius: Style.cornerRadius
                color: Util.alpha(Colors.text, 0.09)
                border.color: Util.alpha(Colors.text, 0.12)
                border.width: 1

                StyledText {
                    id: pageCountText
                    anchors.centerIn: parent
                    text: (readerView.visiblePage + 1) + " / " + Manga.chapterPages.length
                    font.family: readerView.fontBody
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.5
                    color: Util.alpha(Colors.text, 0.65)
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
                color: Util.alpha(Colors.text, 0.45)
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
    // indexAt answers -1 in an area the list has not laid out (its height
    // estimate can fall short while pages are recycled). Keep the last answer
    // instead of dropping to currentIndex, which never moves with a wheel.
    property int _lastPage: 0

    // Placeholder height ratio (height / width). The old fixed 1.42 was eight
    // times smaller than a real long-strip page (852 vs 6667 px), so every
    // page grew hugely when it loaded and the list's height estimate kept
    // collapsing. The first loaded page teaches the real value.
    property real _ratio: 1.42
    function _learnRatio(value) {
        if (value > 0.1 && value < 50)
            readerView._ratio = value
    }
    readonly property int visiblePage: {
        const index = pageListView.indexAt(pageListView.width / 2, pageListView.contentY + 1)
        // Clamped to the current chapter: the remembered page survives a
        // chapter change, and a shorter chapter would otherwise report an
        // out-of-range number and look like it is already at the end.
        return index < 0 ? Math.max(0, Math.min(readerView._lastPage, pageListView.count - 1)) : index
    }
    onVisiblePageChanged: if (visiblePage !== _lastPage) _lastPage = visiblePage

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
        cacheBuffer: Math.max(0, height * 2)
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
                // Still laying out (contentHeight not known yet). Swallowing the
                // event made the reader look frozen; move without the upper
                // clamp instead and let the list re-measure.
                if (limit <= 0) {
                    if (pageListView.count > 0) {
                        console.warn("[reader] no scrollable height yet (count=" + pageListView.count
                            + " contentH=" + pageListView.contentHeight + " h=" + pageListView.height + ")")
                        pageListView.contentY = Math.max(0, pageListView.contentY
                            - WheelScroll.stepOf(event.angleDelta.y, event.pixelDelta.y) * UiPrefs.scrollFactor)
                    }
                    event.accepted = true
                    return
                }
                const target = WheelScroll.nextContentY(
                    pageListView.contentY, event.angleDelta.y, event.pixelDelta.y,
                    UiPrefs.scrollFactor, limit)
                // The list's contentHeight is an ESTIMATE while pages are
                // recycled, and it can fall well short of the real end: the
                // pixel clamp then parks the reader on a fake bottom. When that
                // happens and pages remain, move by page instead — this uses
                // the laid-out items, not the estimate.
                if (target >= limit && WheelScroll.stepOf(event.angleDelta.y, event.pixelDelta.y) < 0
                        && readerView.visiblePage < pageListView.count - 1) {
                    pageListView.positionViewAtIndex(readerView.visiblePage + 1, ListView.Beginning)
                } else {
                    pageListView.contentY = target
                }
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
            height: pageImg.status === Image.Ready && pageImg.implicitWidth > 0
                ? pageImg.implicitHeight * (Math.max(1, pageListView.width) / pageImg.implicitWidth)
                : Math.max(1, pageListView.width) * readerView._ratio

            // While this page sits entirely above the viewport, its height
            // change must move the content back by the same amount, or the
            // reading position drifts.
            property real _lastHeight: 0
            onHeightChanged: {
                // Judge with the height BEFORE the change: a page that was
                // fully above the viewport and grew past it would fail a check
                // against the new height and skip the compensation.
                if (_lastHeight > 0 && y + _lastHeight <= pageListView.contentY) {
                    const limit = pageListView.contentHeight - pageListView.height
                    let next = pageListView.contentY + (height - _lastHeight)
                    // Only clamp the top here: while the list's estimate is
                    // short, a zero limit would otherwise jump to the start.
                    if (limit > 0)
                        next = Math.min(next, limit)
                    pageListView.contentY = Math.max(0, next)
                }
                _lastHeight = height
            }

            Image {
                id: pageImg
                anchors.fill: parent
                source: modelData.url || ""
                // A page is often 1080x3000; decoding it at full size costs
                // ~12 MB each and several per screen with the preload, which
                // is what made fast scrolling stutter. Scaling during decode
                // keeps the aspect ratio and returns the same implicit size.
                sourceSize.width: Math.max(1, pageListView.width)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                opacity: status === Image.Ready ? 1 : 0
                onStatusChanged: if (status === Image.Ready && implicitWidth > 0)
                    readerView._learnRatio(implicitHeight / implicitWidth)
                Behavior on opacity { NumberAnimation { duration: Motion.slow } }

            }

            // Loading placeholder. Beside the page, not inside it: the page
            // sits at opacity 0 until it's ready, which would hide a child.
            Rectangle {
                anchors.fill: parent
                z: -1
                color: Colors.surface_container_low
                visible: pageImg.status !== Image.Ready

                Column {
                    anchors.centerIn: parent
                    spacing: Style.spacing.xxl

                    Spinner {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pageImg.status !== Image.Error
                        width: 22
                        border.width: 2
                        border.color: Util.alpha(Colors.text, 0.08)
                        arcColor: Util.alpha(Colors.text, 0.45)
                        duration: Motion.loop
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pageImg.status === Image.Error
                        text: "⊘"
                        font.pixelSize: 22 // style-ignore — bespoke size
                        color: Util.alpha(Colors.text, 0.3)
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("page", { 1: modelData.index + 1 })
                            + (pageImg.status === Image.Error ? "  ·  " + I18n.t("manga.pageFailed") : "")
                        color: Util.alpha(Colors.text, 0.3)
                        font.pixelSize: Style.font.caption
                        font.family: readerView.fontBody
                        font.letterSpacing: 1.5
                    }

                    // Download progress, once the image reports any
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: pageImg.status === Image.Loading && pageImg.progress > 0
                        width: 96; height: 2; radius: height / 2 // style-ignore — progress
                        color: Util.alpha(Colors.text, 0.08)

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
            color: Util.alpha(Colors.text, 0.06)
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
