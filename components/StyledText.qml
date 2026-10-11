import QtQuick
import qs.app
import qs.Commons

// Base text element for the shell. The colour and family are defaulted; size
// stays whatever Text gives you. Set font.family to opt out.
Text {
    color: Colors.on_surface
    font.family: Style.font.family
}
