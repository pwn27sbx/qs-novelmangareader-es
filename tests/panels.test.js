// tests/panels.test.js — el estado de los paneles (Plan C).
//
// Nació del bug de 727733a: al cerrar un panel por otro, `open` quedaba en true,
// así que volvía al segundo toque y seguía en el mask de entrada. Ese caso y los
// efectos de cada rama están pinneados aquí.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const p = require("../services/panels.js");

test("toggleAction: las tres ramas de toggle() (active, no item)", () => {
    assert.equal(p.toggleAction({ active: false, open: false }), p.ACTION.LOAD);
    assert.equal(p.toggleAction({ active: true, open: true }), p.ACTION.HIDE);
    assert.equal(p.toggleAction({ active: true, open: false }), p.ACTION.RESTORE);
});

test("togglePatch: cada acción escribe SOLO sus campos", () => {
    // hide no toca open ni minimized: la cascada (afterHide) es la que cierra open.
    assert.deepEqual(p.togglePatch(p.ACTION.HIDE), { visible: false });
    assert.deepEqual(p.togglePatch(p.ACTION.RESTORE), { open: true, minimized: false, visible: true });
    // LOAD resets minimized explicitly: a panel declares that flag as its
    // initial state, and a future default change must not leave a freshly
    // loaded panel "minimized" (the pre-extraction code relied on the default).
    assert.deepEqual(p.togglePatch(p.ACTION.LOAD), { open: true, minimized: false, visible: true });
});

test("togglePlan: el cableado no vuelve a decidir la acción", () => {
    const load = p.togglePlan({ active: false, open: false });
    assert.equal(load.action, p.ACTION.LOAD);
    assert.equal(load.activate, true);
    assert.equal(load.open, true);
    assert.equal(load.notify, true);

    const hide = p.togglePlan({ active: true, open: true });
    assert.equal(hide.activate, false);
    assert.equal(hide.open, undefined);   // la cascada cierra open, no el toggle
    assert.equal(hide.notify, false);
    assert.deepEqual(hide.item, { visible: false });

    const restore = p.togglePlan({ active: true, open: false });
    assert.equal(restore.activate, false);
    assert.equal(restore.open, true);
    assert.equal(restore.notify, true);
});

test("togglePatch: una acción desconocida falla en vez de restaurar", () => {
    assert.throws(() => p.togglePatch("nueva"), /unknown toggle action/);
    assert.throws(() => p.togglePatch(undefined), /unknown toggle action/);
});

test("afterHide: la guarda devuelve el open recibido", () => {
    assert.deepEqual(p.afterHide({ open: true, visible: false, minimized: false }), { open: false, startUnload: true });
    assert.deepEqual(p.afterHide({ open: true, visible: false, minimized: true }), { open: false, startUnload: false });
    assert.deepEqual(p.afterHide({ open: true, visible: true, minimized: false }), { open: true, startUnload: false });
    assert.deepEqual(p.afterHide({ open: false, visible: false, minimized: false }), { open: false, startUnload: false });
});

test("othersToClose: uno a la vez, keep intacto", () => {
    const s = [{ open: true }, { open: true }, { open: false }];
    assert.deepEqual(p.othersToClose(s, 1), [0]);
    assert.deepEqual(p.othersToClose([{ open: true }, { open: true }, { open: true }, { open: true }], 3), [0, 1, 2]);
    assert.deepEqual(p.othersToClose(s, 0), [1]);
});

test("closePatch: open/minimized/visible, y no toca un slot sin item", () => {
    assert.deepEqual(p.closePatch({ loaded: true }), { open: false, minimized: true, visible: false });
    assert.deepEqual(p.closePatch({ loaded: false }), { open: false, minimized: false, visible: false });
});

test("vuelta en el primer toque tras closePatch", () => {
    const closed = p.closePatch({ loaded: true });
    assert.equal(p.toggleAction({ active: true, open: closed.open }), p.ACTION.RESTORE);
    assert.equal(p.togglePatch(p.ACTION.RESTORE).minimized, false);
});

test("shouldUnload: el minimizado se queda, el cerrado a mano se va, el item nulo se va", () => {
    assert.equal(p.shouldUnload({ open: false, minimized: true }), false);
    assert.equal(p.shouldUnload({ open: false, minimized: false }), true);
    assert.equal(p.shouldUnload({ open: false, minimized: undefined }), true);
    assert.equal(p.shouldUnload({ open: true, minimized: false }), false);
});

test("opacityFor: 1 / 0.15 / guarda de tipo", () => {
    assert.equal(p.IDLE_OPACITY, 0.15);
    assert.equal(p.opacityFor({ open: false, loaded: true, pointerInside: true }), 1);
    assert.equal(p.opacityFor({ open: true, loaded: false, pointerInside: undefined }), 1);
    assert.equal(p.opacityFor({ open: true, loaded: true, pointerInside: true }), 1);
    assert.equal(p.opacityFor({ open: true, loaded: true, pointerInside: false }), 0.15);
    assert.equal(p.opacityFor({ open: true, loaded: true, pointerInside: undefined }), 1);
    assert.equal(p.opacityFor({ open: true, loaded: true, pointerInside: 0 }), 1);
    assert.equal(p.opacityFor({ open: true, loaded: true, pointerInside: "true" }), 1);
});
