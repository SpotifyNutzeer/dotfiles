import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: panel
    property bool panelOpen: false
    // Geteilter NotificationServer (Owner: shell.qml) — speist Verlauf + Popups.
    property var notifServer
    signal closeRequested()

    // ── Catppuccin Mocha ──────────────────────────────────────────────────────
    readonly property color clrBase:     "#1e1e2e"
    readonly property color clrMantle:   "#181825"
    readonly property color clrSurface0: "#313244"
    readonly property color clrSurface1: "#45475a"
    readonly property color clrText:     "#cdd6f4"
    readonly property color clrSubtext0: "#a6adc8"
    readonly property color clrSubtext1: "#bac2de"
    readonly property color clrLavender: "#b4befe"
    readonly property color clrBlue:     "#89b4fa"
    readonly property color clrGreen:    "#a6e3a1"
    readonly property color clrYellow:   "#f9e2af"
    readonly property color clrRed:      "#f38ba8"
    readonly property color clrPeach:    "#fab387"
    readonly property color clrSky:      "#89dceb"
    readonly property color clrMauve:    "#cba6f7"

    screen: Quickshell.screens[0]
    anchors { top: true; left: true; bottom: true }
    margins { top: 8; left: 12; bottom: 8 }
    implicitWidth: 300
    color: "transparent"
    visible: panelOpen || hideTimer.running

    onPanelOpenChanged: {
        if (!panelOpen) {
            hideTimer.start()
        } else {
            // Poll current states when opening
            wifiProc.running  = true
            btProc.running    = true
            micProc.running   = true
            volReadProc.running = true
        }
    }

    Timer { id: hideTimer; interval: 350 }

    // ── Toggle states ────────────────────────────────────────────────────────
    property bool wifiEnabled: false
    property bool btEnabled:   false
    property bool micMuted:    false
    property bool dndEnabled:  false

    Process {
        id: wifiProc
        command: ["bash", "-c", "nmcli radio wifi"]
        stdout: SplitParser { onRead: d => panel.wifiEnabled = d.trim() === "enabled" }
    }
    Process {
        id: btProc
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        stdout: SplitParser { onRead: d => panel.btEnabled = d.trim() === "yes" }
    }
    Process {
        id: micProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_SOURCE@"]
        stdout: SplitParser { onRead: d => panel.micMuted = d.includes("[MUTED]") }
    }

    // ── Volume / Brightness ───────────────────────────────────────────────────
    property real volumeVal:     0.5
    property real brightnessVal: 1.0

    Process {
        id: volReadProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}'"]
        stdout: SplitParser { onRead: d => { var v = parseFloat(d.trim()); if (!isNaN(v)) panel.volumeVal = Math.min(v, 1.0) } }
    }

    function runCmd(cmd) {
        var p = Qt.createQmlObject("import Quickshell.Io; Process {}", panel)
        p.command = ["/bin/bash", "-c", cmd]
        p.running = true
    }

    // ── MPRIS ─────────────────────────────────────────────────────────────────
    property var activePlayer: {
        var list = Mpris.players.values ?? Mpris.players
        if (!list || list.length === 0) return null
        for (var i = 0; i < list.length; i++)
            if (list[i].identity?.toLowerCase().includes("tidal") &&
                list[i].playbackState === MprisPlaybackState.Playing) return list[i]
        for (var i = 0; i < list.length; i++)
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i]
        for (var i = 0; i < list.length; i++)
            if (list[i].identity?.toLowerCase().includes("tidal")) return list[i]
        return list.length > 0 ? list[0] : null
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: content
            width: parent.width
            height: parent.height
            x: panel.panelOpen ? 0 : -parent.width
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            color: panel.clrMantle
            radius: 16
            border { color: Qt.rgba(0.537, 0.863, 0.922, 0.15); width: 1 }

            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 12

                // ── Header ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: panel.clrSurface0
                        Text {
                            anchors.centerIn: parent
                            text: "󰄛"; color: panel.clrSky
                            font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                        }
                    }
                    Text {
                        text: "Control Center"
                        color: panel.clrText
                        font { pixelSize: 14; bold: true; family: "JetBrainsMono Nerd Font" }
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: panel.clrSurface0
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"; color: panel.clrSubtext0
                            font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.closeRequested()
                        }
                    }
                }

                // ── Quick Toggles ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { icon: "󰤨", label: "WiFi",      active: panel.wifiEnabled },
                            { icon: "󰂱", label: "Bluetooth", active: panel.btEnabled   },
                            { icon: "󰍬", label: "Mic",       active: !panel.micMuted   },
                            { icon: "󰂚", label: "DND",       active: panel.dndEnabled  }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 12
                            color: modelData.active
                                   ? Qt.rgba(0.537, 0.863, 0.922, 0.2)
                                   : panel.clrSurface0
                            border {
                                color: modelData.active ? panel.clrSky : "transparent"
                                width: 1
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    color: modelData.active ? panel.clrSky : panel.clrSubtext0
                                    font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    color: modelData.active ? panel.clrSky : panel.clrSubtext0
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (index === 0) {
                                        panel.runCmd("nmcli radio wifi " + (panel.wifiEnabled ? "off" : "on"))
                                        panel.wifiEnabled = !panel.wifiEnabled
                                    } else if (index === 1) {
                                        panel.runCmd("bluetoothctl power " + (panel.btEnabled ? "off" : "on"))
                                        panel.btEnabled = !panel.btEnabled
                                    } else if (index === 2) {
                                        panel.runCmd("wpctl set-mute @DEFAULT_SOURCE@ toggle")
                                        panel.micMuted = !panel.micMuted
                                    } else if (index === 3) {
                                        panel.runCmd("pkill -USR1 dunst")
                                        panel.dndEnabled = !panel.dndEnabled
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Volume slider ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰕾"; color: panel.clrBlue
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    }
                    Item {
                        Layout.fillWidth: true
                        height: 20

                        Rectangle {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
                            height: 6; radius: 3
                            color: panel.clrSurface0
                            Rectangle {
                                width: parent.width * panel.volumeVal
                                height: parent.height; radius: parent.radius
                                color: panel.clrBlue
                            }
                        }
                        // Thumb
                        Rectangle {
                            x: panel.volumeVal * (parent.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: panel.clrText
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed:         { var v = Math.max(0, Math.min(mouseX / width, 1)); panel.volumeVal = v; panel.runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2)) }
                            onPositionChanged: { var v = Math.max(0, Math.min(mouseX / width, 1)); panel.volumeVal = v; panel.runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + v.toFixed(2)) }
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    Text {
                        text: Math.round(panel.volumeVal * 100) + "%"
                        color: panel.clrSubtext0
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        Layout.minimumWidth: 30
                    }
                }

                // ── Brightness slider ─────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰃟"; color: panel.clrYellow
                        font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                    }
                    Item {
                        Layout.fillWidth: true
                        height: 20

                        Rectangle {
                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
                            height: 6; radius: 3
                            color: panel.clrSurface0
                            Rectangle {
                                width: parent.width * panel.brightnessVal
                                height: parent.height; radius: parent.radius
                                color: panel.clrYellow
                            }
                        }
                        Rectangle {
                            x: panel.brightnessVal * (parent.width - width)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 7
                            color: panel.clrText
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed:         { var v = Math.max(0, Math.min(mouseX / width, 1)); panel.brightnessVal = v; panel.runCmd("brightnessctl set " + Math.round(v * 100) + "%") }
                            onPositionChanged: { var v = Math.max(0, Math.min(mouseX / width, 1)); panel.brightnessVal = v; panel.runCmd("brightnessctl set " + Math.round(v * 100) + "%") }
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                    Text {
                        text: Math.round(panel.brightnessVal * 100) + "%"
                        color: panel.clrSubtext0
                        font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                        Layout.minimumWidth: 30
                    }
                }

                // ── Media card ────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 70
                    radius: 12
                    color: panel.clrSurface0
                    visible: panel.activePlayer !== null

                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 10

                        // Album art
                        Rectangle {
                            width: 50; height: 50; radius: 8
                            color: panel.clrSurface1; clip: true
                            Image {
                                anchors.fill: parent
                                source: panel.activePlayer ? panel.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                            }
                            // Fallback icon
                            Text {
                                anchors.centerIn: parent
                                text: "󰝚"; color: panel.clrMauve
                                font { pixelSize: 18; family: "JetBrainsMono Nerd Font" }
                                visible: !panel.activePlayer || !panel.activePlayer.trackArtUrl
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: panel.activePlayer ? (panel.activePlayer.trackTitle || "") : ""
                                color: panel.clrText
                                font { pixelSize: 11; bold: true; family: "JetBrainsMono Nerd Font" }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: panel.activePlayer ? (panel.activePlayer.trackArtist || "") : ""
                                color: panel.clrSubtext0
                                font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 14
                                Text {
                                    text: "󰒮"; color: panel.clrSubtext1
                                    font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (panel.activePlayer) panel.activePlayer.previous() } }
                                }
                                Text {
                                    text: (panel.activePlayer && panel.activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰏥" : "󰐊"
                                    color: panel.clrSky
                                    font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!panel.activePlayer) return
                                            if (panel.activePlayer.playbackState === MprisPlaybackState.Playing)
                                                panel.activePlayer.pause()
                                            else
                                                panel.activePlayer.play()
                                        }
                                    }
                                }
                                Text {
                                    text: "󰒭"; color: panel.clrSubtext1
                                    font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (panel.activePlayer) panel.activePlayer.next() } }
                                }
                            }
                        }
                    }
                }

                // ── Notifications ─────────────────────────────────────────────
                Text {
                    text: "Notifications"
                    color: panel.clrSubtext0
                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                    visible: notifServer.trackedNotifications.length > 0
                }

                ListView {
                    id: nv
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: notifServer.trackedNotifications
                    spacing: 6
                    clip: true

                    delegate: Rectangle {
                        width: nv.width
                        height: notifCol.implicitHeight + 16
                        radius: 10
                        color: panel.clrSurface0

                        RowLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 8

                            ColumnLayout {
                                id: notifCol
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.summary
                                    color: panel.clrText
                                    font { pixelSize: 11; bold: true; family: "JetBrainsMono Nerd Font" }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.body
                                    color: panel.clrSubtext0
                                    font { pixelSize: 10; family: "JetBrainsMono Nerd Font" }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: modelData.body !== ""
                                }
                            }
                            Text {
                                text: "󰅖"; color: panel.clrSubtext1
                                font { pixelSize: 14; family: "JetBrainsMono Nerd Font" }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.dismiss()
                                }
                            }
                        }
                    }
                }

                // ── Bottom actions ────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: panel.clrSurface1
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Repeater {
                        model: [
                            { icon: "󰍁", label: "Lock",    cmd: "loginctl lock-session", color: panel.clrBlue  },
                            { icon: "󰜉", label: "Reboot",  cmd: "systemctl reboot",       color: panel.clrPeach },
                            { icon: "󰐥", label: "Shutdown",cmd: "systemctl poweroff",     color: panel.clrRed   }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: 10
                            color: panel.clrSurface0

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    color: modelData.color
                                    font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    color: panel.clrSubtext0
                                    font { pixelSize: 9; family: "JetBrainsMono Nerd Font" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: panel.runCmd(modelData.cmd)
                            }
                        }
                    }
                }
            }
        }
    }
}
