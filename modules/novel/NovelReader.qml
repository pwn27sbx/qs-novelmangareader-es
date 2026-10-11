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

    property int browseStack:  0
    property int libraryStack: 0

    // Hidden but kept loaded: shell.qml skips the unload while this is set,
    // so the toggle brings the panel back exactly as it was left.
    property bool minimized: false

    function minimize() {
        minimized = true
        visible = false
    }

    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(0)

        Rectangle {
            Layout.fillWidth: true; height: 36
            color: Colors.surface_container_low; z: 10

            IconButton {
                id: minimizeButton
                anchors { right: parent.right; rightMargin: Style.spacing.lg; verticalCenter: parent.verticalCenter }
                icon: "󰖰"
                onClicked: root.minimize()
            }

            LanguageToggle {
                id: languageToggle
                anchors { right: minimizeButton.left; rightMargin: Style.spacing.sm; verticalCenter: parent.verticalCenter }
            }

            ButtonGroup {
                id: tabRow
                objectName: "tabRow"
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
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: root.tabIndex

            Item {
                BrowseView {
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

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
