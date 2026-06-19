pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Aktive Variante ──────────────────────────────────────────────
    property string variant: "mocha"                  // "mocha" | "liquidglass"
    readonly property bool glass: variant === "liquidglass"

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string statePath: stateDir + "/theme"

    function setVariant(name) {
        if (name !== "mocha" && name !== "liquidglass")
            return
        variant = name
        stateFile.setText(name + "\n")
    }

    function toggle() {
        setVariant(variant === "mocha" ? "liquidglass" : "mocha")
    }

    // ── Persistenz: einmal lesen beim Start, schreiben bei Änderung ───
    Process { command: ["mkdir", "-p", root.stateDir]; running: true }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false                            // fehlende Datei beim Erststart ist ok
        onLoaded: {
            const t = text().trim()
            if (t === "mocha" || t === "liquidglass")
                root.variant = t
        }
    }

    // ── Glas-spezifische Token ───────────────────────────────────────
    // Im Glas-Look bleibt die Border in der Sky/Aqua-Tönung des Mocha-Themes,
    // aber deutlich weicher (Alpha ~0.4×), damit sie nicht dominiert.
    function borderColor(a) {
        return glass ? Qt.rgba(0.72, 0.94, 1.00, a * 0.85)
                     : Qt.rgba(0.537, 0.863, 0.922, a)
    }

    // Aqua-getönte, durchscheinende Glasfläche (statt reinem Weiß) – wirkt erst
    // mit Compositor-Blur als frosted Glass.
    readonly property color panelBg: glass ? Qt.rgba(0.45, 0.80, 0.85, 0.32) : "#1e1e2e"
    readonly property color rim:     glass ? Qt.rgba(0.70, 0.95, 1.00, 0.25) : "transparent"
    readonly property int   radius:  glass ? 16 : 12
    readonly property color accent:  glass ? "#88d8ff" : "#89dceb"

    // ── Semantische Palette (Namen wie im Altcode) ───────────────────
    readonly property color clrBase:     glass ? "#0b0814"            : "#1e1e2e"
    readonly property color clrMantle:   glass ? Qt.rgba(1,1,1,0.04)  : "#181825"
    readonly property color clrSurface0: glass ? Qt.rgba(0.45,0.80,0.85,0.26) : "#313244"
    readonly property color clrSurface1: glass ? Qt.rgba(0.55,0.88,0.92,0.18) : "#45475a"
    readonly property color clrText:     glass ? Qt.rgba(1,1,1,0.94)  : "#cdd6f4"
    readonly property color clrSubtext0: glass ? Qt.rgba(1,1,1,0.62)  : "#a6adc8"
    readonly property color clrSubtext1: glass ? Qt.rgba(1,1,1,0.78)  : "#bac2de"
    readonly property color clrBlue:     glass ? "#9cd2ff"            : "#89b4fa"
    readonly property color clrLavender: glass ? "#c9d2ff"            : "#b4befe"
    readonly property color clrGreen:    glass ? "#86efac"            : "#a6e3a1"
    readonly property color clrYellow:   glass ? "#fde68a"            : "#f9e2af"
    readonly property color clrPeach:    glass ? "#fdba74"            : "#fab387"
    readonly property color clrRed:      glass ? "#fca5a5"            : "#f38ba8"
    readonly property color clrTeal:     glass ? "#5eead4"            : "#94e2d5"
    readonly property color clrSky:      glass ? "#88d8ff"            : "#89dceb"
    readonly property color clrSapphire: glass ? "#7dd3fc"            : "#74c7ec"
    readonly property color clrMauve:    glass ? "#d8b4fe"            : "#cba6f7"
    readonly property color clrPink:     glass ? "#f9a8d4"            : "#f5c2e7"
}
