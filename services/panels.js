// Panel shell state, without the drawing.
//
// shell.qml used to decide everything inline: whether a reader opens, hides or
// comes back, which of the others close, when a hidden one may be unloaded, and
// how opaque it should be. That is all state, and it lives here so a node test
// can pin it — a review of the inline version found that closing a panel left
// `open` set, which made it take two presses to return and kept a hidden panel
// in the input mask.
//
// The QML keeps only the wiring: it applies these patches and paints.

var IDLE_OPACITY = 0.15;

// The actions travel as these constants, never as bare strings: the QML compares
// against them, so a typo or a new action cannot fall silently into the restore
// branch — togglePatch throws instead.
var ACTION = {
    LOAD: "load",
    HIDE: "hide",
    RESTORE: "restore"
};

// What the toggle must do, given the slot's state.
function toggleAction(state) {
    state = state || {};
    if (!state.active)
        return ACTION.LOAD;
    return state.open ? ACTION.HIDE : ACTION.RESTORE;
}

// Only the properties THAT action writes; a field absent from the patch is a
// field the caller must not touch.
//
// "hide" writes `visible` alone on purpose: the visible-changed cascade is what
// clears `open` (see afterHide), and clearing it early would disarm the unload
// timer, keeping the panel loaded forever.
// load and restore write the same "this panel is on screen" fields; one
// constant so an edit to one cannot silently diverge from the other. LOAD sets
// `minimized: false` because a panel declares that flag as its initial state,
// and a future default change must not leave a newly loaded panel minimized.
var OPENED_PATCH = { open: true, minimized: false, visible: true };

// A copy each time: a caller that mutates the patch must not corrupt the next one.
function openedPatch() {
    return { open: OPENED_PATCH.open, minimized: OPENED_PATCH.minimized, visible: OPENED_PATCH.visible };
}

function togglePatch(action) {
    if (action === ACTION.HIDE)
        return { visible: false };
    if (action === ACTION.RESTORE)
        return openedPatch();
    if (action === ACTION.LOAD)
        return openedPatch();
    throw new Error("panels: unknown toggle action " + String(action));
}

// The visible-changed cascade: a panel that was open and got hidden closes its
// `open` flag and asks for an unload unless it is minimized (kept loaded so the
// switch back is instant).
//
// The guard returns the received `open` untouched: returning false here would
// switch off a panel that is being shown.
function afterHide(state) {
    state = state || {};
    if (!state.open || state.visible)
        return { open: !!state.open, startUnload: false };
    return { open: false, startUnload: !state.minimized };
}

// The unload timer: only a panel neither open nor kept loaded is freed.
function shouldUnload(state) {
    state = state || {};
    return !state.open && !state.minimized;
}

// One panel at a time: every open slot except `keepIndex`.
function othersToClose(states, keepIndex) {
    var close = [];
    for (var i = 0; i < (states || []).length; i++) {
        if (i !== keepIndex && states[i] && states[i].open)
            close.push(i);
    }
    return close;
}

// What closing another panel writes. A slot without a loaded item has no
// `minimized` flag to set.
function closePatch(state) {
    var loaded = !!(state && state.loaded);
    return { open: false, minimized: loaded, visible: false };
}

// Ghost mode: a panel painted over the whole screen drops to IDLE_OPACITY when
// the pointer is elsewhere. A panel that does not expose `pointerInside` (a
// future one) stays opaque instead of ghosting forever, so the guard is on the
// type, not on truthiness.
function opacityFor(state) {
    state = state || {};
    if (!state.open || !state.loaded)
        return 1;
    if (typeof state.pointerInside !== "boolean")
        return 1;
    return state.pointerInside ? 1 : IDLE_OPACITY;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        IDLE_OPACITY: IDLE_OPACITY,
        ACTION: ACTION,
        toggleAction: toggleAction,
        togglePatch: togglePatch,
        afterHide: afterHide,
        shouldUnload: shouldUnload,
        othersToClose: othersToClose,
        closePatch: closePatch,
        opacityFor: opacityFor
    };
}
