# CLAUDE.md

This repo holds personal Omarchy Linux desktop configuration: Hyprland
overrides, `shell.json`, and custom bar plugins. It exists so a fresh Omarchy
install can be restored to this setup, either by hand (see `README.md`) or by
pointing Claude Code at this repo.

## Security — read before ever touching this repo

**Never commit secrets, passwords, API keys, tokens, private SSH keys, or any
other sensitive personal information to this repository.** It is public.
Before adding or editing any file here:

- Config files (`hypr/*.lua`, `omarchy/shell.json`) should only ever contain
  desktop/appearance/behavior settings — not credentials, tokens, Wi-Fi
  passwords, or anything else private.
- Plugin code should not embed API keys or auth tokens, even for personal
  convenience services. If a plugin needs a credential, it must read it from
  an environment variable or a file outside this repo (e.g. under
  `~/.config/` but not tracked here) — never hardcode it.
- If something sensitive is ever accidentally committed, it must be treated
  as compromised (rotate/revoke it), not just removed in a later commit —
  git history is not a safe place to "undo" a leak on a public repo.

## What this repo is for

- `hypr/` — Hyprland Lua overrides (`~/.config/hypr/<file>.lua` equivalents).
  These are loaded *after* Omarchy's own defaults
  (`/usr/share/omarchy/default/hypr/`), so they only need to contain the
  deltas from stock Omarchy, not a full copy of Omarchy's config.
- `omarchy/shell.json` — the Omarchy shell's bar layout, widget list, and
  idle timings (`~/.config/omarchy/shell.json`).
- `omarchy/shell.toml` — machine-level style override (`~/.config/omarchy/shell.toml`,
  distinct from `shell.json`): font size, popup translucency (`[popups]
  background-alpha`), etc. Values here win over the active theme's own
  `shell.toml` and survive `omarchy theme set`. This is the right place for
  any further "match every panel/popup to X" style change — no per-widget
  plugin edit needed.
- `plugins/<id>/` — custom Omarchy shell plugins, each a self-contained
  package per <https://plugins.omarchy.org/develop.html> (`manifest.json` +
  entry point QML + `README.md` + `LICENSE`). These are user-owned clones of
  built-in Omarchy widgets (bar, tray, workspaces), not third-party
  downloads.

## Working in this repo — rules for Claude

- **Never edit anything under `/usr/share/omarchy/`.** That's the
  package-owned tree; Omarchy overwrites it on update. All Omarchy
  customization goes through `~/.config/` (or this repo, symlinked into
  `~/.config/`).
- Use the `omarchy` skill for anything involving `~/.config/hypr/`,
  `~/.config/omarchy/`, or `omarchy <group> <action>` commands — it documents
  the safe override locations and the plugin-clone workflow in detail.
- Validate any plugin folder before committing changes to it:
  `omarchy plugin validate plugins/<id>`.
- Validate any Hyprland Lua change against the *live* system before
  committing: symlink it in (or copy it over the live file temporarily),
  `hyprctl reload`, then `hyprctl configerrors` must come back clean.
- Keep each `plugins/<id>/manifest.json` version bumped (`version` field)
  when its behavior changes, so `omarchy plugin update` (for anyone who did
  add it via `omarchy plugin add`) has something meaningful to report.
- This repo intentionally does not track all of `~/.config/hypr/` — only the
  files that actually diverge from Omarchy's stock templates. Before adding a
  new file here, check whether it actually differs from
  `/usr/share/omarchy/config/hypr/<file>` (or the relevant default under
  `/usr/share/omarchy/default/`) — don't check in an unmodified copy of a
  stock file.
