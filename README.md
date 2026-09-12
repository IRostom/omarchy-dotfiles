# omarchy-dotfiles

Personal [Omarchy](https://omarchy.org/) desktop configuration: Hyprland
overrides, the Omarchy shell config (`shell.json`), and custom bar plugins —
kept here so a fresh Omarchy install can be restored to the same setup
instead of re-doing every tweak by hand.

## What's in here

```
hypr/
  looknfeel.lua      # decoration/blur + the omarchy-bar layer_rule (frosted glass bar)
  monitors.lua        # display layout
omarchy/
  shell.json          # bar layout/widgets, idle timings
plugins/
  irostom.bar/         # personal clone of the built-in bar (frosted-glass chips)
  irostom.tray/        # personal clone of the built-in tray widget
  irostom.workspaces/  # personal clone of the built-in workspaces widget
```

Each folder under `plugins/` is a self-contained Omarchy shell plugin per the
[plugin development reference](https://plugins.omarchy.org/develop.html)
(`manifest.json`, entry point, `README.md`, `LICENSE`) and passes
`omarchy plugin validate <folder>`.

## Restoring on a fresh Omarchy install

Do these **in order**. Steps 1–2 are config files; steps 3–5 are the plugins
(each plugin must be enabled in your bar layout via `shell.json`, which the
symlink in step 2 already encodes — so 2 must come after the plugin folders
exist on disk, i.e. after step 1's clone but you can do 3–5 in any order
relative to each other, just before/around step 2).

Simplest correct order:

1. **Clone this repo**
   ```bash
   git clone https://github.com/IRostom/omarchy-dotfiles.git ~/Work/omarchy-dotfiles
   ```

2. **Symlink the custom Hyprland config** (back up anything real first —
   these commands assume a stock, untouched `~/.config/hypr`):
   ```bash
   REPO=~/Work/omarchy-dotfiles
   mv ~/.config/hypr/looknfeel.lua ~/.config/hypr/looknfeel.lua.bak
   mv ~/.config/hypr/monitors.lua ~/.config/hypr/monitors.lua.bak
   ln -s "$REPO/hypr/looknfeel.lua" ~/.config/hypr/looknfeel.lua
   ln -s "$REPO/hypr/monitors.lua" ~/.config/hypr/monitors.lua
   hyprctl reload
   hyprctl configerrors   # should print nothing
   ```

3. **Symlink each plugin folder into place** (order doesn't matter between
   these three, but do this before/with step 4 since `shell.json` references
   these plugin ids by name):
   ```bash
   REPO=~/Work/omarchy-dotfiles
   mkdir -p ~/.config/omarchy/plugins
   ln -s "$REPO/plugins/irostom.bar" ~/.config/omarchy/plugins/irostom.bar
   ln -s "$REPO/plugins/irostom.tray" ~/.config/omarchy/plugins/irostom.tray
   ln -s "$REPO/plugins/irostom.workspaces" ~/.config/omarchy/plugins/irostom.workspaces
   omarchy-shell shell rescanPlugins
   ```

4. **Symlink the shell config** (this is what actually puts the bar in
   `irostom.bar` mode and wires the tray/workspaces widgets into the layout —
   do this *after* step 3 so the plugin ids it references already exist):
   ```bash
   REPO=~/Work/omarchy-dotfiles
   mv ~/.config/omarchy/shell.json ~/.config/omarchy/shell.json.bak
   ln -s "$REPO/omarchy/shell.json" ~/.config/omarchy/shell.json
   omarchy restart shell
   ```

5. **Verify**
   ```bash
   hyprctl configerrors        # empty output = clean
   omarchy plugin list --json  # irostom.bar / irostom.tray / irostom.workspaces should show up, enabled
   ```

### Adding a genuinely third-party plugin (not part of this repo)

For a plugin that lives in its own upstream repo (i.e. the normal case this
repo's own plugins don't fit, since `omarchy plugin add` requires the git
repo root to *be* the plugin), the flow is just:

```bash
omarchy plugin add https://github.com/<author>/<plugin-repo>.git --enable
```

Review the code first — plugins run unsandboxed inside your shell process.

## Making further changes

Edit files under this repo (they're symlinked in, so edits apply live —
Hyprland auto-reloads `.lua`, and `shell.json`/`plugins/**` hot-reload), then
commit and push as usual.

## Asking Claude to do this instead

You can point Claude Code at this repo and ask it to restore the setup (or
apply a specific piece of it) — it has an `omarchy` skill that knows the
safe, update-proof way to symlink these files and enable plugins, and it will
follow the same order as above.
