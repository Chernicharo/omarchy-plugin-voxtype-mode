import QtQuick
import Quickshell.Io
import qs.Ui

// Bar widget for voxtype-mode: shows which mode the dictation daemon is in and
// switches on click.
//
// All state comes from `voxtype-mode status --json`; this widget owns no state
// of its own. That matters because the mode is also switched from a keybinding
// and from the terminal, so the widget has to be a reader that polls, not the
// source of truth.
BarWidget {
  id: root
  moduleName: "io.github.chernicharo.voxtype-mode"

  // Mirrors the JSON payload. `mode` stays empty until the first successful
  // read, which is what keeps the widget hidden on machines without the CLI.
  property string mode: ""
  property string model: ""
  property string service: ""
  property var vramMb: null
  property bool switching: false

  readonly property bool gpu: mode === "gpu"

  // A switch restarts the daemon and waits for the model to load, so the CLI
  // can block for several seconds. Poll slowly in the background; the click
  // path refreshes on its own the moment the toggle returns.
  readonly property int pollInterval: 30000

  visible: mode !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggle() {
    if (switching || toggleProc.running) return
    switching = true
    toggleProc.running = true
  }

  function applyStatus(raw) {
    var text = String(raw || "").trim()
    if (text === "") return
    try {
      var data = JSON.parse(text)
      root.mode = String(data.mode || "")
      root.model = String(data.model || "")
      root.service = String(data.service || "")
      // null is meaningful: it means no nvidia-smi, as opposed to 0 MiB held.
      root.vramMb = (data.vram_mb === null || data.vram_mb === undefined) ? null : data.vram_mb
    } catch (e) {
      // A malformed read leaves the previous state on screen rather than
      // blanking the widget; the next poll will correct it.
    }
  }

  function tooltip() {
    if (switching) return "voxtype: switching mode…"
    var parts = ["voxtype: " + (gpu ? "GPU" : "CPU") + " mode"]
    if (model !== "") parts.push("model " + model)
    if (vramMb !== null) parts.push(vramMb + " MiB VRAM")
    if (service !== "" && service !== "active") parts.push("service " + service)
    return parts.join("  ·  ") + "\nClick to switch to " + (gpu ? "CPU" : "GPU")
  }

  // Lets a keybinding drive the same toggle the click does, so a switch fired
  // from the keyboard still shows its progress on the icon.
  //
  // Note the asymmetry: `toggle` deliberately does NOT broadcast. A bar surface
  // exists per monitor, so broadcasting would spawn one `voxtype-mode toggle`
  // per screen — on two monitors the second switch would undo the first. The
  // switch runs once here; it is the resulting refresh that fans out.
  IpcHandler {
    target: "io.github.chernicharo.voxtype-mode"

    function toggle(): void {
      root.toggle()
    }

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: statusProc
    command: ["voxtype-mode", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: toggleProc
    command: ["voxtype-mode", "toggle"]
    onExited: {
      root.switching = false
      // Every monitor's copy has to re-read, not just the one that was clicked.
      root.broadcast("refresh")
    }
  }

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // cpu-64-bit / expansion-card-variant / timer-sand, all present in the
    // Nerd Font the bar resolves to.
    text: root.switching ? "󰔟" : (root.gpu ? "󰢮" : "󰻠")
    // GPU is the state worth flagging: it is the one holding VRAM.
    active: root.gpu
    dimmed: root.switching
    tooltipText: root.tooltip()
    onPressed: function (b) {
      root.toggle()
    }
  }
}
