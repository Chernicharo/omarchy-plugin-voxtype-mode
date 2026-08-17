# Voxtype Mode — Omarchy bar widget

Shows whether the [voxtype](https://voxtype.io) dictation daemon is running on **CPU** or
**GPU**, and switches between them on click.

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
| [`voxtype-mode`](https://github.com/Chernicharo/voxtype-mode) ≥ 1.1 | Provides `voxtype-mode status --json` and `voxtype-mode toggle`, which are the only two commands this widget runs | MIT |
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

## Pairs well with a keybinding

The CLI documents a matching Hyprland binding (`SUPER + CTRL + SHIFT + X`) that sits next
to Omarchy's own voxtype bindings on `X`. The widget and the keybinding stay in sync
because both go through the same CLI. See the
[voxtype-mode README](https://github.com/Chernicharo/voxtype-mode#keybinding-omarchy--hyprland).

## License

MIT — see [LICENSE](LICENSE).

Not affiliated with, sponsored by, or endorsed by Omarchy, 37signals, or voxtype.
