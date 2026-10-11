import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.app
import qs.Commons
import qs.services
import qs.components

Item {
    id: browseView

    readonly property string fontDisplay: Style.font.family
    readonly property string fontBody:    Style.font.family

    // Passes the full show object so DetailView can seed itself immediately
    signal animeSelected(var show)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Colors.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: Style.spacing.huge; rightMargin: Style.spacing.xl }
                spacing: Style.spacing.lg

                // Wordmark (hidden when search is open)
                Row {
                    spacing: Style.space(0)
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    StyledText {
                        text: "A"
                        font.family: browseView.fontDisplay
                        font.pixelSize: Style.font.display; font.letterSpacing: 1
                        color: Colors.primary
                    }
                    StyledText {
                        text: "nime" // i18n-ignore — brand wordmark (with the "A" above)
                        font.family: browseView.fontDisplay
                        font.pixelSize: Style.font.display; font.letterSpacing: 1
                        color: Colors.on_surface; opacity: 0.85
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 36; radius: height / 2
                    color: Colors.surface_container
                    visible: false
                    border.color: searchField.activeFocus ? Colors.primary : Colors.outline_variant
                    border.width: searchField.activeFocus ? 1.5 : 1
                    Behavior on border.width { NumberAnimation { duration: Motion.fast } }

                    TextInput {
                        id: searchField
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left; right: clearBtn.left
                            leftMargin: Style.spacing.xxxl; rightMargin: Style.spacing.md
                        }
                        color: Colors.on_surface
                        font.family: browseView.fontBody
                        font.pixelSize: Style.font.subtitle
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            Anime.fetchPopular(true)
                        }
                    }

                    StyledText {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: Style.spacing.xxxl }
                        text: I18n.t("anime.search")
                        color: Colors.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: Style.font.subtitle
                        visible: searchField.text.length === 0
                        opacity: 0.6
                    }

                    Item {
                        id: clearBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Style.spacing.xl }
                        width: 22; height: 22
                        visible: searchField.text.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18; height: 18; radius: height / 2
                            color: Colors.surface_container_highest
                        }
                        StyledText {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Colors.on_surface_variant
                            font.pixelSize: 9; font.bold: true // style-ignore — bespoke size
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length > 0)
                            Anime.searchAnime(searchField.text.trim(), true)
                        else
                            Anime.fetchPopular(true)
                    }
                }

                // Search toggle
                Item {
                    width: 38; height: 38

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: height / 2
                        color: searchBar.visible ? Colors.primary_container : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: "⌕"; font.pixelSize: Style.font.iconLarge
                        color: searchBar.visible ? Colors.on_primary_container : Colors.on_surface_variant
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchBar.visible = !searchBar.visible
                            if (searchBar.visible) searchField.forceActiveFocus()
                            else {
                                searchField.text = ""
                                Anime.fetchPopular(true)
                            }
                        }
                    }
                }

                // Sub / Dub toggle
                Rectangle {
                    height: 28
                    width: modeRow.implicitWidth + 16
                    radius: height / 2
                    color: Colors.surface_container
                    border.color: Colors.outline_variant; border.width: 1

                    Row {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: Style.space(0)

                        Repeater {
                            model: ["sub", "dub"]

                            delegate: Item {
                                width: modeText.implicitWidth + 16
                                height: 28
                                readonly property bool active: Anime.currentMode === modelData

                                Rectangle {
                                    anchors { fill: parent; margins: Style.spacing.xs }
                                    radius: height / 2
                                    color: active ? Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: Motion.base } }
                                }
                                StyledText {
                                    id: modeText
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true
                                    color: active ? Colors.on_primary : Colors.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: Motion.base } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Anime.setMode(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Filter chips ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Colors.surface_container_low
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.25
            }

            ListView {
                id: chipList
                anchors { fill: parent; leftMargin: Style.spacing.xxl; rightMargin: Style.spacing.xxl }
                orientation: ListView.Horizontal
                spacing: Style.space(7); clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { labelKey: "anime.filter.popular"; view: "popular"; country: "ALL" }
                    ListElement { labelKey: "anime.filter.latest";  view: "latest";  country: "ALL" }
                    ListElement { labelKey: "anime.filter.japan";   view: "latest";  country: "JP"  }
                    ListElement { labelKey: "anime.filter.china";   view: "latest";  country: "CN"  }
                    ListElement { labelKey: "anime.filter.korea";   view: "latest";  country: "KR"  }
                }

                delegate: Item {
                    width: chipRect.implicitWidth + 24
                    height: chipList.height

                    readonly property bool active:
                        Anime.currentView === view && Anime.currentCountry === country

                    Rectangle {
                        id: chipRect
                        anchors.centerIn: parent
                        implicitWidth: chipLbl.implicitWidth + 24
                        height: 28; radius: height / 2
                        color: active ? Colors.primary : Colors.surface_container
                        border.color: active ? Colors.primary : Colors.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: Motion.base } }

                        StyledText {
                            id: chipLbl
                            anchors.centerIn: parent
                            text: I18n.t(labelKey)
                            font.family: browseView.fontBody
                            font.pixelSize: Style.font.bodySmall; font.letterSpacing: 0.5
                            color: active ? Colors.on_primary : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: Motion.base } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchField.text = ""
                            searchBar.visible = false
                            Anime.currentCountry = country
                            if (view === "popular") Anime.fetchPopular(true)
                            else Anime.fetchLatest(true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
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
                                height: 20; radius: height / 2
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
                                height: 20; radius: height / 2
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
                                height: 20; radius: height / 2
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
                            width: 7; height: 7; radius: height / 2
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
