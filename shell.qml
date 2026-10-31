import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.anime
import qs.modules.manga
import qs.modules.novel
import qs.app
import qs.components
import qs.services
import "services/panels.js" as Panels

// Anime player, manga reader and novel reader as side panels. Each one is
// loaded on its first toggle, kept while minimized, and unloaded shortly
// after it is closed:
//
//   qs-novelmangareader anime|manga|novel
// (bin/qs-novelmangareader; underneath, `qs -p <this folder> ipc call
// animePlayer|mangaReader|novelReader toggle`)
ShellRoot {
    id: root

    // R-C2: warn at startup when Omarchy moved away from the supported
    // line; the panels keep working, the log names what may have changed.
    Component.onCompleted: OmarchyVersion.check()

    // Live theme switches: the panels follow the palette the desktop is on,
    // not the one it had when they started.
    ThemeWatcher {}

    component ReaderSlot: Loader {
        id: slot

        // Tracked by hand: while the window is unmapped every panel in it
        // reads as invisible, so item.visible can't say what should show.
        property bool open: false

        // Only one panel at a time: whoever opens asks the root to close the rest.
        signal opened

        function toggle() {
            var action = Panels.toggleAction({ active: slot.active, open: slot.open })
            var patch = Panels.togglePatch(action)
            if (action === Panels.ACTION.LOAD) {
                // The Loader creates `item` synchronously here; the guard below
                // covers a source that ever becomes asynchronous.
                slot.active = true
            }
            if (slot.item) {
                if (patch.minimized !== undefined)
                    slot.item.minimized = patch.minimized
                if (patch.visible !== undefined)
                    slot.item.visible = patch.visible
            }
            if (patch.open !== undefined)
                slot.open = patch.open
            if (action !== Panels.ACTION.HIDE)
                slot.opened()
        }

        active: false

        Timer {
            id: unloadTimer
            interval: 600
            // unless it was reopened or minimized in the meantime
            onTriggered: if (Panels.shouldUnload({
                open: slot.open,
                minimized: slot.item ? !!slot.item.minimized : false
            })) slot.active = false
        }

        Connections {
            target: slot.item
            // Closed from the toggle or its own minimize button.
            function onVisibleChanged() {
                var next = Panels.afterHide({
                    open: slot.open,
                    visible: slot.item ? slot.item.visible : false,
                    minimized: slot.item ? !!slot.item.minimized : false
                })
                slot.open = next.open
                if (next.startUnload)
                    unloadTimer.start();
            }
        }
    }

    PanelWindow {
        id: window

        // Mapped only while a panel is showing; the rest of the surface
        // passes input through to the windows below.
        visible: animeSlot.open || mangaSlot.open || novelSlot.open

        WlrLayershell.namespace: "qs-novelmangareader"
        WlrLayershell.layer: WlrLayer.Top
        // Keep clear of the user's bar and other panels' exclusive zones.
        exclusionMode: ExclusionMode.Normal
        focusable: true
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            Region {
                item: root.maskItem(mangaSlot)
            }
            Region {
                item: root.maskItem(novelSlot)
            }
            Region {
                item: root.maskItem(animeSlot)
            }
        }

        Item {
            anchors.fill: parent

            // All three panels share the right edge: switching never moves the
            // eye (or the pointer) to the other side of the screen.
            ReaderSlot {
                id: mangaSlot
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: MangaReader {}
                onOpened: root.closeOthers(mangaSlot)
                opacity: root.panelOpacity(mangaSlot)
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            ReaderSlot {
                id: novelSlot
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: NovelReader {}
                onOpened: root.closeOthers(novelSlot)
                opacity: root.panelOpacity(novelSlot)
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            ReaderSlot {
                id: animeSlot
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: AnimePanel {}
                onOpened: root.closeOthers(animeSlot)
                opacity: root.panelOpacity(animeSlot)
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            // Omarchy adoption smoke test (Plan C, R-C1): invisible.
            OmarchySmoke {}
        }
    }

    // One panel at a time. The others close but stay LOADED (minimized), so
    // switching back is instant, and their `open` flag is cleared here instead
    // of relying on the visible-changed cascade: maskItem() reads `open`, and a
    // stale true would keep a hidden panel in the input mask.
    function closeOthers(keep) {
        var slots = [mangaSlot, novelSlot, animeSlot]
        var states = slots.map(function(slot) { return { open: slot.open } })
        var closing = Panels.othersToClose(states, slots.indexOf(keep))
        for (var i = 0; i < closing.length; i++) {
            var other = slots[closing[i]]
            var patch = Panels.closePatch({ loaded: !!other.item })
            other.open = patch.open
            if (other.item) {
                other.item.minimized = patch.minimized
                other.item.visible = patch.visible
            }
        }
    }

    // Ghost mode: painted over the whole screen, so when the pointer is
    // elsewhere it drops to Panels.IDLE_OPACITY. No delay, and the mask is
    // untouched, which is what lets the panel notice the pointer coming back.
    function panelOpacity(slot) {
        return Panels.opacityFor({
            open: slot.open,
            loaded: !!slot.item,
            pointerInside: slot.item ? slot.item.pointerInside : undefined
        })
    }

    function maskItem(slot) {
        return slot.open ? slot.item : null;
    }

    IpcHandler {
        target: "mangaReader"
        function toggle(): void {
            mangaSlot.toggle();
        }
    }

    IpcHandler {
        target: "novelReader"
        function toggle(): void {
            novelSlot.toggle();
        }
    }

    IpcHandler {
        target: "animePlayer"
        function toggle(): void {
            animeSlot.toggle();
        }
    }
}
