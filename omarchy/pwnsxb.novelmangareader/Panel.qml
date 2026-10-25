import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One bar icon that opens a small menu: Anime / Manga / Novelas. Each entry
// runs `qs-novelmangareader <key>`, which toggles the matching reader panel
// (the wrapper talks to the app over IPC).
//
// The rows are qs.Ui Buttons (icon + left-aligned label, shared hover/selected
// states) inside the kit's KeyboardPanel, so the popup reads like the rest of
// Omarchy instead of a hand-drawn column.
Panel {
  id: root
  moduleName: "pwnsxb.novelmangareader"
  ipcTarget: "pwnsxb.novelmangareader"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Glyphs are Material Design Icons (Nerd Font). Swap freely.
  readonly property var entries: [
    { key: "anime", label: "Anime",   icon: "󰿊" },
    { key: "manga", label: "Manga",   icon: "󰃶" },
    { key: "novel", label: "Novelas", icon: "󰗚" }
  ]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function launch(key) {
    opener.command = ["qs-novelmangareader", key]
    opener.running = true
    root.close()
  }

  Process {
    id: opener
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰂺"
    tooltipText: "Reader — Anime / Manga / Novelas"
    onPressed: function(code) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(240))
    contentHeight: panel.fittedContentHeight(menu.implicitHeight)

    Column {
      id: menu
      width: parent.width
      spacing: Style.spacing.sm

      PanelSectionHeader {
        width: parent.width
        text: "Reader"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.entries

        delegate: Button {
          required property var modelData

          width: menu.width
          leftAlign: true
          bordered: true
          iconText: modelData.icon
          text: modelData.label
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.launch(modelData.key)
        }
      }
    }
  }
}
