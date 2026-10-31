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
            if (!active) {
                active = true;
                item.visible = true;
                open = true;
                opened();
            } else if (open) {
                item.visible = false;
            } else {
                // restoring a minimized panel; closing it next time unloads it
                item.minimized = false;
                item.visible = true;
                open = true;
                opened();
            }
        }

        active: false

        Timer {
            id: unloadTimer
            interval: 600
            // unless it was reopened or minimized in the meantime
            onTriggered: if (!slot.open && !slot.item?.minimized) slot.active = false
        }

        Connections {
            target: slot.item
            // Closed from the toggle or its own minimize button.
            function onVisibleChanged() {
                if (!slot.open || slot.item.visible)
                    return;
                slot.open = false;
                if (!slot.item.minimized)
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
        for (var i = 0; i < slots.length; i++) {
            var other = slots[i]
            if (other === keep || !other.open)
                continue
            other.open = false
            if (other.item) {
                other.item.minimized = true
                other.item.visible = false
            }
        }
    }

    // Ghost mode: painted over the whole screen, so when the pointer is
    // elsewhere it drops to idleOpacity. No delay, and the mask is untouched,
    // which is what lets the panel notice the pointer coming back by itself.
    readonly property real idleOpacity: 0.15

    // The slot contract: a panel may expose `pointerInside`. One that does not
    // (a future panel) stays fully opaque instead of ghosting forever.
    function panelOpacity(slot) {
        if (!slot.open || !slot.item)
            return 1
        if (typeof slot.item.pointerInside !== "boolean")
            return 1
        return slot.item.pointerInside ? 1 : root.idleOpacity
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
