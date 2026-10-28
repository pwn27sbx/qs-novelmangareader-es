import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.manga.components
import qs.app

ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 400
        color: "#1d2021"
        ReaderView { anchors.fill: parent }
    }
    Timer { interval: 15000; running: true; onTriggered: Qt.quit() }
}
