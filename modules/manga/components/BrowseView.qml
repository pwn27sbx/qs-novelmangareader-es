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

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property string fontBody: Style.font.family

    // Emitted when the user taps a manga card
    signal mangaSelected(string mangaId)

    property string currentTagId: ""

    // Emitted when an in-panel filter change invalidates the current search;
    // the panel clears its search bar in response.
    signal searchCleared()

    function resetList() {
        Manga.fetchByOrigin(currentTagId, true)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Tag filter chips ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Colors.surface_container_low
            clip: true

            Divider {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                opacity: 0.25
            }

            ListView {
                id: tagList
                anchors {
                    fill: parent
                    topMargin: Style.spacing.md; bottomMargin: Style.spacing.md
                    leftMargin: Style.spacing.xxxl; rightMargin: Style.spacing.xxxl
                }
                orientation: ListView.Horizontal
                spacing: Style.space(7)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { labelKey: "manga.filter.hot";    tagId: ""       }
                    ListElement { labelKey: "manga.filter.latest"; tagId: "latest" }
                    ListElement { labelKey: "Manga";               tagId: "ja"     }
                    ListElement { labelKey: "Manhwa";              tagId: "ko"     }
                    ListElement { labelKey: "Manhua";              tagId: "zh"     }
                }

                delegate: SegmentChip {
                    required property string labelKey
                    required property string tagId
                    text: I18n.t(labelKey)
                    active: browseView.currentTagId === tagId
                    fontFamily: browseView.fontBody
                    onClicked: {
                        browseView.currentTagId = tagId
                        browseView.searchCleared()
                        Manga.fetchByOrigin(tagId, true)
                    }
                }
            }

            Divider {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                opacity: 0.3
            }
        }

        // ── Main content area ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading state: ghost cards where the first page will land
            SkeletonGrid {
                anchors.fill: parent
                z: 10
                active: Manga.isFetchingManga && Manga.mangaList.length === 0
                cellWidth: (width - 30) / 4
                ratio: 1.58
            }

            // More pages on the way
            LoadingBar {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                z: 11
                active: Manga.isFetchingManga && Manga.mangaList.length > 0
            }

            // Error state
            Rectangle {
                anchors.fill: parent
                color: Colors.background
                visible: Manga.mangaError.length > 0 && !Manga.isFetchingManga
                z: 9

                Column {
                    anchors.centerIn: parent
                    spacing: Style.spacing.xl
                    StyledText {
                        text: "⚠"
                        font.pixelSize: 32 // style-ignore — bespoke size
                        color: Colors.error
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.8
                    }
                    StyledText {
                        text: Manga.mangaError
                        color: Colors.on_surface_variant
                        font.pixelSize: Style.font.body
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap
                        width: 260
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                    }
                }
            }

            // ── Manga grid ───────────────────────────────────────────────────
            GridView {
                id: mangaGrid
                anchors.fill: parent
                anchors.margins: Style.spacing.xl
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // A ScriptModel diffs each new array against the last, so appending a
                // page inserts rows instead of resetting the view (and its scroll).
                model: ScriptModel { values: Manga.mangaList }

                ScrollBar.vertical: StyledScrollBar {
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Manga.fetchNextMangaPage()
                }

                delegate: Item {
                    width: mangaGrid.cellWidth
                    height: mangaGrid.cellHeight

                    ClickableRect {
                        id: card
                        anchors { fill: parent; margins: Style.space(5) }
                        radius: Style.cornerRadius
                        color: Colors.surface_container
                        clip: true

                        CoverPlaceholder {
                            anchors.fill: coverImg
                            status: coverImg.status
                        }

                        // Cover image
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Motion.slow } }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: Style.spacing.lg; rightMargin: Style.spacing.lg }
                                height: 20
                                radius: Style.cornerRadius
                                width: typeText.implicitWidth + 14
                                color: Qt.rgba(0, 0, 0, 0.7)

                                StyledText {
                                    id: typeText
                                    anchors.centerIn: parent
                                    text: I18n.tData(modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8 // style-ignore — bespoke size
                                    font.letterSpacing: 1
                                    font.bold: true
                                    color: Colors.primary_fixed_dim
                                }
                            }

                            // Gradient vignette at bottom of cover
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 56
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Colors.surface_container }
                                }
                            }
                        }

                        // Title bar
                        Rectangle {
                            id: titleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: titleText.implicitHeight + 18
                            color: Colors.surface_container
                            radius: Style.cornerRadius

                            StyledText {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Style.spacing.xl; rightMargin: Style.spacing.xl
                                }
                                text: modelData.title || ""
                                font.family: browseView.fontBody
                                font.pixelSize: Style.font.bodySmall
                                font.letterSpacing: 0.2
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.3
                            }
                        }

                        // Hover + press overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: Style.cornerRadius
                            color: Colors.primary
                            opacity: card.pressed
                                ? Style.pressedFillAlpha
                                : (card.hovered ? Style.hoverFillAlpha : 0)
                            Behavior on opacity { NumberAnimation { duration: Motion.base } }
                        }

                        // Scale effect on hover
                        transform: Scale {
                            origin.x: card.width / 2
                            origin.y: card.height / 2
                            xScale: card.pressed ? 0.97 : 1.0
                            yScale: card.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
                            Behavior on yScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
                        }

                        onClicked: {
                                Manga.fetchMangaDetail(modelData.id)
                                browseView.mangaSelected(modelData.id)
                            }
                    }
                }
            }
        }
    }
}
