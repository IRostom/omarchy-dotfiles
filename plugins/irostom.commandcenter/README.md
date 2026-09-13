# Command Center

A single bar button opening a macOS-Control-Center-style popup with four
zones, styled entirely with the same Ui kit and dark/light theme every other
first-party panel uses (no macOS visual mimicry, just the layout idea):

1. **Connectivity** — Wi-Fi and Bluetooth rows. The switch on each row flips
   it on/off directly; clicking the rest of the row opens the real
   `omarchy.network` / `omarchy.bluetooth` popup (same panels the standalone
   bar widgets show) via `omarchy-shell <target> toggle`.
2. **Sound** — output volume slider and mute button, bound straight to the
   default Pipewire sink (the same node the `omarchy.audio` panel controls).
3. **Now playing** — art, title/artist, and previous/play-pause/next for
   whatever MPRIS player `omarchy.media` currently considers active.
4. **Quick actions** — toggles for Stay Awake, Silence Notifications, Night
   Light, and Screen Recording — the same four actions as the indicators in
   the bar's middle tray, reading and driving the same first-party services
   (`omarchy.idle`, `omarchy.notifications`, `omarchy.nightlight`) and the
   same `gpu-screen-recorder` process check.

This widget owns no state of its own — every zone reads and drives the
services/IPC targets the dedicated panels and indicators already use, so it
never drifts out of sync with them.

## License

MIT — see `LICENSE`.
