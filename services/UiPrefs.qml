pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "prefs.js" as Core

// The app's preferences, and the ONLY writer of
// <config>/qs-novelmangareader/settings.json.
//
// Two features own a key here: the language row (`language`) and the readers
// (`scrollFactor`). There used to be two writers with two in-memory copies of
// the file, which is how one key could clobber the other; every write now goes
// through `setSetting()`, which merges into what is on disk-as-loaded and
// preserves the rest (services/prefs.js).
//
// The values are reactive: `scrollFactor` is read by the readers' wheel
// handlers and `language` by I18n, so a change applies without a restart.
Singleton {
    id: root

    readonly property string settingsDir: {
        const base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
        return base + "/qs-novelmangareader"
    }
    readonly property string settingsPath: root.settingsDir + "/settings.json"

    property string raw: ""

    // "es" | "en" when the file says so, "" otherwise (I18n applies the rest
    // of its precedence: QS_LANG -> settings -> LANG -> en).
    readonly property string language: {
        const value = Core.parseSettings(root.raw).language
        return (value === "es" || value === "en") ? value : ""
    }

    // 1..10; a missing or broken value falls back to the default.
    readonly property real scrollFactor: Core.normalizeScrollFactor(Core.parseSettings(root.raw).scrollFactor)

    function setSetting(key, value) {
        root.raw = Core.withSetting(root.raw, key, value)
        writer.setText(root.raw)
    }

    function setLanguage(code) {
        root.setSetting("language", String(code) === "es" ? "es" : "en")
    }

    function setScrollFactor(value) {
        root.setSetting("scrollFactor", Core.normalizeScrollFactor(value))
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

    // The config dir may not exist on a fresh setup; create it before writing.
    Process {
        id: ensureDir
        command: ["mkdir", "-p", root.settingsDir]
    }

    Component.onCompleted: {
        ensureDir.running = true
        reader.reload()
    }
}
