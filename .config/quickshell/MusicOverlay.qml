import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: overlay

    property bool musicOpen:     false
    property real islandX:       0
    property real islandWidth:   200
    property var  player:        null
    property real trackPosition: 0
    property real trackLength:   0

    // ── Catppuccin Mocha ─────────────────────────────────────────────────────
    readonly property color clrBase:     "#1e1e2e"
    readonly property color clrSurface0: "#313244"
    readonly property color clrSurface1: "#45475a"
    readonly property color clrText:     "#cdd6f4"
    readonly property color clrSubtext0: "#a6adc8"
    readonly property color clrLavender: "#b4befe"
    readonly property color clrMauve:    "#cba6f7"
    readonly property string nfFont:     "JetBrainsMono Nerd Font"

    function fmt(s) {
        if (!s || s <= 0) return "0:00"
        s = Math.floor(s)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ── Fenster ──────────────────────────────────────────────────────────────
    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "DP-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    anchors { top: true; left: true; right: true }
    margins { top: 58; left: 12; right: 12 }
    exclusiveZone: -1
    color: "transparent"
    implicitHeight: musicOpen ? 175 : 4
    Behavior on implicitHeight { NumberAnimation { duration: 280; easing.type: Easing.InOutCubic } }

    // ── Panel (unter Music Island zentriert) ─────────────────────────────────
    Rectangle {
        id: panel

        // Unter der Music Island ausrichten, an Kanten clampen
        x: Math.max(0, Math.min(
               overlay.islandX + (overlay.islandWidth - width) / 2,
               parent.width - width))
        anchors { top: parent.top; bottom: parent.bottom }
        width: Math.max(overlay.islandWidth, 290)

        radius: 12
        color:  overlay.clrBase
        border  { color: Qt.rgba(0.706, 0.745, 0.996, 0.55); width: 2 }
        clip:   true
        opacity: overlay.musicOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

        ColumnLayout {
            anchors { fill: parent; margins: 14; topMargin: 13; bottomMargin: 13 }
            spacing: 10

            // ── Album Art + Track Info ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                // Album Art
                Rectangle {
                    width: 66; height: 66
                    radius: 8
                    color: overlay.clrSurface0
                    clip: true

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: overlay.player ? (overlay.player.trackArtUrl ?? "") : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰝚"
                        color: overlay.clrMauve
                        font { family: overlay.nfFont; pixelSize: 26 }
                        visible: albumArt.status !== Image.Ready
                    }
                }

                // Track-Infos
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3
                    clip: true

                    Text {
                        Layout.fillWidth: true
                        text: overlay.player ? (overlay.player.trackTitle ?? "–") : "–"
                        color: overlay.clrText
                        font { family: overlay.nfFont; pixelSize: 13; bold: true }
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: overlay.player ? (overlay.player.trackArtist ?? "") : ""
                        color: overlay.clrSubtext0
                        font { family: overlay.nfFont; pixelSize: 12 }
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                    Text {
                        Layout.fillWidth: true
                        text: overlay.player ? (overlay.player.trackAlbum ?? "") : ""
                        color: Qt.rgba(overlay.clrSubtext0.r, overlay.clrSubtext0.g,
                                       overlay.clrSubtext0.b, 0.5)
                        font { family: overlay.nfFont; pixelSize: 11 }
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }

                    // Player-Badge
                    Rectangle {
                        visible: overlay.player !== null
                        height: 17
                        width: badgeText.implicitWidth + 12
                        radius: 4
                        color: Qt.rgba(0.706, 0.745, 0.996, 0.10)
                        border { color: Qt.rgba(0.706, 0.745, 0.996, 0.25); width: 1 }
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: overlay.player ? (overlay.player.identity ?? "") : ""
                            color: Qt.rgba(0.706, 0.745, 0.996, 0.65)
                            font { family: overlay.nfFont; pixelSize: 10 }
                        }
                    }
                }
            }

            // ── Trennlinie ───────────────────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: overlay.clrSurface1; opacity: 0.45 }

            // ── Steuerung ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰒮"
                    color: overlay.clrSubtext0
                    font { family: overlay.nfFont; pixelSize: 19 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (overlay.player) overlay.player.previous() }
                    }
                }

                Item { width: 22 }

                Text {
                    text: (overlay.player &&
                           overlay.player.playbackState === MprisPlaybackState.Playing)
                          ? "󰏥" : "󰐊"
                    color: overlay.clrLavender
                    font { family: overlay.nfFont; pixelSize: 28 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!overlay.player) return
                            if (overlay.player.playbackState === MprisPlaybackState.Playing)
                                overlay.player.pause()
                            else
                                overlay.player.play()
                        }
                    }
                }

                Item { width: 22 }

                Text {
                    text: "󰒭"
                    color: overlay.clrSubtext0
                    font { family: overlay.nfFont; pixelSize: 19 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (overlay.player) overlay.player.next() }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // ── Fortschrittsbalken ───────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: overlay.fmt(overlay.trackPosition)
                    color: overlay.clrSubtext0
                    font { family: overlay.nfFont; pixelSize: 11 }
                }

                Item {
                    Layout.fillWidth: true
                    height: 5
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent; radius: 3
                        color: overlay.clrSurface1
                    }
                    Rectangle {
                        width: overlay.trackLength > 0
                               ? parent.width * Math.min(overlay.trackPosition / overlay.trackLength, 1)
                               : 0
                        height: parent.height; radius: 3
                        color: overlay.clrLavender
                    }
                    MouseArea {
                        anchors { fill: parent; margins: -8 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (overlay.player && overlay.trackLength > 0) {
                                var pos = Math.max(0, Math.min(mouse.x / width, 1)) * overlay.trackLength
                                overlay.player.position = pos
                            }
                        }
                    }
                }

                Text {
                    text: overlay.fmt(overlay.trackLength)
                    color: overlay.clrSubtext0
                    font { family: overlay.nfFont; pixelSize: 11 }
                }
            }
        }
    }
}
