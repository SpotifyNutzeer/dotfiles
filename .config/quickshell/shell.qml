//@ pragma UseQApplication
import Quickshell
import QtQuick

ShellRoot {
    id: root

    property bool sidePanelOpen: false

    Bar {
        onPanelToggled: root.sidePanelOpen = !root.sidePanelOpen
    }

    SidePanel {
        panelOpen: root.sidePanelOpen
        onCloseRequested: root.sidePanelOpen = false
    }

    // Dismiss overlay for SidePanel
    PanelWindow {
        screen: Quickshell.screens[0]
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        margins {
            left: 316
        }
        exclusiveZone: -1
        color: "transparent"
        visible: root.sidePanelOpen
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.sidePanelOpen = false
            }
        }
    }
}
