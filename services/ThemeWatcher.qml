import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "theme.js" as Theme

// Follows the Omarchy theme for the whole app.
//
// Omarchy loads the palette once at startup (Commons/Color.qml uses
// `watchChanges: false`) and pushes a live switch through its own shell IPC,
// which only the main shell receives. Our panels are a separate Quickshell
// instance, so after `omarchy theme set` they kept the palette they booted
// with until the app was restarted.
//
// theme.name is rewritten for every theme change, AFTER the new
// colors.toml/shell.toml are in place, so watching it is enough.
QtObject {
    id: root

    readonly property string namePath:
        Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"

    property string name: ""

    // The first read is the theme we already loaded at startup; only later
    // changes (or a change that landed while we were starting) need a reload.
    property bool primed: false

    function apply(raw) {
        const next = Theme.themeName(raw)
        if (!root.primed) {
            root.primed = true
            root.name = next
            return
        }
        if (!Theme.shouldReload(root.name, next))
            return
        root.name = next
        console.log("[ThemeWatcher] theme changed —", next)
        // Commons.Color keeps its own FileViews with watchChanges:false;
        // reload() is the only supported way to re-read them.
        Commons.Color.colorsFile.reload()
        Commons.Color.shellFile.reload()
    }

    property FileView nameFile: FileView {
        path: root.namePath
        watchChanges: true
        printErrors: false
        onLoaded: root.apply(text())
        // text() is stale inside the change signal, so re-read first.
        onFileChanged: reload()
        onLoadFailed: root.apply("")
    }
}
