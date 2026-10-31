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
    assert.equal(p.toggleAction({ active: false, open: false }), "load");
    assert.equal(p.toggleAction({ active: true, open: true }), "hide");
    assert.equal(p.toggleAction({ active: true, open: false }), "restore");
});

test("togglePatch: hide NO limpia open, restore limpia minimized (bug 727733a)", () => {
    assert.deepEqual(p.togglePatch("hide"), { open: true, minimized: false, visible: false });
    assert.deepEqual(p.togglePatch("restore"), { open: true, minimized: false, visible: true });
    assert.deepEqual(p.togglePatch("load"), { open: true, minimized: false, visible: true });
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
    assert.equal(p.toggleAction({ active: true, open: closed.open }), "restore");
    assert.equal(p.togglePatch("restore").minimized, false);
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
