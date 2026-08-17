# Voxtype Mode — Omarchy bar widget

Shows whether the [voxtype](https://voxtype.io) dictation daemon is running on **CPU** or
**GPU**, and switches between them on click.

![The widget in both states](preview.png)

| State | Icon | Meaning |
|---|---|---|
| CPU mode | 󰻠 | Small model on the CPU. Zero VRAM held — the gaming state. |
| GPU mode | 󰢮 (highlighted) | Large model on the GPU. Best accuracy, ~1.5 GB VRAM resident. |
| Switching | 󰔟 (dimmed) | Daemon restarting and loading the new model. |

The tooltip carries the details: active mode, model name, VRAM held, and the service state
if it is anything other than `active`.

## Why

The voxtype daemon loads its Whisper model at startup and keeps it resident for as long as
it runs — there is no idle-unload setting. On an 8 GB card, `large-v3-turbo` is ~19% of
your VRAM gone before a game even starts. Stopping the service frees it but costs you
dictation entirely.

This widget is the one-click front end for switching between the two, without giving up
dictation in either state.

## Requirements

**This widget is a front end. It does nothing on its own** — it needs the `voxtype-mode`
CLI on your `PATH`:

| Dependency | Why | License |
|---|---|---|
| [`voxtype-mode`](https://github.com/Chernicharo/voxtype-mode), recent enough to support `status --json` | Provides `voxtype-mode status --json` and `voxtype-mode toggle` — the only two commands this widget ever runs | MIT |
| [voxtype](https://voxtype.io) | The dictation daemon being switched | see upstream |
| Omarchy Quattro (4.x) | The Quickshell bar host that loads the plugin | — |

`nvidia-smi` is optional; without it the tooltip simply omits the VRAM figure.

Install the CLI first:

```bash
git clone https://github.com/Chernicharo/voxtype-mode ~/personal/voxtype-mode
cd ~/personal/voxtype-mode && ./install.sh
```

Verify it before installing the widget — if this prints JSON, the widget will work:

```bash
voxtype-mode status --json
```

## Install

```bash
omarchy plugin add https://github.com/Chernicharo/omarchy-plugin-voxtype-mode --enable
```

Pick a bar section when prompted, or place it afterwards:

```bash
omarchy bar move io.github.chernicharo.voxtype-mode --section right
```

The widget appears immediately. If you also want the [keybinding](#keybinding), restart the
shell once — the IPC route registers on a full start, not on the hot reload:

```bash
omarchy restart shell
```

## Remove

```bash
omarchy plugin disable io.github.chernicharo.voxtype-mode
omarchy plugin remove io.github.chernicharo.voxtype-mode
```

Removing the widget does not touch the `voxtype-mode` CLI, your voxtype configs, or the
active mode. Uninstall the CLI separately with its own `./uninstall.sh`.

## Behaviour notes

- **The widget is a reader, not the source of truth.** The mode is also switchable from a
  keybinding and from the terminal, so the widget polls `voxtype-mode status --json` every
  30 seconds and refreshes immediately after its own toggle finishes.
- **It hides itself when the CLI is missing** rather than showing a broken icon. If the
  widget never appears, run `voxtype-mode status --json` by hand to see why.
- **Switching is not instant.** The daemon restarts and waits for the model to load, which
  takes a few seconds; the icon dims to 󰔟 for the duration and clicks are ignored until it
  completes.
- **No sudo, no system files, no shared state.** Everything runs through the systemd *user*
  service, and the active mode lives in `$XDG_RUNTIME_DIR` (per-user, wiped on logout) —
  not in `/tmp`.

## Keybinding

The widget exposes an IPC route, so a key can drive the same toggle a click does — and the
bar icon reports the progress, instead of a notification covering whatever you are doing:

```bash
omarchy-shell io.github.chernicharo.voxtype-mode toggle
```

**Suggested key: `SUPER + CTRL + SHIFT + X`.** Omarchy already keeps voxtype on `X`
(`SUPER + CTRL + X` toggles dictation, `F9` is push-to-talk), so adding `SHIFT` reads as
"toggle *how* dictation runs" on the same key. Nothing in stock Omarchy claims the combo.

Add it to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + SHIFT + X", "Toggle voxtype CPU/GPU mode",
  [[bash -c 'omarchy-shell io.github.chernicharo.voxtype-mode toggle 2>/dev/null || notify-send -a voxtype "voxtype" "$(voxtype-mode toggle 2>&1)"']])
```

Hyprland reloads on save; confirm with `hyprctl configerrors` and
`omarchy menu keybindings --print`.

> **The IPC target only registers on a full shell start**, not on the hot reload that
> `omarchy plugin add` triggers. Until you run `omarchy restart shell` once, the target does
> not exist. That is exactly what the `||` fallback is for: it calls the CLI directly and
> notifies, so the key works in the gap and in any session where the shell is not running.

Widget, keybinding and terminal all end up in the same CLI, so they cannot disagree about
the current mode.

An `omarchy-shell io.github.chernicharo.voxtype-mode refresh` route exists too, if you want
to force a re-read after changing the mode by some other means.

### Older setups

For an Omarchy before the Lua config, the same binding in `bindings.conf` form:

```ini
bind = SUPER CTRL SHIFT, X, exec, bash -c 'omarchy-shell io.github.chernicharo.voxtype-mode toggle 2>/dev/null || notify-send -a voxtype "voxtype" "$(voxtype-mode toggle 2>&1)"'
```

## License

MIT — see [LICENSE](LICENSE).

Not affiliated with, sponsored by, or endorsed by Omarchy, 37signals, or voxtype.
