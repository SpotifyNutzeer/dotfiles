import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Transiente Notification-Toasts oben rechts. Hört auf das notification-Signal
// des geteilten Servers (Owner: shell.qml) und zeigt jede neue Notification als
// Popup, das nach ~5 s verschwindet (kritische bleiben bis weggeklickt). Der
// Verlauf lebt unabhängig im SidePanel weiter — ein geschlossenes Popup entfernt
// die Notification NICHT aus trackedNotifications.
PanelWindow {
    id: root

    property var notifServer
    property var barScreen

    // Aktuell sichtbare Toasts (Notification-Objekte), neueste zuerst.
    property var popups: []

    screen: barScreen
    anchors { top: true; right: true }
    // Zen: Fenster reicht bis an den Rand, der Sichtabstand (notifRight) wandert
    // als innerer Margin an die Column — so hat der Schatten rechts Platz.
    margins { top: Theme.notifTop; right: Theme.shadowEnabled ? 0 : Theme.notifRight }
    exclusiveZone: -1
    color: "transparent"
    visible: popups.length > 0

    implicitWidth: 380
    implicitHeight: col.implicitHeight + (Theme.shadowEnabled ? 24 : 0)

    function removePopup(notif) {
        root.popups = root.popups.filter(n => n !== notif)
    }

    Connections {
        target: root.notifServer
        function onNotification(notification) {
            root.popups = [notification].concat(root.popups)
        }
    }

    Column {
        id: col
        anchors { top: parent.top; right: parent.right; rightMargin: Theme.shadowEnabled ? Theme.notifRight : 0 }
        width: 360
        spacing: 8

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "x"; from: 40; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
        move: Transition {
            NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.popups

            delegate: Rectangle {
                id: toast
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                width: col.width
                height: row.implicitHeight + 20
                radius: Theme.notifRadius
                color: Theme.notifBg
                border.width: toast.critical ? 1 : Theme.notifBorderWidth
                border.color: toast.critical ? Theme.clrRed : Theme.borderColor(0.3)

                // Zen: weicher Schatten statt Border — Tiefe ohne Linien.
                layer.enabled: Theme.shadowEnabled
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.45)
                    shadowBlur: 0.9
                    shadowVerticalOffset: 4
                }

                // Auto-Dismiss des Toasts (nicht des Verlauf-Eintrags).
                Timer {
                    interval: 5000
                    running: !toast.critical
                    onTriggered: root.removePopup(toast.modelData)
                }

                // Verschwindet die Notification anderweitig (z. B. SidePanel-X,
                // App schließt sie), Toast mitentfernen.
                Connections {
                    target: toast.modelData
                    function onClosed(reason) { root.removePopup(toast.modelData) }
                }

                RowLayout {
                    id: row
                    anchors { fill: parent; margins: 10 }
                    spacing: 10

                    Image {
                        visible: toast.modelData.image !== ""
                        source: toast.modelData.image
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignTop
                        fillMode: Image.PreserveAspectCrop
                        sourceSize { width: 40; height: 40 }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: toast.modelData.appName !== "" ? toast.modelData.appName : "Notification"
                            color: toast.critical ? Theme.clrRed : Theme.clrSky
                            font { pixelSize: 11; family: "JetBrainsMono Nerd Font" }
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: toast.modelData.summary
                            color: Theme.clrText
                            font { pixelSize: 14; bold: true; family: "JetBrainsMono Nerd Font" }
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: toast.modelData.body
                            color: Theme.clrSubtext0
                            font { pixelSize: 12; family: "JetBrainsMono Nerd Font" }
                            visible: toast.modelData.body !== ""
                            textFormat: Text.StyledText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: "󰅖"
                        color: Theme.clrSubtext1
                        font { pixelSize: 16; family: "JetBrainsMono Nerd Font" }
                        Layout.alignment: Qt.AlignTop
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removePopup(toast.modelData)
                        }
                    }
                }
            }
        }
    }
}
