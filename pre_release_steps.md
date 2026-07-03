# Pre-Release Steps

Diese Datei bleibt waehrend der Release-Vorbereitung aktuell. Sie ist die kurze
Arbeitsliste; ausfuehrliche Begruendungen bleiben in `DESIGN_NOTES.md`.

## 1. Release-kritisch

### 1.1 README finalisieren

- [x] Mixed-Scrap-Verhalten als Feature beschreiben:
  - `yis-mixed-scrap`
  - 60%-Recyclingpool
  - gewichtete Verteilung nach erwarteter Scrap-Haeufigkeit
  - konservatives `floor`, mindestens 1, fuer Mixed-Mengen
- [x] Ancestry-Modi spielerisch erklaeren: Was sieht der Spieler praktisch?
- [x] Klar sagen wie Fluessigkeiten aktuell behandelt werden.
      (`yis-fluid-recipes` hidden)
- [x] `Current behavior` an den aktuellen Stand anpassen.
- [x] Known-Compat-Status ergaenzen:
  - Base+DLC: supported
  - Quality: Recycler Scrap Sink bewusstes Verhalten
  - K2: getestet
  - Bob/Angels: getestet; komplexe Ketten koennen Mixed-Scrap erzeugen
  - Chemistry/Preserve Shape: bewusst future/not included

### 1.2 Changelog 2.0.0 ueberarbeiten

- [x] Format streng beibehalten.
- [x] 2.0.0-Eintrag erweitern:
  - Factorio 2.0 Rewrite
  - Active Ancestry Resolver
  - Mixed Scrap
  - gewichtetes Mixed-Scrap-Recycling
  - Public API
  - Testharness und JSON-Dumps
  - Release/Public-ZIP Deploy
  - K2/Bob/Angels Compat

### 1.3 Settings/Locale Review

- [ ] `locale/en/scrap.cfg` gegen aktuelles Verhalten pruefen.
- [ ] `locale/de/scrap.cfg` gegen aktuelles Verhalten pruefen.
- [ ] Besonders pruefen:
  - `yis-ancestry-mode`
  - `yis-ancestry-max-depth`
  - `yis-ancestry-mixed-limit`
  - `yis-needed`
  - `yis-amount-limit`
  - `yis-fixed-amount`

### 1.4 Release-ZIP trocken pruefen

- [ ] `python tools\toolset\deploy.py check --verbose` ausfuehren.
- [ ] `python tools\toolset\deploy.py build` ausfuehren.
- [ ] `_release_/public.zip` pruefen.
- [ ] `_release_/Ingredient_Scrap_<version>.zip` pruefen.
- [ ] Sicherstellen, dass der Release keine lokalen/dev-only Inhalte enthaelt:
  - keine `tools/`
  - keine Dumps
  - keine `DESIGN_NOTES.md`
  - keine `pre_release_steps.md`
  - keine Debug-Regionen
  - kein Debug-only `require("code.lib.definitions")`
- [ ] Mod-Portal-ZIP einmal in Factorio starten.

## 2. Test-Matrix

- [ ] Base+DLC default:
  - `python tools\test\run_tests.py --profile default --no-color`
- [ ] Base+DLC alle Standardprofile:
  - `python tools\test\run_tests.py --all --no-color`
- [ ] K2 default:
  - `python tools\test\run_tests.py --mod-profile krastorio_is --profile default --no-color`
- [ ] Bob+Angels Full default:
  - `python tools\test\run_tests.py --mod-profile bob_angels_full_is --profile default --no-color`
- [ ] Bob+Angels Full strict mixed width:
  - `python tools\test\run_tests.py --mod-profile bob_angels_full_is --profile ancestry_width_1 --no-color`
- [ ] Optional: Bob Full einzeln.
- [ ] Optional: Angels Full einzeln.

## 3. Design Notes Aufraeumen

- [ ] Oben `Next` aktualisieren.
- [ ] Erledigte grosse Bloecke unter `Done` zusammenfassen.
- [ ] Release-Block mit finaler Checkliste abgleichen.
- [ ] Veraltete Warnungen entfernen, falls sie durch Tests erledigt sind.

## 4. Nice-to-have vor Release

- [ ] Localised names weiter modularisieren:
  - [x] Technology-Namen ueber Factorio-Locale-Schablone bauen.
  - [x] Zusaetzliche Locales anlegen: fr, es, it, pl, pt-BR.
  - [x] Recipe- und Item-Schablonen nochmal gegen beide Sprachen pruefen.
  - [x] Generische Locale-Keys statt Lua-String-Verkettung nutzen.
- [ ] Deploy-Tool CLI schoener machen, falls noch Zeit ist.
- [ ] Weitere Dumps/Profile archivieren, falls sie fuer die Release-Entscheidung
      wirklich gebraucht werden.

## 5. Bewusst nicht vor Release

Nur anfassen, wenn ein Test einen echten Bug findet:

- [ ] Preserve Recipe Shape.
- [ ] Chemistry/Metallurgy als separate Erweiterungsmod.
- [ ] Schrotthaufen als eigene Resource-Quelle.
- [ ] Public Release Publisher Tool fuer GitHub `main`.
- [ ] Viewer-Komfortfunktionen.
- [ ] Weight/Evidence Profiler.
- [ ] Grosse API-Erweiterungen.
- [ ] Weitere Resolver-Heuristiken.
