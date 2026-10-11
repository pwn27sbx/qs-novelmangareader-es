pragma ComponentBehavior: Bound

import QtQuick
import qs.colors
import qs.Commons

// Placeholder rows for a chapter / episode list while it's fetched: a number
// pill and a title (plus a subtitle line when `subtitle` is set), rippling
// top to bottom. Row height and divider inset match the real list. Fades out
// once `active` drops.
Rectangle {
    id: root

    property bool active: false
    property int rowHeight: 58
    property bool subtitle: true
    property int dividerInset: 72

    color: Colors.background
    clip: true
    opacity: root.active ? 1 : 0
    visible: root.opacity > 0
    Behavior on opacity { NumberAnimation { duration: Style.motion.slow; easing.type: Style.motion.easeOut } }

    Column {
        anchors { left: parent.left; right: parent.right }

        Repeater {
            model: root.visible ? Math.ceil(root.height / root.rowHeight) : 0

            delegate: Item {
                id: row
                required property int index

                width: parent.width
                height: root.rowHeight

                Item {
                    id: content
                    anchors { fill: parent; leftMargin: Style.space(16); rightMargin: Style.space(16) }

                    Rectangle {
                        id: pill
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 26; radius: height / 2
                        color: Colors.surface_container_high
                    }

                    Column {
                        anchors {
                            left: pill.right; leftMargin: Style.spacing.xxxl
                            right: parent.right; rightMargin: Style.space(24)
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Style.space(7)

                        Rectangle {
                            // Varied so the rows don't read as a barcode.
                            width: parent.width * [0.62, 0.48, 0.7, 0.55, 0.4][row.index % 5]
                            height: 9; radius: height / 2
                            color: Colors.surface_container_high
                        }
                        Rectangle {
                            visible: root.subtitle
                            width: 64; height: 7; radius: height / 2
                            color: Colors.surface_container
                        }
                    }
                }

                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left; right: parent.right
                        leftMargin: root.dividerInset; rightMargin: Style.space(16)
                    }
                    height: 1; color: Colors.outline_variant; opacity: 0.2
                }

                SkeletonPulse {
                    target: content
                    delay: row.index * 90
                    running: root.visible
                }
            }
        }
    }
}
