# Quickshell-Theme „Zen“ — Design-Spec

**Datum:** 2026-07-13
**Status:** vom Nutzer freigegeben (Brainstorming mit Visual-Mockups, Optionen jeweils per Klick gewählt)

## Ziel

Eine dritte Theme-Variante `zen` für die Quickshell-Konfiguration
(`.config/quickshell/`), neben `mocha` und `liquidglass`. Grundfarbpalette
bleibt Catppuccin Mocha mit Teal/Sky als Akzent, aber der Look wird modern und
minimalistisch — inspiriert von [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
(Material-3-Expressive-Formsprache: randlose Flächen, Capsule-Formen, Tiefe
über Flächenabstufung statt Linien, betonte Animationen).

**Harte Anforderung:** `mocha` und `liquidglass` bleiben pixelidentisch.

## Getroffene Entscheidungen (Brainstorming)

| Frage | Entscheidung |
|---|---|
| Eingriffstiefe | Voller Struktur-Umbau inkl. eigenem Bar-Layout-Modus |
| Bar-Inhalt | Alle Module bleiben sichtbar, nur ruhiger gestaltet |
| Bar-Struktur | „Zen-Fläche“: eine durchgehende, angedockte, opake Fläche; Module ohne eigene Container |
| Screen-Frame | Ja — Bar + Rahmen (links/rechts/unten) als eine Fläche, Desktop als abgerundetes Viewport |
| Typografie | Alles bleibt JetBrainsMono Nerd Font (keine neuen Font-Abhängigkeiten) |
| Architektur | Token-getrieben: Theme.qml bekommt volles Token-Set, Komponenten lesen nur Tokens; gezielte Verzweigungen nur wo Zen strukturell abweicht |
| Name | `zen` |

## Look & Feel

### Bar (44 px, angedockt)

- Durchgehende opake Fläche in Mantle `#181825`, volle Bildschirmbreite,
  keine Außenabstände (heutige Insel-Bar: transparentes Fenster mit 10 px
  Margins und fünf umrandeten Inseln).
- Keine Borders, keine 1-px-Trennstriche; Gruppierung nur über Abstände.
- Die fünf bisherigen Inseln bleiben als unsichtbare Layout-Container
  bestehen (Füllung transparent, Border 0) — Modul-Reihenfolge und -Inhalt
  unverändert.
- **Workspace-Capsule (Hero-Element):** Container in Surface0 `#313244` mit
  voller Rundung (Capsule), darin die Workspace-Ziffern. Ein Teal-Indikator
  `#94e2d5` (Capsule, etwas breiter als die inaktiven Ziffernkreise) gleitet
  animiert zum aktiven Workspace; die überfahrene Ziffer wechselt animiert
  auf Crust `#11111b`, inaktive Ziffern stehen in Subtext0 `#a6adc8`.

### Screen-Frame + Viewport

- Rahmen links/rechts/unten, Dicke 10 px, Mantle `#181825` — optisch ein
  Stück mit der Bar (oben).
- Die vier inneren Ecken des so entstehenden Viewports werden mit konkaven
  Viertelkreis-Fillets gerundet, Radius 16 px.
- Vollbild-Apps decken Bar und Frame ab (Layer „top“, keine Overlay-Ebene).
- Frame ist vollständig klick-durchlässig (leere Input-Region).

### Farbdisziplin

In Zen wird die heutige Mehrfarbigkeit der Stats (grün/sky/peach/gelb/
teal/mauve je Modulgruppe) zurückgenommen:

- Stat-Icons: **Teal** `#94e2d5`
- Werte: Text `#cdd6f4` bzw. Subtext für Sekundäres
- Uhr: **Sky** `#89dceb`
- Kritische Zustände (Batterie niedrig, Notification critical): **Rot** `#f38ba8`
- Sonst keine weiteren Buntfarben. Tiefe über die Flächenleiter
  Mantle `#181825` → Base `#1e1e2e` → Surface0 `#313244` → Surface1 `#45475a`,
  plus weicher Schatten auf frei schwebenden Cards — nie über Linien.

### Overlays & Panels (Zen-Verhalten)

- **MusicOverlay / StatsOverlay:** docken nahtlos unter der Bar an
  (top-Gap 0, gleiche Mantle-Fläche, nur untere Ecken gerundet ~20 px,
  Border 0). Sie „wachsen“ aus der Bar heraus.
- **SidePanel:** dockt am linken Frame an (Margins 0, beginnt unter der
  Bar, läuft bis zum unteren Frame), Mantle-Fläche, nur rechte Ecken
  gerundet. Innere Cards folgen der Flächenleiter.
- **NotificationPopup:** randlose Base-Cards `#1e1e2e` mit Schatten,
  Radius ~16 px, oben rechts im Viewport (Abstand: Frame + Gap).
- **SearchResults:** randlos, Base-Fläche, größere Rundung, Schatten.

### Motion

Material-3-angelehnte Tokens, nur für Zen-spezifische Animationen:

- Positions-/Größenwechsel (Workspace-Indikator, Overlay-Slide): ~350 ms,
  Easing mit leichtem Überschwingen (Bezier ≈ 0.38, 1.21, 0.22, 1.0)
- Farb-/Opacity-Wechsel: ~200 ms, weich (OutCubic o. ä.)
- Bestehende Animationen in Mocha/Liquidglass bleiben unverändert.

## Token-Architektur (Theme.qml)

### Variantenverwaltung

- `variant: "mocha" | "liquidglass" | "zen"`, neu `readonly bool zen`
- `setVariant()` validiert alle drei Namen; State-Datei-Parsing ebenso
- `toggle()` rotiert: mocha → liquidglass → zen → mocha
- IPC unverändert: `qs ipc call theme setVariant zen`

### Neue Tokens (Werte je Variante)

Mocha/Liquidglass erhalten exakt die heute hartkodierten Werte; nur Zen
weicht ab. Auszug der wichtigsten Tokens:

| Token | mocha | liquidglass | zen |
|---|---|---|---|
| `barBg` | transparent | transparent | `#181825` |
| `barMargin` | 10 | 10 | 0 |
| `islandBg` | `panelBg` | `panelBg` (Glas) | transparent |
| `islandBorderWidth` | 2 | 2 | 0 |
| `sepVisible` | true | true | false |
| `radius` (bestehend) | 12 | 16 | 20 (Panels) |
| `radiusCapsule` | — | — | 999 (Workspaces) |
| `frameEnabled` | false | false | true |
| `frameThickness` | — | — | 10 |
| `viewportRadius` | — | — | 16 |
| `shadowEnabled` | false | false | true (nur freie Cards) |
| `overlayTopGap` | heutiger Wert | heutiger Wert | 0 |
| `durFast` / `durNormal` | — | — | 200 / 350 |

- Farb-Helfer `Theme.statIcon(fallback)`: liefert in Zen `clrTeal`, sonst die
  übergebene bisherige Modulfarbe — so bleibt Mocha bunt, Zen diszipliniert.
- Die bestehende `clr*`-Palette und `borderColor(a)` bleiben unangetastet;
  `borderColor` liefert in Zen effektiv nichts Sichtbares (Border-Breiten 0).
- Genaue heutige Werte (z. B. Overlay-Top-Margins) werden beim Umsetzen aus
  dem Code übernommen — Anspruch bleibt Pixelgleichheit der Alt-Themes.

### Hyprland-Kopplung

- Bei Variantenwechsel **und beim Start** setzt Theme.qml per `Process`:
  `hyprctl keyword general:gaps_out <wert>` — Zen: **6**, sonst: **10**
  (Restore-Wert als dokumentierte Konstante; muss zu
  `.config/hypr/hyprland.conf` passen, dort steht heute `gaps_out = 10`).
- Ausführung auch beim Start macht das selbstheilend (Absturz unter Zen →
  Neustart repariert die Gaps passend zur geladenen Variante).
- `rounding = 10` und `gaps_in = 5` bleiben unangetastet.

## Komponenten-Änderungen

| Datei | Änderung |
|---|---|
| `Theme.qml` | Drei Varianten, Token-Set, Hyprland-Kopplung |
| `Bar.qml` | Fenster-Bg/Margins aus Tokens; Insel-Optik aus Tokens; Trennstriche an `sepVisible`; Workspace-Modul mit zwei Darstellungen (heutige Pills vs. Zen-Capsule mit Gleit-Indikator); Stat-Icon-Farben über `Theme.statIcon(...)` |
| `Frame.qml` (neu) | 3 Kanten-PanelWindows (exclusiveZone = Dicke) + 4 Eck-Fenster mit konkaven Fillets (Canvas); klick-durchlässig; nur bei `Theme.zen` aktiv |
| `shell.qml` | Frame einhängen; Dismiss-Fenster-Margins (heute hart 58 / 316) an Bar-Geometrie/Tokens binden |
| `MusicOverlay.qml`, `StatsOverlay.qml` | Radius/Border/Bg/Top-Gap aus Tokens; Zen: nahtloses Andocken, nur untere Ecken gerundet (Radius + deckendes Rechteck an der Oberkante) |
| `SidePanel.qml` | Margins/Radius/Bg aus Tokens; Zen: am Frame angedockt, rechte Ecken gerundet |
| `NotificationPopup.qml` | Radius/Border/Bg/Schatten aus Tokens |
| `SearchResults.qml` | Hartkodierte Farben (`#181825` u. a.) durch Tokens ersetzen |
| `StatItem.qml`, `BarButton.qml`, `MiniGraph.qml`, `SearchItem.qml` | Hartkodierte Defaults (`#cdd6f4`, `#89b4fa`) an Theme binden — gleiche Werte wie heute, kein sichtbarer Unterschied in Alt-Themes |
| `scripts/theme-switch.sh` | Menü mit drei Einträgen (`󰧉 Mocha / 󰂭 Liquidglass / 󰚀 Zen`); `toggle` nutzt die Shell-Rotation |

Bekannter Nebenbefund (wird beim Token-Umbau mit erledigt):
`SearchItem.qml:19` nutzt `Qt.rgba(180, 190, 254, 0.15)` — Werte > 1 clampen
auf Weiß; gemeint war Lavender `#b4befe`. Fix ändert den heutigen Look nicht
wahrnehmbar (bleibt dezentes helles Hover), wird aber korrekt auf die
Palette gebunden.

## Verifikation

1. Test direkt aus dem Repo, ohne Flake-Rebuild:
   `qs -p ~/git/dotfiles/.config/quickshell`
2. **Regression Alt-Themes:** Screenshots (grim) von Mocha und Liquidglass
   vor/nach dem Umbau vergleichen — Anspruch: pixelidentisch.
3. **Zen funktional:** Frame-Klick-Durchlässigkeit (Fenster am Rand
   bedienen), Workspace-Indikator-Animation, nahtloses Overlay-Andocken,
   Notification-Look, Vollbild deckt Frame ab.
4. **Gaps-Kopplung:** mehrfach zwischen allen Varianten wechseln,
   `hyprctl getoption general:gaps_out` prüfen (6 unter Zen, 10 sonst);
   qs-Neustart unter jeder Variante.
5. State-Datei (`~/.local/state/quickshell/theme`) nach jedem Wechsel prüfen.

Hinweis Deployment: Das Repo wird per NixOS-Flake ausgerollt — für den
Dauerbetrieb ist nach dem Merge ein Rebuild nötig; für die Entwicklung
reicht `qs -p`.

## Nicht im Scope

- Keine Modul-Reduktion, kein Auto-Hide der Bar
- Keine dynamischen Wallpaper-Farben (Palette bleibt fix Mocha)
- Keine neuen Fonts, keine Material Symbols (Nerd-Font-Glyphen bleiben)
- Kein SDF-/Metaball-Shader wie im Original — die „eine Fläche“-Wirkung
  entsteht über gleiche Farbe + Fillets nur an den vier Viewport-Ecken
- Keine Änderungen an Rofi, Hyprland-Rounding oder anderen Programmen
