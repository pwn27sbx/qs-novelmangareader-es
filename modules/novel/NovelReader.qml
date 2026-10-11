import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.modules.novel.components
import qs.components
import qs.Ui

Item {
    id: root
    anchors {
        top: parent.top
        bottom: parent.bottom
        right: parent.right
    }
    implicitWidth: fullscreen ? (parent && parent.parent ? parent.parent.width : 1200) : 600
    visible: false

    Behavior on implicitWidth { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

    readonly property string fontBody: Style.font.family

    property bool fullscreen: false
    property int tabIndex: 0

    // ── Search state ──────────────────────────────────────────────────────────
    property bool searchOpen: false

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

    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        // ── Header bar (tabs · search · language · minimize) ──────────────────
        Rectangle {
            Layout.fillWidth: true; height: 44
            color: Colors.surface_container_low; z: 2

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
                    text: I18n.t("novel.search")
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
                    if (searchField.text.trim().length > 0) {
                        browseView.currentFilter = "search"
                        Novel.searchNovels(searchField.text.trim(), "", "All", true)
                    } else {
                        browseView.resetList()
                    }
                }
            }

            // ── Right actions: provider · search · language · minimize ────────
            Item {
                id: providerButton
                visible: root.tabIndex === 0 && !root.searchOpen
                anchors { right: searchToggle.left; rightMargin: Style.spacing.sm; verticalCenter: parent.verticalCenter }
                width: providerRow.implicitWidth + Style.spacing.lg * 2
                height: 30

                Rectangle {
                    anchors.fill: parent; radius: Style.cornerRadius
                    color: providerDropArea.containsMouse ? Colors.surface_container_highest : Colors.surface_container
                    Behavior on color { ColorAnimation { duration: Motion.base } }
                }

                Row {
                    id: providerRow
                    anchors.centerIn: parent
                    spacing: Style.space(5)

                    StyledText {
                        text: {
                            for (var i = 0; i < Novel.availableProviders.length; i++) {
                                if (Novel.availableProviders[i].name === Novel.activeProvider)
                                    return Novel.availableProviders[i].label
                            }
                            return Novel.activeProvider
                        }
                        font.family: root.fontBody; font.pixelSize: Style.font.bodySmall
                        font.letterSpacing: 0.3
                        color: Novel.isSwitchingProvider ? Colors.on_surface_variant : Colors.on_surface
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Motion.base } }
                    }

                    Spinner {
                        visible: Novel.isSwitchingProvider
                        width: 10; border.width: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        duration: Motion.loop
                        running: Novel.isSwitchingProvider
                    }

                    StyledText {
                        visible: !Novel.isSwitchingProvider
                        text: providerPopup.visible ? "▲" : "▾"
                        font.pixelSize: 8 // style-ignore — bespoke size
                        color: Colors.on_surface_variant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: providerDropArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (!Novel.isSwitchingProvider) providerPopup.visible = !providerPopup.visible
                }

                Rectangle {
                    id: providerPopup
                    visible: false
                    anchors { top: parent.bottom; right: parent.right; topMargin: Style.spacing.md }
                    width: 160
                    height: popupColumn.implicitHeight + 10
                    radius: Style.cornerRadius
                    color: Colors.surface_container_high
                    border.color: Colors.outline_variant; border.width: 1
                    z: 100

                    Column {
                        id: popupColumn
                        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Style.space(5) }
                        spacing: Style.space(0)

                        Repeater {
                            model: Novel.availableProviders

                            delegate: Item {
                                width: parent.width
                                height: 36

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.leftMargin: Style.spacing.sm; anchors.rightMargin: Style.spacing.sm
                                    radius: Style.cornerRadius
                                    color: {
                                        if (modelData.name === Novel.activeProvider) return Colors.primary_container
                                        return optionArea.containsMouse ? Colors.surface_container_highest : "transparent"
                                    }
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                }

                                Row {
                                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: Style.spacing.xxxl }
                                    spacing: Style.spacing.lg

                                    Rectangle {
                                        width: 6; height: 6; radius: height / 2 // style-ignore — dot
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Colors.primary
                                        visible: modelData.name === Novel.activeProvider
                                    }
                                    Item { width: 6; height: 6; visible: modelData.name !== Novel.activeProvider }

                                    StyledText {
                                        text: modelData.label
                                        font.family: root.fontBody; font.pixelSize: Style.font.body
                                        color: modelData.name === Novel.activeProvider ? Colors.on_primary_container : Colors.on_surface
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: optionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        providerPopup.visible = false
                                        Novel.switchProvider(modelData.name)
                                    }
                                }
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

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: root.tabIndex

            Item {
                BrowseView {
                    id: browseView
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onSearchCleared: root.clearSearch()

                    onNovelSelected: function(novelId) {
                        root.browseStack = 1
                    }
                }

                DetailView {
                    id: browseDetail
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    onBackRequested:    { root.browseStack = 0 }
                    onChapterSelected:  { root.browseStack = 2 }
                }

                ReaderView {
                    id: browseReader
                    anchors.fill: parent
                    visible: root.browseStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

                    isFullscreen: root.fullscreen
                    onToggleFullscreen: root.fullscreen = !root.fullscreen

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

                    onNovelSelected: function(novelId) {
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

                    isFullscreen: root.fullscreen
                    onToggleFullscreen: root.fullscreen = !root.fullscreen

                    onBackRequested: {
                        root.libraryStack = 1
                        libraryReader.reset()
                    }
                }
            }
        }
    }

    PanelDecor {
        title: I18n.t("panel.novel")
    }
}
