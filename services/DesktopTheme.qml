pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// Deprecated shim, kept only while the remaining module views finish migrating
// onto `Commons/Style.qml`. The desktop-theme registry this stood in for never
// existed in the standalone packages, so every radius now delegates to the
// shared token and is therefore already unified. This file is deleted once no
// view references it (R1.7).
Singleton {
    readonly property bool enabled: false
    readonly property string theme: ""
    readonly property real controlRadius: -1
    readonly property bool roundControls: false
    readonly property string font: Style.font.family
    readonly property color accent: Style.accent
    readonly property color accent2: Style.accent

    function rad(normal) {
        return Style.cornerRadius;
    }
}
