import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property bool   sidePanelOpen: false
    property bool   searchOpen:    false
    property string searchQuery:   ""

    // ── Keyboard shortcut via FIFO ───────────────────────────────────────────
    // Hyprland bind: $mainMod SHIFT, Return, exec, echo 1 > /tmp/qs-search-toggle
    Process {
        command: ["/bin/bash",
                  Qt.resolvedUrl("scripts/search-listener.sh").toString().replace("file://", "")]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: _ => root.searchOpen = !root.searchOpen
        }
    }

    Bar {
        searchOpen:  root.searchOpen
        searchQuery: root.searchQuery
        onPanelToggled:        root.sidePanelOpen = !root.sidePanelOpen
        onSearchOpenRequested: root.searchOpen = true
        onSearchQueryUpdated:  q => root.searchQuery = q
        onSearchEnterPressed:  { if (searchLoader.item) searchLoader.item.launchFirst() }
        onSearchClosed:        { root.searchOpen = false; root.searchQuery = "" }
    }

    Loader {
        id: searchLoader
        active: root.searchOpen
        sourceComponent: Component {
            SearchResults {
                searchOpen:  root.searchOpen
                searchQuery: root.searchQuery
                onLaunchCalled: { root.searchOpen = false; root.searchQuery = "" }
            }
        }
    }

    SidePanel {
        panelOpen: root.sidePanelOpen
        onCloseRequested: root.sidePanelOpen = false
    }

    // Dismiss overlay — covers only the area to the RIGHT of the side panel
    PanelWindow {
        screen: {
            for (var i = 0; i < Quickshell.screens.length; i++)
                if (Quickshell.screens[i].name === "HDMI-A-1")
                    return Quickshell.screens[i]
            return Quickshell.screens[0]
        }
        anchors { top: true; left: true; right: true; bottom: true }
        margins { left: 392 }
        exclusiveZone: -1
        color: "transparent"
        visible: root.sidePanelOpen

        MouseArea {
            anchors.fill: parent
            onClicked: root.sidePanelOpen = false
        }
    }
}
