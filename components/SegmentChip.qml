import QtQuick
import qs.app
import qs.Commons

// Segmented chip, copied from the Mini Cider plugin's tabs so the panel tabs,
// the SUB/DUB toggle and the filter rows all speak one language: active is an
// accent-tinted fill with an accent border and accent text; inactive is a
// subtle foreground fill with a faint foreground border and plain text.
// Sized comfortably (36px) with the body font size.
Rectangle {
    id: root

    property string text: ""
    property bool active: false
    property string fontFamily: Style.font.family

    signal clicked()

    implicitWidth: label.implicitWidth + Style.spacing.xxxl * 2
    implicitHeight: Math.max(Style.space(36), label.implicitHeight + Style.spacing.md * 2)
    width: implicitWidth
    height: implicitHeight

    radius: Style.cornerRadius
    border.width: 1
    color: root.active ? Util.alpha(Color.accent, 0.15) : Util.alpha(Color.foreground, 0.05)
    border.color: root.active ? Color.accent : Util.alpha(Color.foreground, 0.1)
    Behavior on color { ColorAnimation { duration: Motion.base } }
    Behavior on border.color { ColorAnimation { duration: Motion.base } }

    Text {
        id: label
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.text
        color: root.active ? Color.accent : Color.foreground
        opacity: root.active ? 1.0 : 0.5
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: root.active
        Behavior on color { ColorAnimation { duration: Motion.base } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
