import QtQuick
import QtQuick.Layouts
import qs.app
import qs.services
import qs.Commons
import qs.components
import qs.Ui

// In-panel settings view, opened from the gear in the header.
//
// It is a view, not a popup: `qs.Ui.PopupCard` and `KeyboardPanel` both require
// a `bar` item and compute their geometry from it, and these panels are
// layer-shell surfaces with no bar. Omarchy's own plugins show settings the
// same way (a sibling page plus a back button).
//
// Everything here is live: the slider writes `scrollFactor`, which the readers'
// wheel handlers read; the toggle writes `language`, which I18n reads.
Item {
    id: root

    // The anime panel has no reader, so the scroll row makes no sense there.
    property bool showScroll: true
    // The panels do not hand focus to this view, and Esc needs a focused item.
    property bool active: false

    signal closeRequested()

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.active
        Keys.onEscapePressed: root.closeRequested()
    }

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: Style.spacing.md
            rightMargin: Style.spacing.md
            topMargin: Style.spacing.md
            bottomMargin: Style.spacing.md
        }
        spacing: Style.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.md

            PanelActionButton {
                iconText: "󰁍"
                tooltipText: I18n.t("settings.back")
                focusable: true
                onClicked: root.closeRequested()
            }

            StyledText {
                Layout.fillWidth: true
                text: I18n.t("settings.title")
                color: Colors.text
                font.pixelSize: Style.font.heading
                font.bold: true
            }
        }

        PanelSeparator { Layout.fillWidth: true }

        // ── Scroll speed (readers only) ────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.sm
            visible: root.showScroll

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: I18n.t("settings.scroll")
                    color: Colors.text
                    font.pixelSize: Style.font.body
                }

                StyledText {
                    // PanelSlider does not update `value` while dragging, only
                    // `liveValue`, so the readout follows that one.
                    text: String(Math.round(scroll.liveValue))
                    color: Colors.primary
                    font.pixelSize: Style.font.body
                }
            }

            PanelSlider {
                id: scroll
                Layout.fillWidth: true
                minimum: UiPrefs.scrollFactorMin
                maximum: UiPrefs.scrollFactorMax
                step: 1
                integer: true
                value: UiPrefs.scrollFactor
                // `bar` is null inside a panel: pass the theme tokens, or the
                // component falls back to a hardcoded dark track.
                trackColor: Colors.surface_container_high
                fillColor: Colors.primary
                knobColor: Colors.text
                onReleased: function(value) { UiPrefs.setScrollFactor(value) }
            }

            StyledText {
                Layout.fillWidth: true
                text: I18n.t("settings.scrollHint")
                color: Colors.muted
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
            }
        }

        PanelSeparator { Layout.fillWidth: true; visible: root.showScroll }

        // ── UI language ────────────────────────────────────────────────────
        Toggle {
            Layout.fillWidth: true
            label: I18n.t("settings.language")
            description: I18n.pinnedByEnv ? I18n.t("settings.languagePinned") : I18n.t("settings.languageHint")
            checked: I18n.lang === "es"
            // QS_LANG wins over the file, so the row would look broken.
            enabled: !I18n.pinnedByEnv
            opacity: enabled ? 1 : 0.6
            onClicked: I18n.setLanguage(checked ? "en" : "es")
        }

        Item { Layout.fillHeight: true }
    }
}
