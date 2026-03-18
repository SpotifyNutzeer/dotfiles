import QtQuick
import QtQuick.Layouts

Item {
    id: btn

    property string icon:      ""
    property color  iconColor: "#cdd6f4"

    signal clicked()

    implicitWidth:  28
    implicitHeight: 28
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouseArea.containsMouse ? "#313244" : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text:  btn.icon
        color: btn.iconColor
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
