pragma Singleton
import QtQuick
import Quickshell

// App motion tokens.
//
// Omarchy's `Commons/Style` has no animation tokens, so the shared durations
// and easings the views use live here. Durations mirror the shell's QML timing
// (120 for color/state fades, 140 for OutCubic movement, 240 for larger
// surfaces) plus a loop cycle for shimmer/spinner animations.
QtObject {
    readonly property int fast: 120
    readonly property int base: 140
    readonly property int slow: 240
    readonly property int loop: 1000

    readonly property int easeOut: Easing.OutCubic
    readonly property int easeInOut: Easing.InOutCubic
    readonly property int linear: Easing.Linear
}
