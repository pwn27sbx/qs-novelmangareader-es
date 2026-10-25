import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.components

Item {
    id: readerView

    readonly property string fontDisplay: Style.font.family
    readonly property string fontBody:    Style.font.family

    signal backRequested()
    signal toggleFullscreen()

    property bool isFullscreen: false
    property real fontSize:      17
    property real lineHeight:    1.75
    property bool headerVisible: true

    function reset() {
        headerVisible = true
        textScroll.contentY = 0
    }

    readonly property bool _hasPrev: Novel.hasPrevChapter
    readonly property bool _hasNext: Novel.hasNextChapter

    Rectangle { anchors.fill: parent; color: "#1a1714" }

    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54; color: Qt.rgba(0.08, 0.07, 0.06, 0.97); z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1; color: Qt.rgba(1, 1, 1, 0.07)
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Style.spacing.md; rightMargin: Style.spacing.xxxl }
            spacing: Style.spacing.xxs

            Item {
                width: 44; height: 44
                Rectangle {
                    anchors.centerIn: parent; width: 34; height: 34; radius: Style.cornerRadius
                    color: backHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.base } }
                }
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: Style.font.iconLarge; color: Qt.rgba(1,1,1,0.7) }
                MouseArea {
                    id: backHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: { Novel.clearChapter(); readerView.backRequested() }
                }
            }

            Column {
                Layout.fillWidth: true; spacing: Style.spacing.hairline
                StyledText {
                    width: parent.width
                    text: Novel.currentNovel ? Novel.currentNovel.title : ""
                    font.family: readerView.fontDisplay; font.pixelSize: Style.font.bodySmall
                    color: Qt.rgba(1,1,1,0.45); elide: Text.ElideRight
                }
                StyledText {
                    width: parent.width
                    text: Novel.currentChapter ? Novel.currentChapter.title : ""
                    font.family: readerView.fontDisplay; font.pixelSize: Style.font.subtitle
                    color: Qt.rgba(1,1,1,0.85); elide: Text.ElideRight
                }
            }

            Item {
                width: 34; height: 34
                Rectangle {
                    anchors.centerIn: parent; width: 30; height: 30; radius: Style.cornerRadius
                    color: fsMinusHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                Text { anchors.centerIn: parent; text: "A−"; font.pixelSize: Style.font.caption; color: Qt.rgba(1,1,1,0.55) }
                MouseArea {
                    id: fsMinusHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: readerView.fontSize = Math.max(13, readerView.fontSize - 1)
                }
            }

            Item {
                width: 34; height: 34
                Rectangle {
                    anchors.centerIn: parent; width: 30; height: 30; radius: Style.cornerRadius
                    color: fsPlusHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                Text { anchors.centerIn: parent; text: "A+"; font.pixelSize: Style.font.bodySmall; color: Qt.rgba(1,1,1,0.55) }
                MouseArea {
                    id: fsPlusHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: readerView.fontSize = Math.min(26, readerView.fontSize + 1)
                }
            }

            Item {
                width: 34; height: 34
                Rectangle {
                    anchors.centerIn: parent; width: 30; height: 30; radius: Style.cornerRadius
                    color: fullscreenHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                Text {
                    anchors.centerIn: parent
                    text: readerView.isFullscreen ? "🗗" : "⛶"
                    font.pixelSize: Style.font.subtitle; color: Qt.rgba(1,1,1,0.55)
                }
                MouseArea {
                    id: fullscreenHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: readerView.toggleFullscreen()
                }
            }

            Rectangle {
                visible: Novel.currentChapter !== null && Novel.currentChapter.wordCount > 0
                height: 24; width: wcTxt.implicitWidth + 18; radius: Style.cornerRadius
                color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                Text {
                    id: wcTxt; anchors.centerIn: parent
                    text: Novel.currentChapter !== null
                        ? I18n.t("words", { 1: (Math.round(Novel.currentChapter.wordCount / 100) / 10) }) : ""
                    font.family: readerView.fontBody; font.pixelSize: Style.font.caption
                    font.letterSpacing: 0.4; color: Qt.rgba(1,1,1,0.45)
                }
            }
        }
    }

    Item {
        anchors { top: readerHeader.bottom; left: parent.left; right: parent.right }
        height: 2; z: 9
        Rectangle { anchors.fill: parent; color: Qt.rgba(1,1,1,0.04) }
        Rectangle {
            width: textScroll.contentHeight > textScroll.height
                ? parent.width * Math.min(1,
                (textScroll.contentY + textScroll.height) / textScroll.contentHeight)
                : parent.width
            height: parent.height; color: Colors.primary
            Behavior on width { NumberAnimation { duration: Motion.fast } }
        }
    }

    // Loading: a ghost page in the reader's own measure and type size
    Rectangle {
        anchors.fill: parent; color: "#1a1714"; z: 8
        opacity: Novel.isFetchingChapter ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

        SkeletonText {
            anchors.fill: parent
            active: Novel.isFetchingChapter
            fontSize: readerView.fontSize
            lineHeight: readerView.lineHeight
            topInset: readerView.headerVisible ? 56 : 2
        }
    }

    LoadingBar {
        anchors { top: readerHeader.bottom; left: parent.left; right: parent.right }
        z: 10
        active: Novel.isFetchingChapter
    }

    Rectangle {
        anchors.fill: parent; color: "#1a1714"; z: 7
        visible: Novel.chapterError.length > 0 && !Novel.isFetchingChapter
        Column {
            anchors.centerIn: parent; spacing: Style.spacing.xl
            Text {
                text: "⚠"; font.pixelSize: 32; color: Colors.error; opacity: 0.85 // style-ignore — bespoke size
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: Novel.chapterError; color: Qt.rgba(1,1,1,0.4)
                font.pixelSize: Style.font.bodySmall; font.family: readerView.fontBody
                wrapMode: Text.Wrap; width: 260; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
            }
        }
    }

    Flickable {
        id: textScroll
        anchors {
            fill: parent
            topMargin: readerView.headerVisible ? Style.space(56) : Style.spacing.xxs
            bottomMargin: Style.space(56)
        }
        contentWidth: width
        contentHeight: textColumn.implicitHeight + 80
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Behavior on anchors.topMargin { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

        // Same wheel preference as the manga reader (settings.json).
        WheelHandler {
            blocking: true
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                const step = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.pixelDelta.y
                const limit = Math.max(0, textScroll.contentHeight - textScroll.height)
                textScroll.contentY = Math.max(0, Math.min(limit, textScroll.contentY - step * UiPrefs.scrollFactor))
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent; propagateComposedEvents: true
            onClicked: { readerView.headerVisible = !readerView.headerVisible; mouse.accepted = false }
        }

        Column {
            id: textColumn
            width: Math.min(parent.width - 48, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: Style.space(36); bottomPadding: Style.space(48); spacing: Style.space(0)

            StyledText {
                width: parent.width
                text: Novel.currentChapter ? Novel.currentChapter.title : ""
                font.family: readerView.fontDisplay
                font.pixelSize: readerView.fontSize + 7
                font.bold: true
                color: Qt.rgba(0.96, 0.93, 0.87, 0.90)
                wrapMode: Text.Wrap; lineHeight: 1.25; bottomPadding: Style.spacing.lg
            }

            Item {
                width: parent.width; height: 24
                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: Style.space(5)
                    Rectangle { width: 8;  height: 2; radius: height / 2; color: Colors.primary; opacity: 0.3 } // style-ignore — line
                    Rectangle { width: 32; height: 2; radius: height / 2; color: Colors.primary; opacity: 0.7 } // style-ignore — line
                    Rectangle { width: 8;  height: 2; radius: height / 2; color: Colors.primary; opacity: 0.3 } // style-ignore — line
                }
            }

            Item { width: 1; height: 20 }

            Repeater {
                model: Novel.currentChapter ? Novel.currentChapter.paragraphs : []
                StyledText {
                    width: textColumn.width
                    text: modelData
                    font.family: readerView.fontDisplay
                    font.pixelSize: readerView.fontSize
                    color: Qt.rgba(0.91, 0.87, 0.80, 0.87)
                    wrapMode: Text.Wrap; lineHeight: readerView.lineHeight
                    bottomPadding: Math.round(readerView.fontSize * readerView.lineHeight * 0.75)
                    textFormat: Text.PlainText
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 2; color: Colors.primary; opacity: 0.25; radius: width / 2 } // style-ignore — scrollbar
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 56; color: Qt.rgba(0.08, 0.07, 0.06, 0.97); z: 10

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: Qt.rgba(1,1,1,0.07)
        }

        Row {
            anchors { fill: parent; leftMargin: Style.space(16); rightMargin: Style.space(16) }

            Item {
                width: parent.width / 3; height: parent.height
                opacity: readerView._hasPrev ? 1.0 : 0.25
                Behavior on opacity { NumberAnimation { duration: Motion.base } }

                Rectangle {
                    id: prevBtn
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left }
                    width: prevBtnRow.implicitWidth + 28; height: 36; radius: Style.cornerRadius
                    color: prevNavArea.containsMouse && readerView._hasPrev
                        ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        id: prevBtnRow; anchors.centerIn: parent; spacing: Style.space(5)
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "‹"; font.pixelSize: Style.font.iconLarge; color: Qt.rgba(1,1,1,0.7) }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("action.prev"); font.family: readerView.fontBody; font.pixelSize: Style.font.body; color: Qt.rgba(1,1,1,0.7) }
                    }
                }

                MouseArea {
                    id: prevNavArea; anchors.fill: parent; hoverEnabled: true
                    enabled: readerView._hasPrev
                    onClicked: { Novel.fetchPrevChapter(); textScroll.contentY = 0 }
                }
            }

            Item {
                width: parent.width / 3; height: parent.height
                StyledText {
                    anchors.centerIn: parent
                    text: Novel.currentChapter ? Novel.currentChapter.title : ""
                    font.family: readerView.fontBody; font.pixelSize: Style.font.caption
                    color: Qt.rgba(1,1,1,0.28); font.letterSpacing: 0.4
                    elide: Text.ElideMiddle; width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                width: parent.width / 3; height: parent.height
                opacity: readerView._hasNext ? 1.0 : 0.25
                Behavior on opacity { NumberAnimation { duration: Motion.base } }

                Rectangle {
                    id: nextBtn
                    anchors { verticalCenter: parent.verticalCenter; right: parent.right }
                    width: nextBtnRow.implicitWidth + 28; height: 36; radius: Style.cornerRadius
                    color: nextNavArea.containsMouse && readerView._hasNext
                        ? Colors.withAlpha(Colors.primary, 0.45)
                        : Colors.withAlpha(Colors.primary, 0.22)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        id: nextBtnRow; anchors.centerIn: parent; spacing: Style.space(5)
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("action.next"); font.family: readerView.fontBody; font.pixelSize: Style.font.body; color: Qt.rgba(1,1,1,0.92) }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "›"; font.pixelSize: Style.font.iconLarge; color: Qt.rgba(1,1,1,0.92) }
                    }
                }

                MouseArea {
                    id: nextNavArea; anchors.fill: parent; hoverEnabled: true
                    enabled: readerView._hasNext
                    onClicked: { Novel.fetchNextChapter(); textScroll.contentY = 0 }
                }
            }
        }
    }
}
