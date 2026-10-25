# pwnsxb.novelmangareader — Omarchy bar widget

One bar icon that opens a small menu with **Anime / Manga / Novelas**. Each
entry runs `qs-novelmangareader anime|manga|novel`, which toggles the matching
reader panel of the `qs-novelmangareader` Quickshell app.

## Requirements

- Omarchy (Quickshell shell) with a bar.
- `qs-novelmangareader` installed and on `PATH` (`bin/qs-novelmangareader`).

## Supported Omarchy

The panels import `qs.Commons` and `qs.Ui` from `/usr/share/omarchy/shell` (the
`Commons`/`Ui` symlinks at the repo root point there), so an Omarchy upgrade
that moves those layers changes the app's ground. The app is written against
**one major.minor line: `4.0`** (`services/OmarchyVersion.qml`).

At startup it runs `omarchy version` and, when the running line is not `4.0`,
logs one warning — it never blocks and the panels still open:

```bash
qs-novelmangareader log | grep -i omarchy
```

## Updating Omarchy

1. Update Omarchy (`omarchy update`, or your channel's updater), then
   `omarchy-restart-shell`.
2. Restart the app (`qs-novelmangareader stop`, then `qs-novelmangareader`) and
   open the three panels: `qs-novelmangareader anime`, `manga`, `novel`.
3. Read the log: `qs-novelmangareader log`. There must be no `ERROR`,
   `TypeError`, `Unable to assign` or `Cannot read property` lines, and the
   version warning above tells you whether the line moved.
4. Check the palette still follows the theme: the `SMOKE` line must report the
   `accent` of `~/.local/state/omarchy/current/theme/colors.toml`.
5. In the repo, run `node --test`, `node tools/lint-style.js` and
   `node tools/lint-i18n.js`.
6. If a component moved, fix it against
   `/usr/share/omarchy/shell/{Commons,Ui}`, then bump `supported` in
   `services/OmarchyVersion.qml` and this section.

A `dev` checkout (`OMARCHY_PATH` pointing at a git checkout) reports `dev` and
therefore always warns: it has no release line to compare against.

## Install

Copy (or symlink) this directory into your user plugin directory:

```bash
# copy
cp -r omarchy/pwnsxb.novelmangareader ~/.config/omarchy/plugins/
# or symlink (keeps it in sync with the repo)
ln -s "$PWD/omarchy/pwnsxb.novelmangareader" ~/.config/omarchy/plugins/pwnsxb.novelmangareader
```

Omarchy hot-reloads plugin code on save; if the widget does not appear, run:

```bash
omarchy-shell shell rescanPlugins
```

## Enable in the bar

Add the widget to `~/.config/omarchy/shell.json` (the shell hot-reloads on
save). The exact section (`left` / `center` / `right`) is your choice, e.g.:

```jsonc
{
  "bar": {
    "right": [
      // ... your existing widgets ...
      { "id": "pwnsxb.novelmangareader" }
    ]
  }
}
```

Or move it with the bar CLI:

```bash
omarchy bar move pwnsxb.novelmangareader --section right
```

## Use

- **Left click** the bar icon → menu with **Anime / Manga / Novelas**.
- Clicking an entry opens/toggles that reader panel.

## Customize

- **Bar icon glyph**: `Panel.qml` → `BarIconButton { text: "󰂺" }`.
- **Menu entries**: `Panel.qml` → the `entries` array (`key` must be one of
  `anime`, `manga`, `novel`).

Glyphs are Material Design Icons (Nerd Font). Any missing glyph renders as a
box — swap it for one your font has.
