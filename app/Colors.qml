pragma Singleton
import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons

// App palette adapter.
//
// The views were written against Material You role names (`primary`,
// `surface_container`, `outline_variant`, …). Omarchy's `Color` only exposes
// the foundational theme palette (`foreground`/`background`/`accent`/`urgent`/
// `muted`), so this single file maps every legacy role onto it, blending solid
// surfaces out of `background` and `foreground`. Naming the roles here keeps
// the views unchanged and gives one place to retune when the theme or the
// mapping changes; as the views move onto `qs.Ui` (R2–R4) they will read
// `Commons.Color` directly.
//
// Qt 6.12 ships a `Color` value type, so `Color` on its own resolves to that
// value type and every read here comes back `undefined` — no error, just an
// invisible UI. The import alias makes the read unambiguous.
QtObject {
    id: root

    // Blend `a` toward `b` by `t` (0..1) and return an opaque color.
    //
    // A binding that throws is dropped for good: once `mix` raised on a
    // not-yet-loaded input, the role stayed dead for the rest of the session
    // instead of picking the theme up. Return an empty colour so the binding
    // survives and re-evaluates when the theme arrives.
    function mix(a, b, t) {
        if (!a || !b)
            return Qt.rgba(0, 0, 0, 0)
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
    readonly property color background: Commons.Color.background
    readonly property color bg: Commons.Color.background
    readonly property color on_background: Commons.Color.foreground
    readonly property color on_surface: Commons.Color.foreground
    readonly property color text: Commons.Color.foreground
    readonly property color on_surface_variant: Commons.Color.muted
    readonly property color muted: Commons.Color.muted
    readonly property color inverse_surface: Commons.Color.foreground
    readonly property color inverse_on_surface: Commons.Color.background
    readonly property color scrim: "#000000"
    readonly property color shadow: "#000000"

    // ------------------------------------------------------------- surfaces
    readonly property color surface: Commons.Color.background
    readonly property color surface_dim: Commons.Color.background
    readonly property color surface_bright: mix(Commons.Color.background, Commons.Color.foreground, 0.12)
    readonly property color surface_variant: mix(Commons.Color.background, Commons.Color.foreground, 0.08)
    readonly property color surface_tint: Commons.Color.accent
    readonly property color surface_container_lowest: mix(Commons.Color.background, Commons.Color.foreground, 0.02)
    readonly property color surface_container_low: mix(Commons.Color.background, Commons.Color.foreground, 0.03)
    readonly property color surface_container: mix(Commons.Color.background, Commons.Color.foreground, 0.05)
    readonly property color surface_container_high: mix(Commons.Color.background, Commons.Color.foreground, 0.08)
    readonly property color surface_container_highest: mix(Commons.Color.background, Commons.Color.foreground, 0.11)
    readonly property color surfaceHigh: mix(Commons.Color.background, Commons.Color.foreground, 0.08)

    // ------------------------------------------------------------- outlines
    readonly property color outline: Util.alpha(Commons.Color.foreground, 0.5)
    readonly property color outline_variant: Util.alpha(Commons.Color.foreground, 0.15)

    // ------------------------------------------------------------- primary
    readonly property color primary: Commons.Color.accent
    readonly property color accent: Commons.Color.accent
    readonly property color on_primary: Commons.Color.background
    readonly property color onAccent: Commons.Color.background
    readonly property color primary_container: mix(Commons.Color.background, Commons.Color.accent, 0.22)
    readonly property color on_primary_container: Commons.Color.foreground
    readonly property color primary_fixed: Commons.Color.accent
    readonly property color primary_fixed_dim: Commons.Color.accent
    readonly property color on_primary_fixed: Commons.Color.background
    readonly property color on_primary_fixed_variant: mix(Commons.Color.background, Commons.Color.accent, 0.5)
    readonly property color inverse_primary: Commons.Color.accent

    // ------------------------------------------------------------ secondary
    readonly property color secondary: Commons.Color.muted
    readonly property color on_secondary: Commons.Color.background
    readonly property color secondary_container: mix(Commons.Color.background, Commons.Color.foreground, 0.08)
    readonly property color on_secondary_container: Commons.Color.foreground
    readonly property color secondary_fixed: Commons.Color.muted
    readonly property color secondary_fixed_dim: Commons.Color.muted
    readonly property color on_secondary_fixed: Commons.Color.background
    readonly property color on_secondary_fixed_variant: mix(Commons.Color.background, Commons.Color.foreground, 0.4)

    // ------------------------------------------------------------- tertiary
    readonly property color tertiary: Commons.Color.accent
    readonly property color on_tertiary: Commons.Color.background
    readonly property color tertiary_container: mix(Commons.Color.background, Commons.Color.accent, 0.22)
    readonly property color on_tertiary_container: Commons.Color.foreground
    readonly property color tertiary_fixed: Commons.Color.accent
    readonly property color tertiary_fixed_dim: Commons.Color.accent
    readonly property color on_tertiary_fixed: Commons.Color.background
    readonly property color on_tertiary_fixed_variant: mix(Commons.Color.background, Commons.Color.accent, 0.5)

    // ---------------------------------------------------------------- error
    readonly property color error: Commons.Color.urgent
    readonly property color on_error: Commons.Color.background
    readonly property color error_container: mix(Commons.Color.background, Commons.Color.urgent, 0.25)
    readonly property color on_error_container: Commons.Color.foreground

    readonly property color source_color: Commons.Color.accent
}
