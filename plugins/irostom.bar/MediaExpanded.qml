import QtQuick
import qs.Ui
import qs.Commons

// The centre chip's hover state: album art, title over artist, and transport
// controls, in place of the compact one-line now-playing label. Sized to the
// bar's own chip height — the chip grows sideways, never downwards.
//
// implicitWidth is measured from TextMetrics rather than from the laid-out
// labels: they elide to whatever width they are handed, so asking them how
// wide they would like to be after they have been constrained is a loop, and
// the chip's width animation is driven by exactly this number.
Item {
  id: root

  required property QtObject bar

  readonly property var mediaService: bar ? bar.mediaService : null
  readonly property var player: mediaService ? mediaService.activePlayer : null
  readonly property string title: player && player.trackTitle ? player.trackTitle : ""
  readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
  readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property real artSize: Math.max(Style.space(18), height - Style.space(10))
  readonly property real maxTextWidth: Style.space(260)
  readonly property real textWidth: Math.min(maxTextWidth,
    Math.max(Style.space(70),
      Math.max(titleMetrics.advanceWidth, artistMetrics.advanceWidth) + Style.space(2)))

  implicitWidth: artSize + Style.space(9) + textWidth + Style.space(9) + controls.implicitWidth
  implicitHeight: parent ? parent.height : Style.space(40)
  width: implicitWidth

  TextMetrics {
    id: titleMetrics
    text: root.title || "Nothing playing"
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
  }

  TextMetrics {
    id: artistMetrics
    text: root.artist
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(9)

    Rectangle {
      id: art
      width: root.artSize
      height: root.artSize
      radius: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)
      clip: true

      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        source: root.artUrl
        visible: root.artUrl !== "" && status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: root.artUrl === ""
        text: "󰝚"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    Column {
      width: root.textWidth
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        textFormat: Text.PlainText
        text: root.title || "Nothing playing"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        textFormat: Text.PlainText
        text: root.artist
        color: Qt.darker(root.foreground, 1.35)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: parent.width
        visible: text !== ""
      }
    }

    Row {
      id: controls
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      component ChipButton: Item {
        id: btn
        property string glyph: ""
        property bool active: true
        property real glyphSize: Style.font.bodySmall
        signal activated

        width: Style.space(22)
        height: Style.space(22)
        opacity: active ? (tap.containsMouse ? 1.0 : 0.8) : 0.32

        Text {
          anchors.centerIn: parent
          text: btn.glyph
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: btn.glyphSize
        }

        MouseArea {
          id: tap
          anchors.fill: parent
          hoverEnabled: true
          enabled: btn.active
          cursorShape: Qt.PointingHandCursor
          onClicked: btn.activated()
        }
      }

      ChipButton {
        glyph: "󰒮"
        active: !!(root.player && root.player.canGoPrevious)
        onActivated: if (root.mediaService) root.mediaService.runAction("previous", false)
      }

      ChipButton {
        glyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
        glyphSize: Style.font.body
        active: !!root.player
        onActivated: if (root.mediaService) root.mediaService.runAction("playPause", false)
      }

      ChipButton {
        glyph: "󰒭"
        active: !!(root.player && root.player.canGoNext)
        onActivated: if (root.mediaService) root.mediaService.runAction("next", false)
      }
    }
  }
}
