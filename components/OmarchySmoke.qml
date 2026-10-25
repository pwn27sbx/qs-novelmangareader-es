import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Smoke test for the Omarchy adoption (Plan C, R-C1).
//
// Proves at startup that `qs.Commons` and `qs.Ui` load and that one component
// instantiates, and reports the resolved theme (accent / corner radius) after
// the theme files finish loading. If an Omarchy update moves or breaks the
// modules, this fails loudly at launch instead of silently.
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var _probe: null

    Component {
        id: buttonFactory
        Button {}
    }

    Component.onCompleted: root._probe = buttonFactory.createObject(root)

    // The theme is read asynchronously from colors.toml/shell.toml; report
    // once it has settled.
    Timer {
        interval: 700
        running: true
        onTriggered: console.log("SMOKE qs.Commons+qs.Ui ok | accent=" + Commons.Color.accent
            + " | cornerRadius=" + Style.cornerRadius
            + " | button=" + (root._probe ? "ok" : "null"))
    }
}
