import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.app
import qs.services

// Bottom strip of the manga panel: connection state on the left, the installed
// version and the shortcuts that actually work on the right.
//
// Nothing here is invented. The dot follows `Manga.serverReady` (the health
// check the panel already waits on), the version is read from the installed
// manifest.json and vanishes when the file is missing or unparseable, and the
// two shortcuts are the ones the panel really binds ("/" opens the header
// search, Esc closes the search / settings page). No cache size and no tracker:
// both were dropped on purpose (owner decision 3).
//
// The panel stays loaded while minimized, so nothing here polls: the version is
// read once and then refreshed only by the file watcher when an install
// replaces the manifest. No timer, no animation, no reaction of its own.
Rectangle {
    id: root

    // Manga server reachable; the panel sets this from its health check.
    property bool online: false
    property string fontFamily: Style.font.family

    // install_config copies the whole folder to <config>/qs-novelmangareader,
    // so the manifest is next to the running copy. `UiPrefs.settingsDir` is the
    // one place that directory is spelled out.
    readonly property string manifestPath: UiPrefs.settingsDir
        + "/omarchy/pwnsxb.novelmangareader/manifest.json"

    // "" until the manifest is read; the version label hides itself then.
    property string version: ""

    implicitHeight: Style.space(28)
    color: Colors.surface_container

    // Hairline against the views above; the layout gap is zero.
    Divider {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        opacity: 0.5
    }

    function _versionFrom(text) {
        try {
            const data = JSON.parse(String(text))
            return (data && typeof data.version === "string") ? data.version.trim() : ""
        } catch (e) {
            return ""
        }
    }

    FileView {
        id: manifest
        path: root.manifestPath
        // An install replaces this file under a running shell; the watch costs
        // one inotify handle and fires only when that happens.
        watchChanges: true
        onLoaded: root.version = root._versionFrom(manifest.text())
        onFileChanged: root.version = root._versionFrom(manifest.text())
        onLoadFailed: root.version = ""
    }

    Component.onCompleted: manifest.reload()

    RowLayout {
        id: stateRow
        anchors {
            left: parent.left
            leftMargin: Style.spacing.xl
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.spacing.sm

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "●"
            font.pixelSize: Style.font.caption
            color: root.online ? Colors.primary : Colors.error
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.online ? I18n.t("status.online") : I18n.t("status.offline")
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 0.4
            color: Colors.on_surface_variant
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.version !== ""
            text: "v" + root.version
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: Colors.on_surface_variant
            opacity: 0.6
        }
    }

    // A key cap and its label, one per shortcut. The key names are not UI copy:
    // they read the same in both languages.
    component KeyCap: Rectangle {
        property string key: ""
        property string bodyFont: ""

        implicitWidth: keyLabel.implicitWidth + Style.spacing.lg * 2
        implicitHeight: keyLabel.implicitHeight + Style.spacing.xxs * 2
        radius: Style.cornerRadius
        color: Colors.surface_container_high

        StyledText {
            id: keyLabel
            anchors.centerIn: parent
            text: parent.key
            font.family: parent.bodyFont
            font.pixelSize: Style.font.caption
            color: Colors.on_surface_variant
        }
    }

    RowLayout {
        id: shortcutsRow
        anchors {
            right: parent.right
            rightMargin: Style.spacing.xl
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.spacing.md

        KeyCap {
            Layout.alignment: Qt.AlignVCenter
            key: "/"
            bodyFont: root.fontFamily
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: I18n.t("status.search")
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: Colors.on_surface_variant
        }

        KeyCap {
            Layout.alignment: Qt.AlignVCenter
            key: "Esc"
            bodyFont: root.fontFamily
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: I18n.t("status.close")
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            color: Colors.on_surface_variant
        }
    }
}
