# omarchy-dotfiles

Personal [Omarchy](https://omarchy.org/) desktop configuration: Hyprland
overrides, the Omarchy shell config (`shell.json`), and custom bar plugins —
kept here so a fresh Omarchy install can be restored to the same setup
instead of re-doing every tweak by hand.

## What's in here

```
hypr/
  looknfeel.lua      # decoration/blur + the omarchy-bar layer_rule (frosted glass bar + panels)
  monitors.lua        # display layout
omarchy/
  shell.json          # bar layout/widgets, idle timings
  shell.toml           # machine-level style override: font size, popup translucency
plugins/
  irostom.bar/         # personal clone of the built-in bar (frosted-glass chips)
  irostom.tray/        # personal clone of the built-in tray widget
  irostom.workspaces/  # personal clone of the built-in workspaces widget
  irostom.logimouse/   # fork of the third-party omalogimouse plugin (MX Master mouse control)
  irostom.ollama/      # bar widget: local Ollama server status, context window, loaded models
  irostom.commandcenter/ # bar widget: macOS-Control-Center-style popup (Wi-Fi/Bluetooth/volume/media/quick toggles)
  irostom.menu/        # clone of the built-in menu, plus a query-plugin layer (calculator, unit/currency conversion)
```

### Frosted glass, theme-independent

The bar's frosted look is two parts, both here:

- `hypr/looknfeel.lua` — `decoration.blur.enabled = true`, plus a `layer_rule`
  on the `omarchy-bar` namespace with `blur = true`. This genuinely blurs the
  bar's own chips. It does **not** reach the Wi-Fi/Bluetooth/audio/etc.
  panels, despite those being popups of the same layer surface — confirmed
  by testing (screenshots against a detailed wallpaper, plus a real blurred
  window as a control) that no combination of `blur_popups`, `xray`, a
  wildcard `layer_rule`, or the global `decoration.blur.popups` option makes
  any difference. Root cause: the `omarchy-bar` layer surface's own box is
  just `2560x40` (the bar strip); the popups paint well outside that, and
  Hyprland's blur render pass doesn't extend past a layer's own box. This
  matches known upstream issues ([hyprwm/Hyprland#7357](https://github.com/hyprwm/Hyprland/issues/7357),
  [#8408](https://github.com/hyprwm/Hyprland/issues/8408)) — see the comment
  in `hypr/looknfeel.lua` for the full note.
- `omarchy/shell.toml` — `[popups] background-alpha = 0.82`. Since those
  panels can't get real blur, this is opacity-only: a fairly opaque tint so
  they read as a frosted pane rather than plain see-through glass. This is
  Omarchy's own machine-level style override (`~/.config/omarchy/shell.toml`,
  distinct from `shell.json`): every popup panel (Wi-Fi, Bluetooth, audio,
  dropdowns, tooltips — anything using `Color.popups.*`) reads its
  translucency from here, uniformly, without touching a single widget's QML.
  It also survives `omarchy theme set` (a theme's *own* `shell.toml`, if it
  ships one, only supplies the base values this overrides). Only the bar's
  own chip translucency (which *does* get real blur) lives in the
  `irostom.bar` plugin clone (see its README) since the bar draws its own
  chip shapes rather than using `PopupCard`.

`irostom.bar` also adds a `quickStatus` layout region alongside the stock
left/center/right ones: a conditional pill, between the center and right
chips, that only appears once one of Stay Awake/DND/Night Light/Reminder is
active, animating in/out rather than popping. The center pill now similarly
gates the now-playing media widget to "actually playing" (not just loaded)
before showing itself.

That center pill is also a **droplet**: when playback starts it oozes down out
of the top screen edge, held to it by a sticky concave-filleted neck that
stretches, thins, and has pinched off entirely by the time the chip settles
into the bar — so what's left is just the chip. Hovering it grows it sideways
from the compact one-line label into album art, title over artist, and
transport controls. It stays one widget throughout; nothing hangs below the
bar. Configured under `bar.mediaPill` in `shell.json`, with `mode` choosing
between `persistent` (droplet once, when playback starts), `transient` (also
replays it on every track change and expands the chip for `hold` ms), and
`off`. See `plugins/irostom.bar/README.md` for the full key list and how the
blob is drawn.

Each folder under `plugins/` is a self-contained Omarchy shell plugin per the
[plugin development reference](https://plugins.omarchy.org/develop.html)
(`manifest.json`, entry point, `README.md`, `LICENSE`) and passes
`omarchy plugin validate <folder>`.

### Why a third-party plugin needed forking too

`irostom.bar` being a third-party (non-first-party) bar has one consequence
beyond the frosted-glass styling: any *other* third-party plugin that tries
to fetch a live service via `bar.shell.serviceFor(moduleName)` gets a
service-less facade back instead — a deliberate Omarchy shell restriction so
an untrusted bar can't read a different third-party plugin's live service
object. `omalogimouse` (Logitech MX Master mouse control) hit exactly this:
it showed permanently offline under `irostom.bar` despite Solaar itself
seeing the mouse fine. `irostom.logimouse` is a fork that has the widget own
its Solaar-backed process directly instead of looking it up through that
bridge — see its own README for the full explanation. This is a property of
running *any* custom bar, not something specific to `irostom.bar`'s styling.

### And why the cloned menu carries its own app library

`irostom.menu` hit a second, related case. The shell hands a scoped
`appLibrary` to any plugin declaring `kind: "menu"`, which is what fills the
Apps list. It does not survive for a *cloned* menu: `shell.qml`'s
`prunePluginApis()` destroys a third-party plugin's scoped APIs whenever
`isEnabled()` reads false, which it transiently does while `shell.json` is
being re-applied — and nothing ever re-injects them. `isEnabled()`
short-circuits to `true` for first-party plugins, so only clones are hit. The
symptom is exact: the built-in menu lists 77 apps, a byte-identical clone
lists none.

So `irostom.menu` owns its app library instead of borrowing one, carrying
verbatim copies of the shell's `AppLibrary.qml` and `AppSearch.js` — the same
move `irostom.logimouse` makes with its Solaar service. Both are the same
lesson: a third-party plugin that depends on a host-injected object inherits
that object's lifetime bugs, and owning it outright is the durable fix.

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
   these, but do this before/with step 4 since `shell.json` references these
   plugin ids by name). `irostom.logimouse` additionally needs `solaar`
   installed (`sudo pacman -S solaar`) and a paired Logitech MX Master mouse
   to ever show as connected, and `irostom.ollama` needs a local `ollama`
   install reachable at `http://127.0.0.1:11434` — otherwise they just render
   offline, harmlessly:
   ```bash
   REPO=~/Work/omarchy-dotfiles
   mkdir -p ~/.config/omarchy/plugins
   ln -s "$REPO/plugins/irostom.bar" ~/.config/omarchy/plugins/irostom.bar
   ln -s "$REPO/plugins/irostom.tray" ~/.config/omarchy/plugins/irostom.tray
   ln -s "$REPO/plugins/irostom.workspaces" ~/.config/omarchy/plugins/irostom.workspaces
   ln -s "$REPO/plugins/irostom.logimouse" ~/.config/omarchy/plugins/irostom.logimouse
   ln -s "$REPO/plugins/irostom.ollama" ~/.config/omarchy/plugins/irostom.ollama
   ln -s "$REPO/plugins/irostom.commandcenter" ~/.config/omarchy/plugins/irostom.commandcenter
   ln -s "$REPO/plugins/irostom.menu" ~/.config/omarchy/plugins/irostom.menu
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

5. **Symlink the shell style override** (font size + frosted popup
   translucency — hot-reloads, no restart needed):
   ```bash
   REPO=~/Work/omarchy-dotfiles
   [[ -f ~/.config/omarchy/shell.toml ]] && mv ~/.config/omarchy/shell.toml ~/.config/omarchy/shell.toml.bak
   ln -s "$REPO/omarchy/shell.toml" ~/.config/omarchy/shell.toml
   ```

6. **Verify**
   ```bash
   hyprctl configerrors        # empty output = clean
   omarchy plugin list --json  # irostom.bar / irostom.tray / irostom.workspaces / irostom.logimouse /
                                # irostom.ollama / irostom.commandcenter / irostom.menu should show up,
                                # enabled — and omarchy.menu should show as disabled, replaced by the clone
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
