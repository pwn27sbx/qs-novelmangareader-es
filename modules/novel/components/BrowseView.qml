import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.app
import qs.Commons
import qs.services
import qs.components
import qs.Ui

Item {
    id: browseView

    readonly property string fontBody: Style.font.family

    signal novelSelected(string novelId)

    property string currentFilter: "hot"

    // Emitted when an in-panel filter change invalidates the current search;
    // the panel clears its search bar in response.
    signal searchCleared()

    function resetList() {
        currentFilter = "hot"
        Novel.fetchHot()
    }

    function _switchFilter(f) {
        if (currentFilter === f) return
        currentFilter = f
        browseView.searchCleared()
        Novel.clearNovelList()
        if (f === "hot") Novel.fetchHot()
        else             Novel.fetchLatest(true)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Filter chips (Hot / Latest) ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48
            color: Colors.surface_container_low; clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.25
            }

            ListView {
                anchors {
                    fill: parent
                    topMargin: Style.spacing.md; bottomMargin: Style.spacing.md
                    leftMargin: Style.spacing.xxxl; rightMargin: Style.spacing.xxxl
                }
                orientation: ListView.Horizontal; spacing: Style.space(7); clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { labelKey: "novel.filter.hot";    fid: "hot"    }
                    ListElement { labelKey: "novel.filter.latest"; fid: "latest" }
                }

                delegate: SegmentChip {
                    required property string labelKey
                    required property string fid
                    text: I18n.t(labelKey)
                    active: browseView.currentFilter === fid
                    fontFamily: browseView.fontBody
                    onClicked: browseView._switchFilter(fid)
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
            }
        }

        // ── Novel grid ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Loading overlay: ghost cards where the first page will land
            SkeletonGrid {
                anchors.fill: parent; z: 10
                active: (Novel.isFetchingNovel || Novel.isSwitchingProvider)
                    && Novel.novelList.length === 0
                cellWidth: (width - 30) / 4
                ratio: 1.65
            }

            // More pages on the way
            LoadingBar {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                z: 11
                active: Novel.isFetchingNovel && Novel.novelList.length > 0
            }

            // Error overlay
            Rectangle {
                anchors.fill: parent; color: Colors.background; z: 9
                visible: Novel.novelError.length > 0 && !Novel.isFetchingNovel

                Column {
                    anchors.centerIn: parent; spacing: Style.spacing.xl
                    Text { text: "⚠"; font.pixelSize: 32; color: Colors.error; anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.8 } // style-ignore — bespoke size
                    Text {
                        text: Novel.novelError; color: Colors.on_surface_variant
                        font.pixelSize: Style.font.body; font.family: browseView.fontBody
                        wrapMode: Text.Wrap; width: 260; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                    }
                }
            }

            GridView {
                id: novelGrid
                anchors.fill: parent; anchors.margins: Style.spacing.xl
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.65
                clip: true; boundsBehavior: Flickable.StopAtBounds
                // A ScriptModel diffs each new array against the last, so appending a
                // page inserts rows instead of resetting the view (and its scroll).
                model: ScriptModel { values: Novel.novelList }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; color: Colors.primary; opacity: 0.45; radius: Style.cornerRadius }
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Novel.fetchNextPage()
                }

                delegate: Item {
                    width: novelGrid.cellWidth; height: novelGrid.cellHeight

                    ClickableRect {
                        id: nCard
                        anchors { fill: parent; margins: Style.space(5) }
                        radius: Style.cornerRadius; color: Colors.surface_container; clip: true

                        CoverPlaceholder {
                            anchors.fill: coverImg
                            status: coverImg.status
                            glyphSize: 28
                        }

                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - nTitleBar.height
                            source: modelData.coverUrl || ""
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Motion.slow } }

                            Rectangle {
                                visible: modelData.status && modelData.status.length > 0
                                anchors { top: parent.top; left: parent.left; topMargin: Style.spacing.lg; leftMargin: Style.spacing.lg }
                                height: 18; radius: Style.cornerRadius; width: statusBadge.implicitWidth + 12
                                color: modelData.status === "Ongoing"
                                    ? Qt.rgba(0.2, 0.75, 0.4, 0.85)
                                    : Qt.rgba(0.3, 0.5, 0.9, 0.85)

                                Text {
                                    id: statusBadge; anchors.centerIn: parent
                                    text: I18n.tData(modelData.status || "").toUpperCase()
                                    font.family: browseView.fontBody; font.pixelSize: 7 // style-ignore — bespoke size
                                    font.letterSpacing: 0.8; font.bold: true; color: "white"
                                }
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 52
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Colors.surface_container }
                                }
                            }
                        }

                        Rectangle {
                            id: nTitleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: nTitleText.implicitHeight + 18; color: Colors.surface_container; radius: Style.cornerRadius

                            Column {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Style.spacing.xl; rightMargin: Style.spacing.xl
                                }
                                spacing: Style.spacing.xs

                                Text {
                                    id: nTitleText; width: parent.width
                                    text: modelData.title || ""
                                    font.family: browseView.fontBody; font.pixelSize: Style.font.bodySmall
                                    font.letterSpacing: 0.2; color: Colors.on_surface
                                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.3
                                }
                                StyledText {
                                    visible: modelData.author && modelData.author.length > 0
                                    width: parent.width
                                    text: modelData.author || ""
                                    font.family: browseView.fontBody; font.pixelSize: 9 // style-ignore — bespoke size
                                    color: Colors.on_surface_variant; opacity: 0.6
                                    elide: Text.ElideRight; font.letterSpacing: 0.3
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: Style.cornerRadius; color: Colors.primary
                            opacity: nCard.pressed ? Style.pressedFillAlpha : (nCard.hovered ? Style.hoverFillAlpha : 0)
                            Behavior on opacity { NumberAnimation { duration: Motion.base } }
                        }

                        transform: Scale {
                            origin.x: nCard.width / 2; origin.y: nCard.height / 2
                            xScale: nCard.pressed ? 0.97 : 1.0
                            yScale: nCard.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
                            Behavior on yScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
                        }

                        onClicked: {
                                Novel.fetchNovelDetail(modelData.id)
                                browseView.novelSelected(modelData.id)
                            }
                    }
                }
            }
        }
    }
}
