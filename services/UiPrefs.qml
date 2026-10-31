pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "prefs.js" as Core

// The app's preferences, and the ONLY writer of
// <config>/qs-novelmangareader/settings.json.
//
// Three features own a key here: the language row (`language`), the readers
// (`scrollFactor`) and the manga Browse/Library layout (`viewMode`). There used
// to be two writers with two in-memory copies of the file, which is how one key
// could clobber the other; every write now goes through `setSetting()`, which
// merges into what is on disk-as-loaded and preserves the rest
// (services/prefs.js).
//
// The values are reactive: `scrollFactor` is read by the readers' wheel
// handlers, `language` by I18n and `viewMode` by the two manga views, so a
// change applies without a restart.
Singleton {
    id: root

    readonly property string settingsDir: {
        const base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
        return base + "/qs-novelmangareader"
    }
    readonly property string settingsPath: root.settingsDir + "/settings.json"

    property string raw: ""
    // A write can land before the first load finishes; the late `onLoaded` must
    // not put the old file back over it (observed: the language write was
    // reverted by the load that started earlier).
    property bool _touched: false
    property bool _loaded: false
    // Writes that arrive before the file is read are held and applied on top of
    // it, so a first-run click can never drop keys it has not seen yet.
    property var _pending: ({})

    // "es" | "en" when the file says so, "" otherwise (I18n applies the rest
    // of its precedence: QS_LANG -> settings -> LANG -> en).
    readonly property string language: {
        const value = Core.parseSettings(root.raw).language
        return (value === "es" || value === "en") ? value : ""
    }

    // 1..10; a missing or broken value falls back to the default. The bounds
    // come from the same place the clamp does, so the slider cannot drift.
    readonly property real scrollFactorMin: Core.MIN_SCROLL_FACTOR
    readonly property real scrollFactorMax: Core.MAX_SCROLL_FACTOR
    readonly property real scrollFactor: Core.normalizeScrollFactor(Core.parseSettings(root.raw).scrollFactor)

    // "grid" | "list"; a missing or broken value normalizes to "grid", so the
    // views never have to guard against anything else.
    readonly property string viewMode: Core.normalizeViewMode(Core.parseSettings(root.raw).viewMode)

    function setSetting(key, value) {
        if (!root._loaded) {
            root._pending[key] = value
            return
        }
        root._write(key, value)
    }

    function _write(key, value) {
        root._touched = true
        root.raw = Core.withSetting(root.raw, key, value)
        writer.setText(root.raw)
    }

    function _flushPending() {
        const keys = Object.keys(root._pending)
        for (let i = 0; i < keys.length; i++)
            root._write(keys[i], root._pending[keys[i]])
        root._pending = ({})
    }

    function setLanguage(code) {
        root.setSetting("language", Core.normalizeLanguage(code))
    }

    function setScrollFactor(value) {
        root.setSetting("scrollFactor", Core.normalizeScrollFactor(value))
    }

    // The views pass "grid" / "list"; normalizing here means a typo can never
    // be what lands in the file (and the next read would ignore it anyway).
    function setViewMode(value) {
        root.setSetting("viewMode", Core.normalizeViewMode(value))
    }

    FileView {
        id: reader
        path: root.settingsPath
        onLoaded: {
            root._loaded = true
            if (!root._touched)
                root.raw = reader.text()
            root._flushPending()
        }
        onLoadFailed: {
            root._loaded = true
            if (!root._touched)
                root.raw = ""
            root._flushPending()
        }
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
