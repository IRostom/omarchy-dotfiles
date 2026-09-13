import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import "Model.js" as Model

// A macOS-Control-Center-style popup: four zones (connectivity, sound, now
// playing, quick toggles) built entirely from the same Ui kit and services
// every other first-party panel already uses. Nothing here owns real state —
// it reads/drives the same services and IPC targets the standalone
// Network/Bluetooth/Audio/Media panels and bar indicators do, so this is a
// second window onto the same state rather than a competing copy of it.
Panel {
  id: root
  moduleName: "irostom.commandcenter"
  ipcTarget: "irostom.commandcenter"

  // ---------------------------------------------------------------- services
  //
  // `bar.shell.firstPartyServiceFor()` only resolves for the bar itself and
  // for clones of omarchy.indicators (see shell.qml's createScopedPluginShell:
  // firstPartyServices is only populated when barCapabilities/indicatorsAllowed
  // is true) — a plain bar-widget plugin like this one always gets null back,
  // silently. So these four zones talk to the same first-party services the
  // same way Zone 1 does: through their public `omarchy-shell <target> <cmd>`
  // IPC, polled on a timer while the popup is open.
  property bool stayAwake: false
  property bool nightlightOn: false
  property bool dndOn: false
  property var media: ({
    hasPlayer: false, playing: false, title: "", artist: "", artUrl: "",
    canGoNext: false, canGoPrevious: false, canTogglePlaying: false
  })

  function refreshQuickActions() {
    if (!idleProc.running) idleProc.running = true
    if (!nightlightProc.running) nightlightProc.running = true
    if (!dndProc.running) dndProc.running = true
    if (!mediaProc.running) mediaProc.running = true
  }

  function toggleStayAwake() {
    Quickshell.execDetached(["omarchy-shell", "idle", "toggle"])
    actionRefreshTimer.restart()
  }

  function toggleNightlight() {
    Quickshell.execDetached(["omarchy-shell", "nightlight", "toggle"])
    actionRefreshTimer.restart()
  }

  function toggleDnd() {
    Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"])
    actionRefreshTimer.restart()
  }

  function mediaAction(action) {
    Quickshell.execDetached(["omarchy-shell", "media", action])
    actionRefreshTimer.restart()
  }

  Timer { id: actionRefreshTimer; interval: 500; repeat: false; onTriggered: root.refreshQuickActions() }

  // ---------------------------------------------------------------- sound
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real outputVolume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false

  function setOutputVolume(v) {
    if (!sink || !sink.audio) return
    sink.audio.volume = Math.max(0, Math.min(1.5, v))
  }

  function toggleMuted() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
  }

  // ---------------------------------------------------------------- wi-fi
  property var netInfo: ({ kind: "disconnected", label: "", signalStrength: -1 })

  function refreshNetwork() {
    if (!netProc.running) netProc.running = true
  }

  function toggleWifi() {
    Networking.wifiEnabled = !Networking.wifiEnabled
  }

  function openNetworkPanel() {
    if (root.bar) root.bar.run("omarchy-shell irostom.commandcenter close; omarchy-shell omarchy.network toggle")
  }

  // ---------------------------------------------------------------- bluetooth
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var btDevices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var connectedBtDevices: btDevices.filter(function(d) { return d && d.connected })

  function toggleBluetooth() {
    if (!adapter) return
    Quickshell.execDetached(["omarchy-bluetooth-power", adapter.enabled ? "off" : "on"])
  }

  function openBluetoothPanel() {
    if (root.bar) root.bar.run("omarchy-shell irostom.commandcenter close; omarchy-shell omarchy.bluetooth toggle")
  }

  // ---------------------------------------------------------------- screen recording
  property bool recording: false

  function refreshRecording() {
    if (!recProc.running) recProc.running = true
  }

  function toggleRecording() {
    if (root.bar) root.bar.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-menu toggle trigger.capture.screenrecord")
  }

  // ---------------------------------------------------------------- lifecycle
  function refresh() {
    refreshNetwork()
    refreshRecording()
    refreshQuickActions()
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Timer { interval: 4000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  Process {
    id: netProc
    command: ["omarchy-network-status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.netInfo = Model.parseNetworkStatus(text) }
  }

  Process {
    id: recProc
    command: ["pgrep", "--quiet", "-f", "^gpu-screen-recorder"]
    onExited: function(exitCode) { root.recording = exitCode === 0 }
  }

  Process {
    id: idleProc
    command: ["omarchy-shell", "idle", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.stayAwake = !!JSON.parse(text).stayAwake } catch (e) {}
      }
    }
  }

  Process {
    id: nightlightProc
    command: ["omarchy-shell", "nightlight", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.nightlightOn = !!JSON.parse(text).enabled } catch (e) {}
      }
    }
  }

  Process {
    id: dndProc
    command: ["omarchy-shell", "notifications", "dndState"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.dndOn = text.trim() === "on" }
  }

  Process {
    id: mediaProc
    command: ["omarchy-shell", "media", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.media = JSON.parse(text) } catch (e) {}
      }
    }
  }

  // No explicit IpcHandler here — Panel's own `manageIpc` (default true)
  // already registers open/close/show/hide/toggle for `ipcTarget` above;
  // a second one just collides with it (see Ui/Panel.qml).

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Command Center"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(16)

        // ================================================== Zone 1: connectivity
        Column {
          width: parent.width
          spacing: Style.space(8)

          ConnectivityRow {
            width: parent.width
            icon: Model.wifiIcon(Networking.wifiEnabled, root.netInfo.kind, root.netInfo.signalStrength)
            title: "Wi-Fi"
            status: Model.wifiStatusText(Networking.wifiEnabled, root.netInfo.kind, root.netInfo.label)
            checked: Networking.wifiEnabled
            onOpenRequested: root.openNetworkPanel()
            onToggleRequested: root.toggleWifi()
          }

          ConnectivityRow {
            width: parent.width
            icon: Model.bluetoothIcon(!!(root.adapter && root.adapter.enabled), root.connectedBtDevices.length)
            title: "Bluetooth"
            status: root.adapter ? Model.bluetoothStatusText(root.adapter.enabled, root.connectedBtDevices) : "Unavailable"
            checked: !!(root.adapter && root.adapter.enabled)
            enabled: !!root.adapter
            onOpenRequested: root.openBluetoothPanel()
            onToggleRequested: root.toggleBluetooth()
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ========================================================= Zone 2: sound
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "SOUND"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            PanelActionButton {
              iconText: Model.volumeIcon(root.outputVolume, root.outputMuted)
              foreground: root.bar.foreground
              fontSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.toggleMuted()
            }

            PanelSlider {
              id: volumeSlider
              bar: root.bar
              width: parent.width - Style.space(44) - volumeLabel.implicitWidth - parent.spacing * 2
              anchors.verticalCenter: parent.verticalCenter
              value: root.outputVolume
              minimum: 0
              maximum: 1
              step: 0.05
              opacity: root.outputMuted ? 0.5 : 1.0
              enabled: !!root.sink
              onMoved: function(v) { root.setOutputVolume(v) }
              onRightClicked: root.toggleMuted()
            }

            Text {
              id: volumeLabel
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: root.outputMuted ? "Muted" : Math.round(root.outputVolume * 100) + "%"
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              width: Style.space(44)
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ==================================================== Zone 3: now playing
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "NOW PLAYING"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            BorderSurface {
              width: Style.space(44)
              height: Style.space(44)
              radius: Style.spacing.labelGap
              anchors.verticalCenter: parent.verticalCenter
              color: Style.normalFillFor(root.bar.foreground, Color.accent)
              borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

              Image {
                anchors.fill: parent
                anchors.margins: Style.space(2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: root.media.artUrl || ""
                visible: source !== ""
              }

              Text {
                anchors.centerIn: parent
                visible: !root.media.artUrl
                text: "󰝚"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Column {
              width: parent.width - Style.space(54) - controlsRow.implicitWidth - parent.spacing * 2
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: root.media.hasPlayer ? (root.media.title || "Playing") : "Nothing playing"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.media.hasPlayer ? (root.media.artist || "") : ""
                visible: text !== ""
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Row {
              id: controlsRow
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              PanelActionButton {
                iconText: "󰒭"
                foreground: root.bar.foreground
                enabled: root.media.hasPlayer && root.media.canGoPrevious
                opacity: enabled ? 1.0 : 0.4
                onClicked: root.mediaAction("previous")
              }

              PanelActionButton {
                iconText: root.media.playing ? "󰏤" : "󰐊"
                foreground: root.bar.foreground
                fontSize: Style.font.title
                enabled: root.media.hasPlayer && root.media.canTogglePlaying
                opacity: enabled ? 1.0 : 0.4
                onClicked: root.mediaAction("playPause")
              }

              PanelActionButton {
                iconText: "󰒮"
                foreground: root.bar.foreground
                enabled: root.media.hasPlayer && root.media.canGoNext
                opacity: enabled ? 1.0 : 0.4
                onClicked: root.mediaAction("next")
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ==================================================== Zone 4: quick toggles
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "QUICK ACTIONS"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Grid {
            width: parent.width
            columns: 2
            rowSpacing: Style.space(8)
            columnSpacing: Style.space(8)

            readonly property real cellWidth: (width - columnSpacing) / columns

            QuickToggle {
              width: parent.cellWidth
              icon: "󰅶"
              label: "Stay Awake"
              checked: root.stayAwake
              onToggled: root.toggleStayAwake()
            }

            QuickToggle {
              width: parent.cellWidth
              icon: "󰂛"
              label: "Silence Notifications"
              checked: root.dndOn
              onToggled: root.toggleDnd()
            }

            QuickToggle {
              width: parent.cellWidth
              icon: "󰔎"
              label: "Night Light"
              checked: root.nightlightOn
              onToggled: root.toggleNightlight()
            }

            QuickButton {
              width: parent.cellWidth
              icon: "󰻂"
              label: root.recording ? "Stop Recording" : "Screen Recording"
              active: root.recording
              onClicked: root.toggleRecording()
            }
          }
        }
      }
    }
  }

  // A connectivity zone row: icon + title/status on the left, a switch on
  // the right. The switch's own MouseArea sits on top of the row's, so
  // flipping it never also fires the row's "open the real panel" click.
  component ConnectivityRow: BorderSurface {
    id: connRow

    property string icon: ""
    property string title: ""
    property string status: ""
    property bool checked: false
    // `enabled` is the built-in Item property — dimming/click-gating for a
    // missing adapter binds straight to it, no shadow property needed.

    signal openRequested()
    signal toggleRequested()

    readonly property bool hot: rowMouse.containsMouse

    implicitHeight: Style.space(52)
    radius: Style.cornerRadius
    color: Style.controlFill(false, hot, root.bar.foreground, Color.accent)
    borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", root.bar.foreground, Color.accent)
    opacity: enabled ? 1.0 : 0.5

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
      anchors.left: parent.left
      anchors.right: rowSwitch.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: connRow.borderLeft + Style.spacing.rowPaddingX
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(12)

      Text {
        textFormat: Text.PlainText
        text: connRow.icon
        anchors.verticalCenter: parent.verticalCenter
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
      }

      Column {
        width: parent.width - Style.space(30)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          text: connRow.title
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          textFormat: Text.PlainText
          text: connRow.status
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: parent.width
        }
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      enabled: connRow.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: connRow.openRequested()
    }

    ToggleSwitch {
      id: rowSwitch
      anchors.right: parent.right
      anchors.rightMargin: connRow.borderRight + Style.spacing.rowPaddingX
      anchors.verticalCenter: parent.verticalCenter
      checked: connRow.checked
      foreground: root.bar.foreground
      onToggled: connRow.toggleRequested()
    }
  }

  // A compact quick-action card: icon + label stacked, switch pinned to the
  // trailing edge. Two sit side by side in the zone-4 grid.
  component QuickToggle: BorderSurface {
    id: quickToggle

    property string icon: ""
    property string label: ""
    property bool checked: false

    signal toggled()

    readonly property bool hot: quickMouse.containsMouse

    implicitHeight: Style.space(52)
    radius: Style.cornerRadius
    color: Style.controlFill(false, hot, root.bar.foreground, Color.accent)
    borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", root.bar.foreground, Color.accent)
    opacity: enabled ? 1.0 : 0.5

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: quickToggle.borderLeft + Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: quickToggle.icon
        color: quickToggle.checked ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: 100 } }
      }

      Text {
        textFormat: Text.PlainText
        text: quickToggle.label
        width: parent.width - parent.spacing - Style.space(48)
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        wrapMode: Text.WordWrap
        anchors.verticalCenter: parent.verticalCenter
      }

      ToggleSwitch {
        checked: quickToggle.checked
        interactive: false
        foreground: root.bar.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: quickMouse
      anchors.fill: parent
      enabled: quickToggle.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: quickToggle.toggled()
    }
  }

  // A compact quick-action card that fires immediately on click, with no
  // switch of its own — for actions that aren't a persistent on/off state
  // (e.g. "start/stop recording" is a command, not a toggle to flip and
  // walk away from). `active` just tints the icon to show it's in progress.
  component QuickButton: BorderSurface {
    id: quickButton

    property string icon: ""
    property string label: ""
    property bool active: false

    signal clicked()

    readonly property bool hot: quickButtonMouse.containsMouse

    implicitHeight: Style.space(52)
    radius: Style.cornerRadius
    color: Style.controlFill(false, hot, root.bar.foreground, Color.accent)
    borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", root.bar.foreground, Color.accent)
    opacity: enabled ? 1.0 : 0.5

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: quickButton.borderLeft + Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: quickButton.icon
        color: quickButton.active ? Color.accent : root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: 100 } }
      }

      Text {
        textFormat: Text.PlainText
        text: quickButton.label
        width: parent.width - parent.spacing - Style.font.title
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        wrapMode: Text.WordWrap
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: quickButtonMouse
      anchors.fill: parent
      enabled: quickButton.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: quickButton.clicked()
    }
  }
}
