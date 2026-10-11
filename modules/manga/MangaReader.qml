import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.modules.manga.components
import qs.components
import qs.Ui

Item {
    id: root
    anchors {
        top: parent.top
        bottom: parent.bottom
        left: parent.left
    }
    implicitWidth: 600
    visible: false

    readonly property string fontBody: Style.font.family

    property int tabIndex: 0

    // ── Search state ──────────────────────────────────────────────────────────
    property bool searchOpen: false

    property int browseStack: 0
    property int libraryStack: 0

    property string selectedMangaId: ""

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

    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Header (tabs · search · language · minimize) ──────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Colors.surface_container_low
            z: 2

            SegmentBar {
                id: tabRow
                objectName: "tabRow"
                visible: !root.searchOpen
                anchors { left: parent.left; leftMargin: Style.spacing.md; verticalCenter: parent.verticalCenter }
                options: [
                    { value: "0", label: I18n.t("tab.browse") },
                    { value: "1", label: I18n.t("tab.library") }
                ]
                value: String(root.tabIndex)
                fontFamily: root.fontBody
                onActivated: function(v) { root.tabIndex = parseInt(v) }
            }

            // Search field — occupies the left region while searching
            Rectangle {
                id: searchBar
                visible: root.searchOpen
                anchors {
                    left: parent.left; leftMargin: Style.spacing.md
                    right: actions.left; rightMargin: Style.spacing.md
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
                    text: I18n.t("manga.search")
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
                        Manga.searchManga(searchField.text.trim(), true)
                    else
                        browseView.resetList()
                }
            }

            // ── Actions (right): search · language · minimize ─────────────────
            Row {
                id: actions
                anchors { right: parent.right; rightMargin: Style.spacing.md; verticalCenter: parent.verticalCenter }
                spacing: Style.spacing.controlGap

                PanelActionButton {
                    visible: root.tabIndex === 0
                    iconText: "⌕"
                    hasCursor: root.searchOpen
                    size: Style.space(36)
                    fontSize: Style.font.iconLarge
                    onClicked: root.searchOpen ? root.closeSearch() : root.openSearch()
                }

                Button {
                    text: I18n.lang === "es" ? "ES" : "EN" // i18n-ignore — language code chip
                    height: Style.space(36)
                    bordered: false
                    background: "transparent"
                    foreground: Colors.muted
                    fontSize: Style.font.caption
                    onClicked: I18n.toggleLanguage()
                }

                PanelActionButton {
                    iconText: "─"
                    size: Style.space(36)
                    onClicked: root.minimize()
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            Item {

                BrowseView {
                    id: browseView
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onSearchCleared: root.clearSearch()

                    onMangaSelected: function(mangaId) {
                        root.selectedMangaId = mangaId
                        root.browseStack = 1
                    }
                }

                DetailView {
                    id: browseDetail
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested:   { root.browseStack = 0 }
                    onChapterSelected: { root.browseStack = 2 }
                }

                ReaderView {
                    id: browseReader
                    anchors.fill: parent
                    visible: root.browseStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested: {
                        root.browseStack = 1
                        browseReader.reset()
                    }
                }
            }

            Item {
                LibraryView {
                    anchors.fill: parent
                    visible: root.libraryStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onMangaSelected: function(mangaId) {
                        root.selectedMangaId = mangaId
                        root.libraryStack = 1
                    }
                }

                DetailView {
                    id: libraryDetail
                    anchors.fill: parent
                    visible: root.libraryStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested:   { root.libraryStack = 0 }
                    onChapterSelected: { root.libraryStack = 2 }
                }

                ReaderView {
                    id: libraryReader
                    anchors.fill: parent
                    visible: root.libraryStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested: {
                        root.libraryStack = 1
                        libraryReader.reset()
                    }
                }
            }
        }
    }

    PanelDecor {
        title: I18n.t("panel.manga")
    }
}
