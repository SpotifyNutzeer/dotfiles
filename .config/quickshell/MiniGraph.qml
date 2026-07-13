import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property var    history:   []
    property color  lineColor: Theme.clrBlue
    property string label:     ""
    property real   maxValue:  100
    property bool   showLabel: true

    spacing: 4

    onHistoryChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        Layout.fillWidth: true
        Layout.fillHeight: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var h = root.history
            if (!h || h.length < 2) return

            var maxV = root.maxValue > 0 ? root.maxValue : 1
            var pad  = 3

            function getY(v) {
                return height - pad - (Math.min(Math.max(v, 0), maxV) / maxV) * (height - pad * 2)
            }

            function rgba(c, a) {
                return "rgba(" + Math.round(c.r * 255) + ","
                               + Math.round(c.g * 255) + ","
                               + Math.round(c.b * 255) + "," + a + ")"
            }

            // Filled area under line
            ctx.beginPath()
            ctx.moveTo(0, getY(h[0]))
            for (var i = 1; i < h.length; i++)
                ctx.lineTo((i / (h.length - 1)) * width, getY(h[i]))
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            var grad = ctx.createLinearGradient(0, 0, 0, height)
            grad.addColorStop(0, rgba(root.lineColor, 0.28))
            grad.addColorStop(1, rgba(root.lineColor, 0.0))
            ctx.fillStyle = grad
            ctx.fill()

            // Line
            ctx.beginPath()
            ctx.strokeStyle = rgba(root.lineColor, 0.9)
            ctx.lineWidth   = 1.5
            ctx.lineJoin    = "round"
            ctx.moveTo(0, getY(h[0]))
            for (var i = 1; i < h.length; i++)
                ctx.lineTo((i / (h.length - 1)) * width, getY(h[i]))
            ctx.stroke()

            // Dot at latest value
            var lx = width
            var ly = getY(h[h.length - 1])
            ctx.beginPath()
            ctx.arc(lx - 0.5, ly, 2.5, 0, Math.PI * 2)
            ctx.fillStyle = rgba(root.lineColor, 1.0)
            ctx.fill()
        }
    }

    Text {
        visible: root.showLabel
        Layout.alignment: Qt.AlignHCenter
        text: {
            if (root.history.length === 0) return root.label
            var v = root.history[root.history.length - 1]
            var s = v < 10 ? v.toFixed(1) : Math.round(v).toString()
            return root.label ? (root.label + "  " + s) : s
        }
        color: Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.65)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
    }
}
