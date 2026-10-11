import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// One bar icon that opens a small menu: Anime / Manga / Novelas. Each entry
// runs `qs-novelmangareader <key>`, which toggles the matching reader panel
// (the wrapper talks to the app over IPC).
Panel {
  id: root
  moduleName: "pwnsxb.novelmangareader"
  ipcTarget: "pwnsxb.novelmangareader"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Glyphs are Material Design Icons (Nerd Font). Swap freely.
  readonly property var entries: [
    { key: "anime", label: "Anime",   icon: "󰿊" },
    { key: "manga", label: "Manga",   icon: "󰃶" },
    { key: "novel", label: "Novelas", icon: "󰗚" }
  ]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

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
    onPressed: function(code) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(220)
    contentHeight: column.implicitHeight + Style.spacing.lg * 2

    Column {
      id: column
      anchors.fill: parent
      anchors.margins: Style.spacing.lg
      spacing: Style.spacing.sm

      Repeater {
        model: root.entries

        delegate: Rectangle {
          required property var modelData
          width: column.width
          height: Style.space(38)
          radius: Style.cornerRadius
          color: rowArea.containsMouse ? root.alpha(root.foreground, 0.08) : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: modelData.icon + "   " + modelData.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.launch(modelData.key)
          }
        }
      }
    }
  }
}
