import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: bar

    signal panelToggled()

    // ── Search state ─────────────────────────────────────────────────────────
    property bool   searchOpen:  false
    property string searchQuery: ""
    signal searchOpenRequested()
    signal searchQueryUpdated(string q)
    signal searchEnterPressed()
    signal searchClosed()

    onSearchOpenChanged: {
        if (searchOpen) {
            searchInput.text = ""
            focusTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: searchInput.forceActiveFocus()
    }

    // ── Catppuccin Mocha ─────────────────────────────────────────────────────
    readonly property color clrBase:     "#1e1e2e"
    readonly property color clrSurface0: "#313244"
    readonly property color clrSurface1: "#45475a"
    readonly property color clrText:     "#cdd6f4"
    readonly property color clrSubtext0: "#a6adc8"
    readonly property color clrBlue:     "#89b4fa"
    readonly property color clrLavender: "#b4befe"
    readonly property color clrGreen:    "#a6e3a1"
    readonly property color clrYellow:   "#f9e2af"
    readonly property color clrPeach:    "#fab387"
    readonly property color clrRed:      "#f38ba8"
    readonly property color clrTeal:     "#94e2d5"
    readonly property color clrSky:      "#89dceb"
    readonly property color clrSapphire: "#74c7ec"
    readonly property color clrMauve:    "#cba6f7"
    readonly property color clrPink:     "#f5c2e7"

    // ── Screen ───────────────────────────────────────────────────────────────
    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "HDMI-A-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    anchors { top: true; left: true; right: true }
    margins { top: 8; left: 12; right: 12 }
    implicitHeight: 44
    exclusiveZone: 52
    focusable: true
    color: "transparent"

    HyprlandFocusGrab {
        windows: [ bar ]
        active: bar.searchOpen
    }

    // ── Stats state ──────────────────────────────────────────────────────────
    property string cpuUsage:  "0"
    property string cpuPower:  "0W"
    property string cpuTemp:   "0"
    property string ramUsed:   "0.0"
    property string gpuUsage:  "0"
    property string gpuPower:  "0W"
    property string gpuVram:   "0M"
    property string netDown:   "0K"
    property string netUp:     "0K"
    property string clockTime: Qt.formatTime(new Date(), "hh:mm")

    // ── MPRIS ─────────────────────────────────────────────────────────────────
    property var activePlayer: {
        var list = Mpris.players.values ?? Mpris.players
        // 1. Tidal playing
        for (var i = 0; i < list.length; i++)
            if (list[i].identity?.toLowerCase().includes("tidal") &&
                list[i].playbackState === MprisPlaybackState.Playing) return list[i]
        // 2. Any other source playing
        for (var i = 0; i < list.length; i++)
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i]
        // 3. Tidal paused
        for (var i = 0; i < list.length; i++)
            if (list[i].identity?.toLowerCase().includes("tidal")) return list[i]
        // 4. First available
        return list.length > 0 ? list[0] : null
    }
    property string songText: {
        if (!activePlayer) return ""
        var t = activePlayer.trackTitle  || ""
        var a = activePlayer.trackArtist || ""
        if (a && t) return a + "  –  " + t
        return t || a
    }

    property real trackPosition: 0
    property real trackLength:   activePlayer ? (activePlayer.length   ?? 0) : 0

    onActivePlayerChanged: trackPosition = activePlayer ? (activePlayer.position ?? 0) : 0

    // Tick position forward every second while playing
    Timer {
        interval: 1000; repeat: true
        running: bar.activePlayer !== null &&
                 bar.activePlayer.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            if (bar.activePlayer)
                bar.trackPosition = bar.activePlayer.position ?? (bar.trackPosition + 1000000)
        }
    }

    function formatTime(us) {
        if (!us || us <= 0) return "0:00"
        var s = Math.floor(us / 1000000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: bar.clockTime = Qt.formatTime(new Date(), "hh:mm")
    }

    // ── Stat processes ───────────────────────────────────────────────────────
    Process {
        id: cpuUsageProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/cpu-usage.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.cpuUsage = d.trim() } }
    }
    Process {
        id: cpuPowerProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/cpu-power.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.cpuPower = d.trim() } }
    }
    Process {
        id: cpuTempProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/cpu-temp.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.cpuTemp = d.trim() } }
    }
    Process {
        id: ramProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/ram.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.ramUsed = d.trim() } }
    }
    Process {
        id: gpuUsageProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/gpu-usage.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuUsage = d.trim() } }
    }
    Process {
        id: gpuPowerProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/gpu-power.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuPower = d.trim() + "W" } }
    }
    Process {
        id: gpuVramProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/gpu-vram.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuVram = d.trim() } }
    }
    Process {
        id: netProc
        command: ["/bin/bash", Qt.resolvedUrl("scripts/net.sh").toString().replace("file://", "")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                if (!d.trim()) return
                var parts = d.trim().split(" ")
                if (parts.length >= 2) { bar.netDown = parts[0]; bar.netUp = parts[1] }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            if (!cpuUsageProc.running) cpuUsageProc.running = true
            if (!cpuPowerProc.running) cpuPowerProc.running = true
            if (!cpuTempProc.running)  cpuTempProc.running  = true
            if (!ramProc.running)      ramProc.running      = true
            if (!gpuUsageProc.running) gpuUsageProc.running = true
            if (!gpuPowerProc.running) gpuPowerProc.running = true
            if (!gpuVramProc.running)  gpuVramProc.running  = true
            if (!netProc.running)      netProc.running      = true
        }
    }

    Component.onCompleted: {
        cpuUsageProc.running = true
        cpuPowerProc.running = true
        cpuTempProc.running  = true
        ramProc.running      = true
        gpuUsageProc.running = true
        gpuPowerProc.running = true
        gpuVramProc.running  = true
        netProc.running      = true
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // ── Left island: Workspaces + Search ────────────────────────────────
        Rectangle {
            id: leftIsland
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            height: parent.height - 4
            radius: 12
            color: bar.clrBase
            border { color: Qt.rgba(0.706, 0.745, 0.996, 0.55); width: 2 }
            clip: true

            width: bar.searchOpen ? 420 : leftRow.implicitWidth + 16
            Behavior on width {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            // ── Normal: workspace buttons + icons ────────────────────────────
            RowLayout {
                id: leftRow
                anchors.centerIn: parent
                spacing: 4
                opacity: bar.searchOpen ? 0 : 1
                enabled: !bar.searchOpen
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Repeater {
                    model: {
                        var ws = []
                        for (var i = 0; i < Hyprland.workspaces.length; i++) {
                            var w = Hyprland.workspaces[i]
                            if (w.id >= 1 && w.id <= 10) ws.push(w)
                        }
                        ws.sort(function(a, b) { return a.id - b.id })
                        return ws
                    }

                    delegate: Rectangle {
                        required property var modelData
                        property bool isActive: Hyprland.focusedMonitor &&
                            Hyprland.focusedMonitor.activeWorkspace &&
                            Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

                        width: 28; height: 28
                        radius: 6
                        color: isActive ? bar.clrLavender : bar.clrSurface0

                        Text {
                            anchors.centerIn: parent
                            text:  modelData.id
                            color: parent.isActive ? bar.clrBase : bar.clrSubtext0
                            font  { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: parent.isActive }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                // Side panel toggle
                BarButton {
                    icon:      "󰍜"
                    iconColor: bar.clrBlue
                    onClicked: bar.panelToggled()
                }

                // Search open button
                BarButton {
                    icon:      "󰍉"
                    iconColor: bar.clrLavender
                    onClicked: bar.searchOpenRequested()
                }
            }

            // ── Search: icon + text input + clear ────────────────────────────
            RowLayout {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12; rightMargin: 10
                }
                spacing: 8
                opacity: bar.searchOpen ? 1 : 0
                enabled: bar.searchOpen
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Text {
                    text:  "󰍉"
                    color: bar.clrLavender
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color:       bar.clrText
                    font         { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                    cursorVisible: activeFocus
                    clip:          true

                    // Placeholder text
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text:    "Search apps & power…"
                        color:   bar.clrSubtext0
                        font     { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                        visible: parent.text.length === 0 && !parent.activeFocus
                    }

                    Keys.onEscapePressed: {
                        bar.searchClosed()
                    }

                    Keys.onReturnPressed:  bar.searchEnterPressed()
                    Keys.onEnterPressed:   bar.searchEnterPressed()

                    onTextChanged: bar.searchQueryUpdated(text)
                }

                Text {
                    text:    "󰅖"
                    color:   bar.clrSubtext0
                    font     { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    visible: searchInput.text.length > 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked:   searchInput.text = ""
                    }
                }
            }
        }

        // ── Music island: track + controls + progress ────────────────────────
        Rectangle {
            id: musicIsland
            anchors.verticalCenter: parent.verticalCenter
            x: (leftIsland.x + leftIsland.width + centerIsland.x) / 2 - width / 2
            height:  parent.height - 4
            radius:  12
            color:   bar.clrBase
            border   { color: Qt.rgba(0.706, 0.745, 0.996, 0.55); width: 2 }
            visible: bar.activePlayer !== null
            width:   musicRow.implicitWidth + 20

            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: 8

                // ── Icon + Title ─────────────────────────────────────────────
                Text {
                    text:  "󰝚"
                    color: bar.clrMauve
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                // Scrolling title
                Item {
                    id: titleClip
                    implicitWidth: 180
                    implicitHeight: scrollText.implicitHeight
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: scrollText
                        text:  bar.songText
                        color: bar.clrText
                        font   { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }

                        onTextChanged: {
                            scrollText.x = 0
                            marquee.stop()
                            marqueeDelay.restart()
                        }

                        Component.onCompleted: marqueeDelay.restart()
                    }

                    // Small delay before starting so text width is measured
                    Timer {
                        id: marqueeDelay
                        interval: 100
                        onTriggered: {
                            if (scrollText.implicitWidth > titleClip.implicitWidth)
                                marquee.restart()
                        }
                    }

                    SequentialAnimation {
                        id: marquee
                        loops: Animation.Infinite

                        PauseAnimation   { duration: 2000 }
                        NumberAnimation  {
                            target: scrollText; property: "x"
                            to: -(scrollText.implicitWidth - titleClip.implicitWidth)
                            duration: Math.max(0, scrollText.implicitWidth - titleClip.implicitWidth) * 22
                            easing.type: Easing.Linear
                        }
                        PauseAnimation   { duration: 1500 }
                        NumberAnimation  {
                            target: scrollText; property: "x"
                            to: 0
                            duration: Math.max(0, scrollText.implicitWidth - titleClip.implicitWidth) * 22
                            easing.type: Easing.InOutCubic
                        }
                    }
                }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                // ── Controls ─────────────────────────────────────────────────
                Text {
                    text: "󰒮"
                    color: bar.clrSubtext0
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (bar.activePlayer) bar.activePlayer.previous() }
                    }
                }
                Text {
                    text: (bar.activePlayer && bar.activePlayer.playbackState === MprisPlaybackState.Playing)
                          ? "󰏥" : "󰐊"
                    color: bar.clrLavender
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!bar.activePlayer) return
                            if (bar.activePlayer.playbackState === MprisPlaybackState.Playing)
                                bar.activePlayer.pause()
                            else
                                bar.activePlayer.play()
                        }
                    }
                }
                Text {
                    text: "󰒭"
                    color: bar.clrSubtext0
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (bar.activePlayer) bar.activePlayer.next() }
                    }
                }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                // ── Progress ─────────────────────────────────────────────────
                Text {
                    text:  bar.formatTime(bar.trackPosition)
                    color: bar.clrSubtext0
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                }

                Item {
                    implicitWidth: 90
                    implicitHeight: 4
                    Layout.alignment: Qt.AlignVCenter

                    // Track
                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: bar.clrSurface1
                    }
                    // Fill
                    Rectangle {
                        width: bar.trackLength > 0
                               ? parent.width * Math.min(bar.trackPosition / bar.trackLength, 1)
                               : 0
                        height: parent.height
                        radius: 2
                        color: bar.clrLavender
                    }
                    // Click to seek
                    MouseArea {
                        anchors { fill: parent; margins: -6 }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (bar.activePlayer && bar.trackLength > 0) {
                                var pos = Math.max(0, Math.min(mouse.x / width, 1)) * bar.trackLength
                                bar.activePlayer.position = pos
                                bar.trackPosition = pos
                            }
                        }
                    }
                }

                Text {
                    text:  bar.formatTime(bar.trackLength)
                    color: bar.clrSubtext0
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                }
            }
        }

        // ── Center island: Stats ─────────────────────────────────────────────
        Rectangle {
            id: centerIsland
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            height: parent.height - 4
            radius: 12
            color: bar.clrBase
            border { color: Qt.rgba(0.706, 0.745, 0.996, 0.55); width: 2 }
            width: statsRow.implicitWidth + 24

            RowLayout {
                id: statsRow
                anchors.centerIn: parent
                spacing: 14

                StatItem { icon: "󰻠"; value: bar.cpuUsage + "%"; iconColor: bar.clrGreen;   textColor: bar.clrText }
                StatItem { icon: "󱐋"; value: bar.cpuPower;        iconColor: bar.clrPeach;   textColor: bar.clrText }
                StatItem { icon: "󰔏"; value: bar.cpuTemp + "°C";  iconColor: bar.clrYellow;  textColor: bar.clrText }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                StatItem { icon: "󰍛"; value: bar.ramUsed + "G";   iconColor: bar.clrMauve;   textColor: bar.clrText }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                StatItem { icon: "󰢮"; value: bar.gpuUsage + "%";  iconColor: bar.clrTeal;    textColor: bar.clrText }
                StatItem { icon: "󱐋"; value: bar.gpuPower;         iconColor: bar.clrPeach;   textColor: bar.clrText }
                StatItem { icon: "󰆧"; value: bar.gpuVram;          iconColor: bar.clrSky;     textColor: bar.clrText }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                StatItem { icon: "󰁆"; value: bar.netDown; iconColor: bar.clrBlue;    textColor: bar.clrText }
                StatItem { icon: "󰁞"; value: bar.netUp;   iconColor: bar.clrSapphire; textColor: bar.clrText }

            }
        }

        // ── Right island: Tray + Clock + Buttons ────────────────────────────
        Rectangle {
            id: rightIsland
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            height: parent.height - 4
            radius: 12
            color: bar.clrBase
            border { color: Qt.rgba(0.706, 0.745, 0.996, 0.55); width: 2 }
            width: rightRow.implicitWidth + 16

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 8

                // System Tray
                RowLayout {
                    spacing: 10
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            required property SystemTrayItem modelData
                            width: 20; height: 20
                            Layout.alignment: Qt.AlignVCenter

                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: modelData.activate()
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                // Clock
                Text {
                    text:  "󰃰 " + bar.clockTime
                    color: bar.clrPink
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true }
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle { width: 1; height: 20; color: bar.clrSurface1 }

                // Power menu
                BarButton {
                    icon:      "󰐥"
                    iconColor: bar.clrRed
                    onClicked: bar.powerMenu()
                }
            }
        }
    }

    function powerMenu() {
        var proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["/bin/bash", "/home/paul/.config/waybar/powermenu.sh"] }',
            bar
        )
        proc.running = true
    }
}
