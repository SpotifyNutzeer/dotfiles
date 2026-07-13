import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: overlay

    property real   panelWidth: 800
    property bool   statsOpen:  false

    // ── Werte von Bar ────────────────────────────────────────────────────────
    property string cpuUsage: "0";  property string cpuClock: "0MHz"
    property string cpuPower: "0W"; property string cpuTemp:  "0"
    property string ramUsed:  "0.0"
    property string gpuUsage: "0";  property string gpuClock: "0MHz"
    property string gpuPower: "0W"; property string gpuTemp:  "0"
    property string gpuVram:  "0M"
    property string netDown:  "0K"; property string netUp:    "0K"

    property var  cpuHistory:     []
    property var  gpuHistory:     []
    property var  ramHistory:     []
    property var  netDownHistory: []
    property real netDownMax:     1000

    // ── Systeminfos ──────────────────────────────────────────────────────────
    property string privateIp: "…"
    property string publicIp:  "…"
    property string coreCount: "…"
    property string uptimeStr: "…"
    property string kernelVer: "…"
    property string hostname:  "…"

    Process {
        command: ["bash", "-c",
            "ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\"){print $(i+1);exit}}'"]
        running: true
        stdout: SplitParser { splitMarker: "\n"
            onRead: d => { if (d.trim()) overlay.privateIp = d.trim() } }
    }
    Process {
        id: pubIpProc
        command: ["bash", "-c", "curl -s --max-time 8 ifconfig.me 2>/dev/null || echo '?'"]
        running: true
        stdout: SplitParser { splitMarker: "\n"
            onRead: d => { if (d.trim()) overlay.publicIp = d.trim() } }
    }
    Timer { interval: 1800000; repeat: true; running: true
        onTriggered: if (!pubIpProc.running) pubIpProc.running = true }
    Process {
        command: ["nproc"]
        running: true
        stdout: SplitParser { splitMarker: "\n"
            onRead: d => { if (d.trim()) overlay.coreCount = d.trim() } }
    }
    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/^up //'"]
        running: true
        stdout: SplitParser { splitMarker: "\n"
            onRead: d => { if (d.trim()) overlay.uptimeStr = d.trim() } }
    }
    Timer { interval: 60000; repeat: true; running: true
        onTriggered: if (!uptimeProc.running) uptimeProc.running = true }
    Process {
        command: ["bash", "-c", "uname -r | cut -d'-' -f1,2"]
        running: true
        stdout: SplitParser { splitMarker: "\n"
            onRead: d => { if (d.trim()) overlay.kernelVer = d.trim() } }
    }
    Process {
        command: ["bash", "-c", "hostname -s 2>/dev/null || cat /etc/hostname"]
        running: true
        stdout: SplitParser { splitMarker: "\n"
            onRead: d => { if (d.trim()) overlay.hostname = d.trim() } }
    }

    readonly property string nfFont: "JetBrainsMono Nerd Font"

    // ── Fenster ──────────────────────────────────────────────────────────────
    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "HDMI-A-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    anchors { top: true; left: true; right: true }
    margins { top: Theme.overlayTop; left: 12; right: 12 }
    exclusiveZone: -1
    color: "transparent"
    implicitHeight: statsOpen ? 228 : 4
    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }

    // ── Haupt-Panel ──────────────────────────────────────────────────────────
    ZenPanelSurface {
        targetX:     statsPanel.x
        targetWidth: statsPanel.width
        panelHeight: statsPanel.height
        open:        overlay.statsOpen
    }

    Rectangle {
        id: statsPanel
        anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width:  overlay.panelWidth
        radius: Theme.radius
        color:  Theme.zen ? "transparent" : Theme.panelBg
        border  { color: Theme.borderColor(0.55); width: Theme.overlayBorderWidth }
        clip:   true
        opacity: overlay.statsOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

        ColumnLayout {
            anchors { fill: parent; margins: 12; topMargin: 10; bottomMargin: 10 }
            spacing: 10

            // ── Cards ────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // CPU Card
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.clrSurface0; radius: 8

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 2; radius: 8; color: Theme.clrGreen
                    }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10; topMargin: 8; bottomMargin: 8 }
                        spacing: 5

                        RowLayout {
                            spacing: 5
                            Text { text: "󰻠"; color: Theme.clrGreen
                                font { family: overlay.nfFont; pixelSize: 12 } }
                            Text { text: "CPU"; color: Theme.clrGreen
                                font { family: overlay.nfFont; pixelSize: 11; bold: true } }
                        }

                        MiniGraph {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            history: overlay.cpuHistory; lineColor: Theme.clrGreen
                            maxValue: 100; showLabel: false
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2; columnSpacing: 10; rowSpacing: 3

                            Row { spacing: 3
                                Text { text: "󰻠 "; color: Theme.clrGreen;  font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.cpuUsage + "%"; color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󰓅 "; color: Theme.clrSky;    font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.cpuClock;  color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󱐋 "; color: Theme.clrPeach;  font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.cpuPower;  color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󰔏 "; color: Theme.clrYellow; font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.cpuTemp + "°C"; color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                        }
                    }
                }

                // GPU Card
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.clrSurface0; radius: 8

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 2; radius: 8; color: Theme.clrTeal
                    }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10; topMargin: 8; bottomMargin: 8 }
                        spacing: 5

                        RowLayout {
                            spacing: 5
                            Text { text: "󰢮"; color: Theme.clrTeal
                                font { family: overlay.nfFont; pixelSize: 12 } }
                            Text { text: "GPU"; color: Theme.clrTeal
                                font { family: overlay.nfFont; pixelSize: 11; bold: true } }
                        }

                        MiniGraph {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            history: overlay.gpuHistory; lineColor: Theme.clrTeal
                            maxValue: 100; showLabel: false
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3; columnSpacing: 10; rowSpacing: 3

                            Row { spacing: 3
                                Text { text: "󰢮 "; color: Theme.clrTeal;   font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.gpuUsage + "%"; color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󰓅 "; color: Theme.clrSky;    font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.gpuClock;  color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󱐋 "; color: Theme.clrPeach;  font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.gpuPower;  color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󰔏 "; color: Theme.clrYellow; font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.gpuTemp + "°C"; color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󰆧 "; color: Theme.clrSky;    font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.gpuVram;   color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Item {}
                        }
                    }
                }

                // RAM Card
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.clrSurface0; radius: 8

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 2; radius: 8; color: Theme.clrMauve
                    }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10; topMargin: 8; bottomMargin: 8 }
                        spacing: 5

                        RowLayout {
                            spacing: 5
                            Text { text: "󰍛"; color: Theme.clrMauve
                                font { family: overlay.nfFont; pixelSize: 12 } }
                            Text { text: "RAM"; color: Theme.clrMauve
                                font { family: overlay.nfFont; pixelSize: 11; bold: true } }
                        }

                        MiniGraph {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            history: overlay.ramHistory; lineColor: Theme.clrMauve
                            maxValue: 64; showLabel: false
                        }

                        Row { spacing: 3; Layout.alignment: Qt.AlignHCenter
                            Text { text: "󰍛 "; color: Theme.clrMauve;    font { family: overlay.nfFont; pixelSize: 11 } }
                            Text { text: overlay.ramUsed + " G"; color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                        }
                    }
                }

                // NET Card
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: Theme.clrSurface0; radius: 8

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 2; radius: 8; color: Theme.clrBlue
                    }

                    ColumnLayout {
                        anchors { fill: parent; margins: 10; topMargin: 8; bottomMargin: 8 }
                        spacing: 5

                        RowLayout {
                            spacing: 5
                            Text { text: "󰛳"; color: Theme.clrBlue
                                font { family: overlay.nfFont; pixelSize: 12 } }
                            Text { text: "Netzwerk"; color: Theme.clrBlue
                                font { family: overlay.nfFont; pixelSize: 11; bold: true } }
                        }

                        MiniGraph {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            history: overlay.netDownHistory; lineColor: Theme.clrBlue
                            maxValue: overlay.netDownMax; showLabel: false
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3
                            Row { spacing: 3
                                Text { text: "󰁆 "; color: Theme.clrBlue;     font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.netDown; color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                            Row { spacing: 3
                                Text { text: "󰁞 "; color: Theme.clrSapphire; font { family: overlay.nfFont; pixelSize: 11 } }
                                Text { text: overlay.netUp;   color: Theme.clrSubtext0; font { family: overlay.nfFont; pixelSize: 11 } }
                            }
                        }
                    }
                }
            }

            // ── Trennlinie ───────────────────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.clrSurface1; opacity: 0.5 }

            // ── Systeminfo-Leiste ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                // Hostname
                Row { spacing: 4
                    Text { text: "󰟀"; color: Theme.clrSky; font { family: overlay.nfFont; pixelSize: 13 } }
                    Text { text: overlay.hostname; color: Theme.clrText; font { family: overlay.nfFont; pixelSize: 12 } }
                }

                Rectangle { width: 1; height: 14; color: Theme.clrSurface1; opacity: 0.6
                    Layout.leftMargin: 10; Layout.rightMargin: 10 }

                // Private IP
                Row { spacing: 4
                    Text { text: "󰈀"; color: Theme.clrGreen; font { family: overlay.nfFont; pixelSize: 13 } }
                    Text { text: overlay.privateIp; color: Theme.clrText; font { family: overlay.nfFont; pixelSize: 12 } }
                }

                Rectangle { width: 1; height: 14; color: Theme.clrSurface1; opacity: 0.6
                    Layout.leftMargin: 10; Layout.rightMargin: 10 }

                // Public IP
                Row { spacing: 4
                    Text { text: "󰀃"; color: Theme.clrBlue; font { family: overlay.nfFont; pixelSize: 13 } }
                    Text { text: overlay.publicIp; color: Theme.clrText; font { family: overlay.nfFont; pixelSize: 12 } }
                }

                Rectangle { width: 1; height: 14; color: Theme.clrSurface1; opacity: 0.6
                    Layout.leftMargin: 10; Layout.rightMargin: 10 }

                // Kerne
                Row { spacing: 4
                    Text { text: "󰘚"; color: Theme.clrTeal; font { family: overlay.nfFont; pixelSize: 13 } }
                    Text { text: overlay.coreCount + " Cores"; color: Theme.clrText; font { family: overlay.nfFont; pixelSize: 12 } }
                }

                Rectangle { width: 1; height: 14; color: Theme.clrSurface1; opacity: 0.6
                    Layout.leftMargin: 10; Layout.rightMargin: 10 }

                // Kernel
                Row { spacing: 4
                    Text { text: "󰌽"; color: Theme.clrPeach; font { family: overlay.nfFont; pixelSize: 13 } }
                    Text { text: overlay.kernelVer; color: Theme.clrText; font { family: overlay.nfFont; pixelSize: 12 } }
                }

                Rectangle { width: 1; height: 14; color: Theme.clrSurface1; opacity: 0.6
                    Layout.leftMargin: 10; Layout.rightMargin: 10 }

                // Uptime
                Row { spacing: 4
                    Text { text: "󰔟"; color: Theme.clrPink; font { family: overlay.nfFont; pixelSize: 13 } }
                    Text { text: overlay.uptimeStr; color: Theme.clrText; font { family: overlay.nfFont; pixelSize: 12 } }
                }
            }
        }
    }
}
