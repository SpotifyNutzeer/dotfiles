import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects

PanelWindow {
    id: panel

    property bool panelOpen: false
    signal closeRequested()

    // ── Catppuccin Mocha Lavender ────────────────────────────────────────────
    readonly property color clrBase:     "#1e1e2e"
    readonly property color clrMantle:   "#181825"
    readonly property color clrSurface0: "#313244"
    readonly property color clrSurface1: "#45475a"
    readonly property color clrText:     "#cdd6f4"
    readonly property color clrSubtext0: "#a6adc8"
    readonly property color clrSubtext1: "#bac2de"
    readonly property color clrBlue:     "#89b4fa"
    readonly property color clrLavender: "#b4befe"
    readonly property color clrSky:      "#89dceb"
    readonly property color clrGreen:    "#a6e3a1"
    readonly property color clrYellow:   "#f9e2af"
    readonly property color clrPeach:    "#fab387"
    readonly property color clrRed:      "#f38ba8"
    readonly property color clrMauve:    "#cba6f7"

    // ── Screen ───────────────────────────────────────────────────────────────
    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "HDMI-A-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    anchors       { top: true; left: true; bottom: true }
    margins       { top: 8; left: 12; bottom: 8 }
    implicitWidth: 380
    exclusiveZone: 0
    color: "transparent"

    // ── Notification server ──────────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: true
    }

    // ── Power runner ─────────────────────────────────────────────────────────
    Process {
        id: powerProc
        property string pendingCmd: ""
        command: ["/bin/bash", "-c", pendingCmd]
    }

    function runCmd(cmd) {
        if (!powerProc.running) {
            powerProc.pendingCmd = cmd
            powerProc.running = true
        }
    }

    // ── Active MPRIS player (prefer Tidal, then any playing, then first) ────
    property var activePlayer: {
        var list = Mpris.players.values ?? Mpris.players
        if (!list || list.length === 0) return null
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (p && p.identity && p.identity.toLowerCase().indexOf("tidal") >= 0)
                return p
        }
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (p && p.playbackState === MprisPlaybackState.Playing)
                return p
        }
        return list[0] ?? null
    }

    // ── Slide-in from left ───────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: content
            width:  parent.width
            height: parent.height - 4
            anchors.verticalCenter: parent.verticalCenter
            x: panel.panelOpen ? 0 : -parent.width

            Behavior on x {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            // Material You inspired: very rounded, no harsh border
            color:  panel.clrMantle
            radius: 28
            border { color: Qt.rgba(0.706, 0.745, 0.996, 0.25); width: 2 }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 14

                // ── Header ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2

                    Text {
                        text:  "Quick Panel"
                        color: panel.clrLavender
                        font  { family: "JetBrainsMono Nerd Font"; pixelSize: 22; bold: true }
                        Layout.fillWidth: true
                    }

                    // Close — pill button
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: closeHover.containsMouse ? panel.clrSurface1 : panel.clrSurface0

                        Text {
                            anchors.centerIn: parent
                            text:  "󰅖"
                            color: panel.clrSubtext0
                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.closeRequested()
                        }
                    }
                }

                // ── Now Playing card ─────────────────────────────────────────
                Rectangle {
                    id: nowPlayingCard
                    Layout.fillWidth: true
                    implicitHeight: nowPlayingCol.implicitHeight + 28
                    radius: 20
                    color: panel.clrSurface0
                    clip: true
                    visible: panel.activePlayer !== null

                    // Blurred album art background
                    Image {
                        id: albumArtBg
                        anchors.fill: parent
                        source: (panel.activePlayer && panel.activePlayer.trackArtUrl)
                                ? panel.activePlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false  // used as blur source only
                        asynchronous: true
                    }

                    MultiEffect {
                        source: albumArtBg
                        anchors.fill: albumArtBg
                        blurEnabled:  true
                        blur:         1.0
                        blurMax:      64
                        visible:      albumArtBg.source !== "" && albumArtBg.status === Image.Ready
                    }

                    // Dark overlay so text stays readable
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0.094, 0.094, 0.141, 0.78)
                        visible: albumArtBg.source !== "" && albumArtBg.status === Image.Ready
                    }

                    // Lavender accent strip on the left
                    Rectangle {
                        width: 4; height: parent.height - 16
                        anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
                        radius: 2
                        color: panel.clrLavender
                    }

                    ColumnLayout {
                        id: nowPlayingCol
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 16; rightMargin: 14
                        }
                        spacing: 4

                        Text {
                            text:  "NOW PLAYING"
                            color: panel.clrLavender
                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                        }

                        Text {
                            text:  panel.activePlayer ? (panel.activePlayer.trackTitle || "—") : "—"
                            color: panel.clrText
                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 15; bold: true }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text:  panel.activePlayer ? (panel.activePlayer.trackArtist || "") : ""
                            color: panel.clrSubtext0
                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: text !== ""
                        }

                        // Controls
                        RowLayout {
                            spacing: 10
                            Layout.topMargin: 6
                            Layout.alignment: Qt.AlignHCenter

                            // Previous — tonal
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: prevHover.containsMouse ? panel.clrSurface1 : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text:  "󰒮"
                                    color: panel.clrText
                                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                                }
                                MouseArea {
                                    id: prevHover
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (panel.activePlayer) panel.activePlayer.previous() }
                                }
                            }

                            // Play / Pause — filled primary button
                            Rectangle {
                                width: 52; height: 52; radius: 26
                                color: playHover.containsMouse
                                       ? Qt.lighter(panel.clrLavender, 1.15)
                                       : panel.clrLavender

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (!panel.activePlayer) return "󰐊"
                                        return panel.activePlayer.playbackState === MprisPlaybackState.Playing
                                               ? "󰏤" : "󰐊"
                                    }
                                    color: panel.clrMantle
                                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 22 }
                                }
                                MouseArea {
                                    id: playHover
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!panel.activePlayer) return
                                        if (panel.activePlayer.playbackState === MprisPlaybackState.Playing)
                                            panel.activePlayer.pause()
                                        else
                                            panel.activePlayer.play()
                                    }
                                }
                            }

                            // Next — tonal
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: nextHover.containsMouse ? panel.clrSurface1 : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text:  "󰒭"
                                    color: panel.clrText
                                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                                }
                                MouseArea {
                                    id: nextHover
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (panel.activePlayer) panel.activePlayer.next() }
                                }
                            }
                        }
                    }
                }

                // ── Notifications ────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text:  "Notifications"
                        color: panel.clrSubtext1
                        font  { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true }
                        Layout.fillWidth: true
                    }

                    Text {
                        text:  "Clear all"
                        color: panel.clrLavender
                        font  { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                        visible: notifServer.trackedNotifications.length > 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var list = notifServer.trackedNotifications
                                for (var i = list.length - 1; i >= 0; i--)
                                    list[i].close()
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth:  width
                    contentHeight: notifColumn.height
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: notifColumn
                        width:   parent.width
                        spacing: 8

                        Repeater {
                            model: notifServer.trackedNotifications

                            delegate: Rectangle {
                                required property var modelData
                                width:  notifColumn.width
                                height: notifInner.implicitHeight + 24
                                radius: 16
                                color:  panel.clrSurface0

                                ColumnLayout {
                                    id: notifInner
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 14; rightMargin: 14
                                    }
                                    spacing: 3

                                    Row {
                                        width: parent.width
                                        spacing: 4

                                        Text {
                                            width: parent.width - dismissBtn.width - parent.spacing
                                            text:  (modelData.appName || "") !== ""
                                                   ? modelData.appName.toUpperCase() : "APP"
                                            color: panel.clrLavender
                                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true; letterSpacing: 1.2 }
                                        }

                                        Text {
                                            id: dismissBtn
                                            text:  "󰅖"
                                            color: panel.clrSubtext0
                                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape:  Qt.PointingHandCursor
                                                onClicked:    modelData.close()
                                            }
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text:  modelData.summary || "Notification"
                                        color: panel.clrText
                                        font  { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true }
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width:    parent.width
                                        text:     modelData.body || ""
                                        color:    panel.clrSubtext0
                                        font      { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                                        wrapMode: Text.WordWrap
                                        visible:  text !== ""
                                    }
                                }
                            }
                        }

                        Text {
                            width:              notifColumn.width
                            horizontalAlignment: Text.AlignHCenter
                            topPadding:         12
                            text:    "No notifications"
                            color:   panel.clrSubtext0
                            font     { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                            visible: notifServer.trackedNotifications.length === 0
                        }
                    }
                }

                // ── Power row ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: panel.clrSurface1
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    Layout.bottomMargin: 2

                    property var actions: [
                        { icon: "󰍁", color: clrBlue,   cmd: "loginctl lock-session"  },
                        { icon: "󰒲", color: clrSky,    cmd: "systemctl suspend"       },
                        { icon: "󰍃", color: clrYellow, cmd: "hyprctl dispatch exit"   },
                        { icon: "󰜉", color: clrPeach,  cmd: "systemctl reboot"        },
                        { icon: "󰐥", color: clrRed,    cmd: "systemctl poweroff"      }
                    ]

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: parent.actions

                        delegate: Rectangle {
                            required property var modelData
                            property bool hovered: false

                            width: 44; height: 44
                            radius: 22

                            color: hovered
                                   ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.28)
                                   : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text:  modelData.icon
                                color: modelData.color
                                font  { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited:  parent.hovered = false
                                onClicked: panel.runCmd(modelData.cmd)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
