# Quickshell Theme-Switcher (Mocha ↔ Liquidglass) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Quickshell-Bar/Overlays laufzeit-umschaltbar zwischen dem bestehenden Catppuccin-Mocha-Look und einer Liquidglass-Variante (Glasflächen + Compositor-Blur) machen, gesteuert über IPC, Rofi-Menü und Keybind.

**Architecture:** Ein `Theme.qml`-Singleton wird zur einzigen Farbquelle. Alle 5 QML-Komponenten beziehen ihre Farben reaktiv daraus statt aus lokal duplizierten Paletten. Ein `IpcHandler` in `shell.qml` schaltet die aktive Variante via `qs ipc call theme …`; die Wahl wird in eine State-Datei persistiert und beim Start zurückgelesen. Hyprland blurrt den Quickshell-Layer, wodurch die durchscheinenden Glasflächen frosted wirken.

**Tech Stack:** Quickshell 0.3.0 (QML), `Quickshell.Io` (`IpcHandler`, `FileView`, `Process`), Hyprland `layerrule`, Bash + Rofi.

## Global Constraints

- Quickshell-Version: **0.3.0** (Arch). Keine externen Abhängigkeiten hinzufügen.
- Layer-Namespace für Hyprland-Regeln ist exakt `quickshell` (verifiziert via `hyprctl layers`).
- Liquidglass-Akzent: `#88d8ff`. Glas-Token aus `homepage/src/styles/tokens.css`.
- **Mocha muss nach dem Refactor pixelidentisch zum Status quo bleiben.** Jede Komponente in beiden Varianten visuell abnehmen.
- **Kein Unit-Test-Harness vorhanden** (Shell-Config). „Verifikation" je Task bedeutet:
  1. Datei speichern → Quickshell lädt per Hot-Reload neu. QML-Fehler über `qs log` prüfen (alternativ `quickshell` in einem Terminal starten und stderr beobachten). **Keine Fehler, betroffene UI rendert weiterhin.**
  2. `qs ipc call theme setVariant mocha` → Komponente sieht aus wie vor dem Refactor.
  3. `qs ipc call theme setVariant liquidglass` → Komponente zeigt durchscheinende Flächen.
- Alle Token-Namen aus dem bestehenden Code (`clrBase`, `clrSurface0/1`, `clrMantle`, `clrText`, `clrSubtext0/1`, `clrBlue`, `clrLavender`, `clrGreen`, `clrYellow`, `clrPeach`, `clrRed`, `clrTeal`, `clrSky`, `clrSapphire`, `clrMauve`, `clrPink`) bleiben erhalten und werden im Singleton variantenabhängig belegt.

---

### Task 1: Theme-Singleton + qmldir

**Files:**
- Create: `.config/quickshell/Theme.qml`
- Create: `.config/quickshell/qmldir`

**Interfaces:**
- Produces:
  - Singleton `Theme` (importierbar via `import "."`), mit:
    - `property string variant` (`"mocha"` | `"liquidglass"`), `readonly property bool glass`
    - `function setVariant(name)`, `function toggle()`
    - `function borderColor(real a) -> color`
    - Token-Properties: `panelBg`, `rim` (color), `radius` (int), `accent` (color) und alle `clr*` (color) aus den Global Constraints.

- [ ] **Step 1: `qmldir` anlegen**

Datei `.config/quickshell/qmldir`:

```
singleton Theme 1.0 Theme.qml
```

- [ ] **Step 2: `Theme.qml` anlegen**

Datei `.config/quickshell/Theme.qml`:

```qml
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
    function borderColor(a) {
        return glass ? Qt.rgba(1, 1, 1, a)
                     : Qt.rgba(0.537, 0.863, 0.922, a)
    }

    readonly property color panelBg: glass ? Qt.rgba(1, 1, 1, 0.06) : "#1e1e2e"
    readonly property color rim:     glass ? Qt.rgba(1, 1, 1, 0.32) : "transparent"
    readonly property int   radius:  glass ? 16 : 12
    readonly property color accent:  glass ? "#88d8ff" : "#89dceb"

    // ── Semantische Palette (Namen wie im Altcode) ───────────────────
    readonly property color clrBase:     glass ? "#0b0814"            : "#1e1e2e"
    readonly property color clrMantle:   glass ? Qt.rgba(1,1,1,0.04)  : "#181825"
    readonly property color clrSurface0: glass ? Qt.rgba(1,1,1,0.10)  : "#313244"
    readonly property color clrSurface1: glass ? Qt.rgba(1,1,1,0.16)  : "#45475a"
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
```

- [ ] **Step 3: Hot-Reload prüfen**

Datei speichern. Quickshell lädt neu. `Theme` wird noch nicht konsumiert → kein sichtbarer Unterschied.
Run: `qs log` (oder Terminal-stderr).
Expected: **Keine** QML-Fehler zu `Theme.qml`/`qmldir`. Bar unverändert sichtbar.

- [ ] **Step 4: Commit**

```bash
git add .config/quickshell/Theme.qml .config/quickshell/qmldir
git commit -m "feat(quickshell): Theme-Singleton mit Mocha- und Liquidglass-Variante"
```

---

### Task 2: IPC-Handler verdrahten + Bar.qml umstellen

**Files:**
- Modify: `.config/quickshell/shell.qml` (Imports + `IpcHandler`)
- Modify: `.config/quickshell/Bar.qml` (Palette → `Theme`)

**Interfaces:**
- Consumes: `Theme` aus Task 1 (`Theme.clr*`, `Theme.panelBg`, `Theme.radius`, `Theme.borderColor()`, `Theme.toggle()`, `Theme.setVariant()`).
- Produces: IPC-Target `theme` mit Funktionen `toggle()` und `setVariant(name)`.

- [ ] **Step 1: Imports in `shell.qml` ergänzen**

In `.config/quickshell/shell.qml` die Importzeilen (oben, nach `import QtQuick`) erweitern:

```qml
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import "."
```

- [ ] **Step 2: `IpcHandler` in `shell.qml` hinzufügen**

Innerhalb des `ShellRoot { … }`-Blocks (z. B. direkt nach dem `NotificationServer { … }`) einfügen:

```qml
    // ── Theme-Umschaltung via IPC ───────────────────────────────────────────────
    // qs ipc call theme toggle   /   qs ipc call theme setVariant liquidglass
    IpcHandler {
        target: "theme"
        function toggle(): void { Theme.toggle() }
        function setVariant(name: string): void { Theme.setVariant(name) }
    }
```

- [ ] **Step 3: IPC-Registrierung prüfen**

Speichern, dann:
Run: `qs ipc show`
Expected: Listet das Target `theme` mit `toggle()` und `setVariant(string)`.

- [ ] **Step 4: `Bar.qml` — Import ergänzen, Inseln auf `panelBg`/`radius`/`border` umstellen**

In `.config/quickshell/Bar.qml` nach den bestehenden Imports `import "."` ergänzen.

Die 6 Insel-Rechtecke umstellen. Jeweils die Füllung `color: bar.clrBase` → `color: Theme.panelBg`, das `radius: 12` → `radius: Theme.radius`, und die Border-Farbe auf `Theme.borderColor(...)`. Betroffene Zeilen (vor Änderung):

- Zeilen 322–324, 386–388, 419–421, 590–592, 681–683: `radius: 12` → `radius: Theme.radius`; `color: bar.clrBase` → `color: Theme.panelBg`; `border { color: Qt.rgba(0.537, 0.863, 0.922, 0.55); width: 2 }` → `border { color: Theme.borderColor(0.55); width: 2 }`.
- Zeile 635–637 (Audio-Insel mit animierter Border): `radius:  12` → `radius: Theme.radius`; `color:   bar.clrBase` → `color: Theme.panelBg`; `border   { color: Qt.rgba(0.537, 0.863, 0.922, bar.hasAudio ? 0.55 : 0.0); width: 2 }` → `border { color: Theme.borderColor(bar.hasAudio ? 0.55 : 0.0); width: 2 }`.

- [ ] **Step 5: `Bar.qml` — restliche Border-Literale + generischer Paletten-Rename**

Verbleibende Sky-Border-Literale und alle übrigen Paletten-Referenzen mechanisch ersetzen:

```bash
cd ~/git/dotfiles/.config/quickshell
# verbleibende Border-Literale -> Theme.borderColor(<alpha>)
sed -i -E 's/Qt\.rgba\(0\.537, 0\.863, 0\.922, ([^)]*)\)/Theme.borderColor(\1)/g' Bar.qml
# alle restlichen bar.clr* -> Theme.clr*  (Insel-Füllungen sind bereits panelBg)
sed -i -E 's/\bbar\.clr/Theme.clr/g' Bar.qml
```

> Hinweis: `bar.clrBase` in der aktiven/inaktiven Workspace-Logik (`parent.isActive ? bar.clrBase : bar.clrSubtext0`) wird hier korrekt zu `Theme.clrBase` (dunkle Kontrastfarbe auf hellem Akzent) — **nicht** zu `panelBg`. Das ist beabsichtigt.

- [ ] **Step 6: `Bar.qml` — lokale Palette löschen**

Den Block der lokalen Farbdefinitionen entfernen (ehemals Zeilen 23–38, `readonly property color clrBase: …` bis `clrPink: …`).

- [ ] **Step 7: Verifizieren (beide Varianten)**

```bash
qs ipc call theme setVariant mocha
qs ipc call theme setVariant liquidglass
qs ipc call theme setVariant mocha
```
Expected: Keine QML-Fehler in `qs log`. In `mocha` ist die Bar identisch zum vorherigen Stand. In `liquidglass` werden die Inseln durchscheinend mit weißer Border. Umschalten wirkt **live** (kein Reload).

- [ ] **Step 8: Commit**

```bash
git add .config/quickshell/shell.qml .config/quickshell/Bar.qml
git commit -m "feat(quickshell): Bar an Theme-Singleton + IPC-Umschaltung angebunden"
```

---

### Task 3: SidePanel.qml umstellen

**Files:**
- Modify: `.config/quickshell/SidePanel.qml`

**Interfaces:**
- Consumes: `Theme` (`Theme.clr*`, `Theme.panelBg`, `Theme.borderColor()`).

- [ ] **Step 1: Import + Panel-Container umstellen**

`import "."` nach den Imports ergänzen. Den Panel-Container umstellen:
- Zeile 117: `color: panel.clrMantle` → `color: Theme.panelBg`
- Zeile 119: `border { color: Qt.rgba(0.537, 0.863, 0.922, 0.15); width: 1 }` → `border { color: Theme.borderColor(0.15); width: 1 }`

- [ ] **Step 2: Generischer Rename**

```bash
cd ~/git/dotfiles/.config/quickshell
sed -i -E 's/Qt\.rgba\(0\.537, 0\.863, 0\.922, ([^)]*)\)/Theme.borderColor(\1)/g' SidePanel.qml
sed -i -E 's/\bpanel\.clr/Theme.clr/g' SidePanel.qml
```

- [ ] **Step 3: Lokale Palette löschen**

Block `readonly property color clrBase: …` bis `clrMauve: …` (ehemals Zeilen 17–31) entfernen.

- [ ] **Step 4: Verifizieren**

SidePanel öffnen (Bar-Button), dann:
```bash
qs ipc call theme setVariant liquidglass
qs ipc call theme setVariant mocha
```
Expected: Keine Fehler. SidePanel in `mocha` unverändert; in `liquidglass` durchscheinend. Karten/Buttons (ehemals `clrSurface0`) lesbar.

- [ ] **Step 5: Commit**

```bash
git add .config/quickshell/SidePanel.qml
git commit -m "feat(quickshell): SidePanel an Theme-Singleton angebunden"
```

---

### Task 4: StatsOverlay.qml umstellen

**Files:**
- Modify: `.config/quickshell/StatsOverlay.qml`

**Interfaces:**
- Consumes: `Theme` (`Theme.clr*`, `Theme.panelBg`, `Theme.radius`, `Theme.borderColor()`).

- [ ] **Step 1: Import + Overlay-Container umstellen**

`import "."` ergänzen. Container umstellen:
- Zeile 117: `radius: 12` → `radius: Theme.radius`
- Zeile 118: `color:  overlay.clrBase` → `color: Theme.panelBg`
- Zeile 119: `border  { color: Qt.rgba(0.537, 0.863, 0.922, 0.55); width: 2 }` → `border { color: Theme.borderColor(0.55); width: 2 }`

- [ ] **Step 2: Generischer Rename**

```bash
cd ~/git/dotfiles/.config/quickshell
sed -i -E 's/Qt\.rgba\(0\.537, 0\.863, 0\.922, ([^)]*)\)/Theme.borderColor(\1)/g' StatsOverlay.qml
sed -i -E 's/\boverlay\.clr/Theme.clr/g' StatsOverlay.qml
```

- [ ] **Step 3: Lokale Palette löschen**

Block `readonly property color clrBase: …` bis `clrPink: …` (ehemals Zeilen 80–94) entfernen.

- [ ] **Step 4: Verifizieren**

Stats-Overlay öffnen, beide Varianten durchschalten (`qs ipc call theme setVariant liquidglass` / `mocha`).
Expected: Keine Fehler. Stat-Karten (ehemals `clrSurface0`) und Graphen-Linien in beiden Varianten lesbar; `mocha` unverändert.

- [ ] **Step 5: Commit**

```bash
git add .config/quickshell/StatsOverlay.qml
git commit -m "feat(quickshell): StatsOverlay an Theme-Singleton angebunden"
```

---

### Task 5: MusicOverlay.qml umstellen

**Files:**
- Modify: `.config/quickshell/MusicOverlay.qml`

**Interfaces:**
- Consumes: `Theme` (`Theme.clr*`, `Theme.panelBg`, `Theme.radius`, `Theme.borderColor()`).

- [ ] **Step 1: Import + Container umstellen**

`import "."` ergänzen. Container umstellen:
- Zeile 61: `radius: 12` → `radius: Theme.radius`
- Zeile 62: `color:  overlay.clrBase` → `color: Theme.panelBg`
- Zeile 63: `border  { color: Qt.rgba(0.537, 0.863, 0.922, 0.55); width: 2 }` → `border { color: Theme.borderColor(0.55); width: 2 }`

- [ ] **Step 2: Generischer Rename**

```bash
cd ~/git/dotfiles/.config/quickshell
sed -i -E 's/Qt\.rgba\(0\.537, 0\.863, 0\.922, ([^)]*)\)/Theme.borderColor(\1)/g' MusicOverlay.qml
sed -i -E 's/\boverlay\.clr/Theme.clr/g' MusicOverlay.qml
```

> Hinweis: Die innere Cover-Border in Zeile 139 (`…, 0.25`) wird durch das Border-`sed` automatisch zu `Theme.borderColor(0.25)`.

- [ ] **Step 3: Lokale Palette löschen**

Block `readonly property color clrBase: …` bis `clrMauve: …` (ehemals Zeilen 17–24) entfernen.

- [ ] **Step 4: Verifizieren**

Music-Overlay öffnen (Musik-Insel), beide Varianten durchschalten.
Expected: Keine Fehler; `mocha` unverändert; `liquidglass` durchscheinend.

- [ ] **Step 5: Commit**

```bash
git add .config/quickshell/MusicOverlay.qml
git commit -m "feat(quickshell): MusicOverlay an Theme-Singleton angebunden"
```

---

### Task 6: NotificationPopup.qml umstellen

**Files:**
- Modify: `.config/quickshell/NotificationPopup.qml`

**Interfaces:**
- Consumes: `Theme` (`Theme.clr*`, `Theme.panelBg`, `Theme.radius`, `Theme.borderColor()`).

- [ ] **Step 1: Import + Toast-Container umstellen**

`import "."` ergänzen. Toast-Container umstellen:
- Zeile 75: `radius: 12` → `radius: Theme.radius`
- Zeile 76: `color: root.clrMantle` → `color: Theme.panelBg`
- Zeile 78: `border.color: toast.critical ? root.clrRed : Qt.rgba(0.537, 0.863, 0.922, 0.3)` → `border.color: toast.critical ? Theme.clrRed : Theme.borderColor(0.3)`

- [ ] **Step 2: Generischer Rename**

```bash
cd ~/git/dotfiles/.config/quickshell
sed -i -E 's/Qt\.rgba\(0\.537, 0\.863, 0\.922, ([^)]*)\)/Theme.borderColor(\1)/g' NotificationPopup.qml
sed -i -E 's/\broot\.clr/Theme.clr/g' NotificationPopup.qml
```

- [ ] **Step 3: Lokale Palette löschen**

Block `readonly property color clrMantle: …` bis `clrRed: …` (ehemals Zeilen 31–38) entfernen.

- [ ] **Step 4: Verifizieren**

Test-Notification senden:
```bash
notify-send "Theme-Test" "Liquidglass-Popup"
qs ipc call theme setVariant liquidglass
notify-send "Theme-Test" "Glas-Popup"
qs ipc call theme setVariant mocha
```
Expected: Keine Fehler; Popup in `mocha` unverändert, in `liquidglass` durchscheinend; kritische Notifications behalten rote Border.

- [ ] **Step 5: Commit**

```bash
git add .config/quickshell/NotificationPopup.qml
git commit -m "feat(quickshell): NotificationPopup an Theme-Singleton angebunden"
```

---

### Task 7: Hyprland — Layer-Blur + Keybind

**Files:**
- Modify: `.config/hypr/hyprland.conf`

**Interfaces:**
- Consumes: IPC-Target `theme` aus Task 2; Skript aus Task 8 (Keybind ruft es auf).

- [ ] **Step 1: Layerrules für Compositor-Blur ergänzen**

In `.config/hypr/hyprland.conf` nach dem `blur { … }`-Block (Ende des `decoration`-Blocks, ~Zeile 175) ergänzen:

```
# Frosted Glass für die Quickshell-Layer (greift nur bei durchscheinenden Flächen,
# also in der Liquidglass-Variante; Mocha bleibt unbeeinflusst).
layerrule = blur, quickshell
layerrule = ignorezero, quickshell
```

- [ ] **Step 2: Keybind ergänzen**

Bei den übrigen `bind = …`-Zeilen ergänzen (Tastenkombination vorher gegen bestehende Binds prüfen, hier `$mainMod SHIFT, T`):

```
bind = $mainMod SHIFT, T, exec, ~/.config/quickshell/scripts/theme-switch.sh toggle
```

> Vor dem Eintragen prüfen, dass `$mainMod SHIFT, T` frei ist:
> `grep -n 'SHIFT, T' ~/.config/hypr/hyprland.conf` — falls belegt, andere freie Kombination wählen.

- [ ] **Step 3: Hyprland neu laden + Blur prüfen**

```bash
hyprctl reload
qs ipc call theme setVariant liquidglass
```
Expected: Hintergrund hinter Bar/Panels wird sichtbar geblurrt (frosted). `qs ipc call theme setVariant mocha` → opaker Look, kein sichtbarer Blur. Keine Hyprland-Konfigfehler (`hyprctl reload` ohne Fehlermeldung).

- [ ] **Step 4: Commit**

```bash
git add .config/hypr/hyprland.conf
git commit -m "feat(hyprland): Layer-Blur für Quickshell + Theme-Switch-Keybind"
```

---

### Task 8: Rofi-/Toggle-Skript

**Files:**
- Create: `.config/quickshell/scripts/theme-switch.sh`

**Interfaces:**
- Consumes: IPC-Target `theme` (`toggle`, `setVariant`).

- [ ] **Step 1: Skript anlegen**

Datei `.config/quickshell/scripts/theme-switch.sh`:

```bash
#!/bin/bash
# Schaltet das Quickshell-Theme um.
#   theme-switch.sh toggle   -> wechselt zwischen Mocha und Liquidglass
#   theme-switch.sh menu     -> Rofi-Auswahl
# Persistenz erledigt die Shell selbst (State-Datei).

case "$1" in
    toggle)
        qs ipc call theme toggle
        ;;
    menu)
        MOCHA="󰧉 Mocha"
        GLASS="󰂭 Liquidglass"
        CHOICE=$(printf "%s\n%s" "$MOCHA" "$GLASS" \
            | rofi -dmenu \
                -p "󰸉" \
                -theme ~/.config/rofi/catppuccin-mocha.rasi \
                -theme-str 'window { width: 220px; } listview { lines: 2; }')
        case "$CHOICE" in
            "$MOCHA") qs ipc call theme setVariant mocha ;;
            "$GLASS") qs ipc call theme setVariant liquidglass ;;
        esac
        ;;
    *)
        echo "usage: $0 {toggle|menu}" >&2
        exit 1
        ;;
esac
```

- [ ] **Step 2: Ausführbar machen**

```bash
chmod +x ~/.config/quickshell/scripts/theme-switch.sh
```

- [ ] **Step 3: Verifizieren**

```bash
~/.config/quickshell/scripts/theme-switch.sh toggle    # schaltet hin und her
~/.config/quickshell/scripts/theme-switch.sh menu       # Rofi-Auswahl erscheint
```
Expected: `toggle` wechselt die Variante sichtbar; `menu` öffnet Rofi im Mocha-Stil, Auswahl wird angewandt. Keybind aus Task 7 (`$mainMod SHIFT, T`) wechselt ebenfalls.

- [ ] **Step 4: Persistenz prüfen**

```bash
qs ipc call theme setVariant liquidglass
cat "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/theme"   # -> liquidglass
# Quickshell neu starten
hyprctl dispatch exec "killall quickshell; quickshell"
```
Expected: Datei enthält `liquidglass`; nach Neustart startet die Shell direkt im Liquidglass-Look.

- [ ] **Step 5: Commit**

```bash
git add .config/quickshell/scripts/theme-switch.sh
git commit -m "feat(quickshell): Theme-Switch-Skript (toggle + Rofi-Menü)"
```

---

## Self-Review

- **Spec-Abdeckung:** Theme-Singleton + qmldir (Task 1) ✓; IPC-Umschaltung + Live-Update (Task 2) ✓; Persistenz via State-Datei lesen/schreiben (Task 1 + Task 8 Step 4) ✓; Token-Modell beide Varianten (Task 1) ✓; alle 5 QML-Refactors (Tasks 2–6) ✓; Hyprland-Layerrules + Keybind (Task 7) ✓; Rofi-Menü + Toggle (Task 8) ✓. YAGNI-Ausschlüsse (Blobs/Noise/Serif) bleiben außen vor ✓.
- **Platzhalter:** keine.
- **Typ-/Namenskonsistenz:** `setVariant`/`toggle`/`borderColor`/`panelBg`/`radius`/`clr*` durchgängig identisch zwischen Task 1 (Definition) und Tasks 2–6 (Verwendung) sowie IPC (Task 2, Task 8).
- **Offene Risiken (im Spec dokumentiert):** IPC-Verfügbarkeit (Task 2 Step 3 prüft via `qs ipc show`); Blur der transparenten Bar-Lücken (Task 7, ggf. `ignorealpha` nachjustieren); Lesbarkeit der Akzentfarben auf Glas (Verifikationsschritte 2–6).
