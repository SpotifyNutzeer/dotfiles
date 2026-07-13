import QtQuick
import QtQuick.Layouts

Item {
    id: searchItem

    property string itemIcon:     ""
    property string itemIconPath: ""
    property color  itemColor:    "#cdd6f4"
    property string itemLabel:    ""

    signal activated()

    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: ma.containsMouse ? Qt.rgba(0.706, 0.745, 0.996, 0.15) : "transparent"
        
        Behavior on color { ColorAnimation { duration: 150 } }

        // Subtle border on hover
        border {
            color: ma.containsMouse ? Qt.rgba(0.706, 0.745, 0.996, 0.3) : "transparent"
            width: 1
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12; rightMargin: 12
        }
        spacing: 12

        // App Icon
        Rectangle {
            width: 32; height: 32; radius: 8
            color: Qt.rgba(24, 24, 37, 0.5)
            clip: true
            
            Image {
                visible: itemIconPath !== ""
                anchors.centerIn: parent
                source:  itemIconPath !== "" ? "file://" + itemIconPath : ""
                width:  24; height: 24
                sourceSize: Qt.size(24, 24)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                visible: itemIconPath === ""
                anchors.centerIn: parent
                text: "󰀻"
                color: itemColor
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
            }
        }

        Text {
            text:  itemLabel
            color: ma.containsMouse ? "#ffffff" : "#cdd6f4"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: ma.containsMouse }
            elide: Text.ElideRight
            Layout.fillWidth: true
            
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Indicator for "Enter to launch"
        Text {
            visible: ma.containsMouse
            text: "󰌑"
            color: Qt.rgba(0.706, 0.745, 0.996, 0.5)
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: activated()
    }
}
