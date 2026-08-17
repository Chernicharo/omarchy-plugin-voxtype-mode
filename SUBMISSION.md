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

It runs only that CLI — `voxtype-mode status --json` to read state on a 30s poll, and
`toggle`/`cpu`/`gpu` to switch — plus `notify-send` when the optional notification setting
is on. Subprocesses are spawned as argv arrays, never as shell strings, so a model name
coming from a user-edited config file cannot be reinterpreted as shell syntax.

No sudo, no system files, no network access. The only thing it writes is its own entry in
~/.config/omarchy/shell.json, through the shell's own settings API. The switched daemon is
a systemd *user* service, and the active mode is stored in $XDG_RUNTIME_DIR (per-user,
wiped on logout) rather than a shared path in /tmp.

If the CLI is not installed the widget hides itself instead of rendering a broken icon.

Bar widget plus a panel (mode picker showing the model each mode loads, and an opt-in
notification setting). IPC routes: `toggle` opens the panel, `toggleMode` switches, plus
`setMode`, `toggleNotify` and `refresh`.

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
| 4 | Plugin respects user configuration | Yes — writes nothing outside its plugin folder; the mode it changes is the CLI's own runtime state |
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
