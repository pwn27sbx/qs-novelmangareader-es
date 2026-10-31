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

    // El panel se atenúa cuando el puntero no está encima (pintado sobre la
    // pantalla, ver shell.qml). HoverHandler escucha el área completa del panel,
    // no solo sus hijos.
    HoverHandler { id: pointer }

    readonly property bool pointerInside: pointer.hovered
    anchors {
        top: parent.top
        bottom: parent.bottom
        left: parent.left
    }
    implicitWidth: 600
    visible: false

    readonly property string fontBody: Style.font.family

    property int tabIndex: 0

    // Gear in the header: the settings view replaces the content stack.
    property bool settingsMode: false
    readonly property int settingsPageIndex: 2   // third page of the content stack

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

    // "Search other sources" from the no-Spanish notice: go back to Browse and
    // re-run the search for the current title across every source (plan §F3).
    function searchOtherSources() {
        const title = Manga.detailTitle || ""
        root.tabIndex = 0
        root.browseStack = 0
        root.searchOpen = true
        if (searchField) {
            searchField.text = title
            searchField.forceActiveFocus()
        }
        if (title.length > 0)
            Manga.searchManga(title, true)
        else
            browseView.resetList()
    }

    // "/" opens the header search. The panel stays loaded while minimized, so
    // the visibility guard is what keeps it from opening over another panel;
    // the search guard keeps a "/" typed in the field (or the settings page
    // showing) from being swallowed by the shortcut.
    Shortcut {
        sequence: "/"
        context: Qt.WindowShortcut
        enabled: root.visible && !root.searchOpen && !root.settingsMode
        onActivated: root.openSearch()
    }

    // Header brand: the app glyph plus this panel's short name (decision 1).
    // The other two panels pass their own; the shared PanelHeader renders it.
    Component {
        id: brandComponent
        PanelBrand { title: I18n.t("brand.manga"); fontFamily: root.fontBody }
    }

    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Header (tabs · search · language · minimize) ──────────────────────
        PanelHeader {
            Layout.fillWidth: true
            z: 2
            tabs: [I18n.t("tab.browse"), I18n.t("tab.library")]
            tabIndex: root.tabIndex
            brand: brandComponent
            tabCounts: [Manga.mangaList.length, Manga.libraryList.length]
            searchOpen: root.searchOpen
            fontFamily: root.fontBody
            settingsMode: root.settingsMode
            onTabActivated: function(index) {
                root.settingsMode = false
                root.tabIndex = index
            }
            onSettingsClicked: root.settingsMode = !root.settingsMode
            onSearchClicked: root.searchOpen ? root.closeSearch() : root.openSearch()
            onMinimizeClicked: root.minimize()

            // Search field — occupies the left region while searching
            Rectangle {
                id: searchBar
                visible: root.searchOpen
                anchors {
                    fill: parent
                    leftMargin: Style.spacing.md
                    rightMargin: Style.spacing.md
                    topMargin: Style.spacing.md
                    bottomMargin: Style.spacing.md
                }
                radius: Style.cornerRadius
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
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.settingsMode ? root.settingsPageIndex : root.tabIndex


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
                    onSearchOtherSourcesRequested: root.searchOtherSources()
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
                    onSearchOtherSourcesRequested: root.searchOtherSources()
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

            // Settings view (gear in the header). Third page of the same stack,
            // so Browse/Library keep their state while it is open.
            PanelSettings {
                showScroll: true
                active: root.settingsMode
                onCloseRequested: root.settingsMode = false
            }
        }
    }

    PanelDecor {
        title: I18n.t("panel.manga")
    }
}
