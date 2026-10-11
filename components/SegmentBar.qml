import QtQuick
import qs.app
import qs.Commons

// A single joined segmented control: one rounded outline, segments touching
// edge to edge (no gap), thin separators between them, and the Mini Cider
// tint on the active segment. Shared by the panel tabs and the SUB/DUB toggle
// so they match the filter bar.
//
// `options` is either ["a", "b"] or [{ value, label }, ...]. `upper` renders
// the label uppercase (for code-like segments such as SUB/DUB).
Item {
    id: root

    property var options: []
    property string value: ""
    property bool upper: false
    property string fontFamily: Style.font.family
    property real segmentPadding: Style.spacing.xxl

    signal activated(string value)

    function optValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
    function optLabel(o) {
        var s = (o && typeof o === "object") ? String(o.label) : String(o)
        return root.upper ? s.toUpperCase() : s
    }

    implicitWidth: bar.width
    implicitHeight: bar.height
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: bar
        width: segRow.width + Style.spacing.hairline * 2
        height: Style.space(36)
        radius: Style.cornerRadius
        color: Util.alpha(Color.foreground, 0.05)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.1)

        Row {
            id: segRow
            x: Style.spacing.hairline
            y: Style.spacing.hairline
            width: implicitWidth
            height: bar.height - Style.spacing.hairline * 2
            spacing: Style.space(0)

            Repeater {
                id: segRep
                model: root.options

                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool active: root.optValue(modelData) === root.value

                    implicitWidth: segLabel.implicitWidth + root.segmentPadding * 2
                    width: implicitWidth
                    height: segRow.height

                    Rectangle {
                        anchors.fill: parent
                        color: active ? Util.alpha(Color.accent, 0.15) : "transparent"
                        topLeftRadius: index === 0 ? Style.cornerRadius : 0
                        bottomLeftRadius: index === 0 ? Style.cornerRadius : 0
                        topRightRadius: index === segRep.count - 1 ? Style.cornerRadius : 0
                        bottomRightRadius: index === segRep.count - 1 ? Style.cornerRadius : 0
                    }

                    Rectangle {
                        visible: index > 0
                        width: Style.spacing.hairline
                        height: parent.height
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        color: Util.alpha(Color.foreground, 0.1)
                    }

                    Text {
                        id: segLabel
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: root.optLabel(modelData)
                        color: active ? Color.accent : Color.foreground
                        opacity: active ? 1.0 : 0.5
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: active
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activated(root.optValue(modelData))
                    }
                }
            }
        }
    }
}
