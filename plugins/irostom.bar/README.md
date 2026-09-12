# irostom.bar

Personal fork of Omarchy's built-in status bar (`omarchy.bar`), created with
`omarchy plugin clone omarchy.bar`.

## What's different from upstream

- The three bar chips (left/center/right) render with a translucent
  (`frostedAlpha = 0.55`) background instead of a fully opaque one, paired
  with a Hyprland `layer_rule` (see `hypr/looknfeel.lua` in the parent repo)
  that blurs the `omarchy-bar` layer surface. Together this gives a
  macOS-style frosted-glass bar. See `Bar.qml`, search for `frostedBackground`.

Everything else is unmodified upstream bar engine code — see Omarchy's own
docs for the general bar architecture and `shell.json` bar config shape.

## License

MIT — see `LICENSE`. Original bar engine code is Omarchy's; this fork keeps
the same license.
