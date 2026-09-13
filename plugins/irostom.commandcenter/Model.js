// Pure helpers for the Command Center panel — icon selection and the tiny
// bit of text parsing needed to read `omarchy-network-status`'s output.
// Kept separate from Panel.qml so the glyph/format logic can be eyeballed
// (and unit-tested by hand) without wading through QML.

function parseNetworkStatus(raw) {
  // Tab-separated: kind, label (SSID or blank), signal (0-100 or -1), freq.
  var parts = String(raw || "disconnected\t\t\t").replace(/\r?\n+$/, "").split("\t")
  return {
    kind: parts[0] || "disconnected",
    label: parts[1] || "",
    signalStrength: parts[2] ? parseInt(parts[2], 10) : -1
  }
}

function wifiIcon(enabled, kind, signalStrength) {
  if (!enabled) return "󰖪"
  if (kind !== "wifi") return "󰖩"
  var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  var index = Math.max(0, Math.min(4, Math.ceil(signalStrength / 20) - 1))
  return icons[index]
}

function wifiStatusText(enabled, kind, label) {
  if (!enabled) return "Off"
  if (kind === "wifi" && label) return label
  if (kind === "ethernet") return "Ethernet"
  return "Not Connected"
}

function bluetoothIcon(enabled, connectedCount) {
  if (!enabled) return "󰂲"
  if (connectedCount > 0) return "󰂱"
  return "󰂯"
}

function bluetoothStatusText(enabled, connectedDevices) {
  if (!enabled) return "Off"
  if (connectedDevices.length === 0) return "On"
  if (connectedDevices.length === 1) return deviceLabel(connectedDevices[0])
  return connectedDevices.length + " Devices Connected"
}

function deviceLabel(device) {
  if (!device) return ""
  return String(device.name || device.deviceName || "Device")
}

function volumeIcon(volume, muted) {
  if (muted || volume <= 0) return "󰖁"
  if (volume < 0.34) return "󰕼"
  if (volume < 0.67) return "󰕽"
  return "󰕾"
}
