# Quickshell „Zen“-Theme — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dritte Theme-Variante `zen` (Catppuccin Mocha, Teal/Sky-Akzent, Caelestia-inspiriert: randlose Zen-Bar, Screen-Frame mit Viewport, SDF-artige Übergänge, Hyprland/Rofi-Harmonisierung) — bei pixelidentischen `mocha`/`liquidglass`.

**Architecture:** Token-getrieben: `Theme.qml` (Singleton) bekommt drei Varianten und ein volles Token-Set; Komponenten lesen nur Tokens. Strukturelle Zen-Abweichungen (Workspace-Capsule, Frame, Panel-Fillets) sind gezielte `Theme.zen`-Verzweigungen. Der Frame ist EIN klick-durchlässiges Overlay-Fenster ohne Exclusive-Zones; die Fenster-Freihaltung übernimmt die ohnehin gekoppelte Hyprland-Gap-Umschaltung (bewusste Abweichung von der Spec-Formulierung „exclusiveZone = Dicke“ — gleiche Optik, keine Zonen-Konflikte zwischen Bar und Frame-Streifen).

**Tech Stack:** Quickshell 0.3.0 (Nixpkgs, Qt 6.11.1), QML (`QtQuick`, `QtQuick.Effects` für Schatten, Canvas für Fillets), `hyprctl`, Rofi (rasi), POSIX sh.

**Spec:** `docs/superpowers/specs/2026-07-13-quickshell-zen-theme-design.md`

## Global Constraints

- `mocha` und `liquidglass` bleiben **pixelidentisch** — jede Wert-Extraktion in Tokens übernimmt die exakten heutigen Werte (einzige genehmigte Ausnahme: `SearchItem.qml:19` Qt.rgba-Clamp-Fix, siehe Spec).
- Kommentare auf Deutsch, Stil wie Bestand (Boxen mit `── … ──`).
- Font überall ausschließlich `JetBrainsMono Nerd Font` — keine neuen Font-Abhängigkeiten.
- Keine neuen Pakete/Dependencies; nur Dateien in `~/git/dotfiles`. `~/git/nixos` wird in diesem Plan **nicht** angefasst (Restore-Werte müssen zu `home/program-configs/linux/hyprland.nix` passen: `gaps_out = 10`, `rounding = 10`, `col.active_border = "$sky $teal 45deg"` mit `$sky=rgb(89dceb)`, `$teal=rgb(94e2d5)`).
- Farbwerte fix (Catppuccin Mocha): Crust `#11111b`, Mantle `#181825`, Base `#1e1e2e`, Surface0 `#313244`, Surface1 `#45475a`, Text `#cdd6f4`, Subtext0 `#a6adc8`, Teal `#94e2d5`, Sky `#89dceb`, Rot `#f38ba8`.
- Zen-Kennzahlen: Bar-Höhe 44 (unverändert), Frame-Dicke 10, Viewport-Radius 16, Panel-Radius 20, Fillet/Flare 12, Gaps unter Zen `6,16,16,16` (top,right,bottom,left), sonst `10`.

## Dev-Loop (gilt für jeden Task)

Die live laufende Shell kommt aus dem Nix-Store (alte Config). Für Tests immer:

```bash
# 1. Laufende Instanz stoppen (Name des Binaries ist "qs"/"quickshell"):
pkill -f quickshell ; sleep 1

# 2. Dev-Instanz aus dem Repo starten (Log beobachten!):
qs -p /home/paul/git/dotfiles/.config/quickshell > /tmp/qs-dev.log 2>&1 &
sleep 3 && head -50 /tmp/qs-dev.log
```

Erwartung nach Start: keine Zeilen mit `ERROR`/`error:`/`Cannot assign`/`is not a type`. Warnungen, die es heute schon gibt, sind okay.

Variante umschalten und prüfen:

```bash
qs ipc call theme setVariant zen     # bzw. mocha / liquidglass
cat ~/.local/state/quickshell/theme  # muss den Namen enthalten
```

Am Ende JEDES Tasks: Dev-Instanz laufen lassen für den visuellen Check, danach für den nächsten Task neu starten. Nach dem letzten Task: `pkill -f quickshell ; hyprctl dispatch exec quickshell` (stellt die Store-Version wieder her).

---

### Task 1: Baseline-Screenshots der Alt-Themes

**Files:**
- Create: `/home/paul/git/dotfiles/.superpowers/baseline/` (gitignored, nur lokal)

**Interfaces:**
- Produces: `baseline/mocha.png`, `baseline/liquidglass.png` — Referenz für die Pixel-Parität-Checks aller späteren Tasks.

- [ ] **Step 1: Dev-Instanz mit unverändertem Code starten** (Dev-Loop oben). Erwartung: Bar erscheint wie gewohnt.

- [ ] **Step 2: Beide Varianten fotografieren**

```bash
mkdir -p /home/paul/git/dotfiles/.superpowers/baseline
qs ipc call theme setVariant mocha && sleep 1
grim -o HDMI-A-1 /home/paul/git/dotfiles/.superpowers/baseline/mocha.png
qs ipc call theme setVariant liquidglass && sleep 1
grim -o HDMI-A-1 /home/paul/git/dotfiles/.superpowers/baseline/liquidglass.png
qs ipc call theme setVariant mocha
```

Erwartung: beide PNGs existieren, > 100 KB. Kein Commit (Ordner ist gitignored).

---

### Task 2: Theme.qml — drei Varianten + Token-Set

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/Theme.qml` (komplett ersetzen)

**Interfaces:**
- Produces (von allen späteren Tasks konsumiert):
  - `variant: string` (`"mocha" | "liquidglass" | "zen"`), `glass: bool`, `zen: bool`, `setVariant(name)`, `toggle()` (rotiert mocha→liquidglass→zen→mocha)
  - Bestand (unverändert): `borderColor(a)`, `panelBg`, `panelBgDeep`, `rim`, `radius`, `accent`, `vizBarTop`, `clrBase/clrSurface0/clrSurface1/clrText/clrSubtext0/clrSubtext1/clrBlue/clrGreen/clrYellow/clrPeach/clrRed/clrTeal/clrSky/clrSapphire/clrMauve/clrPink` — jeweils um Zen-Werte erweitert
  - Neu: `clrCrust: color`, `barBg: color`, `barMargin: int`, `barHeight: int` (44), `islandBg: color`, `islandBorderWidth: int`, `sepVisible: bool`, `panelRadius: int`, `overlayBorderWidth: int`, `overlayTop: int`, `notifBg: color`, `notifBorderWidth: int`, `notifRadius: int`, `notifTop: int`, `notifRight: int`, `sidePanelBorderWidth: int`, `sidePanelMarginTop/Left/Bottom: int`, `dismissLeft: int`, `searchBg: color`, `searchBorderWidth: int`, `searchRadius: int`, `frameThickness: int` (10), `viewportRadius: int` (16), `filletSize: int` (12), `shadowEnabled: bool`, `durFast: int` (200), `durNormal: int` (350), `wsActiveBg: color`, `wsActiveFg: color`, `clockColor: color`, `statIcon(fallback): color`

- [ ] **Step 1: Theme.qml komplett ersetzen**

```qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── Aktive Variante ──────────────────────────────────────────────
    property string variant: "mocha"                  // "mocha" | "liquidglass" | "zen"
    readonly property var  variants: ["mocha", "liquidglass", "zen"]
    readonly property bool glass: variant === "liquidglass"
    readonly property bool zen:   variant === "zen"

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell"
    readonly property string statePath: stateDir + "/theme"

    function setVariant(name) {
        if (variants.indexOf(name) === -1)
            return
        variant = name
        stateFile.setText(name + "\n")
    }

    // Rotiert durch alle Varianten: mocha → liquidglass → zen → mocha
    function toggle() {
        setVariant(variants[(variants.indexOf(variant) + 1) % variants.length])
    }

    // ── Persistenz: einmal lesen beim Start, schreiben bei Änderung ───
    Process { command: ["mkdir", "-p", root.stateDir]; running: true }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false                            // fehlende Datei beim Erststart ist ok
        onLoaded: {
            const t = text().trim()
            if (root.variants.indexOf(t) !== -1)
                root.variant = t
        }
    }

    // ── Glas-spezifische Token ───────────────────────────────────────
    // Im Glas-Look bleibt die Border in der Sky/Aqua-Tönung des Mocha-Themes,
    // aber deutlich weicher (Alpha ~0.4×), damit sie nicht dominiert.
    // In Zen sind alle Border-Breiten 0 — der Rückgabewert ist dort egal.
    function borderColor(a) {
        return glass ? Qt.rgba(0.72, 0.94, 1.00, a * 0.85)
                     : Qt.rgba(0.537, 0.863, 0.922, a)
    }

    // Aqua-getönte, durchscheinende Glasfläche (statt reinem Weiß) – wirkt erst
    // mit Compositor-Blur als frosted Glass. Zen: opakes Mantle — Bar, Frame
    // und angedockte Overlays sind EINE Fläche.
    readonly property color panelBg: zen ? "#181825"
                                   : glass ? Qt.rgba(0.45, 0.80, 0.85, 0.32) : "#1e1e2e"
    // Tiefere Variante für Panels, die im Mocha-Look auf clrMantle saßen
    // (SidePanel, Notification). Im Glas-Look identisch zu panelBg.
    readonly property color panelBgDeep: zen ? "#181825"
                                       : glass ? Qt.rgba(0.45, 0.80, 0.85, 0.32) : "#181825"
    readonly property color rim:     glass ? Qt.rgba(0.70, 0.95, 1.00, 0.25) : "transparent"
    readonly property int   radius:  zen ? 20 : glass ? 16 : 12
    readonly property color accent:  zen ? "#94e2d5" : glass ? "#88d8ff" : "#89dceb"
    // Oberer Farbstopp des Audio-Visualizer-Gradienten (heller Sky-Highlight).
    readonly property color vizBarTop: glass ? Qt.rgba(0.80, 0.96, 1.00, 1.0) : "#c8eef5"

    // ── Semantische Palette (Namen wie im Altcode) ───────────────────
    readonly property color clrCrust:    "#11111b"
    readonly property color clrBase:     glass ? "#0b0814"            : "#1e1e2e"

    readonly property color clrSurface0: glass ? Qt.rgba(0.45,0.80,0.85,0.26) : "#313244"
    readonly property color clrSurface1: glass ? Qt.rgba(0.55,0.88,0.92,0.18) : "#45475a"
    readonly property color clrText:     glass ? Qt.rgba(1,1,1,0.94)  : "#cdd6f4"
    readonly property color clrSubtext0: glass ? Qt.rgba(1,1,1,0.62)  : "#a6adc8"
    readonly property color clrSubtext1: glass ? Qt.rgba(1,1,1,0.78)  : "#bac2de"
    readonly property color clrBlue:     glass ? "#9cd2ff"            : "#89b4fa"

    readonly property color clrGreen:    glass ? "#86efac"            : "#a6e3a1"
    readonly property color clrYellow:   glass ? "#fde68a"            : "#f9e2af"
    readonly property color clrPeach:    glass ? "#fdba74"            : "#fab387"
    readonly property color clrRed:      glass ? "#fca5a5"            : "#f38ba8"
    readonly property color clrTeal:     glass ? "#5eead4"            : "#94e2d5"
    readonly property color clrSky:      glass ? "#88d8ff"            : "#89dceb"
    readonly property color clrSapphire: glass ? "#7dd3fc"            : "#74c7ec"
    readonly property color clrMauve:    glass ? "#d8b4fe"            : "#cba6f7"
    readonly property color clrPink:     glass ? "#f9a8d4"            : "#f5c2e7"

    // ── Zen: Bar & Inseln ─────────────────────────────────────────────
    // Zen: die Bar SELBST ist die Fläche (Mantle, volle Breite, keine Margins);
    // die Inseln werden zu unsichtbaren Layout-Containern.
    readonly property color barBg:            zen ? "#181825" : "transparent"
    readonly property int   barMargin:        zen ? 0  : 10
    readonly property int   barHeight:        44
    readonly property color islandBg:         zen ? "transparent" : panelBg
    readonly property int   islandBorderWidth: zen ? 0 : 2
    readonly property bool  sepVisible:       !zen

    // ── Zen: Farbdisziplin ────────────────────────────────────────────
    // Statt Regenbogen-Stats: Icons teal, Uhr sky, kritisches rot — sonst nichts.
    function statIcon(fallback) { return zen ? clrTeal : fallback }
    readonly property color clockColor: zen ? clrSky  : clrPink
    readonly property color wsActiveBg: zen ? clrTeal : clrSky
    readonly property color wsActiveFg: zen ? clrCrust : clrBase

    // ── Zen: Overlays & Panels ────────────────────────────────────────
    readonly property int   panelRadius:        zen ? 20 : 16       // SidePanel-Ecken
    readonly property int   overlayBorderWidth: zen ? 0  : 2        // Music/Stats
    readonly property int   overlayTop:         zen ? 44 : 58       // Fensterabstand oben
    readonly property color notifBg:            zen ? "#1e1e2e" : panelBgDeep
    readonly property int   notifBorderWidth:   zen ? 0  : 1
    readonly property int   notifRadius:        zen ? 16 : radius
    readonly property int   notifTop:           zen ? 54 : 56
    readonly property int   notifRight:         zen ? 18 : 14
    readonly property int   sidePanelBorderWidth: zen ? 0 : 1
    readonly property int   sidePanelMarginTop:   zen ? 0 : 8
    readonly property int   sidePanelMarginLeft:  zen ? 0 : 12
    readonly property int   sidePanelMarginBottom: zen ? 0 : 8
    readonly property int   dismissLeft:        zen ? 304 : 316     // SidePanel-Breite + Margin + Puffer
    readonly property color searchBg:           zen ? "#1e1e2e" : "#181825"
    readonly property int   searchBorderWidth:  zen ? 0  : 2
    readonly property int   searchRadius:       zen ? 20 : 16

    // ── Zen: Frame & Viewport ─────────────────────────────────────────
    readonly property int  frameThickness: 10
    readonly property int  viewportRadius: 16
    readonly property int  filletSize:     12    // konkave Flares an Panel-Oberkanten
    readonly property bool shadowEnabled:  zen   // weicher Schatten nur auf freien Cards

    // ── Zen: Motion ───────────────────────────────────────────────────
    readonly property int durFast:   200   // Farbe/Opacity
    readonly property int durNormal: 350   // Position/Größe (mit Überschwingen)
}
```

- [ ] **Step 2: Parse-/Regressions-Test.** Dev-Loop: starten, Log prüfen (keine Errors). Dann:

```bash
qs ipc call theme setVariant zen         && cat ~/.local/state/quickshell/theme   # → zen
qs ipc call theme toggle                 && cat ~/.local/state/quickshell/theme   # → mocha
qs ipc call theme toggle                 && cat ~/.local/state/quickshell/theme   # → liquidglass
qs ipc call theme toggle                 && cat ~/.local/state/quickshell/theme   # → zen
qs ipc call theme setVariant quatsch     && cat ~/.local/state/quickshell/theme   # → bleibt zen
qs ipc call theme setVariant mocha
```

- [ ] **Step 3: Visuelle Parität.** Mocha und Liquidglass mit den Baselines aus Task 1 vergleichen (Bar, SidePanel öffnen, StatsOverlay öffnen). `zen` sieht noch fast wie mocha aus (nur Panel-Radius 20 in Overlays) — das ist hier okay.

- [ ] **Step 4: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/Theme.qml
git commit -m "quickshell: theme.qml — zen-variante + token-set"
```

---

### Task 3: Hartkodierte Defaults an Theme binden (kein sichtbarer Unterschied)

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/StatItem.qml:7-8`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/BarButton.qml:8,19`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/MiniGraph.qml:7`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/SearchItem.qml:19,25,76`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/SearchResults.qml:81-91`

**Interfaces:**
- Consumes: `Theme.clrText`, `Theme.clrSurface0`, `Theme.clrBlue`, `Theme.clrSky`, `Theme.searchBg`, `Theme.searchBorderWidth`, `Theme.searchRadius` (Task 2)

- [ ] **Step 1: StatItem.qml** — Zeilen 7-8 ersetzen:

```qml
    property color  iconColor: Theme.clrText
    property color  textColor: Theme.clrText
```

- [ ] **Step 2: BarButton.qml** — nur Zeile 8 ersetzen (der Hover-Hintergrund `"#313244"` in Zeile 19 bleibt Literal: in Liquidglass ist `Theme.clrSurface0` ein anderer, transluzenter Wert — Tokenisieren würde den Glass-Look ändern; Zen-Surface0 ist ohnehin exakt `#313244`):

```qml
    property color  iconColor: Theme.clrText
```

- [ ] **Step 3: MiniGraph.qml** — Zeile 7 ersetzen:

```qml
    property color  lineColor: Theme.clrBlue
```

- [ ] **Step 4: SearchItem.qml** — nur die Qt.rgba-Clamp-Bugs fixen (Werte waren 0–255 statt 0–1; gemeint war Lavender `#b4befe`). `itemColor` (Zeile 9) bleibt Literal — der Default färbt das Fallback-Icon und soll wie der ganze Launcher in allen Varianten fix dunkel-hell bleiben. Zeile 19 und 25 ersetzen:

```qml
        color: ma.containsMouse ? Qt.rgba(0.706, 0.745, 0.996, 0.15) : "transparent"
```

```qml
            color: ma.containsMouse ? Qt.rgba(0.706, 0.745, 0.996, 0.3) : "transparent"
```

Hinweis: Zeile 64 (`"#ffffff"`/`"#cdd6f4"` Hover-Text) und Zeile 76 (Enter-Hinweis, gleicher Clamp) analog: Zeile 76 wird `Qt.rgba(0.706, 0.745, 0.996, 0.5)`; Zeile 64 bleibt unverändert (bewusst weißer Hover).

- [ ] **Step 5: SearchResults.qml** — Panel-Rectangle (Zeilen 81-91): NUR Hintergrund, Radius und Border-Breite tokenisieren. Die übrigen Hex-Literale (`#313244` Suchfeld/Border-Farbe, `#89dceb` Icon, `#cdd6f4` TextInput) bleiben bewusst Literale — der Launcher ist in allen Varianten fix dunkel, und Glass-Tokens (`clrSurface0`/`clrSky`/`clrText`) haben dort andere Werte, die den heutigen Look verändern würden. Zen bekommt durch `searchBg`/`searchRadius`/`searchBorderWidth` + Schatten (Task 9) alles, was die Spec verlangt.

```qml
    Rectangle {
        width: 350
        height: Math.min(mainCol.implicitHeight + 24, 450)
        x: 20
        y: 60
        color: Theme.searchBg
        radius: Theme.searchRadius
        border {
            color: "#313244"
            width: Theme.searchBorderWidth
        }
```

- [ ] **Step 6: Test.** Dev-Loop-Neustart, Log fehlerfrei. Mocha gegen Baseline: Bar-Stats, BarButtons, Launcher (`SUPER+SHIFT+Return` ist Rofi — die interne Suche über `scripts/focus-search.sh` bzw. SearchResults per Hover prüfen, falls gebunden; sonst reicht: keine Log-Errors + Stats/Buttons unverändert). Liquidglass kurz durchschalten: Stats-Icons müssen jetzt die Glas-Textfarbe zeigen, wie vorher (StatItem bekam Farben schon immer explizit übergeben — Default greift nur, wo nichts übergeben wird).

- [ ] **Step 7: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/StatItem.qml .config/quickshell/BarButton.qml .config/quickshell/MiniGraph.qml .config/quickshell/SearchItem.qml .config/quickshell/SearchResults.qml
git commit -m "quickshell: hartkodierte farben an theme binden (inkl. rgba-clamp-fix)"
```

---

### Task 4: Bar.qml token-getrieben (Zen-Fläche, ohne Workspace-Capsule)

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/Bar.qml`

**Interfaces:**
- Consumes: `Theme.barBg`, `Theme.barMargin`, `Theme.barHeight`, `Theme.islandBg`, `Theme.islandBorderWidth`, `Theme.sepVisible`, `Theme.statIcon(c)`, `Theme.clockColor` (Task 2)
- Produces: unverändertes Bar-API für shell.qml (`centerIslandWidth`, `musicIslandX`, `musicIslandWidth`, Signale)

- [ ] **Step 1: Fenster-Geometrie auf Tokens** — Zeilen 30-34 ersetzen:

```qml
    anchors { top: true; left: true; right: true }
    margins { top: Theme.barMargin; left: Theme.barMargin; right: Theme.barMargin }
    implicitHeight: Theme.barHeight
    exclusiveZone:  Theme.barHeight
    color: Theme.barBg
```

- [ ] **Step 2: Alle fünf Insel-Rectangles auf Tokens.** Bei `leftIsland` (388-396), `windowIsland` (452-461), `musicIsland` (483-491), `centerIsland` (704-711), `rightIsland` (749-756) jeweils die zwei Zeilen ersetzen:

```qml
            color: Theme.islandBg
            border { color: Theme.borderColor(0.55); width: Theme.islandBorderWidth }
```

(`radius: Theme.radius` bleibt wie es ist — bei transparenter Füllung unsichtbar.)

- [ ] **Step 3: Alle Trennstriche an `sepVisible`.** Jede der neun Separator-Rectangles (`width: 1; height: 20; color: Theme.clrSurface1` — Zeilen 569, 607, 653-656, 723, 727, 735, 800, 830-833, 843) bekommt `visible: Theme.sepVisible`; bei den zwei bereits konditionalen:
  - Zeile 653-656 (Viz-Separator): `visible: Theme.sepVisible && vizContainer.visible`
  - Zeile 830-833 (Battery-Separator): `visible: Theme.sepVisible && bar.isLaptop && bar.batteryCapacity >= 0`

Beispiel einfacher Fall:

```qml
                Rectangle { width: 1; height: 20; color: Theme.clrSurface1; visible: Theme.sepVisible }
```

- [ ] **Step 4: Stat-Icon-Farbdisziplin.** In `statsRow` (Zeilen 718-738) jede `iconColor:` durch `Theme.statIcon(...)` wrappen, z. B.:

```qml
                StatItem { icon: "󰻠"; value: bar.cpuUsage + "%"; valueChars: 4; iconColor: Theme.statIcon(Theme.clrGreen);   textColor: Theme.clrText }
```

(analog für alle 13 StatItems: clrGreen/clrSky/clrPeach/clrYellow/clrMauve/clrTeal/clrBlue/clrSapphire bleiben als Fallback erhalten). Ebenso die zwei BarButtons im leftIsland: `iconColor: Theme.statIcon(Theme.clrBlue)` (Zeile 438) und `iconColor: Theme.statIcon(Theme.clrSky)` (Zeile 445), das Fenster-Icon `󰖯` (Zeile 469): `color: Theme.statIcon(Theme.clrBlue)`, das Musik-Icon `󰝚` (Zeile 503): `color: Theme.statIcon(Theme.clrMauve)`. Der Power-Button (Zeile 848, clrRed) bleibt rot — kritische Aktion.

- [ ] **Step 5: Uhr.** Zeile 838 ersetzen:

```qml
                    color: Theme.clockColor
```

- [ ] **Step 6: Test.** Dev-Loop-Neustart. Mocha + Liquidglass = Baseline (Inseln, Borders, Separatoren, bunte Icons, pinke Uhr — alles wie vorher). Dann `qs ipc call theme setVariant zen`: Bar wird volle Breite Mantle, Inseln verschwinden als Boxen, keine Separatoren, Stat-Icons teal, Uhr sky. Workspaces sehen noch wie alte Pills aus (kommt in Task 5).

- [ ] **Step 7: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/Bar.qml
git commit -m "quickshell: bar token-getrieben — zen-flaeche, farbdisziplin"
```

---

### Task 5: Workspace-Capsule mit Gleit-Indikator (nur Zen)

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/Bar.qml:403-433` (Workspace-Repeater)

**Interfaces:**
- Consumes: `Theme.zen`, `Theme.clrSurface0`, `Theme.clrSubtext0`, `Theme.wsActiveBg`, `Theme.wsActiveFg`, `Theme.durFast`, `Theme.durNormal`

- [ ] **Step 1: Workspace-Block ersetzen.** Den bestehenden `Repeater { model: {...} delegate: Rectangle {...} }` (Zeilen 403-433) durch Folgendes ersetzen (beide Darstellungen; das Workspace-Modell wird geteilt):

```qml
                // Gemeinsames, sortiertes Workspace-Modell (IDs 1–10)
                Item {
                    id: wsHolder
                    property var wsList: {
                        var ws = []
                        for (var i = 0; i < Hyprland.workspaces.length; i++) {
                            var w = Hyprland.workspaces[i]
                            if (w.id >= 1 && w.id <= 10) ws.push(w)
                        }
                        ws.sort(function(a, b) { return a.id - b.id })
                        return ws
                    }
                    property int activeIdx: {
                        var act = Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
                                  ? Hyprland.focusedMonitor.activeWorkspace.id : -1
                        for (var i = 0; i < wsList.length; i++)
                            if (wsList[i].id === act) return i
                        return -1
                    }
                    visible: false
                }

                // ── Klassische Pills (Mocha / Liquidglass) ────────────────────
                Row {
                    spacing: 4
                    visible: !Theme.zen
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: wsHolder.wsList
                        delegate: Rectangle {
                            required property var modelData
                            property bool isActive: Hyprland.focusedMonitor &&
                                Hyprland.focusedMonitor.activeWorkspace &&
                                Hyprland.focusedMonitor.activeWorkspace.id === modelData.id
                            width: 28; height: 28
                            radius: 6
                            color: isActive ? Theme.clrSky : Theme.clrSurface0
                            Text {
                                anchors.centerIn: parent
                                text:  modelData.id
                                color: parent.isActive ? Theme.clrBase : Theme.clrSubtext0
                                font  { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: parent.isActive }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                // ── Zen: Capsule mit gleitendem Teal-Indikator ────────────────
                Rectangle {
                    visible: Theme.zen
                    Layout.alignment: Qt.AlignVCenter
                    width:  wsRow.width + 6
                    height: 28
                    radius: height / 2
                    color:  Theme.clrSurface0

                    // Indikator hinter den Ziffern: gleitet mit Überschwingen
                    Rectangle {
                        id: wsIndicator
                        visible: wsHolder.activeIdx >= 0
                        x: 3 + wsHolder.activeIdx * (24 + 4)
                        y: 3
                        width: 22; height: 22
                        radius: height / 2
                        color: Theme.wsActiveBg
                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.durNormal
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.2
                            }
                        }
                    }

                    Row {
                        id: wsRow
                        x: 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: wsHolder.wsList
                            delegate: Item {
                                required property var modelData
                                required property int index
                                property bool isActive: index === wsHolder.activeIdx
                                width: 24; height: 22
                                Text {
                                    anchors.centerIn: parent
                                    text:  modelData.id
                                    color: parent.isActive ? Theme.wsActiveFg : Theme.clrSubtext0
                                    font  { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: parent.isActive }
                                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Hyprland.dispatch("workspace " + modelData.id)
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }
```

Hinweis: Das umgebende `RowLayout` (`leftRow`) bleibt; die zwei neuen Top-Level-Elemente (Row + Rectangle) ersetzen exakt den alten `Repeater`. Indikator-Geometrie: Zelle 24 breit + 4 spacing, Indikator 22 mit 3 px Innenabstand — Indikator-x ist bewusst 3 + idx·28 relativ zur Capsule; `wsRow.x: 3` richtet die Ziffern darüber aus (Indikator zentriert unter 24er-Zelle: 3 + 1 px optischer Versatz ist gewollt vernachlässigbar).

- [ ] **Step 2: Test.** Dev-Loop-Neustart. Mocha: Pills exakt wie Baseline. Zen: Capsule sichtbar; `hyprctl dispatch workspace 3` → Indikator gleitet mit sichtbarem Überschwingen, Ziffer 3 wird dunkel (Crust) auf Teal, alte Ziffer wird grau. Klick auf Ziffern wechselt Workspace.

- [ ] **Step 3: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/Bar.qml
git commit -m "quickshell: zen workspace-capsule mit gleit-indikator"
```

---

### Task 6: Frame.qml (Viewport-Rahmen) + shell.qml-Wiring

**Files:**
- Create: `/home/paul/git/dotfiles/.config/quickshell/Frame.qml`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/shell.qml:42-43` (Frame einhängen), `:92,106,126` (Dismiss-Margins auf Tokens)

**Interfaces:**
- Consumes: `Theme.zen`, `Theme.frameThickness`, `Theme.viewportRadius`, `Theme.panelBg`, `Theme.barHeight`, `Theme.overlayTop`, `Theme.dismissLeft`
- Produces: `Frame { }` — parameterlos, rendert nur wenn `Theme.zen`

- [ ] **Step 1: Frame.qml anlegen**

```qml
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
```

- [ ] **Step 2: shell.qml — Frame einhängen.** Nach dem `Bar { ... }`-Block (nach Zeile 42) einfügen:

```qml
    Frame { }
```

- [ ] **Step 3: shell.qml — Dismiss-Margins auf Tokens.** Zeile 92 und 106 (`margins { top: 58 }`) ersetzen durch:

```qml
        margins { top: Theme.overlayTop }
```

Zeile 125-127 (`margins { left: 316 }`) ersetzen durch:

```qml
        margins { left: Theme.dismissLeft }
```

- [ ] **Step 4: Test.** Dev-Loop-Neustart. Mocha: kein Frame, alles wie Baseline. Zen: Mantle-Rahmen links/rechts/unten, vier konkave Ecken direkt unter der Bar bzw. über dem unteren Rahmen — Bar und Rahmen wirken als eine Fläche. Klick-Durchlässigkeit: Fenster an den Bildschirmrand schieben und in den ersten 10 px anklicken → Klick kommt im Fenster an. `SUPER+F` (Vollbild): Frame und Bar verschwinden hinter dem Fenster. Fenster überlappen den Frame noch (Gaps kommen in Task 9).

- [ ] **Step 5: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/Frame.qml .config/quickshell/shell.qml
git commit -m "quickshell: zen screen-frame mit viewport-ecken"
```

---

### Task 7: ZenPanelSurface + Music-/StatsOverlay docken nahtlos an

**Files:**
- Create: `/home/paul/git/dotfiles/.config/quickshell/ZenPanelSurface.qml`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/MusicOverlay.qml:34-57`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/StatsOverlay.qml:89-105`

**Interfaces:**
- Consumes: `Theme.zen`, `Theme.panelBg`, `Theme.radius`, `Theme.filletSize`, `Theme.overlayBorderWidth`, `Theme.overlayTop`, `Theme.durNormal`, `Theme.borderColor(a)`
- Produces: `ZenPanelSurface { targetX, targetWidth, panelHeight, open }` — zeichnet die Mantle-Fläche mit konkaven Top-Flares + unten gerundeten Ecken und liefert den Jelly-Effekt; Panels legen ihren Inhalt darüber.

- [ ] **Step 1: ZenPanelSurface.qml anlegen**

```qml
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
```

- [ ] **Step 2: MusicOverlay.qml anpassen.**
  Zeile 35 (`margins { top: 58; left: 12; right: 12 }`) ersetzen:

```qml
    anchors { top: true; left: true; right: true }
    margins { top: Theme.overlayTop; left: 12; right: 12 }
```

  Vor dem Panel-`Rectangle` (Zeile 42) das Surface als Geschwister einfügen:

```qml
    // Zen: Mantle-Fläche, die nahtlos aus der Bar wächst (Flares + Jelly)
    ZenPanelSurface {
        targetX:     panel.x
        targetWidth: panel.width
        panelHeight: panel.height
        open:        overlay.musicOpen
    }
```

  Im Panel-Rectangle (Zeilen 52-54) Farbe/Border/Radius tokenisieren:

```qml
        radius: Theme.radius
        color:  Theme.zen ? "transparent" : Theme.panelBg
        border  { color: Theme.borderColor(0.55); width: Theme.overlayBorderWidth }
```

- [ ] **Step 3: StatsOverlay.qml identisch behandeln.**
  Zeile 90 (`margins { top: 58; left: 12; right: 12 }`) ersetzen:

```qml
    margins { top: Theme.overlayTop; left: 12; right: 12 }
```

  Das Haupt-Panel-Rectangle (Zeile 97) hat kein `id` — eines vergeben und Surface davor einfügen:

```qml
    ZenPanelSurface {
        targetX:     statsPanel.x
        targetWidth: statsPanel.width
        panelHeight: statsPanel.height
        open:        overlay.statsOpen
    }

    Rectangle {
        id: statsPanel
        anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width:  overlay.panelWidth
        radius: Theme.radius
        color:  Theme.zen ? "transparent" : Theme.panelBg
        border  { color: Theme.borderColor(0.55); width: Theme.overlayBorderWidth }
```

  (Rest des Rectangles unverändert.)

- [ ] **Step 4: Test.** Dev-Loop-Neustart. Mocha: Overlays öffnen (Klick auf Musik-Insel / Stats-Insel) — Abstand, Border, Radius wie Baseline. Zen: Overlay liegt bündig an der Bar-Unterkante (kein Spalt), gleiche Mantle-Farbe, konkave Flares links/rechts an der Oberkante, unten 20er-Rundung, beim Öffnen kurzes Jelly-Wobbeln. Klick außerhalb schließt (Dismiss-Fenster sitzt dank Task 6 bei top 44).

- [ ] **Step 5: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/ZenPanelSurface.qml .config/quickshell/MusicOverlay.qml .config/quickshell/StatsOverlay.qml
git commit -m "quickshell: zen overlays wachsen nahtlos aus der bar (flares + jelly)"
```

---

### Task 8: SidePanel dockt am Frame an

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/SidePanel.qml:17-18,94-102`

**Interfaces:**
- Consumes: `Theme.sidePanelMarginTop/Left/Bottom`, `Theme.panelRadius`, `Theme.sidePanelBorderWidth`, `Theme.zen`, `Theme.panelBgDeep`, `Theme.borderColor(a)`

- [ ] **Step 1: Fenster-Margins tokenisieren** — Zeile 18 ersetzen:

```qml
    margins { top: Theme.sidePanelMarginTop; left: Theme.sidePanelMarginLeft; bottom: Theme.sidePanelMarginBottom }
```

- [ ] **Step 2: Content-Rectangle** — Zeilen 100-102 ersetzen:

```qml
            color: Theme.panelBgDeep
            radius: Theme.panelRadius
            border { color: Theme.borderColor(0.15); width: Theme.sidePanelBorderWidth }
```

  Direkt NACH der border-Zeile ein Deckstück einfügen, das in Zen die linken Ecken eckig macht (Panel verschmilzt links mit dem Frame):

```qml
            // Zen: linke Kante eckig — das Panel geht nahtlos in den Frame über.
            Rectangle {
                visible: Theme.zen
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: parent.radius
                color: parent.color
            }
```

- [ ] **Step 3: Test.** Dev-Loop-Neustart. Mocha: SidePanel öffnen (Menü-Button links) — 16er-Radius, Border, 8/12/8-Margins wie Baseline. Zen: Panel beginnt direkt unter der Bar, läuft bis zum unteren Bildschirmrand, linke Kante bündig/eckig am Frame (gleiches Mantle → verschmilzt), rechte Ecken 20er-Radius, keine Border. Klick außerhalb schließt (Dismiss bei `dismissLeft` 304).

- [ ] **Step 4: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/SidePanel.qml
git commit -m "quickshell: zen sidepanel dockt am frame an"
```

---

### Task 9: NotificationPopup + SearchResults — randlos mit Schatten

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/NotificationPopup.qml:22,58-68`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/SearchResults.qml:81-91` (nur Schatten ergänzen; Tokens kamen in Task 3)

**Interfaces:**
- Consumes: `Theme.notifBg`, `Theme.notifBorderWidth`, `Theme.notifRadius`, `Theme.notifTop`, `Theme.notifRight`, `Theme.shadowEnabled`, `Theme.clrRed`, `Theme.borderColor(a)`

- [ ] **Step 1: NotificationPopup.qml.** Zeile 22 ersetzen:

```qml
    margins { top: Theme.notifTop; right: Theme.notifRight }
```

  Im Toast-Delegate (Zeilen 58-68): Import oben ergänzen (`import QtQuick.Effects` nach Zeile 3) und den Rectangle-Kopf ersetzen:

```qml
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
```

  (Kritische Notifications behalten die rote 1px-Border auch in Zen — kritisch bleibt rot.)

- [ ] **Step 2: SearchResults.qml.** Import `QtQuick.Effects` nach Zeile 4 ergänzen; im Panel-Rectangle aus Task 3 nach der `border { ... }`-Gruppe einfügen:

```qml
        layer.enabled: Theme.shadowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.9
            shadowVerticalOffset: 4
        }
```

- [ ] **Step 3: Test.** Dev-Loop-Neustart. Mocha: `notify-send "Test" "Hallo"` → Toast wie Baseline (Border, Position). Zen: Toast randlos in Base (#1e1e2e) mit weichem Schatten, Position leicht in den Viewport gerückt; `notify-send -u critical "Kritisch" "!"` → rote Border bleibt. Beide Varianten: Log ohne Errors (MultiEffect-Import verfügbar in Qt 6.11).

- [ ] **Step 4: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/NotificationPopup.qml .config/quickshell/SearchResults.qml
git commit -m "quickshell: zen notifications/launcher randlos mit schatten"
```

---

### Task 10: Hyprland-Kopplung in Theme.qml

**Files:**
- Modify: `/home/paul/git/dotfiles/.config/quickshell/Theme.qml` (Block am Ende des Singletons ergänzen)

**Interfaces:**
- Consumes: `hyprctl` (läuft in der Hyprland-Session)
- Produces: automatische Keyword-Umschaltung bei Variantenwechsel und Shell-Start

- [ ] **Step 1: Kopplungs-Block ergänzen.** In Theme.qml direkt vor der schließenden Klammer des Singletons einfügen:

```qml
    // ── Hyprland-Kopplung ─────────────────────────────────────────────
    // Zen passt die Fenster-Deko an (Gaps machen Platz für den Frame, solider
    // Teal-Border statt rotierendem Gradient, Rounding harmonisiert mit dem
    // Viewport). Restore-Werte MÜSSEN zu ~/git/nixos/home/program-configs/
    // linux/hyprland.nix passen. Läuft auch beim Start → selbstheilend.
    readonly property string hyprZen:
        "keyword general:gaps_out 6,16,16,16 ; " +
        "keyword general:col.active_border rgb(94e2d5) ; " +
        "keyword decoration:rounding 12"
    readonly property string hyprRestore:
        "keyword general:gaps_out 10 ; " +
        "keyword general:col.active_border rgb(89dceb) rgb(94e2d5) 45deg ; " +
        "keyword decoration:rounding 10"

    Process {
        id: hyprProc
        // command wird vor jedem Start gesetzt; stale-Prozess unkritisch.
    }
    function applyHyprland() {
        hyprProc.command = ["hyprctl", "--batch", zen ? hyprZen : hyprRestore]
        hyprProc.running = true
    }
    onVariantChanged: applyHyprland()
    Component.onCompleted: applyHyprland()
```

  Achtung Reihenfolge: `Component.onCompleted` feuert vor dem asynchronen `FileView.onLoaded`; lädt die State-Datei danach eine andere Variante, feuert `onVariantChanged` erneut — Endzustand stimmt also immer.

- [ ] **Step 2: Test**

```bash
# Dev-Loop-Neustart, dann:
qs ipc call theme setVariant zen && sleep 1
hyprctl getoption general:gaps_out            # → custom type: 6 16 16 16
hyprctl getoption decoration:rounding -j | jq .int   # → 12
hyprctl getoption general:col.active_border   # → nur rgb(94e2d5), kein 45deg
qs ipc call theme setVariant mocha && sleep 1
hyprctl getoption general:gaps_out            # → int: 10
hyprctl getoption decoration:rounding -j | jq .int   # → 10
hyprctl getoption general:col.active_border   # → zwei Farben + 45deg
```

Zusätzlich visuell unter Zen: getilte Fenster halten links/rechts/unten 16 px Abstand (6 px sichtbares Wallpaper neben dem 10-px-Frame), unter der Bar 6 px; kein Fenster liegt unter dem Frame.

- [ ] **Step 3: Selbstheilung testen.** Unter Zen `pkill -f quickshell`, dann Dev-Instanz neu starten → State-Datei sagt zen → Gaps bleiben 6,16,16,16. Danach `qs ipc call theme setVariant mocha` → alles restauriert.

- [ ] **Step 4: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/quickshell/Theme.qml
git commit -m "quickshell: hyprland-kopplung fuer zen (gaps, border, rounding)"
```

---

### Task 11: Rofi — Zen-Theme + Symlink-Mechanismus + 3er-Menü

**Files:**
- Create: `/home/paul/git/dotfiles/.config/rofi/catppuccin-zen.rasi`
- Modify: `/home/paul/git/dotfiles/.config/rofi/config.rasi:12`
- Modify: `/home/paul/git/dotfiles/.config/quickshell/Theme.qml` (Symlink-Pflege)
- Modify: `/home/paul/git/dotfiles/.config/quickshell/scripts/theme-switch.sh`

**Interfaces:**
- Consumes: Theme-Variantenwechsel (Task 2), `~/.local/state/quickshell/` (existiert durch Theme.qml)
- Produces: `~/.local/state/quickshell/rofi-theme.rasi` → Symlink auf die zur Variante passende .rasi; `rofi -show drun` folgt automatisch

- [ ] **Step 1: catppuccin-zen.rasi anlegen** — randlos, Mantle, Teal-Selektion mit Crust-Text:

```rasi
* {
    base:     #1e1e2e;
    mantle:   #181825;
    crust:    #11111b;
    surface0: #313244;
    surface1: #45475a;
    overlay0: #6c7086;
    text:     #cdd6f4;
    subtext0: #a6adc8;
    teal:     #94e2d5;
    sky:      #89dceb;

    background-color: transparent;
    text-color:       @text;
}

window {
    background-color: @mantle;
    border:           0px;
    border-radius:    20px;
    width:            600px;
    padding:          14px;
}

mainbox {
    background-color: transparent;
    children:         [ inputbar, listview ];
    spacing:          10px;
}

inputbar {
    background-color: @surface0;
    border:           0px;
    border-radius:    12px;
    padding:          10px 14px;
    children:         [ prompt, entry ];
    spacing:          6px;
}

prompt {
    background-color: transparent;
    text-color:       @teal;
    font:             "JetBrainsMono Nerd Font Bold 13";
}

entry {
    background-color: transparent;
    text-color:       @text;
    placeholder:      "Suchen...";
    placeholder-color: @overlay0;
}

listview {
    background-color: transparent;
    lines:            8;
    columns:          1;
    scrollbar:        false;
    spacing:          4px;
}

element {
    background-color: transparent;
    border-radius:    10px;
    padding:          8px 10px;
    spacing:          10px;
    orientation:      horizontal;
}

element normal.normal {
    background-color: transparent;
    text-color:       @text;
}

element selected.normal {
    background-color: @teal;
    text-color:       @crust;
}

element alternate.normal {
    background-color: transparent;
    text-color:       @text;
}

element-icon {
    size:             24px;
    vertical-align:   0.5;
}

element-text {
    vertical-align:   0.5;
    text-color:       inherit;
}
```

- [ ] **Step 2: config.rasi** — Zeile 12 ersetzen:

```rasi
@theme "~/.local/state/quickshell/rofi-theme.rasi"
```

- [ ] **Step 3: Theme.qml — Symlink pflegen.** Im Hyprland-Block aus Task 10 die Funktion `applyHyprland()` um die Rofi-Zeile erweitern (Process-Objekt daneben anlegen):

```qml
    // Rofi folgt der Variante über einen Symlink; ~/.config/rofi/config.rasi
    // bindet ihn ein. Liquidglass nutzt das Mocha-Rasi (kein eigenes Glas-Rofi).
    Process { id: rofiLinkProc }
    function applyRofiTheme() {
        var target = zen ? "catppuccin-zen.rasi" : "catppuccin-mocha.rasi"
        rofiLinkProc.command = ["/bin/sh", "-c",
            "ln -sfn \"$HOME/.config/rofi/" + target + "\" \"" + stateDir + "/rofi-theme.rasi\""]
        rofiLinkProc.running = true
    }
```

  Und `applyHyprland()`/Hooks ergänzen — `onVariantChanged`/`Component.onCompleted` rufen beide auf:

```qml
    onVariantChanged: { applyHyprland(); applyRofiTheme() }
    Component.onCompleted: { applyHyprland(); applyRofiTheme() }
```

  (Die frühere einzelne `onVariantChanged`/`onCompleted`-Zeile aus Task 10 entsprechend ersetzen — es darf nur je einen Handler geben.)

- [ ] **Step 4: theme-switch.sh — Menü mit drei Einträgen über den Symlink**

```sh
#!/bin/sh
# Schaltet das Quickshell-Theme um.
#   theme-switch.sh toggle   -> rotiert Mocha -> Liquidglass -> Zen
#   theme-switch.sh menu     -> Rofi-Auswahl
# Persistenz + Hyprland-/Rofi-Kopplung erledigt die Shell selbst.

ROFI_THEME="$HOME/.local/state/quickshell/rofi-theme.rasi"
[ -e "$ROFI_THEME" ] || ROFI_THEME="$HOME/.config/rofi/catppuccin-mocha.rasi"

case "$1" in
    toggle)
        qs ipc call theme toggle
        ;;
    menu)
        MOCHA="󰧉 Mocha"
        GLASS="󰂭 Liquidglass"
        ZEN="󱅻 Zen"
        CHOICE=$(printf "%s\n%s\n%s" "$MOCHA" "$GLASS" "$ZEN" \
            | rofi -dmenu \
                -p "󰸉" \
                -theme "$ROFI_THEME" \
                -theme-str 'window { width: 220px; } listview { lines: 3; }')
        case "$CHOICE" in
            "$MOCHA") qs ipc call theme setVariant mocha ;;
            "$GLASS") qs ipc call theme setVariant liquidglass ;;
            "$ZEN")   qs ipc call theme setVariant zen ;;
        esac
        ;;
    *)
        echo "usage: $0 {toggle|menu}" >&2
        exit 1
        ;;
esac
```

- [ ] **Step 5: Test**

```bash
# Dev-Loop-Neustart, dann:
qs ipc call theme setVariant zen && sleep 1
readlink ~/.local/state/quickshell/rofi-theme.rasi   # → .../catppuccin-zen.rasi
rofi -show drun &   # → randlos, Mantle, Teal-Selektion; ESC schließt
qs ipc call theme setVariant mocha && sleep 1
readlink ~/.local/state/quickshell/rofi-theme.rasi   # → .../catppuccin-mocha.rasi
sh ~/git/dotfiles/.config/quickshell/scripts/theme-switch.sh menu   # → 3 Einträge, Auswahl wirkt
```

Hinweis: `rofi -show drun` lädt config.rasi aus `~/.config/rofi` — das ist die deployte Store-Version, die den Symlink noch nicht kennt. Für den Dev-Test explizit: `rofi -show drun -theme ~/.local/state/quickshell/rofi-theme.rasi`. Nach Flake-Rebuild greift config.rasi automatisch.

- [ ] **Step 6: Commit**

```bash
cd /home/paul/git/dotfiles
git add .config/rofi/catppuccin-zen.rasi .config/rofi/config.rasi .config/quickshell/Theme.qml .config/quickshell/scripts/theme-switch.sh
git commit -m "rofi: zen-theme + variantengesteuerter symlink; theme-menu mit 3 eintraegen"
```

---

### Task 12: End-Verifikation (Spec-Checkliste) + Aufräumen

**Files:** keine neuen Änderungen (nur Fixes, falls Checks scheitern)

- [ ] **Step 1: Voller Regressionslauf Alt-Themes.** Dev-Loop-Neustart → mocha: Bar, SidePanel, StatsOverlay, MusicOverlay, Notification (`notify-send`), Launcher gegen `baseline/mocha.png` vergleichen. Dasselbe für liquidglass gegen `baseline/liquidglass.png`. Erwartung: keine wahrnehmbaren Unterschiede (Uhrzeit/Statwerte ausgenommen).

- [ ] **Step 2: Zen-Funktionscheck** (jede Zeile muss stimmen):
  - Bar: volle Breite, Mantle, keine Borders/Separatoren, Stats teal, Uhr sky
  - Workspace-Capsule: Indikator gleitet mit Überschwingen, Knockout-Farbwechsel
  - Frame: 10 px links/rechts/unten, 4 konkave Ecken, klick-durchlässig, Vollbild deckt ab
  - Overlays: bündig an Bar, Flares, Jelly, unten 20er-Rundung
  - SidePanel: unter Bar bis Bildschirmrand, links mit Frame verschmolzen
  - Notifications: randlos + Schatten, kritisch = rote Border
  - Hyprland: `gaps_out 6,16,16,16`, solider Teal-Border, rounding 12
  - Rofi: Zen-Look über Symlink
- [ ] **Step 3: Zyklustest.** `theme-switch.sh toggle` dreimal (voller Zyklus), nach jedem Schritt: State-Datei, `hyprctl getoption general:gaps_out`, Optik. Danach qs unter Zen killen + neu starten (Selbstheilung), zurück zu mocha.

- [ ] **Step 4: Live-Shell wiederherstellen**

```bash
pkill -f quickshell ; hyprctl dispatch exec quickshell
```

- [ ] **Step 5: Abschluss-Commit (falls Fixes anfielen) und Zusammenfassung an den Nutzer:** Deployment-Hinweis wiederholen (commit+push → `nix flake update dotfiles` in ~/git/nixos → `nixos-rebuild switch`; bis dahin läuft die Store-Version ohne Zen).

---

## Plan-Self-Review (erledigt)

- **Spec-Abdeckung:** Varianten/Token (T2), Farbdisziplin + Bar (T4), Workspace-Hero (T5), Frame/Viewport (T6), SDF-Nahtstellen + Jelly (T7), SidePanel (T8), Notifications/Search + Schatten (T9), Hyprland-Keywords (T10), Rofi (T11), Verifikation (T12), Nebenbefund rgba-Clamp (T3). Bewusste Abweichung von der Spec dokumentiert (Frame ohne Exclusive-Zones, Gaps `6,16,16,16` statt `6` — im Architecture-Absatz begründet).
- **Platzhalter:** keine (alle Steps mit vollständigem Code/Kommandos).
- **Typ-/Namens-Konsistenz:** Token-Namen in T3–T11 gegen die Interfaces-Liste in T2 geprüft (`statIcon`, `sepVisible`, `overlayTop`, `dismissLeft`, `filletSize`, `panelRadius`, `notif*`, `search*`, `sidePanel*`, `ws*`, `durFast/durNormal`, `frameThickness`, `viewportRadius`, `shadowEnabled`, `barBg/barMargin/barHeight`, `islandBg/islandBorderWidth`, `clrCrust`, `clockColor`).
