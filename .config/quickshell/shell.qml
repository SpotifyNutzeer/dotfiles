//@ pragma UseQApplication
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    id: root

    property bool sidePanelOpen:  false
    property bool statsOpen:      false
    property bool musicOpen:      false

    // ── Notifications ───────────────────────────────────────────────────────────
    // Einziger Server (besitzt org.freedesktop.Notifications). Eingehende
    // Notifications müssen explizit getrackt werden, sonst werden sie sofort
    // verworfen. trackedNotifications speist SidePanel-Verlauf + Popups.
    NotificationServer {
        id: notifServer
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: false
        onNotification: (notification) => { notification.tracked = true }
    }

    Bar {
        id: mainBar
        onPanelToggled: root.sidePanelOpen = !root.sidePanelOpen
        onStatsToggled: root.statsOpen     = !root.statsOpen
        onMusicToggled: root.musicOpen     = !root.musicOpen
    }

    SidePanel {
        panelOpen: root.sidePanelOpen
        notifServer: notifServer
        onCloseRequested: root.sidePanelOpen = false
    }

    NotificationPopup {
        notifServer: notifServer
        barScreen:   mainBar.screen
    }

    StatsOverlay {
        statsOpen:      root.statsOpen
        panelWidth:     mainBar.centerIslandWidth

        cpuUsage:  mainBar.cpuUsage
        cpuClock:  mainBar.cpuClock
        cpuPower:  mainBar.cpuPower
        cpuTemp:   mainBar.cpuTemp
        ramUsed:   mainBar.ramUsed
        gpuUsage:  mainBar.gpuUsage
        gpuClock:  mainBar.gpuClock
        gpuPower:  mainBar.gpuPower
        gpuTemp:   mainBar.gpuTemp
        gpuVram:   mainBar.gpuVram
        netDown:   mainBar.netDown
        netUp:     mainBar.netUp

        cpuHistory:     mainBar.cpuHistory
        gpuHistory:     mainBar.gpuHistory
        ramHistory:     mainBar.ramHistory
        netDownHistory: mainBar.netDownHistory
        netDownMax:     mainBar.netDownMax
    }

    MusicOverlay {
        musicOpen:     root.musicOpen
        islandX:       mainBar.musicIslandX
        islandWidth:   mainBar.musicIslandWidth
        player:        mainBar.activePlayer
        trackPosition: mainBar.trackPosition
        trackLength:   mainBar.trackLength
    }

    // Klick außerhalb schließt MusicOverlay
    PanelWindow {
        screen: mainBar.screen
        anchors { top: true; left: true; right: true; bottom: true }
        margins { top: 58 }
        exclusiveZone: -1
        color: "transparent"
        visible: root.musicOpen
        MouseArea {
            anchors.fill: parent
            onClicked: root.musicOpen = false
        }
    }

    // Klick außerhalb schließt StatsOverlay
    PanelWindow {
        screen: mainBar.screen
        anchors { top: true; left: true; right: true; bottom: true }
        margins { top: 58 }
        exclusiveZone: -1
        color: "transparent"
        visible: root.statsOpen
        MouseArea {
            anchors.fill: parent
            onClicked: root.statsOpen = false
        }
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
