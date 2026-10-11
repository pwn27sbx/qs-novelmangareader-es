pragma Singleton
import QtQuick
import Quickshell.Io
import qs.colors

// Structural style tokens for the standalone reader shell.
//
// Mirrored 1:1 from Omarchy's `Commons/Style.qml` so the app shares the
// desktop's metric language without importing Omarchy: the corner radius
// mirrors Hyprland's `decoration:rounding`, the edge gap is half of
// `general:gaps_out`, and the spacing / typography scales and the interactive
// state affordances are the shell's. The palette roles come from the app's own
// Material You singleton (`qs.colors`); no Omarchy `Color`/`Util` is pulled in.
//
// Golden rule: surfaces use `Style.cornerRadius`, every gap uses
// `Style.spacing.*` (or `Style.space(n)`), and every control paints its
// normal/hover/selected/focus state from the `*FillFor` / `*BorderFor`
// helpers. No raw radius or spacing number in a view.
QtObject {
    id: root

    // ------------------------------------------------------ live Hyprland
    //
    // Read straight from `hyprctl` at startup; both are re-readable through
    // `refresh()`. Values are the compositor's, so the app never hardcodes a
    // radius that would drift from the windows around it.
    property int cornerRadius: 0
    property int gapsOut: 0

    function applyRoundingJson(raw) {
        try {
            var n = Number(JSON.parse(raw || "{}").int)
            if (isFinite(n) && n >= 0) cornerRadius = n
        } catch (e) {
            // hyprctl missing / Hyprland not running — keep the previous value.
        }
    }

    function applyGapsOutJson(raw) {
        try {
            var json = JSON.parse(raw || "{}")
            var parts = String(json.css || "").match(/-?\d+(?:\.\d+)?/g) || []
            var n = parts.length > 0 ? Number(parts[0]) : Number(json.int)
            if (isFinite(n) && n >= 0) gapsOut = Math.max(0, Math.round(n / 2))
        } catch (e) {
            // hyprctl missing — keep the previous value.
        }
    }

    function refresh() {
        roundingProc.running = true
        gapsOutProc.running = true
    }

    property Process roundingProc: Process {
        command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyRoundingJson(text)
        }
    }

    property Process gapsOutProc: Process {
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyGapsOutJson(text)
        }
    }

    Component.onCompleted: refresh()

    // ------------------------------------------------------------- palette
    //
    // Roles resolved against the app's Material You palette (same names the
    // shell uses) so state helpers below stay palette-agnostic.
    readonly property color foreground: Colors.text
    readonly property color accent: Colors.primary
    readonly property color urgent: Colors.error
    readonly property color background: Colors.background

    function alpha(c, a) {
        return Colors.withAlpha(c === undefined || c === null ? foreground : c, a)
    }

    // ------------------------------------------------------------- states
    //
    // Shared interactive-state afforances: one fill alpha, one border alpha and
    // one border width per state, so every control behaves the same.
    readonly property real normalFillAlpha: 0.04
    readonly property real hoverFillAlpha: 0.08
    readonly property real selectedFillAlpha: 0.18
    readonly property real pressedFillAlpha: 0.22
    readonly property real focusFillAlpha: hoverFillAlpha
    readonly property real selectionFillAlpha: 0.35

    readonly property real normalBorderAlpha: 0.4
    readonly property real hoverBorderAlpha: 0.25
    readonly property real selectedBorderAlpha: 1.0
    readonly property real focusBorderAlpha: hoverBorderAlpha

    readonly property int normalBorderWidth: 1
    readonly property int hoverBorderWidth: 1
    readonly property int selectedBorderWidth: 0
    readonly property int focusBorderWidth: 1

    function normalFillFor(c) { return alpha(c, normalFillAlpha) }
    function hoverFillFor(c) { return alpha(c, hoverFillAlpha) }
    function selectedFillFor(c) { return alpha(c, selectedFillAlpha) }
    function pressedFillFor(c) { return alpha(c, pressedFillAlpha) }
    function focusFillFor(c) { return alpha(c, focusFillAlpha) }
    function selectionFillFor(c) { return alpha(c, selectionFillAlpha) }

    function normalBorderFor(c) { return alpha(c, normalBorderAlpha) }
    function hoverBorderFor(c) { return alpha(c, hoverBorderAlpha) }
    function selectedBorderFor(c) { return alpha(c, selectedBorderAlpha) }
    function focusBorderFor(c) { return alpha(c, focusBorderAlpha) }

    // Focus > hover > normal ladder for a form-control surface.
    function controlFill(focused, hot, c) {
        if (focused) return focusFillFor(c)
        if (hot) return hoverFillFor(c)
        return normalFillFor(c)
    }

    function controlBorder(focused, hot, c) {
        if (focused) return focusBorderFor(c)
        if (hot) return hoverBorderFor(c)
        return normalBorderFor(c)
    }

    function controlBorderWidth(focused, hot) {
        if (focused) return focusBorderWidth
        if (hot) return hoverBorderWidth
        return normalBorderWidth
    }

    readonly property color normalFill: normalFillFor(foreground)
    readonly property color hoverFill: hoverFillFor(foreground)
    readonly property color selectedFill: selectedFillFor(foreground)
    readonly property color pressedFill: pressedFillFor(foreground)
    readonly property color focusFillColor: focusFillFor(foreground)
    readonly property color selectionFill: selectionFillFor(foreground)
    readonly property color selectedAccentFill: alpha(accent, selectedFillAlpha)
    readonly property color normalBorderColor: normalBorderFor(foreground)
    readonly property color hoverBorderColor: hoverBorderFor(foreground)
    readonly property color selectedBorderColor: selectedBorderFor(foreground)
    readonly property color focusBorderColor: focusBorderFor(foreground)

    // ------------------------------------------------------------ spacing
    //
    // The shell's spacing scale: the shell equivalent of rem for margins, gaps
    // and padding. `space(px)` rounds a one-off pixel value onto the scale.
    function space(px) {
        var n = Number(px)
        if (!isFinite(n) || n <= 0) return 0
        return Math.max(1, Math.round(n))
    }

    readonly property QtObject spacing: QtObject {
        readonly property int hairline: 1
        readonly property int xxs: 2
        readonly property int xs: 3
        readonly property int sm: 4
        readonly property int md: 6
        readonly property int lg: 8
        readonly property int xl: 10
        readonly property int xxl: 12
        readonly property int xxxl: 14
        readonly property int huge: 18

        readonly property int controlGap: 8
        readonly property int controlPaddingX: 10
        readonly property int controlPaddingY: 6
        readonly property int controlHeight: 28

        readonly property int rowGap: 8
        readonly property int rowPaddingX: 12
        readonly property int panelGap: 14
        readonly property int panelPadding: 18
        readonly property int popupPadding: 14
    }

    // --------------------------------------------------------- typography
    //
    // Same scale as the shell (base 12). `family` is the UI face; the display
    // face is kept as its own token so headers can keep the serif accent
    // without a per-file family literal.
    property string fontFamily: "Noto Sans"
    property string displayFontFamily: "Noto Serif"

    readonly property QtObject font: QtObject {
        readonly property string family: root.fontFamily
        readonly property string displayFamily: root.displayFontFamily

        readonly property int caption: 10
        readonly property int bodySmall: 11
        readonly property int body: 12
        readonly property int subtitle: 13
        readonly property int title: 14
        readonly property int heading: 16
        readonly property int display: 24
        readonly property int displayLarge: 28

        readonly property int iconSmall: 11
        readonly property int icon: 14
        readonly property int iconLarge: 18
    }

    // ------------------------------------------------------------- motion
    //
    // One duration per intent, mirroring the shell's QML timing (120 for
    // color/state fades, 140 for OutCubic movement, 240 for larger surfaces)
    // plus a loop cycle for shimmer/spinner animations.
    readonly property QtObject motion: QtObject {
        readonly property int fast: 120
        readonly property int base: 140
        readonly property int slow: 240
        readonly property int loop: 1000

        readonly property int easeOut: Easing.OutCubic
        readonly property int easeInOut: Easing.InOutCubic
        readonly property int linear: Easing.Linear
    }
}
