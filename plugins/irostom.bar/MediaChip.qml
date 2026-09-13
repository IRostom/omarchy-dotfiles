import QtQuick
import QtQuick.Shapes
import qs.Ui
import qs.Commons

// Background for the bar's centre (now-playing) chip, drawn as a droplet
// rather than a plain rounded rectangle.
//
// When playback starts the chip oozes down out of the top screen edge, held
// to it by a sticky neck that stretches, thins, pinches, and is simply gone
// by the time the chip settles into its slot in the bar — the "sticky part
// vanishes and only the pill remains" is geometry, not a fade, which is both
// what a real droplet does and the only way to keep this a single fill. The
// chips are 55% translucent, so two overlapping shapes would double-blend
// into a visible seam; neck and capsule are one closed outline instead.
//
// This paints above its own bounds (up to y = -gooInset, the screen edge).
// Nothing on the way up to the layer surface clips, and barWindow grows by
// gooInset specifically to leave that strip of surface available.
Item {
  id: root

  property QtObject bar: null
  // Distance from the chip's resting top edge up to the screen edge, i.e.
  // how far the neck can stretch before it lets go.
  property int gooInset: 0
  // "off" | "transient" | "persistent" — see barConfig.mediaPill in Bar.qml.
  property string mode: "transient"
  property int holdMs: 4000
  // Whether the chip should be present at all (media actually playing).
  property bool active: false
  // Identity of the current track; a change replays the drop in transient
  // mode. Built by Bar.qml's mediaTrackKey.
  property string trackKey: ""

  readonly property bool gooEnabled: mode !== "off"

  // Nothing that was already playing when the shell started should throw an
  // animation on screen, so logging in and `omarchy restart shell` stay calm.
  property bool armed: false
  Timer { running: true; interval: 1500; onTriggered: root.armed = true }

  // Set for one retract's worth of time so the drop can play again from the
  // top on a track change.
  property bool replaying: false
  // Transient mode shows the full UI unprompted for a moment after a change.
  property bool autoExpanded: false

  readonly property bool down: active && !replaying

  // 0 = entirely above the screen edge, 1 = resting in the bar. OutBack
  // pushes past 1, which is what snaps the neck: the extra travel drags the
  // strand past its breaking length before the chip settles back.
  property real progress: down ? 1 : 0
  Behavior on progress {
    enabled: root.gooEnabled
    NumberAnimation {
      duration: root.down ? 640 : 300
      easing.type: root.down ? Easing.OutBack : Easing.InCubic
      // A generous overshoot is doing real work here, not just bounce: the
      // chip dips past its slot, which is the only thing that stretches the
      // neck beyond the bar's 8px edge gap and gives the strand enough length
      // to read as one before it snaps.
      easing.overshoot: 1.9
    }
  }

  // With the goo off the chip stays put and just fades, which is how every
  // other chip in this bar appears.
  property real fade: gooEnabled ? 1 : (active ? 1 : 0)
  Behavior on fade { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }

  // Top edge of the capsule, measured down from the screen edge. At rest it
  // is gooInset below it; at progress 0 the whole capsule sits above it and
  // is therefore off-screen entirely.
  readonly property real capsuleTop: gooEnabled
    ? gooInset - (gooInset + height) * (1 - progress)
    : gooInset
  // Same thing relative to the chip's own slot, for the content to follow.
  readonly property real contentOffset: capsuleTop - gooInset

  // How far the gap between edge and capsule has opened, 0..1.
  readonly property real stretch: gooInset > 0
    ? Math.max(0, Math.min(1, capsuleTop / gooInset)) : 1
  // Smoothstep on the inverse: the strand stays fat while it first pulls
  // away, thins fast through the middle, then tapers to nothing.
  readonly property real neckAmount: {
    var a = 1 - root.stretch
    return a * a * (3 - 2 * a)
  }
  readonly property bool neckVisible: gooEnabled && capsuleTop > 0.5 && neckAmount > 0.02

  readonly property color blobColor: bar && bar.transparent
    ? "transparent"
    : (bar ? bar.frostedBackground(bar.background) : Color.bar.background)

  function replay() {
    if (!root.gooEnabled || !root.armed || !root.active) return
    root.replaying = true
    replayTimer.restart()
  }

  function announce() {
    if (root.mode !== "transient" || !root.armed || !root.active) return
    replay()
    root.autoExpanded = true
    holdTimer.restart()
  }

  onTrackKeyChanged: if (trackKey !== "") announce()
  onActiveChanged: if (!active) { holdTimer.stop(); autoExpanded = false }
  onModeChanged: {
    holdTimer.stop()
    replayTimer.stop()
    replaying = false
    autoExpanded = false
  }

  // Long enough for the retract to finish before the drop starts over.
  Timer { id: replayTimer; interval: 320; onTriggered: root.replaying = false }
  Timer {
    id: holdTimer
    interval: Math.max(800, root.holdMs)
    onTriggered: root.autoExpanded = false
  }

  visible: width > 0.5 && fade > 0.01

  readonly property string blobPath: {
    // Touch the animated inputs so the binding re-evaluates every frame.
    var d = root.capsuleTop
    var amount = root.neckAmount

    var w = root.width
    var h = root.height
    var cx = w / 2
    var R = Math.min(h / 2, w / 2)
    var bottom = d + h
    var p = []

    function seg() {
      for (var i = 0; i < arguments.length; i++) p.push(arguments[i])
    }

    if (root.neckVisible) {
      // Half-widths where the strand meets the screen edge and where it meets
      // the capsule. Both thin as it stretches; the bottom thins faster, so
      // the strand tapers into a teardrop before it lets go.
      var ht = Math.max(0.5, Style.space(13) * amount)
      var hb = Math.max(0.5, Style.space(9) * Math.pow(amount, 1.6))
      // Concave fillets: a quadratic whose control point sits at the *inner*
      // corner curves back toward the fill, which is what welds the strand to
      // the edge above and the capsule below instead of butting into them.
      // Horizontal flare and vertical reach are separate — a fillet that has
      // to stay shallow because the gap is only a few pixels tall can still
      // sweep out wide, which is what keeps the weld looking like surface
      // tension rather than a chamfer.
      var fxT = Style.space(24) * amount
      var fyT = Math.min(Style.space(16) * amount, d * 0.45)
      var fxB = Style.space(17) * amount
      var fyB = Math.min(Style.space(11) * amount, d * 0.34)
      var y0 = fyT
      var y1 = Math.max(y0 + 0.5, d - fyB)
      var span = y1 - y0
      // Side profile. Pulling the control points toward the centre line is
      // what makes the strand's waist concave rather than a straight taper.
      var waist = 0.42

      seg("M", cx - ht - fxT, 0)
      seg("Q", cx - ht, 0, cx - ht, y0)
      seg("C", cx - ht * waist, y0 + span * 0.35, cx - hb * waist, y0 + span * 0.68, cx - hb, y1)
      seg("Q", cx - hb, d, cx - hb - fxB, d)
      seg("L", R, d)
      seg("A", R, R, 0, 0, 0, R, bottom)
      seg("L", w - R, bottom)
      seg("A", R, R, 0, 0, 0, w - R, d)
      seg("L", cx + hb + fxB, d)
      seg("Q", cx + hb, d, cx + hb, y1)
      seg("C", cx + hb * waist, y0 + span * 0.68, cx + ht * waist, y0 + span * 0.35, cx + ht, y0)
      seg("Q", cx + ht, 0, cx + ht + fxT, 0)
      seg("Z")
    } else {
      seg("M", R, d)
      seg("A", R, R, 0, 0, 0, R, bottom)
      seg("L", w - R, bottom)
      seg("A", R, R, 0, 0, 0, w - R, d)
      seg("Z")
    }
    return p.join(" ")
  }

  Shape {
    // Local origin sits on the screen edge, which is where the neck attaches
    // and what every y in blobPath is measured from.
    x: 0
    y: -root.gooInset
    width: root.width
    height: root.height + root.gooInset
    opacity: root.fade
    // Must stay on the default renderer: Shape.CurveRenderer does not support
    // PathSvg and silently draws nothing at all.
    asynchronous: false

    ShapePath {
      fillColor: root.blobColor
      strokeWidth: -1
      strokeColor: "transparent"
      PathSvg { path: root.blobPath }
    }
  }
}
