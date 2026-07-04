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

    Process {
        id: rofiProc
        command: ["rofi", "-show", "drun"]
    }

    function launchRofi() { rofiProc.running = true }

    // ── Screen ───────────────────────────────────────────────────────────────
    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "HDMI-A-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    anchors { top: true; left: true; right: true }
    margins { top: 10; left: 10; right: 10 }
    implicitHeight: 44
    exclusiveZone:  44
    color: "transparent"

    // ── Stats state ──────────────────────────────────────────────────────────
    property string cpuUsage:  "0"
    property string cpuClock:  "0MHz"
    property string cpuPower:  "0W"
    property string cpuTemp:   "0"
    property string ramUsed:   "0.0"
    property string gpuUsage:  "0"
    property string gpuClock:  "0MHz"
    property string gpuPower:  "0W"
    property string gpuTemp:   "0"
    property string gpuVram:   "0M"
    property string netDown:   "0K"
    property string netUp:     "0K"
    property string clockTime:   Qt.formatTime(new Date(), "hh:mm")
    property string windowTitle: ""

    // ── Host ─────────────────────────────────────────────────────────────────
    // Auf dem Laptop wird die Media-Island ausgeblendet (zu wenig Platz).
    property bool isLaptop: false
    Process {
        id: hostnameProc
        command: ["/bin/sh", "-c", "hostname"]
        running: true
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.isLaptop = (d.trim() === "paul-laptop") } }
    }

    // ── Graph history ────────────────────────────────────────────────────────
    signal statsToggled()
    readonly property real centerIslandWidth: centerIsland.width

    // ── Music overlay ─────────────────────────────────────────────────────────
    signal musicToggled()
    readonly property real musicIslandX:     musicIsland.x
    readonly property real musicIslandWidth: musicIsland.width
    property var  cpuHistory:      []
    property var  gpuHistory:      []
    property var  ramHistory:      []
    property var  netDownHistory:  []

    property real netDownMax: {
        if (netDownHistory.length === 0) return 1000
        var m = 1
        for (var i = 0; i < netDownHistory.length; i++)
            if (netDownHistory[i] > m) m = netDownHistory[i]
        return m * 1.2
    }

    function appendHistory(arr, val) {
        var a = arr.slice()
        a.push(val)
        if (a.length > 60) a.shift()
        return a
    }

    function parseNetKB(s) {
        if (!s) return 0
        var n = parseFloat(s) || 0
        if (s.indexOf("G") !== -1) return n * 1024 * 1024
        if (s.indexOf("M") !== -1) return n * 1024
        return n
    }

    // ── Visualizer state ─────────────────────────────────────────────────────
    property var  barValues:   []
    property bool hasAudio:    false
    property real silenceSecs: 0

    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            var loud = bar.barValues.some(v => v > 2)
            if (loud) {
                bar.hasAudio    = true
                bar.silenceSecs = 0
            } else {
                bar.silenceSecs += 0.5
                if (bar.silenceSecs >= 4) bar.hasAudio = false
            }
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p",
                  Qt.resolvedUrl("scripts/cava-bar.ini").toString().replace("file://", "")]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                var parts = d.trim().split(" ")
                if (parts.length > 1)
                    bar.barValues = parts.map(v => Math.max(0, parseInt(v) || 0))
            }
        }
        onRunningChanged: if (!running) cavaRestartTimer.restart()
    }

    Timer {
        id: cavaRestartTimer
        interval: 1000
        repeat: false
        onTriggered: cavaProc.running = true
    }

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
    property real trackLength:   activePlayer ? (activePlayer.length ?? 0) : 0

    onActivePlayerChanged: trackPosition = activePlayer ? (activePlayer.position ?? 0) : 0

    // Tick position forward every second while playing
    Timer {
        interval: 1000; repeat: true
        running: bar.activePlayer !== null &&
                 bar.activePlayer.playbackState === MprisPlaybackState.Playing
        onTriggered: {
            if (bar.activePlayer)
                bar.trackPosition = bar.activePlayer.position ?? (bar.trackPosition + 1)
        }
    }

    function formatTime(s) {
        if (!s || s <= 0) return "0:00"
        s = Math.floor(s)
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
        command: ["/bin/sh", Qt.resolvedUrl("scripts/cpu-usage.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) { bar.cpuUsage = d.trim(); bar.cpuHistory = bar.appendHistory(bar.cpuHistory, parseFloat(d.trim()) || 0) } } }
    }
    Process {
        id: cpuClockProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/cpu-clock.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.cpuClock = d.trim() } }
    }
    Process {
        id: cpuPowerProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/cpu-power.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.cpuPower = d.trim() } }
    }
    Process {
        id: cpuTempProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/cpu-temp.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.cpuTemp = d.trim() } }
    }
    Process {
        id: ramProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/ram.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) { bar.ramUsed = d.trim(); bar.ramHistory = bar.appendHistory(bar.ramHistory, parseFloat(d.trim()) || 0) } } }
    }
    Process {
        id: gpuUsageProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/gpu-usage.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) { bar.gpuUsage = d.trim(); bar.gpuHistory = bar.appendHistory(bar.gpuHistory, parseFloat(d.trim()) || 0) } } }
    }
    Process {
        id: gpuClockProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/gpu-clock.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuClock = d.trim() } }
    }
    Process {
        id: gpuPowerProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/gpu-power.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuPower = d.trim() + "W" } }
    }
    Process {
        id: gpuTempProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/gpu-temp.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuTemp = d.trim() } }
    }
    Process {
        id: gpuVramProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/gpu-vram.sh").toString().replace("file://", "")]
        stdout: SplitParser { splitMarker: "\n"; onRead: d => { if (d.trim()) bar.gpuVram = d.trim() } }
    }
    Process {
        id: netProc
        command: ["/bin/sh", Qt.resolvedUrl("scripts/net.sh").toString().replace("file://", "")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                if (!d.trim()) return
                var parts = d.trim().split(" ")
                if (parts.length >= 2) {
                    bar.netDown = parts[0]
                    bar.netUp   = parts[1]
                    bar.netDownHistory = bar.appendHistory(bar.netDownHistory, bar.parseNetKB(parts[0]))
                }
            }
        }
    }

    // ── Active window title ───────────────────────────────────────────────────
    Process {
        id: winTitleProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.title // empty'"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => { bar.windowTitle = d.trim() }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            if (!cpuUsageProc.running) cpuUsageProc.running = true
            if (!cpuClockProc.running) cpuClockProc.running = true
            if (!cpuPowerProc.running) cpuPowerProc.running = true
            if (!cpuTempProc.running)  cpuTempProc.running  = true
            if (!ramProc.running)      ramProc.running      = true
            if (!gpuUsageProc.running) gpuUsageProc.running = true
            if (!gpuClockProc.running) gpuClockProc.running = true
            if (!gpuPowerProc.running) gpuPowerProc.running = true
            if (!gpuTempProc.running)  gpuTempProc.running  = true
            if (!gpuVramProc.running)  gpuVramProc.running  = true
            if (!netProc.running)      netProc.running      = true
            if (!winTitleProc.running) winTitleProc.running = true
        }
    }

    Component.onCompleted: {
        cpuUsageProc.running = true
        cpuClockProc.running = true
        cpuPowerProc.running = true
        cpuTempProc.running  = true
        ramProc.running      = true
        gpuUsageProc.running = true
        gpuClockProc.running = true
        gpuPowerProc.running = true
        gpuTempProc.running  = true
        gpuVramProc.running  = true
        netProc.running      = true
        winTitleProc.running = true
    }

    // ── Layout ───────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // ── Left island: Workspaces + Buttons ───────────────────────────────
        Rectangle {
            id: leftIsland
            anchors { left: parent.left; top: parent.top; topMargin: 2 }
            height: 40
            radius: Theme.radius
            color: Theme.panelBg
            border { color: Theme.borderColor(0.55); width: 2 }
            clip: true
            width: leftRow.implicitWidth + 16

            RowLayout {
                id: leftRow
                anchors.centerIn: parent
                spacing: 4

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
                        color: isActive ? Theme.clrSky : Theme.clrSurface0
                        Text {
                            anchors.centerIn: parent
                            text:  modelData.id
                            color: parent.isActive ? Theme.clrBase : Theme.clrSubtext0
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
                    iconColor: Theme.clrBlue
                    onClicked: bar.panelToggled()
                }

                // Rofi launcher button
                BarButton {
                    icon:      "󰍉"
                    iconColor: Theme.clrSky
                    onClicked: bar.launchRofi()
                }
            }
        }

        // ── Window title island ───────────────────────────────────────────────
        Rectangle {
            id: windowIsland
            anchors { left: leftIsland.right; leftMargin: 8; top: parent.top; topMargin: 2 }
            height:  40
            radius:  Theme.radius
            color:   Theme.panelBg
            border   { color: Theme.borderColor(0.55); width: 2 }
            visible: bar.windowTitle.length > 0
            implicitWidth: Math.min(winRow.implicitWidth + 20, 280)
            clip: true

            RowLayout {
                id: winRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text:  "󰖯"
                    color: Theme.clrBlue
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                Text {
                    text:  bar.windowTitle
                    color: Theme.clrText
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    elide: Text.ElideRight
                    Layout.maximumWidth: 230
                }
            }
        }

        // ── Music island: track + controls + progress + visualizer ───────────
        Rectangle {
            id: musicIsland
            anchors { right: rightIsland.left; rightMargin: 8; top: parent.top; topMargin: 2 }
            height:  40
            radius:  Theme.radius
            color:   Theme.panelBg
            border   { color: Theme.borderColor(0.55); width: 2 }
            visible: bar.activePlayer !== null && !bar.isLaptop
            width:   musicRow.implicitWidth + 20

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: 8

                // Icon (klick öffnet Overlay)
                Text {
                    text:  "󰝚"
                    color: Theme.clrMauve
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: bar.musicToggled()
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Scrolling title (klick öffnet Overlay)
                Item {
                    id: titleClip
                    implicitWidth: 180
                    implicitHeight: scrollText.implicitHeight
                    clip: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: scrollText
                        text:  bar.songText
                        color: Theme.clrText
                        font   { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }

                        onTextChanged: {
                            scrollText.x = 0
                            marquee.stop()
                            marqueeDelay.restart()
                        }
                        Component.onCompleted: marqueeDelay.restart()
                    }

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

                    MouseArea {
                        anchors.fill: parent
                        onClicked: bar.musicToggled()
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                // Controls
                Text {
                    text: "󰒮"
                    color: Theme.clrSubtext0
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (bar.activePlayer) bar.activePlayer.previous() }
                    }
                }
                Text {
                    text: (bar.activePlayer && bar.activePlayer.playbackState === MprisPlaybackState.Playing)
                          ? "󰏥" : "󰐊"
                    color: Theme.clrSky
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
                    color: Theme.clrSubtext0
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (bar.activePlayer) bar.activePlayer.next() }
                    }
                }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                // Progress
                Text {
                    text:  bar.formatTime(bar.trackPosition)
                    color: Theme.clrSubtext0
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                }

                Item {
                    implicitWidth: 90
                    implicitHeight: 4
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Theme.clrSurface1
                    }
                    Rectangle {
                        width: bar.trackLength > 0
                               ? parent.width * Math.min(bar.trackPosition / bar.trackLength, 1)
                               : 0
                        height: parent.height
                        radius: 2
                        color: Theme.clrSky
                    }
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
                    color: Theme.clrSubtext0
                    font   { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                }

                Rectangle {
                    width: 1; height: 20; color: Theme.clrSurface1
                    visible: vizContainer.visible
                }

                // Visualizer
                Item {
                    id: vizContainer
                    implicitWidth:  vizBars.implicitWidth
                    implicitHeight: 26
                    opacity: bar.hasAudio ? 1.0 : 0.0
                    visible: opacity > 0
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on opacity { NumberAnimation { duration: 700 } }

                    Row {
                        id: vizBars
                        anchors.centerIn: parent
                        spacing: 1

                        Repeater {
                            model: bar.barValues.length > 0 ? Math.min(bar.barValues.length, 44) : 44
                            delegate: Item {
                                required property int index
                                width:  2
                                height: 26

                                property real val: (index < bar.barValues.length)
                                                   ? bar.barValues[index] / 100.0 : 0.0

                                Rectangle {
                                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                    width:  parent.width
                                    height: Math.max(2, parent.height * parent.val)
                                    radius: 1
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: Theme.vizBarTop }
                                        GradientStop { position: 1.0; color: Qt.rgba(Theme.clrSky.r, Theme.clrSky.g, Theme.clrSky.b, 0.4) }
                                    }
                                    Behavior on height { NumberAnimation { duration: 55; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Center island: Stats ─────────────────────────────────────────────
        Rectangle {
            id: centerIsland
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 2 }
            height: 40
            radius: Theme.radius
            color: Theme.panelBg
            border { color: Theme.borderColor(0.55); width: 2 }
            width: statsRow.implicitWidth + 24

            RowLayout {
                id: statsRow
                anchors.centerIn: parent
                spacing: 14

                StatItem { icon: "󰻠"; value: bar.cpuUsage + "%"; valueChars: 4; iconColor: Theme.clrGreen;   textColor: Theme.clrText }
                StatItem { icon: "󰓅"; value: bar.cpuClock;        valueChars: 7; iconColor: Theme.clrSky;     textColor: Theme.clrText }
                StatItem { icon: "󱐋"; value: bar.cpuPower;        valueChars: 4; iconColor: Theme.clrPeach;   textColor: Theme.clrText }
                StatItem { icon: "󰔏"; value: bar.cpuTemp + "°C";  valueChars: 4; iconColor: Theme.clrYellow;  textColor: Theme.clrText }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                StatItem { icon: "󰍛"; value: bar.ramUsed + "G";   valueChars: 5; iconColor: Theme.clrMauve;   textColor: Theme.clrText }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                StatItem { icon: "󰢮"; value: bar.gpuUsage + "%";  valueChars: 4; iconColor: Theme.clrTeal;    textColor: Theme.clrText }
                StatItem { icon: "󰓅"; value: bar.gpuClock;         valueChars: 7; iconColor: Theme.clrSky;     textColor: Theme.clrText }
                StatItem { icon: "󱐋"; value: bar.gpuPower;         valueChars: 4; iconColor: Theme.clrPeach;   textColor: Theme.clrText }
                StatItem { icon: "󰔏"; value: bar.gpuTemp + "°C";   valueChars: 4; iconColor: Theme.clrYellow;  textColor: Theme.clrText }
                StatItem { icon: "󰆧"; value: bar.gpuVram;          valueChars: 6; iconColor: Theme.clrSky;     textColor: Theme.clrText }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                StatItem { icon: "󰁆"; value: bar.netDown; valueChars: 5; iconColor: Theme.clrBlue;     textColor: Theme.clrText }
                StatItem { icon: "󰁞"; value: bar.netUp;   valueChars: 5; iconColor: Theme.clrSapphire; textColor: Theme.clrText }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: bar.statsToggled()
                cursorShape: Qt.PointingHandCursor
            }
        }

        // ── Right island: Tray + Clock + Power ──────────────────────────────
        Rectangle {
            id: rightIsland
            anchors { right: parent.right; top: parent.top; topMargin: 2 }
            height: 40
            radius: Theme.radius
            color: Theme.panelBg
            border { color: Theme.borderColor(0.55); width: 2 }
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
                            QsMenuAnchor {
                                id: trayMenu
                                menu: modelData.menu
                                anchor.window: bar
                            }
                            IconImage {
                                anchors.fill: parent
                                source: modelData.icon
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                        var pos = mapToItem(bar.contentItem, 0, height)
                                        trayMenu.anchor.rect = Qt.rect(pos.x, pos.y, width, 0)
                                        trayMenu.open()
                                    } else {
                                        modelData.activate()
                                    }
                                }
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                // Clock
                Text {
                    text:  "󰃰 " + bar.clockTime
                    color: Theme.clrPink
                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true }
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle { width: 1; height: 20; color: Theme.clrSurface1 }

                // Power menu
                BarButton {
                    icon:      "󰐥"
                    iconColor: Theme.clrRed
                    onClicked: bar.powerMenu()
                }
            }
        }
    }

    function powerMenu() {
        var proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["/bin/sh", "-c", "$HOME/.config/quickshell/scripts/powermenu.sh"] }',
            bar
        )
        proc.running = true
    }
}
