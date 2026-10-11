pragma Singleton
import QtQuick
import Quickshell
import qs.Commons

// App palette adapter.
//
// The views were written against Material You role names (`primary`,
// `surface_container`, `outline_variant`, …). Omarchy's `Color` only exposes
// the foundational theme palette (`foreground`/`background`/`accent`/`urgent`/
// `muted`), so this single file maps every legacy role onto it, blending solid
// surfaces out of `background` and `foreground`. Naming the roles here keeps
// the views unchanged and gives one place to retune when the theme or the
// mapping changes; as the views move onto `qs.Ui` (R2–R4) they will read
// `Color` directly.
QtObject {
    id: root

    // Blend `a` toward `b` by `t` (0..1) and return an opaque color.
    function mix(a, b, t) {
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            1)
    }

    function withAlpha(base, a) {
        return Util.alpha(base, a)
    }

    // ---------------------------------------------------------- foundational
    readonly property color background: Color.background
    readonly property color bg: Color.background
    readonly property color on_background: Color.foreground
    readonly property color on_surface: Color.foreground
    readonly property color text: Color.foreground
    readonly property color on_surface_variant: Color.muted
    readonly property color inverse_surface: Color.foreground
    readonly property color inverse_on_surface: Color.background
    readonly property color scrim: "#000000"
    readonly property color shadow: "#000000"

    // ------------------------------------------------------------- surfaces
    readonly property color surface: Color.background
    readonly property color surface_dim: Color.background
    readonly property color surface_bright: mix(Color.background, Color.foreground, 0.12)
    readonly property color surface_variant: mix(Color.background, Color.foreground, 0.08)
    readonly property color surface_tint: Color.accent
    readonly property color surface_container_lowest: mix(Color.background, Color.foreground, 0.02)
    readonly property color surface_container_low: mix(Color.background, Color.foreground, 0.03)
    readonly property color surface_container: mix(Color.background, Color.foreground, 0.05)
    readonly property color surface_container_high: mix(Color.background, Color.foreground, 0.08)
    readonly property color surface_container_highest: mix(Color.background, Color.foreground, 0.11)
    readonly property color surfaceHigh: mix(Color.background, Color.foreground, 0.08)

    // ------------------------------------------------------------- outlines
    readonly property color outline: Util.alpha(Color.foreground, 0.5)
    readonly property color outline_variant: Util.alpha(Color.foreground, 0.15)

    // ------------------------------------------------------------- primary
    readonly property color primary: Color.accent
    readonly property color accent: Color.accent
    readonly property color on_primary: Color.background
    readonly property color onAccent: Color.background
    readonly property color primary_container: mix(Color.background, Color.accent, 0.22)
    readonly property color on_primary_container: Color.foreground
    readonly property color primary_fixed: Color.accent
    readonly property color primary_fixed_dim: Color.accent
    readonly property color on_primary_fixed: Color.background
    readonly property color on_primary_fixed_variant: mix(Color.background, Color.accent, 0.5)
    readonly property color inverse_primary: Color.accent

    // ------------------------------------------------------------ secondary
    readonly property color secondary: Color.muted
    readonly property color on_secondary: Color.background
    readonly property color secondary_container: mix(Color.background, Color.foreground, 0.08)
    readonly property color on_secondary_container: Color.foreground
    readonly property color secondary_fixed: Color.muted
    readonly property color secondary_fixed_dim: Color.muted
    readonly property color on_secondary_fixed: Color.background
    readonly property color on_secondary_fixed_variant: mix(Color.background, Color.foreground, 0.4)

    // ------------------------------------------------------------- tertiary
    readonly property color tertiary: Color.accent
    readonly property color on_tertiary: Color.background
    readonly property color tertiary_container: mix(Color.background, Color.accent, 0.22)
    readonly property color on_tertiary_container: Color.foreground
    readonly property color tertiary_fixed: Color.accent
    readonly property color tertiary_fixed_dim: Color.accent
    readonly property color on_tertiary_fixed: Color.background
    readonly property color on_tertiary_fixed_variant: mix(Color.background, Color.accent, 0.5)

    // ---------------------------------------------------------------- error
    readonly property color error: Color.urgent
    readonly property color on_error: Color.background
    readonly property color error_container: mix(Color.background, Color.urgent, 0.25)
    readonly property color on_error_container: Color.foreground

    readonly property color source_color: Color.accent
}
