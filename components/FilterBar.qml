import QtQuick
import qs.app
import qs.Commons
import qs.Ui

// Horizontal filter chips shared by the three Browse views (plan R2 §2.2).
//
// The active chip is TINTED (`selected`, the Style selected fill) with the
// foreground text and carries a 1 px accent ring; the rest are muted and have
// no background and no border at all.
//
// `options` is a string[] or an array of { label } objects; `currentIndex`
// marks the active one and `activated(index)` reports a click. `label` is
// already localized by the caller, so a language toggle re-evaluates it.
//
// Chips that do not fit scroll horizontally instead of shrinking or wrapping;
// when they fit, the row does not move at all.
Item {
    id: root

    property var options: []
    property int currentIndex: -1
    property string fontFamily: Style.font.family

    signal activated(int index)

    implicitHeight: Style.space(48)

    function labelOf(option) {
        return (option && typeof option === "object") ? String(option.label) : String(option)
    }

    Flickable {
        id: scroller
        anchors {
            fill: parent
            leftMargin: Style.spacing.md
            rightMargin: Style.spacing.md
            topMargin: Style.spacing.sm
            bottomMargin: Style.spacing.sm
        }
        contentWidth: chips.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width

        Row {
            id: chips
            height: scroller.height
            spacing: Style.spacing.sm

            Repeater {
                model: root.options

                delegate: Button {
                    id: chip

                    required property var modelData
                    required property int index

                    readonly property bool current: index === root.currentIndex

                    text: root.labelOf(modelData)
                    bordered: false
                    selected: current
                    foreground: current ? Colors.text : Colors.muted
                    fontFamily: root.fontFamily
                    fontSize: Style.font.body
                    onClicked: root.activated(index)

                    // The ring of the active chip. It is drawn instead of
                    // assigned as `borderSpec` because Button derives that from
                    // its own state machine (hover, focus, selected); overriding
                    // it here would silently drop those borders. The ring is
                    // inside the reserved border space, so nothing relayouts.
                    Rectangle {
                        anchors.fill: parent
                        visible: chip.current
                        color: "transparent"
                        radius: chip.radius
                        border.width: Style.normalBorderWidth
                        border.color: Colors.primary
                    }
                }
            }
        }
    }
}
