import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: results

    property bool   searchOpen:  false
    property string searchQuery: ""

    signal launchCalled()

    // ── Catppuccin Mocha ─────────────────────────────────────────────────────
    readonly property color clrMantle:   "#181825"
    readonly property color clrSurface0: "#313244"
    readonly property color clrSurface1: "#45475a"
    readonly property color clrText:     "#cdd6f4"
    readonly property color clrLavender: "#b4befe"
    readonly property color clrBlue:     "#89b4fa"
    readonly property color clrSky:      "#89dceb"
    readonly property color clrYellow:   "#f9e2af"
    readonly property color clrPeach:    "#fab387"
    readonly property color clrRed:      "#f38ba8"

    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "HDMI-A-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    // Positioned just below the bar's left island
    anchors  { top: true; left: true }
    margins  { top: 8; left: 12 }
    implicitWidth:  420
    implicitHeight: Math.min(mainCol.implicitHeight + 16, 520)
    exclusiveZone:  0
    color: "transparent"

    // ── App loading (once at startup) ────────────────────────────────────────
    property var allApps: []
    property var _buf:    []

    Process {
        id: appLoader
        command: ["python3", Qt.resolvedUrl("scripts/list-apps.py").toString().replace("file://", "")]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                if (!d.trim()) return
                var p = d.split("|")
                if (p.length >= 2 && p[0].trim() && p[1].trim())
                    results._buf.push({ name: p[0].trim(), exec: p[1].trim(), iconPath: (p[2] || "").trim() })
            }
        }
        onRunningChanged: { if (!running) results.allApps = results._buf.slice() }
    }

    // ── Filtered apps ────────────────────────────────────────────────────────
    property var filteredApps: {
        if (!searchQuery || searchQuery.length < 1) return []
        var q = searchQuery.toLowerCase()
        var starts   = allApps.filter(a =>  a.name.toLowerCase().startsWith(q))
        var contains = allApps.filter(a => !a.name.toLowerCase().startsWith(q)
                                        &&  a.name.toLowerCase().includes(q))
        return starts.concat(contains).slice(0, 8)
    }

    // ── Power options ────────────────────────────────────────────────────────
    readonly property var powerOpts: [
        { name: "Lock",     exec: "loginctl lock-session",  icon: "󰍁", clr: "#89b4fa" },
        { name: "Suspend",  exec: "systemctl suspend",       icon: "󰒲", clr: "#89dceb" },
        { name: "Logout",   exec: "hyprctl dispatch exit",   icon: "󰍃", clr: "#f9e2af" },
        { name: "Reboot",   exec: "systemctl reboot",        icon: "󰜉", clr: "#fab387" },
        { name: "Shutdown", exec: "systemctl poweroff",      icon: "󰐥", clr: "#f38ba8" }
    ]

    property var filteredPower: {
        if (!searchQuery || searchQuery.length < 1) return powerOpts
        var q = searchQuery.toLowerCase()
        return powerOpts.filter(p => p.name.toLowerCase().includes(q))
    }

    // ── Launcher ─────────────────────────────────────────────────────────────
    Process {
        id: launcher
        property string cmd: ""
        command: ["/bin/bash", "-c", cmd]
    }

    function launch(exec) {
        launcher.cmd = exec
        launcher.running = true
        results.launchCalled()
    }

    function launchFirst() {
        if (filteredApps.length > 0)   launch(filteredApps[0].exec)
        else if (filteredPower.length > 0) launch(filteredPower[0].exec)
    }

    // ── Slide-down animation ─────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: dropDown
            width:  parent.width
            height: parent.height
            y: results.searchOpen ? 0 : -parent.height

            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            color:  results.clrMantle
            radius: 16
            border { color: Qt.rgba(0.706, 0.745, 0.996, 0.35); width: 2 }

            // Scroll if results overflow
            Flickable {
                anchors { fill: parent; margins: 8 }
                clip:          true
                contentWidth:  width
                contentHeight: mainCol.implicitHeight

                ColumnLayout {
                    id:      mainCol
                    width:   parent.width
                    spacing: 2

                    // ── Apps ─────────────────────────────────────────────────
                    Text {
                        visible: results.filteredApps.length > 0
                        text:    "APPS"
                        color:   results.clrLavender
                        font     { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true; letterSpacing: 1.5 }
                        Layout.topMargin: 6; Layout.leftMargin: 6; Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: results.filteredApps
                        delegate: SearchItem {
                            required property var modelData
                            Layout.fillWidth: true
                            itemIcon:     "󰀻"
                            itemIconPath: modelData.iconPath
                            itemColor:    results.clrBlue
                            itemLabel:    modelData.name
                            onActivated:  results.launch(modelData.exec)
                        }
                    }

                    Rectangle {
                        visible: results.filteredApps.length > 0 && results.filteredPower.length > 0
                        Layout.fillWidth: true
                        height: 1
                        color:  results.clrSurface1
                        Layout.topMargin: 4; Layout.bottomMargin: 4
                    }

                    // ── Power ─────────────────────────────────────────────────
                    Text {
                        visible: results.filteredPower.length > 0
                        text:    "POWER"
                        color:   results.clrLavender
                        font     { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true; letterSpacing: 1.5 }
                        Layout.topMargin: results.filteredApps.length > 0 ? 0 : 6
                        Layout.leftMargin: 6; Layout.bottomMargin: 2
                    }

                    Repeater {
                        model: results.filteredPower
                        delegate: SearchItem {
                            required property var modelData
                            Layout.fillWidth: true
                            itemIcon:  modelData.icon
                            itemColor: modelData.clr
                            itemLabel: modelData.name
                            onActivated: results.launch(modelData.exec)
                        }
                    }

                    Item { implicitHeight: 6 }
                }
            }
        }
    }
}
