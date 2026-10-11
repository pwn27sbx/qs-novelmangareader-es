import QtQuick
import qs.Commons

// In the rice, desktop themes draw their ornaments over a panel here. The
// standalone packages have no themes, so this keeps the API and draws nothing.
Item {
    property real radius: Style.cornerRadius
    property string title: ""
    property string seal: ""

    visible: false
}
