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

    // Passes the full show object so DetailView can seed itself immediately
    signal animeSelected(var show)

    // Emitted when an in-panel filter change invalidates the current search;
    // the panel clears its search bar in response.
    signal searchCleared()

    function resetList() {
        Anime.fetchPopular(true)
    }

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Filter bar (joined segmented control) ─────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: "transparent"

            Rectangle {
                id: filterBar
                anchors {
                    fill: parent
                    leftMargin: Style.spacing.md; rightMargin: Style.spacing.md
                    topMargin: Style.spacing.sm; bottomMargin: Style.spacing.sm
                }
                radius: Style.cornerRadius
                color: Util.alpha(Color.foreground, 0.05)
                border.width: 1
                border.color: Util.alpha(Color.foreground, 0.1)

                Row {
                    id: segRow
                    anchors { fill: parent; margins: Style.spacing.hairline }
                    spacing: Style.space(0)

                    Repeater {
                        id: segRepeater
                        model: ListModel {
                            ListElement { labelKey: "anime.filter.popular"; view: "popular"; country: "ALL" }
                            ListElement { labelKey: "anime.filter.latest";  view: "latest";  country: "ALL" }
                            ListElement { labelKey: "anime.filter.japan";   view: "latest";  country: "JP"  }
                            ListElement { labelKey: "anime.filter.china";   view: "latest";  country: "CN"  }
                            ListElement { labelKey: "anime.filter.korea";   view: "latest";  country: "KR"  }
                        }

                        delegate: Item {
                            required property string labelKey
                            required property string view
                            required property string country
                            required property int index
                            readonly property bool active:
                                Anime.currentView === view && Anime.currentCountry === country

                            width: segRow.width / Math.max(1, segRepeater.count)
                            height: segRow.height

                            Rectangle {
                                anchors.fill: parent
                                color: active ? Util.alpha(Color.accent, 0.15) : "transparent"
                                topLeftRadius: index === 0 ? Style.cornerRadius : 0
                                bottomLeftRadius: index === 0 ? Style.cornerRadius : 0
                                topRightRadius: index === segRepeater.count - 1 ? Style.cornerRadius : 0
                                bottomRightRadius: index === segRepeater.count - 1 ? Style.cornerRadius : 0
                            }

                            Rectangle {
                                visible: index > 0
                                width: Style.spacing.hairline
                                height: parent.height
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                color: Util.alpha(Color.foreground, 0.1)
                            }

                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: I18n.t(labelKey)
                                color: active ? Color.accent : Color.foreground
                                opacity: active ? 1.0 : 0.5
                                font.family: browseView.fontBody
                                font.pixelSize: Style.font.body
                                font.bold: active
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    browseView.searchCleared()
                                    Anime.currentCountry = country
                                    if (view === "popular") Anime.fetchPopular(true)
                                    else Anime.fetchLatest(true)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading: ghost cards where the first page will land
            SkeletonGrid {
                anchors.fill: parent; z: 10
                active: Anime.isFetchingAnime && Anime.animeList.length === 0
                cellWidth: (width - 30) / 4
                ratio: 1.58
            }

            // More pages on the way
            LoadingBar {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                z: 11
                active: Anime.isFetchingAnime && Anime.animeList.length > 0
            }

            // Error
            Rectangle {
                anchors.fill: parent; color: Colors.background
                visible: Anime.animeError.length > 0 && !Anime.isFetchingAnime
                z: 9

                Column {
                    anchors.centerIn: parent; spacing: Style.spacing.xl

                    Text {
                        text: "⚠"; font.pixelSize: 30; color: Colors.error // style-ignore — bespoke size
                        anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.8
                    }
                    StyledText {
                        text: Anime.animeError
                        color: Colors.on_surface_variant; font.pixelSize: Style.font.body
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap; width: 260
                        horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                    }
                }
            }

            // Grid
            GridView {
                id: animeGrid
                anchors.fill: parent; anchors.margins: Style.spacing.xl
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // A ScriptModel diffs each new array against the last, so appending a
                // page inserts rows instead of resetting the view (and its scroll).
                model: ScriptModel { values: Anime.animeList }

                ScrollBar.vertical: StyledScrollBar {
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Anime.fetchNextPage()
                }

                delegate: Item {
                    width: animeGrid.cellWidth
                    height: animeGrid.cellHeight

                    ClickableRect {
                        id: card
                        anchors { fill: parent; margins: Style.space(5) }
                        radius: Style.cornerRadius; color: Colors.surface_container; clip: true

                        CoverPlaceholder {
                            anchors.fill: coverImg
                            status: coverImg.status
                        }

                        // Cover
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Motion.slow } }

                            // Score badge
                            Rectangle {
                                visible: modelData.score !== null && modelData.score !== undefined
                                anchors { top: parent.top; left: parent.left; topMargin: Style.spacing.lg; leftMargin: Style.spacing.lg }
                                height: 20; radius: Style.cornerRadius
                                width: scoreText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                StyledText {
                                    id: scoreText; anchors.centerIn: parent
                                    text: modelData.score !== null
                                        ? "★ " + (modelData.score || 0).toFixed(1) : ""
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.5 // style-ignore — bespoke size
                                    color: "#f5c518"
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: Style.spacing.lg; rightMargin: Style.spacing.lg }
                                height: 20; radius: Style.cornerRadius
                                width: typeText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.7)

                                StyledText {
                                    id: typeText; anchors.centerIn: parent
                                    text: I18n.tData(modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 1; font.bold: true // style-ignore — bespoke size
                                    color: Colors.primary_fixed_dim
                                }
                            }

                            // Episode count badge (bottom-right of cover)
                            Rectangle {
                                visible: modelData.availableEpisodes
                                    && (modelData.availableEpisodes.sub > 0
                                        || modelData.availableEpisodes.dub > 0)
                                anchors {
                                    bottom: parent.bottom; right: parent.right
                                    bottomMargin: Style.spacing.lg; rightMargin: Style.spacing.lg
                                }
                                height: 20; radius: Style.cornerRadius
                                width: epText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                StyledText {
                                    id: epText; anchors.centerIn: parent
                                    text: {
                                        var avail = modelData.availableEpisodes
                                        var n = Anime.currentMode === "dub"
                                            ? avail.dub : avail.sub
                                        return I18n.t("anime.epCount", { 1: n })
                                    }
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 0.5 // style-ignore — bespoke size
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            // Gradient
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 48
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
                            height: titleText.implicitHeight + 16
                            color: Colors.surface_container; radius: Style.cornerRadius

                            StyledText {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Style.spacing.xl; rightMargin: Style.spacing.xl
                                }
                                text: modelData.englishName || modelData.name || ""
                                font.family: browseView.fontBody
                                font.pixelSize: Style.font.bodySmall; font.letterSpacing: 0.2
                                wrapMode: Text.Wrap; maximumLineCount: 2
                                elide: Text.ElideRight; lineHeight: 1.3
                            }
                        }

                        // Library bookmark dot
                        Rectangle {
                            visible: Anime.isInLibrary(modelData.id)
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: Style.spacing.md }
                            width: 7; height: 7; radius: height / 2 // style-ignore — dot
                            color: Colors.primary
                            opacity: 0.9
                        }

                        Rectangle {
                            anchors.fill: parent; radius: Style.cornerRadius; color: Colors.primary
                            opacity: card.pressed ? Style.pressedFillAlpha : (card.hovered ? Style.hoverFillAlpha : 0)
                            Behavior on opacity { NumberAnimation { duration: Motion.base } }
                        }

                        transform: Scale {
                            origin.x: card.width / 2; origin.y: card.height / 2
                            xScale: card.pressed ? 0.97 : 1.0
                            yScale: card.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
                            Behavior on yScale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeOut } }
                        }

                        onClicked: browseView.animeSelected(modelData)
                    }
                }
            }
        }
    }
}
