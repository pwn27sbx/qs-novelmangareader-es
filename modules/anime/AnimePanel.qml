import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.app
import qs.Commons
import qs.services
import qs.modules.anime.components
import qs.components

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

        // ── Main content (Browse / Library stacks) ────────────────────────────
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            // ── Browse tab ────────────────────────────────────────────────────
            Item {
                BrowseView {
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

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

        // ── Bottom tab bar ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Colors.surface_container_low

            // Top hairline
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
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
                        width: tabRow.width / Math.max(1, tabsRepeater.count)
                        height: parent.height

                        readonly property bool active: root.tabIndex === index

                        Rectangle {
                            anchors.fill: parent
                            color: tabArea.containsMouse && !active
                                ? Style.hoverFillFor(Colors.primary)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: Style.spacing.xxs

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: Style.font.subtitle
                                color: active ? Colors.primary : Colors.on_surface_variant
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: Motion.base } }
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.family: root.fontBody
                                font.pixelSize: Style.font.caption
                                font.letterSpacing: 0.6
                                color: active ? Colors.primary : Colors.on_surface_variant
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: Motion.base } }
                            }
                        }

                        // Active indicator — top edge (drawer is at bottom, indicator on top)
                        Rectangle {
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: active ? 28 : 0
                            height: 2; radius: height / 2
                            color: Colors.primary
                            Behavior on width { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.tabIndex = index
                        }
                    }
                }
            }
        }
    }

    PanelDecor {
        title: I18n.t("panel.anime")
    }
}
