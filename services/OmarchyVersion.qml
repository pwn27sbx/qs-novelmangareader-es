pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "omarchy_version.js" as Core

// Omarchy version guard (Plan C, R-C2).
//
// The app imports `qs.Commons` and `qs.Ui` from the installed Omarchy, so an
// Omarchy upgrade that moves those layers breaks the panels. At startup this
// reads `omarchy version` and warns once when the running major.minor is not
// the line the app is written against. It never blocks: the panels still
// open, and the message names what may have moved.
//
// `omarchy version` prints "4.0.6-1" on a release install and "dev (hash)"
// for a checkout. The parsing and the message live in
// services/omarchy_version.js (tests/omarchy_version.test.js).
//
// Bumping the supported line is a deliberate act: run the panels against the
// new Omarchy, fix what moved, then change `supported` and the README.
Singleton {
    id: root

    readonly property string supported: "4.0"

    // "4.0" / "4.5" / "dev" / "" (command missing or failed).
    property string running: ""
    readonly property bool ok: Core.isSupported(root.supported, root.running)

    // Called once from shell.qml; advisory, so a failed read only warns.
    function check() {
        if (!probe.running)
            probe.running = true
    }

    Process {
        id: probe
        command: ["omarchy", "version"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.running = Core.parseVersion(text)
                if (!root.ok)
                    console.warn("qs-novelmangareader: " + Core.warningMessage(root.supported, root.running))
            }
        }
    }
}
