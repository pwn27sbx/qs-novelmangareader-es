import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.modules.novel.components
import qs.components

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
            Layout.fillWidth: true; height: 44
            color: Colors.surface_container_low; z: 10

            Rectangle {
                anchors { bottom: parent.bottom; right: parent.right; left: parent.left }
                height: 1; color: Colors.outline_variant; opacity: 0.4
            }

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

            Row {
                id: tabRow
                objectName: "tabRow"
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: languageToggle.left; rightMargin: Style.spacing.lg }

                Repeater {
                    id: tabsRepeater
                    model: [
                        { label: I18n.t("tab.browse"),  icon: "⊞" },
                        { label: I18n.t("tab.library"), icon: "⊟" }
                    ]

                    delegate: Item {
                        width: tabRow.width / Math.max(1, tabsRepeater.count); height: parent.height
                        readonly property bool active: root.tabIndex === index

                        Rectangle {
                            anchors.fill: parent
                            color: tabTap.containsMouse && !active
                                ? Style.hoverFillFor(Colors.primary)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Column {
                            anchors.centerIn: parent; spacing: Style.spacing.xxs
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon; font.pixelSize: Style.font.subtitle
                                color: active ? Colors.primary : Colors.on_surface_variant
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: Motion.base } }
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label; font.family: root.fontBody
                                font.pixelSize: Style.font.caption; font.letterSpacing: 0.6
                                color: active ? Colors.primary : Colors.on_surface_variant
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: Motion.base } }
                            }
                        }

                        // Active indicator
                        Rectangle {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            width: active ? 28 : 0; height: 2; radius: height / 2; color: Colors.primary
                            Behavior on width { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }
                        }

                        MouseArea {
                            id: tabTap; anchors.fill: parent; hoverEnabled: true
                            onClicked: root.tabIndex = index
                        }
                    }
                }
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
