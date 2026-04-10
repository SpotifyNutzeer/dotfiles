import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: results
    property bool searchOpen: false
    property string searchQuery: ""
    signal launchCalled()

    screen: Quickshell.screens[0]
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusiveZone: -1
    color: "transparent"
    visible: searchOpen

    onVisibleChanged: {
        if (visible) {
            results.searchQuery = ""
            inputField.text = ""
            focusTimer.start()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            inputField.forceActiveFocus()
        }
    }

    property var allApps: []
    Process {
        id: appLoader
        running: true
        command: ["python3", Qt.resolvedUrl("scripts/list-apps.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: function(d) {
                var p = d.split("|")
                if (p.length >= 2) {
                    results.allApps.push({
                        name: p[0].trim(),
                        exec: p[1].trim(),
                        iconPath: (p[2] || "").trim()
                    })
                }
            }
        }
    }

    function launch(app) {
        var p = Qt.createQmlObject("import Quickshell.Io; Process {}", results)
        p.command = ["bash", "-c", "setsid -f " + app.exec + " >/dev/null 2>&1 &"]
        p.running = true
        results.launchCalled()
    }

    property var filteredApps: {
        var q = searchQuery.toLowerCase()
        var list = allApps.filter(function(a) {
            return a.name.toLowerCase().includes(q)
        })
        return list.slice(0, 6)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            results.launchCalled()
        }
    }

    Rectangle {
        width: 350
        height: Math.min(mainCol.implicitHeight + 24, 450)
        x: 20
        y: 60
        color: "#181825"
        radius: 16
        border {
            color: "#313244"
            width: 2
        }

        ColumnLayout {
            id: mainCol
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 10
                color: "#313244"

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 8
                    }
                    Text {
                        text: "󰍉"
                        color: "#b4befe"
                    }
                    TextInput {
                        id: inputField
                        Layout.fillWidth: true
                        color: "#cdd6f4"
                        font {
                            pixelSize: 14
                        }
                        onTextChanged: {
                            results.searchQuery = text
                        }
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (results.filteredApps.length > 0) {
                                    results.launch(results.filteredApps[0])
                                }
                            }
                            if (event.key === Qt.Key_Escape) {
                                results.launchCalled()
                            }
                        }
                    }
                }
            }

            Repeater {
                model: results.filteredApps
                delegate: SearchItem {
                    Layout.fillWidth: true
                    itemLabel: modelData.name
                    itemIconPath: modelData.iconPath
                    onActivated: {
                        results.launch(modelData)
                    }
                }
            }
        }
    }
}
