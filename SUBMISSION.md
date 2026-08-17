# Marketplace submission — omarchyplugins.com

Not part of the plugin. This is the filled-in form for the listing, kept here so the
submission is reproducible and reviewable before it is sent.

Form: <https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml>

---

**Repository URL** (required)

```
https://github.com/Chernicharo/omarchy-plugin-voxtype-mode
```

**Category** (required, pick one)

```
Hardware
```

Rationale: the plugin's entire purpose is choosing which piece of hardware runs the
workload — CPU versus GPU — and its user-visible payoff is VRAM. `System` is the runner-up
if a reviewer disagrees.

**Tags** (required, max 3)

```
Bar, Quickshell, System
```

`Hyprland` was dropped deliberately: the widget talks to the Omarchy shell and to a
systemd user service, never to the compositor, so claiming the tag would be misleading.

**Suggest a missing tag** (optional)

```
dictation
```

**Maintainer notes** (optional)

```
Bar widget front end for the voxtype-mode CLI (MIT, same author):
https://github.com/Chernicharo/voxtype-mode

It runs only that CLI — `status --json` and `models --json` to read, `toggle`/`cpu`/`gpu`
to switch, `set-model`/`set-language` to configure, `config` to locate a config file —
plus `notify-send` when the optional notification setting is on, and
`omarchy-launch-config-editor` for the settings button, which opens the user's own
configured editor.

Every subprocess is spawned as an argument vector; the plugin never builds a shell command
string. Model names and config paths therefore cannot be reinterpreted as shell syntax, no
matter what a user-edited config file contains.

No sudo, no system files, no network access.

It writes in exactly two places, both only in response to an explicit choice in the panel:
its own entry in ~/.config/omarchy/shell.json (the notification preference, through the
shell's own settings API), and the `model` / `language` keys of
~/.config/voxtype/config.{cpu,gpu}.toml — the files the user is configuring when they use
the model and language pickers. Nothing is written on load, on poll, or on open.

The switched daemon is a systemd *user* service, and the active mode is stored in
$XDG_RUNTIME_DIR (per-user, wiped on logout) rather than a shared path in /tmp.

If the CLI is not installed the widget hides itself instead of rendering a broken icon.

Bar widget plus a panel: mode picker, a per-mode Whisper model picker limited to models
already installed on the machine, a dictation language picker, an editor shortcut, and an
opt-in notification setting. IPC routes: `toggle` opens the panel, `toggleMode` switches,
plus `setMode`, `setModel`, `setLanguage`, `toggleNotify`, `editConfig` and `refresh`.

Verified on Omarchy 4.0.0, voxtype 0.7.5, Hyprland, RTX 4060. `omarchy plugin validate`
exits 0, and the install path was tested end to end with `omarchy plugin add <url>
--enable` from a clean state.
```

**Submission checklist** (all five required)

| # | Item | Status |
|---|---|---|
| 1 | Repository is public with installation/removal instructions | Yes — README has both `omarchy plugin add` and the `disable`/`remove` pair |
| 2 | License and dependencies documented | Yes — MIT in `LICENSE`; the Requirements table names every external dependency and its license |
| 3 | Ownership/permission confirmed | Yes — sole author; the preview image is a screenshot of this widget on the author's own machine |
| 4 | Plugin respects user configuration | Yes, with disclosure — it writes `notifyOnSwitch` to its own `shell.json` entry, and the `model` / `language` keys of `~/.config/voxtype/config.{cpu,gpu}.toml`. Both only in response to an explicit choice in the panel; nothing is written on load, poll or open, and no other key in those files is touched |
| 5 | Approval is listing-only, not a security review | Understood |

---

## Against the automated security baseline

The baseline statically flags four patterns. None apply:

| Flagged pattern | This plugin |
|---|---|
| Download-to-shell execution (`curl … \| sh`) | No network access at all |
| Unpinned external git sources | No git operations |
| Passwordless sudoers policies | No sudo anywhere — that is the point of the underlying CLI |
| Privileged process control via shared `/tmp` state | State lives in `$XDG_RUNTIME_DIR`, per-user; the daemon is a systemd **user** service |
