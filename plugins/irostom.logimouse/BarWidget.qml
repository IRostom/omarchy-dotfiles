import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "irostom.logimouse"

  // Owns its own Service instance directly instead of looking one up via
  // bar.shell.serviceFor(moduleName). That cross-plugin lookup only resolves
  // to a live object under a first-party (trusted) bar — a third-party bar
  // only ever gets a service-less facade back. Service.qml never actually
  // reads its `shell`/`manifest` properties, and process-spawning
  // (Quickshell.Io) isn't gated by plugin trust at all, so instantiating it
  // as a private child here works under any bar, exactly like the built-in
  // Bluetooth widget owns its own D-Bus connection instead of fetching one
  // from the shell. Service.qml is a sibling file, so QML's implicit
  // same-directory import already exposes it as the bare `Service` type.
  Service { id: mouseService }
  readonly property var mouse: mouseService
  readonly property bool ready: !!mouse && mouse.initialized === true
  readonly property bool connected: ready && mouse.connected === true
  readonly property int battery: ready ? mouse.battery : -1

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: content.implicitWidth
  readonly property real openPanelIndicatorHeight: content.implicitHeight

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("mouse" in target) target.mouse = root.mouse
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  onMouseChanged: Qt.callLater(injectPanel)
  Component.onCompleted: Qt.callLater(injectPanel)

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml") + "?v=tabs"
    visible: false
    onLoaded: root.injectPanel()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    dimmed: !root.connected
    tooltipText: (root.mouse && root.connected)
      ? (String(root.mouse.name || "Omalogimouse") + (root.battery >= 0 ? " · " + root.battery + "%" : ""))
      : "Omalogimouse — offline"
    fixedWidth: root.vertical ? -1 : Math.round(content.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.round(content.implicitHeight + scaledVerticalPadding * 2) : -1

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton && root.mouse && root.connected && root.mouse.hasHaptic) root.mouse.playHaptic()
      else if (buttonCode === Qt.RightButton && root.mouse) root.mouse.refresh()
      else root.toggle()
    }

    Item {
      id: content
      anchors.centerIn: parent
      implicitWidth: row.implicitWidth
      implicitHeight: row.implicitHeight

      Row {
        id: row
        spacing: Style.space(4)
        anchors.centerIn: parent

        Text {
          textFormat: Text.PlainText
          text: "󰍽"
          color: button.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          opacity: root.connected ? 1 : 0.45
        }

        Text {
          visible: root.battery >= 0 && !root.vertical
          textFormat: Text.PlainText
          text: root.battery + "%"
          color: root.battery >= 0 && root.battery <= 20
            ? (root.bar && root.bar.urgent ? root.bar.urgent : button.foreground)
            : button.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          opacity: root.connected ? 1 : 0.45
        }
      }
    }
  }
}
