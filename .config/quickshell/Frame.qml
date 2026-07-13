import Quickshell
import Quickshell.Wayland
import QtQuick

// Zen-Screen-Frame: EIN klick-durchlässiges Overlay-Fenster zeichnet
// links/rechts/unten einen Mantle-Rahmen plus vier konkave Viewport-Ecken.
// Keine Exclusive-Zones — die Fenster-Freihaltung übernimmt die Hyprland-
// Gap-Kopplung in Theme.qml. Vollbild-Apps decken den Frame ab (Layer Top).
PanelWindow {
    id: frame

    screen: {
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === "HDMI-A-1")
                return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    anchors { top: true; left: true; right: true; bottom: true }
    exclusiveZone: -1
    color: "transparent"
    visible: Theme.zen

    // Leere Input-Region: alle Klicks gehen an die Fenster darunter.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Top

    readonly property int t: Theme.frameThickness
    readonly property int r: Theme.viewportRadius

    // ── Rahmenstreifen (oben übernimmt die Bar) ───────────────────────
    Rectangle { anchors { left: parent.left;  top: parent.top; bottom: parent.bottom } width: frame.t;  color: Theme.panelBg }
    Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: frame.t; color: Theme.panelBg }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: frame.t; color: Theme.panelBg }

    // ── Konkave Viewport-Ecken ────────────────────────────────────────
    // Zeichnet die Ecke für "oben links"; die anderen drei entstehen durch
    // Rotation. Füllung = Eckquadrat minus Viertelkreis (Radius r).
    component Fillet: Canvas {
        width: frame.r; height: frame.r
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = String(Theme.panelBg)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.arc(width, height, width, -Math.PI / 2, Math.PI, true)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fill()
        }
        onVisibleChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    Fillet { x: frame.t;                     y: Theme.barHeight }                                  // oben links
    Fillet { x: frame.width - frame.t - frame.r; y: Theme.barHeight;                rotation: 90 }  // oben rechts
    Fillet { x: frame.width - frame.t - frame.r; y: frame.height - frame.t - frame.r; rotation: 180 } // unten rechts
    Fillet { x: frame.t;                     y: frame.height - frame.t - frame.r; rotation: 270 }  // unten links
}
