import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
    id: viz

    property bool isFullscreen: false

    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === "HDMI-A-1") return Quickshell.screens[i]
            if (Quickshell.screens[i].name === "DP-2") return Quickshell.screens[i]
            if (Quickshell.screens[i].name === "DP-1") return Quickshell.screens[i]
        }
        return Quickshell.screens[0]
    }

    anchors {
        top:    true
        bottom: true
        left:   true
        right:  true
    }

    visible: isFullscreen
    exclusiveZone: -1
    color: Qt.rgba(0.01, 0.01, 0.02, 0.85) // Slightly darker for focus

    // ── State ─────────────────────────────────────────────────────────────────
    property var  barValues:   []
    property bool hasAudio:    false
    property real silenceSecs: 0

    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            var loud = viz.barValues.some(v => v > 2)
            if (loud) {
                viz.hasAudio    = true
                viz.silenceSecs = 0
            } else {
                viz.silenceSecs += 0.5
                if (viz.silenceSecs >= 4) viz.hasAudio = false
            }
        }
    }

    // ── Cava ──────────────────────────────────────────────────────────────────
    Process {
        command: ["cava", "-p",
                  Qt.resolvedUrl("scripts/cava.ini").toString().replace("file://", "")]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                var parts = d.trim().split(" ")
                if (parts.length > 1)
                    viz.barValues = parts.map(v => Math.max(0, parseInt(v) || 0))
            }
        }
    }

    // ── Visual ────────────────────────────────────────────────────────────────
    Item {
        id: rootItem
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: viz.isFullscreen = false
        }

        // Glassmorphic backdrop - making it much wider
        Rectangle {
            id: backdrop
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            width:  parent.width * 0.94
            height: parent.height * 0.8
            radius: 40
            color:  Qt.rgba(0.094, 0.094, 0.137, viz.hasAudio ? 0.92 : 0.0)
            border {
                color: Qt.rgba(0.706, 0.745, 0.996, viz.hasAudio ? 0.35 : 0.0)
                width: 2
            }

            // Top glow line
            Rectangle {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                width:   parent.width * 0.8
                height:  2
                radius:  1
                color:   Qt.rgba(0.706, 0.745, 0.996, viz.hasAudio ? 0.6 : 0.0)
            }
        }

        // Bars
        Row {
            id: bars
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: backdrop.bottom
                bottomMargin: 60
            }
            spacing: Math.max(2, (backdrop.width - 40) / 150) // Dynamic spacing

            Repeater {
                model: viz.barValues.length > 0 ? Math.min(viz.barValues.length, 120) : 120
                delegate: Item {
                    required property int index
                    // Calculate width to fit 120 bars into 90% of screen
                    width:  (backdrop.width - (119 * bars.spacing) - 80) / 120
                    height: backdrop.height * 0.85

                    property real val: (index < viz.barValues.length)
                                       ? viz.barValues[index] / 100.0 : 0.0

                    // Soft glow behind bar
                    Rectangle {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width:  parent.width + 6
                        height: Math.max(1, parent.height * parent.val)
                        radius: 8
                        color:  Qt.rgba(0.706, 0.745, 0.996, 0.18 * parent.val)
                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                    }

                    // Main bar with gradient
                    Rectangle {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width:  parent.width
                        height: Math.max(2, parent.height * parent.val)
                        radius: 4
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "#e0e4ff" }
                            GradientStop { position: 0.5; color: "#b4befe" }
                            GradientStop { position: 1.0; color: Qt.rgba(0.706, 0.745, 0.996, 0.4) }
                        }
                        Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }
    }
}
