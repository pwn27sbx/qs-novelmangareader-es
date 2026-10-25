"use strict";

// Installer and CLI checks for WU-9 (Spanish messages, command tokens intact).
//
// The help text of both scripts is printed from their header comment by a
// fixed `sed` range, so a translation that adds or drops a line silently
// breaks `--help`. These tests behave like a user: run the script, read the
// output, and install into a temporary HOME with no sudo anywhere in reach.
//
// Run with:  node --test

const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const BIN = path.join(ROOT, "bin", "qs-novelmangareader");
const INSTALL = path.join(ROOT, "install.sh");

function run(script, args, env) {
    return spawnSync("bash", [script, ...args], {
        cwd: ROOT,
        encoding: "utf8",
        timeout: 30000,
        env: { ...process.env, ...env }
    });
}

// Spanish help for a Spanish fork: an accented word or a Spanish verb, and
// none of the English words the original help used.
const SPANISH = /[áéíóúñ¿¡]|\b(inicia|arranca|abre|cierra|instala|opciones|registro|comando)\b/i;
const ENGLISH_LEFTOVER = /\b(skip|download|copy the folder|don't ask|start it|quit it|its log|install the system)\b/i;

test("the command --help prints and keeps the command tokens", () => {
    const result = run(BIN, ["--help"]);
    assert.equal(result.status, 0, result.stderr);
    for (const token of ["anime", "manga", "novel", "stop", "log"])
        assert.match(result.stdout, new RegExp("\\b" + token + "\\b"), "missing token " + token);
    assert.match(result.stdout, /qs-novelmangareader/);
});

test("the command --help is in Spanish", () => {
    const result = run(BIN, ["--help"]);
    assert.match(result.stdout, SPANISH);
    assert.doesNotMatch(result.stdout, ENGLISH_LEFTOVER);
});

test("install.sh --help prints and keeps every flag", () => {
    const result = run(INSTALL, ["--help"]);
    assert.equal(result.status, 0, result.stderr);
    for (const flag of ["--no-deps", "--no-venv", "--copy", "--yes"])
        assert.ok(result.stdout.includes(flag), "missing flag " + flag);
});

test("install.sh --help is in Spanish", () => {
    const result = run(INSTALL, ["--help"]);
    assert.match(result.stdout, SPANISH);
    assert.doesNotMatch(result.stdout, ENGLISH_LEFTOVER);
});

test("install.sh installs into a temporary HOME without sudo", () => {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), "qsnr-home-"))
    const env = {
        HOME: home,
        XDG_CONFIG_HOME: "",
        XDG_DATA_HOME: "",
        // No /usr/local/bin: the sudo branch must never be reachable here.
        SYSTEM_BIN: path.join(home, "not-on-path"),
        PATH: [path.join(home, ".local/bin"), "/usr/bin", "/bin"].join(":")
    };
    const result = run(INSTALL, ["--no-deps", "--no-venv", "--yes"], env);

    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout + result.stderr, SPANISH);
    assert.ok(fs.lstatSync(path.join(home, ".config/qs-novelmangareader")).isSymbolicLink(),
        "the config folder is not a symlink");
    assert.ok(fs.existsSync(path.join(home, ".local/bin/qs-novelmangareader")),
        "the command was not installed");
    // The marker install.sh greps before overwriting the command: it lives in
    // the command's header and in install-common.sh's grep, so both have to
    // carry the same phrase or every reinstall refuses to replace the file.
    const command = fs.readFileSync(path.join(home, ".local/bin/qs-novelmangareader"), "utf8");
    const common = fs.readFileSync(path.join(ROOT, "scripts/install-common.sh"), "utf8");
    // The command names itself; the installer greps the same sentence with
    // the command name interpolated.
    const sentence = "Instalado por el install.sh de ";
    assert.ok(command.includes(sentence + "qs-novelmangareader"),
        "the command header lost the install marker");
    assert.ok(common.includes(sentence + "$name"),
        "install-common.sh no longer greps the install marker");
});
