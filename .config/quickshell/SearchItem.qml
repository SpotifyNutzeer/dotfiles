import QtQuick
import QtQuick.Layouts

Item {
    property string itemIcon:     ""
    property string itemIconPath: ""
    property color  itemColor:    "#cdd6f4"
    property string itemLabel:    ""

    signal activated()

    implicitHeight: 36

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: ma.containsMouse ? "#313244" : "transparent"
    }

    RowLayout {
        anchors {
            left: parent.left; right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 10; rightMargin: 10
        }
        spacing: 10

        // Real icon image (if path resolved)
        Image {
            visible: itemIconPath !== ""
            source:  itemIconPath !== "" ? "file://" + itemIconPath : ""
            width:  20; height: 20
            sourceSize: Qt.size(20, 20)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Nerd Font fallback (shown when no image path)
        Text {
            visible: itemIconPath === ""
            text:    itemIcon
            color:   itemColor
            font     { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
        }

        Text {
            text:  itemLabel
            color: "#cdd6f4"
            font   { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            elide: Text.ElideRight
            Layout.fillWidth: true
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
