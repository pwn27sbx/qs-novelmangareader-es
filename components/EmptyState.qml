import QtQuick
import qs.colors
import qs.Commons

// Centred "nothing here yet" placeholder: large glyph, headline, hint line.
Column {
    id: root

    property string glyph: "⊡"
    property string title: ""
    property string subtitle: ""
    property string displayFont: ""
    property string bodyFont: ""

    anchors.centerIn: parent
    spacing: Style.spacing.xxxl

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.glyph
        font.pixelSize: 44 // style-ignore — bespoke size
        color: Colors.outline
        opacity: 0.3
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.title
        font.family: root.displayFont
        font.pixelSize: 15 // style-ignore — bespoke size
        opacity: 0.45
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.subtitle
        font.family: root.bodyFont
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 0.2
        color: Colors.on_surface_variant
        opacity: 0.4
    }
}
