# pwnsxb.novelmangareader — Omarchy bar widget

One bar icon that opens a small menu with **Anime / Manga / Novelas**. Each
entry runs `qs-novelmangareader anime|manga|novel`, which toggles the matching
reader panel of the `qs-novelmangareader` Quickshell app.

## Requirements

- Omarchy (Quickshell shell) with a bar.
- `qs-novelmangareader` installed and on `PATH` (`bin/qs-novelmangareader`).

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
