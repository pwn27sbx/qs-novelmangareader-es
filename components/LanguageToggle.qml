import QtQuick
import qs.colors
import qs.services

// Small EN/ES UI-language toggle shown in the panel bars. It switches the
// language live (I18n.setLanguage) and persists the choice to settings.json.
Rectangle {
    id: root

    implicitWidth: 34
    implicitHeight: 24
    radius: 12
    color: area.containsMouse ? Colors.surface_container_high : Colors.surface_container
    border.color: Colors.outline_variant
    border.width: 1

    StyledText {
        anchors.centerIn: parent
        text: I18n.lang === "es" ? "ES" : "EN" // i18n-ignore — language code chip
        font.pixelSize: 9; font.bold: true; font.letterSpacing: 1
        color: Colors.on_surface_variant
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: I18n.toggleLanguage()
    }
}
