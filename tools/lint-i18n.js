"use strict";

// i18n guards for the qs-novelmangareader-es fork.
//
//   checkLiterals()  — fails when a UI text property still holds a raw English
//                      string literal instead of I18n.t(...)/I18n.tn(...).
//   checkUsedKeys()  — fails when a key passed to I18n.t()/tn() is missing from
//                      the translation tables (typos, renamed keys).
//
// CLI:  node tools/lint-i18n.js   (exit 1 on violations)
// The test runner calls these from tests/lint.test.js.

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");

// UI files where display strings live. Services are excluded from the literal
// scan (they hold JS objects with title/status fields that are not bindings),
// but are included in the used-key scan.
const UI_DIRS = ["modules", "components"];
const SERVICE_DIR = "services";

const TEXT_PROP = /\b(?:text|label|title|subtitle|placeholderText)\s*:/g;
const KEY_CALL = /I18n\.tn?\s*\(\s*"([^"]+)"/g;
const ASCII_WORD = /[A-Za-z]{2}/;

function walk(dir) {
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) out.push(...walk(full));
        else if (entry.name.endsWith(".qml")) out.push(full);
    }
    return out;
}

function collectFiles(dirs) {
    const files = [];
    for (const d of dirs) {
        const abs = path.join(ROOT, d);
        if (fs.existsSync(abs)) files.push(...walk(abs));
    }
    const shell = path.join(ROOT, "shell.qml");
    if (fs.existsSync(shell)) files.push(shell);
    return files;
}

// Remove `I18n.t(...)` / `I18n.tn(...)` calls, matching balanced parentheses.
function stripI18nCalls(src) {
    let out = "";
    let i = 0;
    while (i < src.length) {
        const m = /I18n\.t(?:n)?\s*\(/.exec(src.slice(i));
        if (!m) { out += src.slice(i); break; }
        out += src.slice(i, i + m.index);
        let j = i + m.index + m[0].length; // just past the '('
        let depth = 1;
        while (j < src.length && depth > 0) {
            const c = src[j];
            if (c === "(") depth++;
            else if (c === ")") depth--;
            j++;
        }
        i = j;
    }
    return out;
}

// Value of a property starting just after its ':': a {...} block (balanced) or
// the rest of the line for simple bindings.
function extractValue(src, start) {
    let i = start;
    while (i < src.length && /\s/.test(src[i])) i++;
    if (src[i] === "{") {
        let depth = 0;
        let j = i;
        for (; j < src.length; j++) {
            if (src[j] === "{") depth++;
            else if (src[j] === "}") { depth--; if (depth === 0) { j++; break; } }
        }
        const block = src.slice(i, j);
        // A `text: { ... }` block holds local data comparisons (e.g.
        // `mode === "dub"`); only the returned expression can be display text.
        const ri = block.lastIndexOf("return");
        return ri >= 0 ? block.slice(ri) : block;
    }
    let j = i;
    while (j < src.length && src[j] !== "\n") j++;
    return src.slice(i, j);
}

// First quoted literal inside `value` that contains at least two letters.
function firstWordLiteral(value) {
    const re = /"((?:[^"\\]|\\.)*)"/g;
    let m;
    while ((m = re.exec(value))) {
        if (ASCII_WORD.test(m[1])) return m[1];
    }
    return null;
}

function checkLiterals() {
    const violations = [];
    for (const file of collectFiles(UI_DIRS)) {
        const raw = fs.readFileSync(file, "utf8");
        const kept = raw
            .split("\n")
            .filter((l) => !/^\s*\/\//.test(l) && !l.includes("i18n-ignore"))
            .join("\n");
        const src = stripI18nCalls(kept);

        TEXT_PROP.lastIndex = 0;
        let m;
        while ((m = TEXT_PROP.exec(src))) {
            const value = extractValue(src, m.index + m[0].length);
            const literal = firstWordLiteral(value);
            if (literal !== null) {
                violations.push({
                    file: path.relative(ROOT, file),
                    property: m[0].replace(/\s*:$/, ""),
                    literal
                });
            }
        }
    }
    return violations;
}

function checkUsedKeys() {
    const { tables } = require("../services/i18n.js");
    const known = new Set(Object.keys(tables.en));
    const violations = [];
    for (const file of collectFiles(UI_DIRS.concat([SERVICE_DIR]))) {
        const raw = fs.readFileSync(file, "utf8");
        KEY_CALL.lastIndex = 0;
        let m;
        while ((m = KEY_CALL.exec(raw))) {
            if (!known.has(m[1])) {
                violations.push({ file: path.relative(ROOT, file), key: m[1] });
            }
        }
    }
    return violations;
}

module.exports = { checkLiterals, checkUsedKeys };

if (require.main === module) {
    const literals = checkLiterals();
    const keys = checkUsedKeys();
    for (const v of literals) {
        console.error(`raw literal: ${v.file} — ${v.property}: "${v.literal}"`);
    }
    for (const v of keys) {
        console.error(`unknown key: ${v.file} — ${v.key}`);
    }
    if (literals.length === 0 && keys.length === 0) {
        console.log("i18n lint: OK");
    } else {
        console.error(`i18n lint: ${literals.length + keys.length} violation(s)`);
        process.exit(1);
    }
}
