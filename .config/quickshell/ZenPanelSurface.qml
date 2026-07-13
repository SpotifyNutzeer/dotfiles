import QtQuick

// Zen-Hintergrund für Overlays, die aus der Bar "herauswachsen":
// Mantle-Fläche mit konkaven Flares an der Oberkante (Anschluss an die Bar)
// und gerundeten unteren Ecken. Plus Squash-and-Stretch beim Öffnen (Jelly).
// Wird als Geschwister HINTER dem Panel-Rectangle platziert (nicht als Kind —
// deren clip würde die Flares abschneiden).
Item {
    id: surface

    property real targetX:     0      // x des Panels im Overlay-Fenster
    property real targetWidth: 200    // Breite des Panels
    property real panelHeight: 0      // Höhe des Panels (Fensterhöhe)
    property bool open:        false

    readonly property int f: Theme.filletSize
    readonly property int r: Theme.radius

    visible: Theme.zen
    x: targetX - f
    y: 0
    width:  targetWidth + 2 * f
    height: panelHeight
    opacity: open ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

    // Jelly: leichter vertikaler Stretch beim Öffnen, von der Oberkante aus.
    transform: Scale {
        id: jelly
        origin.x: surface.width / 2
        origin.y: 0
        yScale: 1.0
    }
    onOpenChanged: if (open && Theme.zen) jellyAnim.restart()
    SequentialAnimation {
        id: jellyAnim
        NumberAnimation { target: jelly; property: "yScale"; from: 0.96; to: 1.05; duration: Theme.durNormal * 0.5; easing.type: Easing.OutQuad }
        NumberAnimation { target: jelly; property: "yScale"; to: 1.0; duration: Theme.durNormal * 0.5; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var ff = surface.f, rr = Math.min(surface.r, h)
            if (w <= 0 || h <= 0) return
            ctx.fillStyle = String(Theme.panelBg)
            ctx.beginPath()
            // Oberkante: volle Breite (liegt an der Bar an)
            ctx.moveTo(0, 0)
            // Linker Flare: konkav von (0,0) zu (f,f), Kreismittelpunkt (0,f)
            ctx.arc(0, ff, ff, -Math.PI / 2, 0, false)
            // Linke Panelkante runter bis zur unteren Rundung
            ctx.lineTo(ff, h - rr)
            ctx.arc(ff + rr, h - rr, rr, Math.PI, Math.PI / 2, true)
            // Unterkante
            ctx.lineTo(w - ff - rr, h)
            ctx.arc(w - ff - rr, h - rr, rr, Math.PI / 2, 0, true)
            // Rechte Panelkante hoch zum rechten Flare
            ctx.lineTo(w - ff, ff)
            ctx.arc(w, ff, ff, Math.PI, Math.PI * 1.5, false)
            ctx.closePath()
            ctx.fill()
        }
        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()
    }
}
