pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.app

// Placeholder poster grid shown while a cover grid's first page loads. Lays
// out like the real grid (same columns, card ratio and inset) so the covers
// land where the ghosts were, and ripples in a diagonal wave. Fades out once
// `active` drops.
Rectangle {
    id: root

    property bool active: false
    property int columns: 4
    // Cell height / cell width, as the real grid's cellHeight.
    property real ratio: 1.58
    property real padding: Style.spacing.xl
    property real cellWidth: (width - padding * 2) / columns
    // Height of an extra bottom strip (the library's progress row).
    property int footerHeight: 0

    readonly property real _cellHeight: cellWidth * ratio
    readonly property int _rows: _cellHeight > 0
        ? Math.ceil((height - padding) / _cellHeight) : 0

    color: Colors.background
    clip: true
    opacity: root.active ? 1 : 0
    visible: root.opacity > 0
    Behavior on opacity { NumberAnimation { duration: Motion.slow; easing.type: Motion.easeOut } }

    Grid {
        x: root.padding
        y: root.padding
        columns: root.columns

        Repeater {
            model: root.visible ? root._rows * root.columns : 0

            delegate: Item {
                id: cell
                required property int index
                readonly property int col: index % root.columns
                readonly property int row: Math.floor(index / root.columns)

                width: root.cellWidth
                height: root._cellHeight

                Rectangle {
                    id: card
                    anchors { fill: parent; margins: Style.space(5) }
                    radius: Style.cornerRadius
                    color: Colors.surface_container

                    // Cover
                    Rectangle {
                        anchors {
                            top: parent.top; left: parent.left; right: parent.right
                            bottom: lines.top; bottomMargin: Style.spacing.xl
                        }
                        radius: card.radius
                        color: Colors.surface_container_high
                    }

                    // Title
                    Column {
                        id: lines
                        anchors {
                            left: parent.left; right: parent.right
                            bottom: parent.bottom
                            leftMargin: Style.spacing.xl; rightMargin: Style.spacing.xl
                            bottomMargin: Style.spacing.xl + root.footerHeight
                        }
                        spacing: Style.spacing.md

                        Rectangle {
                            width: parent.width * (cell.index % 3 === 1 ? 0.9 : 0.75)
                            height: 7; radius: height / 2 // style-ignore — skeleton
                            color: Colors.surface_container_highest
                        }
                        Rectangle {
                            width: parent.width * (cell.index % 2 ? 0.4 : 0.55)
                            height: 7; radius: height / 2 // style-ignore — skeleton
                            color: Colors.surface_container_highest
                        }
                    }

                    // Progress row
                    Rectangle {
                        visible: root.footerHeight > 0
                        anchors {
                            left: parent.left; right: parent.right
                            bottom: parent.bottom
                            leftMargin: Style.spacing.xl; rightMargin: Style.spacing.xl
                            bottomMargin: (root.footerHeight - height) / 2
                        }
                        height: 3; radius: height / 2 // style-ignore — line
                        color: Colors.surface_container_highest
                    }
                }

                SkeletonPulse {
                    target: card
                    delay: (cell.col + cell.row) * 110
                    running: root.visible
                }
            }
        }
    }
}
