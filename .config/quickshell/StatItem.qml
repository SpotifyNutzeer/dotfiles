import QtQuick
import QtQuick.Layouts

RowLayout {
    property string icon:      ""
    property string value:     ""
    property color  iconColor: Theme.clrText
    property color  textColor: Theme.clrText
    // >0: reserviert feste Breite für so viele Monospace-Zeichen, damit der
    // Wert beim Wechsel der Stellenzahl die Bar nicht springen lässt.
    property int    valueChars: 0

    spacing: 4

    Text {
        text: icon
        color: iconColor
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
        Layout.alignment: Qt.AlignVCenter
    }
    Text {
        id: valueText
        text: value
        color: textColor
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        Layout.alignment: Qt.AlignVCenter
        // Feste Reserve, aber nie abschneiden: bei Überlänge wächst der Wert mit.
        Layout.preferredWidth: valueChars > 0
            ? Math.max(implicitWidth, Math.ceil(valueMetrics.advanceWidth * valueChars))
            : implicitWidth
    }

    TextMetrics {
        id: valueMetrics
        font: valueText.font
        text: "0"
    }
}
