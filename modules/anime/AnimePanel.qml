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

        // ── Tab bar ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: Colors.surface_container_low

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
    }

    PanelDecor {
        title: I18n.t("panel.anime")
    }
}
