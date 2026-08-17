import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button plus a popup panel for voxtype-mode: pick CPU or GPU explicitly,
// see which model each one loads, and choose whether a switch announces itself.
//
// All state comes from `voxtype-mode status --json`; this panel owns no state
// of its own. That matters because the mode is also switched from a keybinding
// and from the terminal, so it has to be a reader that polls, not the source of
// truth.
Panel {
  id: root
  moduleName: "io.github.chernicharo.voxtype-mode"
  ipcTarget: "io.github.chernicharo.voxtype-mode"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — the base only exposes open/close/toggle, and the mode switch
  // needs a route of its own.
  manageIpc: false

  // ---- state mirrored from the CLI ----------------------------------------
  property string mode: ""
  property string model: ""
  property string cpuModel: ""
  property string gpuModel: ""
  property string service: ""
  property var vramMb: null
  property var gpuFreeMb: null
  property bool switching: false

  readonly property bool gpu: mode === "gpu"
  readonly property bool known: mode !== ""

  // Off by default: the bar icon already reports the switch, so a notification
  // on top of it is redundant. Opt in when the bar is not where you are looking.
  readonly property bool notifyOnSwitch: setting("notifyOnSwitch", false) === true

  // A switch restarts the daemon and waits for the model to load, so the CLI
  // can block for several seconds. Poll slowly in the background; every path
  // that changes the mode refreshes on its own the moment it finishes.
  readonly property int pollInterval: 30000

  property bool cursorActive: false
  property int modeIndex: 0

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // The Panel base is a bare Item: without an explicit size the bar gives the
  // widget zero width and nothing paints. Collapsing to 0 when the CLI is
  // missing also means the slot takes no space at all, rather than leaving a
  // gap where an invisible button would be.
  visible: known
  implicitWidth: known ? button.implicitWidth : 0
  implicitHeight: known ? button.implicitHeight : 0

  // cpu-64-bit / expansion-card-variant / timer-sand
  function iconFor(which) {
    if (which === "switching") return "󰔟"
    return which === "gpu" ? "󰢮" : "󰻠"
  }

  function modelFor(which) {
    var name = which === "gpu" ? gpuModel : cpuModel
    return name === "" ? "no model set" : name
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function setMode(next) {
    if (switching || toggleProc.running || next === mode) return
    switching = true
    modeProc.command = ["voxtype-mode", next]
    modeProc.running = true
  }

  function toggleMode() {
    if (switching || modeProc.running) return
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
      var models = data.models || {}
      root.cpuModel = String(models.cpu || "")
      root.gpuModel = String(models.gpu || "")
      // null is meaningful: it means no nvidia-smi, as opposed to 0 MiB held.
      root.vramMb = (data.vram_mb === null || data.vram_mb === undefined) ? null : data.vram_mb
      root.gpuFreeMb = (data.gpu_free_mb === null || data.gpu_free_mb === undefined) ? null : data.gpu_free_mb
      root.modeIndex = root.gpu ? 1 : 0
    } catch (e) {
      // A malformed read leaves the previous state on screen rather than
      // blanking the panel; the next poll will correct it.
    }
  }

  // Runs after a switch completes, and only when asked for. The bar icon is
  // the default report; this is the opt-in one for when you are looking
  // elsewhere.
  // Spawned as argv rather than through bar.run(), which takes a shell string:
  // model names come from a user-editable config file, and an argv array cannot
  // be reinterpreted as shell syntax no matter what is in them.
  function announce() {
    if (!notifyOnSwitch) return
    var detail = modelFor(mode)
    if (vramMb !== null) detail += " · " + vramMb + " MiB VRAM"
    notifyProc.command = ["notify-send", "-a", "voxtype", "voxtype",
                          (gpu ? "GPU" : "CPU") + " mode — " + detail]
    notifyProc.running = true
  }

  function finishSwitch() {
    switching = false
    // Every monitor's copy has to re-read, not just the one that was clicked.
    if (bar && typeof bar.moduleWidgets === "function") {
      var peers = bar.moduleWidgets(moduleName)
      for (var i = 0; i < peers.length; i++)
        if (peers[i] && typeof peers[i].refresh === "function") peers[i].refresh()
    } else {
      refresh()
    }
    statusSettled.restart()
  }

  function tooltip() {
    if (switching) return "voxtype: switching mode…"
    var parts = ["voxtype: " + (gpu ? "GPU" : "CPU") + " mode", modelFor(mode)]
    if (vramMb !== null) parts.push(vramMb + " MiB VRAM")
    if (service !== "" && service !== "active") parts.push("service " + service)
    return parts.join("  ·  ")
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function toggleNotify() {
    persistSettings({ notifyOnSwitch: !root.notifyOnSwitch })
  }

  function activateSelected() {
    if (modeIndex === 2) toggleNotify()
    else setMode(modeIndex === 1 ? "gpu" : "cpu")
  }

  function moveCursor(delta) {
    var next = modeIndex + delta
    modeIndex = Math.max(0, Math.min(2, next))
  }

  // ---- IPC ----------------------------------------------------------------
  //
  // `toggle` keeps the meaning the Panel base gives it — open/close the popup —
  // so the panel behaves like every other Omarchy panel. The mode switch gets
  // `toggleMode`, deliberately not broadcast: a bar surface exists per monitor,
  // so broadcasting would spawn one `voxtype-mode` per screen and the second
  // switch would undo the first.
  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }

    function toggleMode(): void { root.toggleMode() }
    function setMode(mode: string): void { root.setMode(mode === "gpu" ? "gpu" : "cpu") }
    function toggleNotify(): void { root.toggleNotify() }
    function refresh(): void { root.refresh() }
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
    onExited: root.finishSwitch()
  }

  Process {
    id: modeProc
    command: ["voxtype-mode", "cpu"]
    onExited: root.finishSwitch()
  }

  Process {
    id: notifyProc
    command: ["true"]
  }

  // The refresh fired straight after a switch races the daemon's own settling,
  // so re-read once more a moment later before announcing — otherwise the
  // notification can quote the VRAM figure from mid-load.
  Timer {
    id: statusSettled
    interval: 900
    repeat: false
    onTriggered: {
      root.refresh()
      root.announce()
    }
  }

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // ---- bar button ---------------------------------------------------------
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.switching ? root.iconFor("switching") : root.iconFor(root.mode)
    // GPU is the state worth flagging: it is the one holding VRAM.
    active: root.gpu
    dimmed: root.switching
    tooltipText: root.opened ? "" : root.tooltip()
    onPressed: function (b) {
      // Right-click switches without opening the panel — the fast path stays
      // one gesture, the way it was before the panel existed.
      if (b === Qt.RightButton) root.toggleMode()
      else root.toggle()
    }
  }

  // ---- popup panel --------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.known
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy !== 0 ? dy : dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelected()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero: icon · title/status · VRAM ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: root.switching ? root.iconFor("switching") : root.iconFor(root.mode)
            color: root.gpu ? (root.bar ? root.bar.urgent : Color.urgent) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Voxtype"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: {
                if (root.switching) return "SWITCHING…"
                var line = (root.gpu ? "GPU" : "CPU") + " MODE"
                if (root.service !== "" && root.service !== "active")
                  line += " · " + root.service.toUpperCase()
                return line
              }
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              visible: root.vramMb !== null
              text: root.vramMb + " MiB held · " + (root.gpuFreeMb === null ? "?" : root.gpuFreeMb) + " MiB free"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { width: parent.width }

        PanelSectionHeader {
          width: parent.width
          text: "Mode"
          fontFamily: root.fontFamily
          foreground: root.foreground
        }

        // ---------- Mode rows ----------
        Repeater {
          model: [
            { key: "cpu", label: "CPU", note: "frees all VRAM" },
            { key: "gpu", label: "GPU", note: "best accuracy" }
          ]

          Rectangle {
            id: row
            required property var modelData
            required property int index

            readonly property bool isActive: root.mode === modelData.key
            readonly property bool hasCursor: root.cursorActive && root.modeIndex === index

            width: column.width
            height: Style.space(46)
            radius: Style.cornerRadius
            color: hasCursor
              ? (root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent")
              : (rowMouse.containsMouse
                 ? (root.bar ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent")
                 : "transparent")

            Text {
              id: rowIcon
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: root.iconFor(row.modelData.key)
              color: row.isActive
                ? (row.modelData.key === "gpu" ? (root.bar ? root.bar.urgent : Color.urgent) : root.foreground)
                : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
            }

            Column {
              anchors.left: rowIcon.right
              anchors.leftMargin: Style.space(12)
              anchors.right: rowMark.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: row.modelData.label + " mode"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.modelFor(row.modelData.key) + " · " + row.modelData.note
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Text {
              id: rowMark
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              // A check for the active mode, an hourglass on the one being
              // loaded, nothing on the idle one.
              text: root.switching && row.isActive ? "󰔟" : (row.isActive ? "󰄬" : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: { root.cursorActive = true; root.modeIndex = row.index }
              onClicked: root.setMode(row.modelData.key)
            }
          }
        }

        PanelSeparator { width: parent.width }

        PanelSectionHeader {
          width: parent.width
          text: "Options"
          fontFamily: root.fontFamily
          foreground: root.foreground
        }

        // ---------- Notify toggle ----------
        Rectangle {
          id: notifyRow
          readonly property bool hasCursor: root.cursorActive && root.modeIndex === 2

          width: column.width
          height: Style.space(46)
          radius: Style.cornerRadius
          color: hasCursor
            ? (root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent")
            : (notifyMouse.containsMouse
               ? (root.bar ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent")
               : "transparent")

          Column {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.right: notifySwitch.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              text: "Notify on switch"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.notifyOnSwitch ? "notifies on every switch"
                                        : "silent — bar icon only"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ToggleSwitch {
            id: notifySwitch
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            checked: root.notifyOnSwitch
            foreground: root.foreground
            accent: Color.accent
            hasCursor: notifyRow.hasCursor
            onToggled: root.toggleNotify()
          }

          MouseArea {
            id: notifyMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { root.cursorActive = true; root.modeIndex = 2 }
            // The switch handles its own clicks; this only covers the label area.
            onClicked: function (mouse) {
              if (mouse.x < notifySwitch.x) root.toggleNotify()
            }
          }
        }
      }
    }
  }
}
