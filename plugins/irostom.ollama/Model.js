// Parsing/formatting helpers for the Ollama panel. Kept separate from
// Panel.qml so the QML file stays about layout and wiring.

function parseVersion(raw) {
  try {
    var obj = JSON.parse(raw)
    return (obj && obj.version) ? String(obj.version) : ""
  } catch (e) {
    return ""
  }
}

// /api/ps returns the models currently loaded into memory, each carrying the
// context window it was loaded with (context_length) and when it will be
// evicted (expires_at — a year-1 sentinel means "kept loaded", i.e.
// keep_alive -1).
function parseModels(raw) {
  try {
    var obj = JSON.parse(raw)
    var list = (obj && obj.models) || []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var m = list[i] || {}
      out.push({
        name: String(m.name || m.model || "unknown"),
        contextLength: Number(m.context_length) || 0,
        sizeVram: Number(m.size_vram || m.size) || 0,
        expiresAt: String(m.expires_at || "")
      })
    }
    return out
  } catch (e) {
    return []
  }
}

function formatBytes(n) {
  var v = Number(n)
  if (!isFinite(v) || v <= 0) return ""
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
  return (v >= 10 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i]
}

function formatContext(tokens) {
  var v = Number(tokens)
  if (!isFinite(v) || v <= 0) return "—"
  if (v >= 1024) {
    var k = v / 1024
    return (Math.round(k * 10) / 10) + "K tokens"
  }
  return v + " tokens"
}

// Compact form for pill labels: "4096" -> "4K".
function formatContextShort(tokens) {
  var v = Number(tokens)
  if (!isFinite(v) || v <= 0) return "0"
  if (v % 1024 === 0) return (v / 1024) + "K"
  return String(v)
}

function parseSettings(raw) {
  try {
    var obj = JSON.parse(raw)
    var n = Number(obj && obj.contextLength)
    return { contextLength: (isFinite(n) && n > 0) ? Math.round(n) : 0 }
  } catch (e) {
    return { contextLength: 0 }
  }
}

function formatExpiresIn(iso) {
  if (!iso) return ""
  var t = Date.parse(iso)
  if (!isFinite(t)) return ""
  // ollama uses a year-1 timestamp for "no expiry" (keep_alive: -1).
  if (new Date(t).getUTCFullYear() <= 1) return "kept loaded"
  var deltaMs = t - Date.now()
  if (deltaMs <= 0) return "unloading…"
  var mins = Math.round(deltaMs / 60000)
  if (mins < 1) return "unloads in <1m"
  if (mins < 60) return "unloads in " + mins + "m"
  var hrs = Math.floor(mins / 60)
  var rem = mins % 60
  return "unloads in " + hrs + "h" + (rem > 0 ? " " + rem + "m" : "")
}
