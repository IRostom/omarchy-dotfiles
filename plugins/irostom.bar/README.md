# irostom.bar

Personal fork of Omarchy's built-in status bar (`omarchy.bar`), created with
`omarchy plugin clone omarchy.bar`.

## What's different from upstream

- The three bar chips (left/center/right) render with a translucent
  (`frostedAlpha = 0.55`) background instead of a fully opaque one, paired
  with a Hyprland `layer_rule` (see `hypr/looknfeel.lua` in the parent repo)
  that blurs the `omarchy-bar` layer surface. Together this gives a
  macOS-style frosted-glass bar. See `Bar.qml`, search for `frostedBackground`.

- A `quickStatus` layout region alongside the stock left/center/right ones,
  and a center chip gated on "media actually playing" rather than merely
  loaded. See `Bar.qml`, search for `AnimatedPillChip` and `centerGate`.

- `MediaChip.qml` / `MediaExpanded.qml`: the now-playing chip oozes down out
  of the top screen edge like a droplet, and expands in place on hover. See
  below.

Everything else is unmodified upstream bar engine code — see Omarchy's own
docs for the general bar architecture and `shell.json` bar config shape.

## The media chip

One widget, not two: the centre chip *is* the media widget. When playback
starts it oozes down out of the top screen edge, held to it by a sticky neck
that stretches, thins, pinches, and is gone by the time the chip settles into
its slot. Hovering it grows it sideways from the compact one-line label into
album art, title over artist, and transport controls.

Configured under `bar.mediaPill` in `~/.config/omarchy/shell.json`:

```json
"bar": {
  "mediaPill": { "mode": "transient", "hold": 4000 }
}
```

| key    | values                             | meaning                                              |
| ------ | ---------------------------------- | ---------------------------------------------------- |
| `mode` | `transient` / `persistent` / `off` | anything else falls back to `transient`               |
| `hold` | ms (default `4000`)                | `transient` only: how long the auto-expansion lasts   |

- **`persistent`** — the droplet plays once, when playback starts. The chip
  then stays put until playback stops, and only hover expands it.
- **`transient`** — as `persistent`, and additionally every track change
  replays the droplet (the chip is sucked back up and dropped again) and
  expands the chip for `hold` ms so the new track announces itself.
- **`off`** — no droplet, no hover expansion. The chip fades in and out like
  every other chip in this bar.

Whatever was already playing when the shell starts still gets its droplet
entrance, but never the `transient` replay or auto-expansion — logging in and
`omarchy restart shell` don't announce a track you have been listening to for
an hour.

One trap to keep in mind when editing the centre section: the compact media
widget reports `implicitWidth: 0` whenever it is not visible, and the chip's
collapsed width is read straight off it. Gate `centerHost.visible` on that
width and it latches shut — width 0 makes the host invisible, which makes the
widget invisible, which keeps the width at 0 — and anything already playing
when the shell starts never appears at all. Visibility there follows
`root.mediaPlaying`; `enabled`, not `visible`, is what hands input between the
compact and expanded states.

Config is read in `Bar.qml`'s `applyMediaPillConfig()`, deliberately *before*
`applyBarConfig()`'s inline-settings early return, so it re-applies on any
`shell.json` write.

### How it's drawn

The neck and the capsule are a single closed SVG outline (`blobPath`) with one
fill, not two overlapping shapes: the chips are 55% translucent, so anything
that overlapped would double-blend into a visible seam. Where the neck meets
the screen edge above and the capsule below it flares out through concave
quadratic fillets — control point at the *inner* corner — whose horizontal
spread and vertical reach are tuned separately, so the weld still sweeps wide
when the gap is only a few pixels tall.

The neck doesn't fade out; it thins to nothing geometrically as the chip falls
(`neckAmount`, smoothstepped against `stretch`), which is both what a real
droplet does and the only way to keep that single fill.

Things worth knowing before touching this:

- **The bar surface reaches the screen edge.** `barWindow` grows by `gooInset`
  (= `edgeGap`) and gives the same amount back off its top margin, so the
  chips, the exclusive zone and the hidden-bar offset are all unchanged — but
  there is now a strip of surface up to the screen edge for the neck to weld
  itself to. `MediaChip` paints into it with a negative `y`; nothing between
  it and the layer surface clips.
- **The overshoot is load-bearing.** `Easing.OutBack` with a large overshoot
  dips the chip past its slot, and that dip is the only thing that stretches
  the neck beyond the bar's 8px edge gap. Reduce it and the weld stops
  reading.
- **It lives in the bar, not in a clone of `omarchy.media`,** because only a
  plugin with **bar** capabilities is handed the `omarchy.media` service
  (`createScopedPluginShell` in Omarchy's `shell.qml`) — the same reason the
  chip's play-state gate lives here.
- **Use `PathSvg` with the default shape renderer.** `Shape.CurveRenderer`
  does not support `PathSvg` and silently renders nothing.
- `MediaExpanded` measures itself with `TextMetrics`, not from its own labels:
  they elide to whatever width they are handed, so asking them how wide they
  would like to be after they have been constrained is a binding loop — and
  that number is exactly what drives the chip's width animation.

## License

MIT — see `LICENSE`. Original bar engine code is Omarchy's; this fork keeps
the same license.
