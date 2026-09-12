import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Bar icon + popup for a local Ollama server: reachability, version, the
// context window and memory each loaded model is holding, a switch that
// stops the running server (or starts a fresh one), and the context length
// a freshly-started server should use.
Panel {
  id: root
  moduleName: "irostom.ollama"
  ipcTarget: "irostom.ollama"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for toggleServer below (mirrors Bluetooth's pattern).
  manageIpc: false

  readonly property string apiBase: "http://127.0.0.1:11434"
  readonly property var contextPresets: [4096, 8192, 16384, 32768, 65536, 131072]

  // Last-confirmed reality from polling.
  property bool running: false
  property bool checking: true
  property string version: ""
  property var models: []

  // Context length (tokens) a freshly-started server should use via
  // OLLAMA_CONTEXT_LENGTH. 0 = unset, i.e. Ollama's own default.
  property int contextLength: 0

  // Optimistic target set by the switch: -1 = none (follow `running`),
  // 0 = user asked to stop, 1 = user asked to start. `desiredAttempts`
  // counts fast-poll cycles spent waiting for reality to catch up — a
  // stopping server can take a few seconds to unload a model and release
  // the port, and a starting one to bind it, so a single poll that still
  // disagrees with the desired state must not be taken as "it didn't
  // work" and snap the switch back.
  property int desired: -1
  property int desiredAttempts: 0
  readonly property int maxDesiredAttempts: 20 // ~20s of fast polling

  readonly property bool busy: desired !== -1
  readonly property bool effectiveRunning: desired === -1 ? running : (desired === 1)

  readonly property string phaseLabel: {
    if (desired === 0) return "STOPPING…"
    if (desired === 1) return "STARTING…"
    return effectiveRunning ? ("RUNNING" + (version !== "" ? " · v" + version : "")) : "STOPPED"
  }

  readonly property string statusLabel: {
    if (desired === 0) return "Stopping…"
    if (desired === 1) return "Starting…"
    if (root.checking && root.version === "" && !root.running) return "Checking…"
    if (!root.effectiveRunning) return "Not running"
    return root.models.length === 1 ? "1 model loaded" : root.models.length + " models loaded"
  }

  readonly property color indicatorColor: {
    if (root.busy) return Color.muted
    if (root.checking && root.version === "" && !root.running) return Color.muted
    return root.running ? Color.accent : Color.urgent
  }

  function contextLabel(value) {
    return value === 0 ? "Default" : Model.formatContextShort(value)
  }

  function setContextLength(value) {
    var n = Math.max(0, Math.round(Number(value) || 0))
    root.contextLength = n
    settingsFile.setText(JSON.stringify({ contextLength: n }, null, 2) + "\n")
  }

  function refresh() {
    root.checking = true
    if (!versionProc.running) versionProc.running = true
  }

  // Runs the actual `ollama serve` launch, honoring the configured context
  // length. Safe to call more than once — a second bind attempt on the same
  // port just fails and exits.
  function launchServer() {
    var cmd = root.contextLength > 0
      ? "OLLAMA_CONTEXT_LENGTH=" + root.contextLength + " exec ollama serve"
      : "exec ollama serve"
    Quickshell.execDetached(["bash", "-lc", cmd])
  }

  // The switch reflects the desired state, not raw reality, so it doesn't
  // bounce while a stop/start is still landing. Flipping it off stops the
  // running server; flipping it back on starts a brand new one — two flips
  // of the same control is a full restart.
  function toggleServer() {
    if (root.busy) return
    if (root.effectiveRunning) {
      root.desired = 0
      root.desiredAttempts = 0
      root.models = []
      root.version = ""
      if (!killProc.running) killProc.running = true
    } else {
      root.desired = 1
      root.desiredAttempts = 0
      root.launchServer()
    }
    root.refresh()
  }

  // Reconciles a poll result against any pending desired state. Called from
  // every versionProc completion — the only source of truth for `running`.
  function applyRunning(nowRunning) {
    root.running = nowRunning
    if (root.desired === -1) return

    var wanted = root.desired === 1
    if (nowRunning === wanted) {
      root.desired = -1
      root.desiredAttempts = 0
      return
    }

    root.desiredAttempts += 1
    if (root.desiredAttempts >= root.maxDesiredAttempts) {
      // Stop fighting reality — surface what's actually there.
      root.desired = -1
      root.desiredAttempts = 0
      return
    }
    // Nudge again every few attempts, in case the first signal/spawn didn't
    // land (e.g. a slow model unload delayed the port release just long
    // enough that a launch raced it).
    if (root.desiredAttempts % 3 === 0) {
      if (root.desired === 0) { if (!killProc.running) killProc.running = true }
      else root.launchServer()
    }
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  property FileView settingsFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/ollama.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.contextLength = Model.parseSettings(text()).contextLength
    onLoadFailed: root.contextLength = 0
  }

  // Polls regardless of whether the panel is open, since the bar glyph and
  // its indicator dot are meant to stay current on their own.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // Faster cadence only while a stop/start is pending confirmation.
  Timer {
    interval: 1000
    running: root.busy
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: versionProc
    running: false
    command: ["curl", "-s", "-m", "2", root.apiBase + "/api/version"]
    stdout: StdioCollector {
      id: versionStdout
      waitForEnd: true
      onStreamFinished: root._versionOutput = text
    }
    onExited: function(exitCode) {
      var raw = String(versionStdout.text || root._versionOutput || "")
      root.checking = false
      if (exitCode === 0 && raw !== "") {
        root.version = Model.parseVersion(raw)
        if (!psProc.running) psProc.running = true
        root.applyRunning(true)
      } else {
        root.version = ""
        root.models = []
        root.applyRunning(false)
      }
    }
  }
  property string _versionOutput: ""

  Process {
    id: psProc
    running: false
    command: ["curl", "-s", "-m", "2", root.apiBase + "/api/ps"]
    stdout: StdioCollector {
      id: psStdout
      waitForEnd: true
      onStreamFinished: root._psOutput = text
    }
    onExited: function(exitCode) {
      var raw = String(psStdout.text || root._psOutput || "")
      root.models = (exitCode === 0 && raw !== "") ? Model.parseModels(raw) : []
    }
  }
  property string _psOutput: ""

  Process {
    id: killProc
    running: false
    // Matches "ollama serve" whether it was launched bare or by full path
    // (e.g. systemd's /usr/bin/ollama serve) — anchoring to "^ollama"
    // alone missed the latter and left the switch fighting a server that
    // was never actually signaled.
    command: ["pkill", "-TERM", "-f", "(^|/)ollama serve$"]
  }

  IpcHandler {
    target: "irostom.ollama"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function toggleServer(): void { root.toggleServer() }
    function setContextLength(tokens: string): void { root.setContextLength(Number(tokens)) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰳆"
    tooltipText: "Ollama — " + root.statusLabel
    onPressed: function(b) { root.toggle() }

    Rectangle {
      width: Style.space(7)
      height: Style.space(7)
      radius: width / 2
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: Style.space(4)
      anchors.bottomMargin: Style.space(4)
      color: root.indicatorColor
      border.width: Math.max(1, Style.space(1))
      border.color: root.bar ? root.bar.background : Color.background

      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        PanelHero {
          iconComponent: Component {
            Text {
              textFormat: Text.PlainText
              text: "󰳆"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              opacity: root.effectiveRunning ? 1.0 : 0.5
            }
          }
          title: "Ollama"
          meta: root.phaseLabel
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          trailingControl: Component {
            ToggleSwitch {
              id: powerSwitch
              checked: root.effectiveRunning
              busy: root.busy
              foreground: root.bar.foreground
              onToggled: root.toggleServer()

              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: root.running ? "Stop the server" : "Start a new server"
                fontFamily: root.bar.fontFamily
              }
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "LOADED MODELS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Text {
            textFormat: Text.PlainText
            visible: root.running && root.models.length === 0
            text: "No model loaded — send it a prompt to load one."
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            visible: !root.running
            text: root.checking ? "Checking for a server…" : "Server is not reachable on " + root.apiBase + "."
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            width: parent.width
          }

          Repeater {
            model: root.running ? root.models : []

            ModelRow {
              required property var modelData
              width: column.width
              entry: modelData
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(ctxHeader.implicitHeight, ctxValue.implicitHeight)

            PanelSectionHeader {
              id: ctxHeader
              text: "CONTEXT LENGTH ON START"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: ctxValue
              textFormat: Text.PlainText
              text: root.contextLabel(root.contextLength)
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Grid {
            id: contextGrid
            width: parent.width
            columns: 4
            spacing: Style.spacing.xs

            readonly property var options: [0].concat(root.contextPresets)
            readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

            Repeater {
              model: contextGrid.options

              ContextPill {
                required property int modelData
                value: modelData
                width: contextGrid.cellWidth
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Sets OLLAMA_CONTEXT_LENGTH the next time the server starts. Flip the switch off then on to apply it now."
            color: Qt.darker(root.bar.foreground, 1.5)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            width: parent.width
          }
        }
      }
    }
  }

  component ContextPill: Button {
    id: pill
    required property int value

    text: root.contextLabel(value)
    fontSize: Style.font.caption
    foreground: root.bar.foreground
    fontFamily: root.bar.fontFamily
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.controlPaddingY
    bordered: true
    active: root.contextLength === value

    onClicked: root.setContextLength(value)
  }

  component ModelRow: Item {
    id: row
    required property var entry

    implicitHeight: rowColumn.implicitHeight + Style.space(10)

    Column {
      id: rowColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: row.entry.name
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        textFormat: Text.PlainText
        text: [
          Model.formatContext(row.entry.contextLength) + " context",
          Model.formatBytes(row.entry.sizeVram),
          Model.formatExpiresIn(row.entry.expiresAt)
        ].filter(function(s) { return s !== "" }).join(" · ")
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: parent.width
      }
    }
  }
}
