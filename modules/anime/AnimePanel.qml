import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.modules.anime.components
import qs.components
import qs.Ui

Item {
    id: root
    anchors {
        left:   parent.left
        bottom:  parent.bottom
        top: parent.top
    }
    implicitWidth: 540
    visible: false

    readonly property string fontBody: Style.font.family

    // ── Tab state ─────────────────────────────────────────────────────────────
    property int tabIndex: 0       // 0 = Browse, 1 = Library

    // ── Search state ──────────────────────────────────────────────────────────
    property bool searchOpen: false

    // ── Navigation stacks (0 = list, 1 = detail) ──────────────────────────────
    // No "reader" stack — MPV handles playback externally
    property int browseStack:  0
    property int libraryStack: 0

    // Hidden but kept loaded: shell.qml skips the unload while this is set,
    // so the toggle brings the panel back exactly as it was left.
    property bool minimized: false

    function minimize() {
        minimized = true
        visible = false
    }

    function openSearch() {
        searchOpen = true
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }

    function clearSearch() {
        searchOpen = false
        if (searchField) searchField.text = ""
    }

    function closeSearch() {
        clearSearch()
        browseView.resetList()
    }

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Colors.background
        // Top edge shadow / divider
        Divider {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            opacity: 0.5
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Header bar (tabs · search · SUB/DUB · language · minimize) ────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Colors.surface_container_low
            z: 2

            ButtonGroup {
                id: tabRow
                objectName: "tabRow"
                visible: !root.searchOpen
                anchors { left: parent.left; leftMargin: Style.spacing.md; verticalCenter: parent.verticalCenter }
                options: [
                    { value: "0", label: I18n.t("tab.browse") },
                    { value: "1", label: I18n.t("tab.library") }
                ]
                value: String(root.tabIndex)
                background: "transparent"
                fontSize: Style.font.bodySmall
                onChanged: function(v) { root.tabIndex = parseInt(v) }
            }

            // Search field — occupies the left region while searching
            Rectangle {
                id: searchBar
                visible: root.searchOpen
                anchors {
                    left: parent.left; leftMargin: Style.spacing.md
                    right: searchToggle.left; rightMargin: Style.spacing.sm
                    verticalCenter: parent.verticalCenter
                }
                height: 32; radius: Style.cornerRadius
                color: Colors.surface_container
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
                    font.family: root.fontBody
                    font.pixelSize: Style.font.subtitle
                    clip: true
                    onTextChanged: searchDebounce.restart()
                    Keys.onEscapePressed: {
                        searchField.text = ""
                        root.closeSearch()
                    }
                }

                StyledText {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: Style.spacing.xxxl }
                    text: I18n.t("anime.search")
                    color: Colors.on_surface_variant
                    font.family: root.fontBody
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
                        width: 18; height: 18; radius: Style.cornerRadius
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
                        browseView.resetList()
                }
            }

            // ── Right actions: SUB/DUB · search · language · minimize ─────────
            Rectangle {
                id: modeToggle
                visible: root.tabIndex === 0 && !root.searchOpen
                anchors { right: searchToggle.left; rightMargin: Style.spacing.sm; verticalCenter: parent.verticalCenter }
                height: 28
                width: modeRow.implicitWidth + 16
                radius: Style.cornerRadius
                color: "transparent"

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
                                radius: Style.cornerRadius
                                color: active ? Style.selectedFillFor(Colors.primary) : "transparent"
                                Behavior on color { ColorAnimation { duration: Motion.base } }
                            }
                            StyledText {
                                id: modeText
                                anchors.centerIn: parent
                                text: modelData.toUpperCase()
                                font.family: root.fontBody
                                font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true
                                color: active ? Colors.primary : Colors.on_surface_variant
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

            IconButton {
                id: searchToggle
                anchors { right: languageToggle.left; rightMargin: Style.spacing.sm; verticalCenter: parent.verticalCenter }
                icon: "⌕"
                visible: root.tabIndex === 0
                onClicked: root.searchOpen ? root.closeSearch() : root.openSearch()
            }

            LanguageToggle {
                id: languageToggle
                anchors { right: minimizeButton.left; rightMargin: Style.spacing.sm; verticalCenter: parent.verticalCenter }
            }

            IconButton {
                id: minimizeButton
                anchors { right: parent.right; rightMargin: Style.spacing.lg; verticalCenter: parent.verticalCenter }
                icon: "󰖰"
                onClicked: root.minimize()
            }
        }

        // ── Main content (Browse / Library stacks) ────────────────────────────
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            // ── Browse tab ────────────────────────────────────────────────────
            Item {
                BrowseView {
                    id: browseView
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onSearchCleared: root.clearSearch()

                    onAnimeSelected: function(show) {
                        Anime.fetchAnimeDetail(show)
                        root.browseStack = 1
                    }
                }

                DetailView {
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested: {
                        root.browseStack = 0
                        Anime.clearDetail()
                    }
                }
            }

            // ── Library tab ───────────────────────────────────────────────────
            Item {
                LibraryView {
                    anchors.fill: parent
                    visible: root.libraryStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onAnimeSelected: function(show) {
                        Anime.fetchAnimeDetail(show)
                        root.libraryStack = 1
                    }
                }

                DetailView {
                    anchors.fill: parent
                    visible: root.libraryStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested: {
                        root.libraryStack = 0
                        Anime.clearDetail()
                    }
                }
            }
        }
    }

    PanelDecor {
        title: I18n.t("panel.anime")
    }
}
