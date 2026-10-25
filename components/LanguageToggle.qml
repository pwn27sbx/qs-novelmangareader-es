import QtQuick
import qs.app
import qs.services
import qs.Commons
import qs.Ui

// Small EN/ES UI-language chip shown in the panel headers. It switches the
// language live (I18n.setLanguage) and persists the choice to settings.json.
//
// It is a chip, not a button: no border, no box — only the hover tint from
// the shared state tokens (plan R2 §2.1).
Button {
    id: root

    objectName: "languageToggle"

    text: I18n.lang === "es" ? "ES" : "EN" // i18n-ignore — language code chip
    bordered: false
    foreground: Colors.muted
    fontFamily: Style.font.family
    fontSize: Style.font.caption
    horizontalPadding: Style.spacing.lg
    verticalPadding: Style.spacing.md
    onClicked: I18n.toggleLanguage()
}
