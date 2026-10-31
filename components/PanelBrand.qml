import QtQuick
import qs.app
import qs.Commons

// The panel's brand: the app glyph plus this panel's short name.
//
// Injected into the shared PanelHeader as a Component, so the three readers do
// not carry three copies of the same row — a styling or glyph change lands here
// once instead of drifting across three files.
Row {
    id: root

    property string title: ""
    property string fontFamily: Style.font.family

    spacing: Style.spacing.sm

    MaterialIcon {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰂺"
        font.pixelSize: Style.font.icon
        color: Colors.primary
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Colors.on_surface
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
    }
}
