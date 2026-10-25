pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "prefs.js" as Core

// Reader/UI preferences kept in <config>/qs-novelmangareader/settings.json.
//
// Today: `scrollFactor`, how far one wheel notch moves a reader (default 2).
// The language toggle owns `language` in the same file; both writers keep the
// other's keys (see services/prefs.js).
Singleton {
    id: root

    readonly property string settingsDir: {
        const base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
        return base + "/qs-novelmangareader"
    }
    readonly property string settingsPath: root.settingsDir + "/settings.json"

    property string raw: ""

    // 1..10; a missing or broken value falls back to the default.
    readonly property real scrollFactor: Core.normalizeScrollFactor(Core.parseSettings(root.raw).scrollFactor)

    function setScrollFactor(value) {
        const data = Core.parseSettings(root.raw)
        data.scrollFactor = Core.normalizeScrollFactor(value)
        root.raw = JSON.stringify(data, null, 2) + "\n"
        writer.setText(root.raw)
        writer.save()
    }

    FileView {
        id: reader
        path: root.settingsPath
        onLoaded: root.raw = reader.text()
        onLoadFailed: root.raw = ""
    }

    FileView {
        id: writer
        path: root.settingsPath
    }

    Component.onCompleted: reader.reload()
}
