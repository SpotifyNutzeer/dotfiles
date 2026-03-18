import QtQuick
import QtQuick.Layouts

RowLayout {
    property string icon:      ""
    property string value:     ""
    property color  iconColor: "#cdd6f4"
    property color  textColor: "#cdd6f4"

    spacing: 4

    Text {
        text: icon
        color: iconColor
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
        Layout.alignment: Qt.AlignVCenter
    }
    Text {
        text: value
        color: textColor
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        Layout.alignment: Qt.AlignVCenter
    }
}
