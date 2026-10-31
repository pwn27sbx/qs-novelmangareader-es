import QtQuick
import qs.app
import qs.Commons
import qs.Ui

// One segment of the grid/list toggle. Both manga views used to inline this
// block; one file means a change to the fill, the glyph or the tooltip lands
// once instead of drifting between Browse and Library.
ClickableRect {
    id: chip

    property string glyph: ""
    property string label: ""
    property bool current: false
    property string bodyFont: ""

    implicitWidth: Style.spacing.controlHeight
    implicitHeight: Style.spacing.controlHeight
    cursorShape: Qt.PointingHandCursor
    color: chip.pressed ? Style.pressedFillFor(Colors.text, Colors.primary)
        : chip.current ? Style.selectedFillFor(Colors.text, Colors.primary)
        : "transparent"
    border.color: chip.hovered ? Style.hoverBorderFor(Colors.text, Colors.primary) : "transparent"
    border.width: chip.hovered ? 1 : 0

    StyledText {
        anchors.centerIn: parent
        text: chip.glyph
        font.family: chip.bodyFont
        font.pixelSize: Style.font.body
        color: chip.current ? Style.selectedStateColor(Colors.text, Colors.primary) : Colors.muted
    }

    PanelToolTip {
        visible: chip.hovered
        text: chip.label
        fontFamily: chip.bodyFont
    }
}
