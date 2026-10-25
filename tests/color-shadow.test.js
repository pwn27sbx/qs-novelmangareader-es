"use strict";

// Guard for the Qt 6.12 `Color` shadowing.
//
// Qt 6.12 ships a `Color` value type in QtQuick. An unqualified `Color.x`
// therefore resolves to that value type instead of the `qs.Commons`
// singleton: every read returns `undefined`, and any binding that goes
// through a function (`Colors.mix(...)`) dies for good. The UI renders its
// text and surfaces invisible and nothing reports an error.
//
// Import the module with an alias and qualify the read:
//
//   import qs.Commons as Commons
//   color: Commons.Color.accent
//
// Views keep asking the app adapter (`qs.app.Colors`), so they write
// `Colors.accent` and never touch `Commons.Color` directly.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");

// `Commons/` and `Ui/` are symlinks into /usr/share/omarchy: Omarchy's own
// code, not ours. The token singleton itself is the one place allowed to
// read `Commons.Color`.
const DIRS = ["app", "components", "modules", "omarchy"];
const FILES = ["shell.qml"];

// `Color.<role>` not already qualified (`Commons.Color.`, `Colors.`, …).
const SHADOWED = /(^|[^\w.$])Color\.[A-Za-z_]/;

function walk(dir, out) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full, out);
        else if (entry.name.endsWith(".qml")) out.push(full);
    }
    return out;
}

function qmlFiles() {
    const out = FILES.map((f) => path.join(ROOT, f)).filter((f) => fs.existsSync(f));
    for (const dir of DIRS) {
        const full = path.join(ROOT, dir);
        if (fs.existsSync(full)) walk(full, out);
    }
    return out;
}

function violations() {
    const found = [];
    for (const file of qmlFiles()) {
        const lines = fs.readFileSync(file, "utf8").split("\n");
        lines.forEach((line, i) => {
            if (line.includes("// color-ignore")) return;
            const code = line.replace(/\/\/.*$/, "");
            if (SHADOWED.test(code))
                found.push(`${path.relative(ROOT, file)}:${i + 1}: ${line.trim()}`);
        });
    }
    return found;
}

test("no unqualified Color.<role> reads (Qt 6.12 shadows the singleton)", () => {
    assert.deepEqual(violations(), [],
        "unqualified Color reads found; use `Commons.Color.` (alias import) "
        + "or the `Colors` adapter:\n" + violations().join("\n"));
});
