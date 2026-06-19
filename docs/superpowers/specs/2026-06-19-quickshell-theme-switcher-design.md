# Quickshell Theme-Switcher: Mocha ↔ Liquidglass

**Datum:** 2026-06-19
**Status:** Genehmigt (Design)

## Ziel

Die Quickshell-Konfiguration soll zwischen dem bestehenden Catppuccin-Mocha-Look
und einer neuen „Liquidglass"-Variante umschaltbar sein. Liquidglass orientiert
sich am gemeinsamen Design der Webprojekte `homepage`, `tidalwave` und
`linkconverter` (durchscheinende Glasflächen, heller Akzent, weiche Schatten).

Die Umschaltung erfolgt zur Laufzeit über ein Rofi-Menü und einen
Hyprland-Keybind und überlebt Neustarts.

## Getroffene Entscheidungen

- **Echtes Frosted Glass** via Compositor-Blur (Hyprland-`layerrule`), nicht nur
  Transparenz.
- **Akzentfarbe** der Liquidglass-Variante: Sky-Blue `#88d8ff` (aus `homepage`).
- **Umschalter:** Rofi-Menü **und** Keybind-Toggle, getriggert über Quickshell-IPC
  (`qs ipc call`); Auswahl persistiert über eine von der Shell geschriebene
  State-Datei.

## Designsprache der Referenzprojekte (Quelle der Liquidglass-Variante)

Aus `homepage/src/styles/tokens.css` (kanonisch; die anderen zwei Projekte teilen
dieselbe Struktur, unterscheiden sich nur im Akzent):

- Glasflächen: `rgba(255,255,255,0.06)` bis `0.10`, Rahmen `rgba(255,255,255,0.16)`,
  Innen-Lichtrand (rim) `rgba(255,255,255,0.32)`.
- `backdrop-filter: blur(28px) saturate(180%)` — der eigentliche Frost-Effekt.
- Schatten: kombinierte Inset-Highlights oben + dunkle Drop-Shadows.
- Dunkler Canvas `#0b0814` / `#120b1e`; Akzente je Projekt: homepage `#88d8ff`,
  tidalwave `#5eead4`, linkconverter `#ffb3cf`.

## Architektur

### Theme-Singleton

Neue Dateien unter `.config/quickshell/`:

- `Theme.qml` — `pragma Singleton`. Einzige Wahrheit für alle Farb- und
  Flächen-Token. Hält beide Varianten als JS-Objekte, exponiert die aktive über
  `property string variant` und bietet die Methoden `setVariant(name)` und
  `toggle()`. Beide aktualisieren `variant` und persistieren die Wahl in die
  State-Datei.
- `qmldir` — Inhalt: `singleton Theme 1.0 Theme.qml`

Heute sind die Farbpaletten in **5 Dateien dupliziert**: `Bar.qml`,
`MusicOverlay.qml`, `NotificationPopup.qml`, `StatsOverlay.qml`, `SidePanel.qml`.
Jede lokale `readonly property color clrX`-Definition wird entfernt und durch
`Theme.clrX` ersetzt (mechanischer Refactor, gleiche Token-Namen).

### Umschaltung via IPC

Die Umschaltung läuft über Quickshell-IPC (deterministisch, kein Datei-Watching):

- In `shell.qml` wird einmalig ein `IpcHandler { target: "theme" }` instanziiert
  mit den Funktionen `toggle()` und `setVariant(string name)`. Diese delegieren an
  die gleichnamigen Methoden des `Theme`-Singletons.
- Aufruf von außen: `qs ipc call theme toggle` bzw.
  `qs ipc call theme setVariant liquidglass`.
- Weil alle QML-Komponenten ihre Farben aus dem reaktiven `Theme`-Singleton
  beziehen, schaltet das Setzen von `Theme.variant` die gesamte Shell **live** um —
  kein Reload nötig.

### Persistenz

`${XDG_STATE_HOME:-~/.local/state}/quickshell/theme` (Inhalt: `mocha` oder
`liquidglass`) dient **ausschließlich** der Persistenz, nicht als Live-Trigger:

- **Schreiben:** `Theme.setVariant`/`toggle` schreiben die neue Wahl in die Datei.
- **Lesen:** einmalig beim Shell-Start (`Component.onCompleted`) zum
  Wiederherstellen der letzten Wahl. Fehlt die Datei, gilt Default `mocha`.

## Token-Modell (beide Varianten)

Gleiche Token-Namen, variantenabhängige Werte:

| Token | `mocha` (heute) | `liquidglass` |
|---|---|---|
| `windowBg` | transparent | transparent |
| `panelBg` | `#1e1e2e` (opak) | `rgba(255,255,255,0.06)` |
| `panelBgStrong` | `#313244` | `rgba(255,255,255,0.10)` |
| `border` | Sky 55 % (`rgba(0.537,0.863,0.922,0.55)`) | `rgba(255,255,255,0.16)` |
| `rim` (Innenlicht) | nicht genutzt | `rgba(255,255,255,0.32)` |
| `accent` | `#89dceb` | `#88d8ff` |
| Akzentfarben (red/green/yellow/…) | Catppuccin-Werte | bleiben unverändert (lesbar auf Glas) |
| `radius` | 12 | 16 |

Die bestehenden semantischen Namen (`clrBase`, `clrSurface0`, `clrSurface1`,
`clrText`, `clrSubtext0`, `clrBlue`, `clrLavender`, `clrGreen`, `clrYellow`,
`clrPeach`, `clrRed`, `clrTeal`, `clrSky`, `clrSapphire`, `clrMauve`, `clrPink`)
bleiben erhalten und werden auf das Token-Modell abgebildet, plus die neuen
Glas-Token (`panelBg`, `panelBgStrong`, `border`, `rim`, `radius`, `accent`).

Der Glas-Look entsteht, weil `panelBg` in `liquidglass` durchscheinend ist **und**
Hyprland die Layer blurrt. In `mocha` ist `panelBg` opak → kein Blur sichtbar, der
alte Look bleibt unverändert.

## Compositor-Blur (Hyprland)

Quickshell registriert seine Layer-Surfaces unter dem Namespace `quickshell`
(Default, verifiziert via `hyprctl layers`). In `.config/hypr/hyprland.conf` kommt
hinzu:

```
layerrule = blur, quickshell
layerrule = ignorezero, quickshell
```

`blur {}` ist global bereits aktiv (size 6, passes 2, vibrancy 0.17). Die
`layerrule` gilt für beide Varianten; in `mocha` ist nichts durchscheinend, also
bleibt sie wirkungslos. `ignorezero` verhindert, dass die volltransparenten Lücken
zwischen den Bar-Inseln den Hintergrund blurren. Tuning-Punkt: bei unerwünschtem
Blur der Lücken über `ignorealpha` nachjustieren.

## Umschalter

### `scripts/theme-switch.sh`

- `theme-switch.sh toggle` — ruft `qs ipc call theme toggle` auf.
- `theme-switch.sh menu` — Rofi-Auswahl (`Mocha` / `Liquidglass`) im Stil des
  bestehenden `scripts/powermenu.sh`; ruft
  `qs ipc call theme setVariant <auswahl>` auf.
- Die State-Datei wird von der Shell selbst geschrieben; das Skript fasst sie nicht
  an.

### Hyprland-Keybind

Eine Zeile in `hyprland.conf`, z. B.:

```
bind = $mod, T, exec, ~/.config/quickshell/scripts/theme-switch.sh toggle
```

(Konkreter Tastencode wird beim Implementieren mit den bestehenden Binds
abgeglichen, um Kollisionen zu vermeiden.)

## Bewusst nicht im Umfang (YAGNI)

- **Animierte Gradient-Blobs + Noise-Overlay:** in QML teuer (Dauer-Repaint auf
  Shell-Ebene), auf einer dünnen Bar wirkungslos. Der Compositor-Blur liefert die
  Tiefe. Kann später für die großen Overlays nachgerüstet werden.
- **`Instrument Serif` für Headlines:** setzt installierten Font voraus und ändert
  den Bar-Charakter stark. Nur auf ausdrücklichen Wunsch.

## Testbarkeit & Risiken

- Nach dem Refactor jede der 5 QML-Dateien einzeln gegen `qmllint` prüfen und die
  Shell starten; beide Varianten live durchschalten und visuell abnehmen.
- Risiko 1: IPC-Verfügbarkeit — `qs ipc call` setzt voraus, dass die Shell läuft
  und der `IpcHandler` korrekt registriert ist; beim Implementieren mit
  `qs ipc show` verifizieren.
- Risiko 2: Blur der transparenten Bar-Lücken (Tuning via `ignorezero`/
  `ignorealpha`).
- Risiko 3: Lesbarkeit der Catppuccin-Akzentfarben auf den helleren Glasflächen —
  visuell prüfen, ggf. minimal aufhellen.

## Betroffene Dateien

- **Neu:** `.config/quickshell/Theme.qml`, `.config/quickshell/qmldir`,
  `.config/quickshell/scripts/theme-switch.sh`
- **Geändert:** `.config/quickshell/shell.qml` (instanziiert `IpcHandler`),
  `Bar.qml`, `MusicOverlay.qml`, `NotificationPopup.qml`, `StatsOverlay.qml`,
  `SidePanel.qml`
- **Geändert:** `.config/hypr/hyprland.conf` (layerrules + Keybind)
