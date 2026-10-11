import QtQuick
import qs.Commons
import qs.app

// The breathing used by the skeleton placeholders: fades `target` down and
// back up forever, starting after `delay` so neighbouring blocks ripple as a
// wave instead of blinking together. The loop sits inside the pause so each
// block keeps its offset.
SequentialAnimation {
    id: root

    property Item target
    property int delay: 0
    property real low: 0.4
    property int period: Motion.loop

    loops: 1

    PauseAnimation { duration: root.delay }
    SequentialAnimation {
        loops: Animation.Infinite
        NumberAnimation {
            target: root.target; property: "opacity"
            to: root.low; duration: root.period / 2
            easing.type: Motion.easeInOut
        }
        NumberAnimation {
            target: root.target; property: "opacity"
            to: 1; duration: root.period / 2
            easing.type: Motion.easeInOut
        }
    }

    onStopped: if (root.target) root.target.opacity = 1
}
