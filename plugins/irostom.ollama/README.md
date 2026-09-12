# Ollama

Bar widget for a local Ollama server (`http://127.0.0.1:11434`).

- Bar icon dims/greys out with a small status dot: accent-colored when the
  server answers, urgent-colored when it doesn't, muted while checking.
- Popup shows reachability, version, and every currently loaded model with
  its context window, VRAM use, and time until it unloads (from `/api/ps`).
- The switch in the popup header reflects "server reachable right now".
  Flipping it off stops the local `ollama serve` process; flipping it back
  on starts a fresh one. One full off/on cycle is a restart.

State is polled every 5s via `curl` against `/api/version` and `/api/ps`,
whether or not the popup is open, so the bar icon and its dot stay current
on their own.

Only manages a plain `ollama serve` process (started/stopped via `pkill`/a
detached spawn), not a systemd unit — this matches how Ollama is actually
running here. If you switch to running Ollama via `systemctl`, update
`toggleServer()` in `Panel.qml` to call `systemctl --user` (or `sudo
systemctl`) instead.
