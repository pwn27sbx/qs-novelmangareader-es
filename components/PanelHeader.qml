import QtQuick
import qs.app
import qs.services
import qs.Commons
import qs.Ui

// One header row shared by the three panels (plan R2 §2.1).
//
// Far left: the optional panel brand (`brand`, a Component); the tabs follow
// it and shift right when it is present. Absent on callers that do not pass
// one, which keeps their header exactly as it was.
// Left: the Browse / Library tabs as tinted text — the active one carries the
// selected fill, the other is muted, and neither has a border or a box.
// Right: search, the optional SUB/DUB pair, the EN/ES chip and minimize, all
// on the same baseline, with the free space in the middle.
//
// The search field itself belongs to each panel (it owns the debounce and the
// backend call), so it is placed in the `overlay` slot: it covers the tabs
// while the search is open and never overlaps the actions.
Item {
    id: root

    property var tabs: []
    // Counters for the tabs above, one entry per tab. A `-1` (or a missing
    // entry) means "no counter". Kept parallel and separate on purpose: `tabs`
    // stays a string[], so the delegates keep rendering `String(modelData)`
    // instead of `[object Object]`.
    property var tabCounts: []
    // Short panel name + glyph, supplied by the panel (Component). `null` here
    // is the default, so a caller without a brand is untouched.
    property Component brand: null
    property int tabIndex: 0
    property bool showSearch: true
    property bool searchOpen: false
    property bool showMode: false
    // While the settings view is open the content controls step aside: search,
    // SUB/DUB and the module action belong to the list, not to settings.
    property bool settingsMode: false
    property string mode: ""
    // Module-specific action (the novel panel's provider dropdown), placed
    // between the SUB/DUB pair and the language chip.
    property Component extraAction: null
    property string fontFamily: Style.font.family

    // Items declared as children land here (the panel's search field).
    default property alias overlay: slot.data

    signal tabActivated(int index)
    signal searchClicked()
    signal settingsClicked()
    signal modeSelected(string value)
    signal minimizeClicked()

    implicitHeight: Style.space(48)
    implicitWidth: parent ? parent.width : 0

    // The brand is part of the tab row: it disappears with it while the
    // search field covers the left region.
    readonly property bool showBrand: root.brand !== null && !root.searchOpen

    Rectangle {
        anchors.fill: parent
        color: Colors.surface_container_low
    }

    // Brand block. An inactive Loader has no width, so the tabs fall back to
    // their original left margin when no brand is loaded.
    Loader {
        id: brandLoader
        anchors {
            left: parent.left
            leftMargin: Style.spacing.md
            verticalCenter: parent.verticalCenter
        }
        active: root.showBrand
        sourceComponent: root.brand
    }

    Row {
        id: tabsRow
        visible: !root.searchOpen
        anchors {
            left: brandLoader.active ? brandLoader.right : parent.left
            leftMargin: Style.spacing.md
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.spacing.md

        Repeater {
            model: root.tabs

            delegate: Button {
                required property var modelData
                required property int index

                readonly property bool active: index === root.tabIndex
                // -1 / missing entry: this tab carries no counter.
                readonly property int count: {
                    var counts = root.tabCounts
                    if (!counts || index >= counts.length)
                        return -1
                    var value = Number(counts[index])
                    return isFinite(value) ? value : -1
                }

                text: count >= 0 ? String(modelData) + " · " + count : String(modelData)
                bordered: false
                selected: active
                foreground: active ? Colors.text : Colors.muted
                fontFamily: root.fontFamily
                fontSize: Style.font.body
                onClicked: root.tabActivated(index)
            }
        }
    }

    Item {
        id: slot
        anchors {
            left: parent.left
            right: actionsRow.left
            top: parent.top
            bottom: parent.bottom
        }
    }

    Row {
        id: actionsRow
        anchors {
            right: parent.right
            rightMargin: Style.spacing.md
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.spacing.controlGap

        PanelActionButton {
            visible: !root.settingsMode && root.showSearch && root.tabIndex === 0
            iconText: "⌕"
            hasCursor: root.searchOpen
            size: Style.space(36)
            fontSize: Style.font.iconLarge
            onClicked: root.searchClicked()
        }

        Row {
            visible: !root.settingsMode && root.showMode && root.tabIndex === 0
            spacing: Style.spacing.xs

            Repeater {
                model: ["sub", "dub"]

                delegate: Button {
                    required property string modelData

                    readonly property bool active: modelData === root.mode

                    text: modelData.toUpperCase()
                    bordered: false
                    selected: active
                    foreground: active ? Colors.text : Colors.muted
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    horizontalPadding: Style.spacing.lg
                    onClicked: root.modeSelected(modelData)
                }
            }
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.settingsMode && root.extraAction !== null && root.tabIndex === 0 && !root.searchOpen
            sourceComponent: root.extraAction
        }

        LanguageToggle {
            visible: !root.settingsMode
            anchors.verticalCenter: parent.verticalCenter
        }

        PanelActionButton {
            iconText: "󰒓"
            tooltipText: I18n.t("settings.open")
            focusable: true
            hasCursor: root.settingsMode
            size: Style.space(36)
            onClicked: root.settingsClicked()
        }

        PanelActionButton {
            iconText: "─"
            size: Style.space(36)
            onClicked: root.minimizeClicked()
        }
    }
}
