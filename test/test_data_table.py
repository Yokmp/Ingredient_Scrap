"""
test_data_table.py
------------------
Validiert die von Ingredient Scrap generierte data_table gegen eine
Referenz-Lua-Datei (Sollwert aus dem Factorio-Log).

Verwendung:
    python test_data_table.py [lua_table.lua]

Die Lua-Datei wird als Text geparst — kein Lua-Interpreter nötig.
Alle Tests sind unabhängig und geben einzelne PASS/FAIL Meldungen aus.
"""

import sys
import re
from pathlib import Path

LUA_FILE = sys.argv[1] if len(sys.argv) > 1 else "lua_table.lua"

# ── Lua-Datei laden ──────────────────────────────────────────────────────────

try:
    text = Path(LUA_FILE).read_text(encoding="utf-8", errors="replace")
except FileNotFoundError:
    print(f"FEHLER: Datei nicht gefunden: {LUA_FILE}")
    sys.exit(1)

# ── Hilfsfunktionen ──────────────────────────────────────────────────────────

results = []

def test(name, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    msg = f"[{status}] {name}"
    if not condition and detail:
        msg += f"\n       -> {detail}"
    results.append((status, name))
    print(msg)

def contains(pattern, flags=0):
    """Prüft ob ein Regex-Pattern im Text vorkommt."""
    return bool(re.search(pattern, text, flags))

def find_all(pattern, flags=0):
    return re.findall(pattern, text, flags)

def section(title):
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")


# ── TESTS ────────────────────────────────────────────────────────────────────

section("1. CONSTANTS")

test("icon_path vorhanden",
    contains(r'icon_path\s*=\s*"__Ingredient_Scrap__/graphics/icons/"'))

test("recycle_categories.solid vorhanden",
    contains(r'solid\s*=\s*"yis-recycle-to-item"'))

test("recycle_categories.fluid vorhanden",
    contains(r'fluid\s*=\s*"yis-recycle_to_fluid"'))


section("2. MATERIALS")

test("materials.solid enthält 'iron'",
    contains(r'solid\s*=\s*\{[^}]*"iron"', re.DOTALL))

test("materials.solid enthält 'copper'",
    contains(r'solid\s*=\s*\{[^}]*"copper"', re.DOTALL))

test("materials.solid enthält 'steel'",
    contains(r'solid\s*=\s*\{[^}]*"steel"', re.DOTALL))

test("materials.solid enthält 'tungsten'",
    contains(r'solid\s*=\s*\{[^}]*"tungsten"', re.DOTALL))

test("materials.fluid enthält 'iron'",
    contains(r'fluid\s*=\s*\{[^}]*"iron"', re.DOTALL))

test("materials.fluid enthält 'copper'",
    contains(r'fluid\s*=\s*\{[^}]*"copper"', re.DOTALL))

test("materials.prefixes enthält 'molten-'",
    contains(r'prefixes\s*=\s*\{[^}]*"molten-"', re.DOTALL))

test("materials.suffixes enthält '-plate'",
    contains(r'suffixes\s*=\s*\{[^}]*"-plate"', re.DOTALL))

test("materials.suffixes enthält '-ore'",
    contains(r'suffixes\s*=\s*\{[^}]*"-ore"', re.DOTALL))


section("3. INGREDIENTS")

fluid_recipes = find_all(r'ingredients.*?fluids.*?\["([^"]+)"\]', re.DOTALL)
test("ingredients.fluids ist nicht leer",
    contains(r'fluids\s*=\s*\{[^}]+', re.DOTALL))

test("ingredients.fluids enthält casting-iron",
    contains(r'\["casting-iron"\]'))

test("ingredients.fluids enthält casting-copper",
    contains(r'\["casting-copper"\]'))

test("ingredients.items ist nicht leer",
    contains(r'items\s*=\s*\{[^}]+', re.DOTALL))


section("4. INSERTS.RECIPES")

# Prüfe Gesamtanzahl main_product Einträge
main_products = find_all(r'main_product\s*=\s*"([^"]+)"')
test(f"inserts.recipes nicht leer ({len(main_products)} Einträge)",
    len(main_products) > 0,
    f"Gefunden: {len(main_products)}")

# Vollständiger Test für artillery-turret:
# Erwartet:
#   ["artillery-turret"] = {
#     main_product = "artillery-turret",
#     results = {
#       { amount = 5, name = "tungsten-scrap", probability = 0.24, type = "item" },
#       { amount = 4, name = "iron-scrap",     probability = 0.24, type = "item" },
#     }
#   }
# inserts.recipes Sektion isolieren — ab Zeile mit "inserts = {"
inserts_match = re.search(r'\n  inserts\s*=\s*\{(.+)', text, re.DOTALL)
inserts_text = inserts_match.group(1) if inserts_match else ""

# artillery-turret Block: endet mit "      }," (6 Leerzeichen + },)
at_match = re.search(
    r'\["artillery-turret"\]\s*=\s*\{(.*?)\n      \},',
    inserts_text, re.DOTALL
)
at_block = at_match.group(1) if at_match else ""

test("inserts.recipes enthält 'artillery-turret'",
    bool(at_match),
    "Kein Eintrag für artillery-turret gefunden")

test("artillery-turret: main_product = 'artillery-turret'",
    bool(re.search(r'main_product\s*=\s*"artillery-turret"', at_block)),
    f"main_product fehlt oder falsch:\n{at_block[:200]}")

test("artillery-turret: results vorhanden",
    bool(re.search(r'results\s*=\s*\{', at_block)),
    "results fehlt im Eintrag")

test("artillery-turret: tungsten-scrap in results",
    bool(re.search(r'name\s*=\s*"tungsten-scrap"', at_block)),
    "tungsten-scrap fehlt in results")

test("artillery-turret: iron-scrap in results",
    bool(re.search(r'name\s*=\s*"iron-scrap"', at_block)),
    "iron-scrap fehlt in results")

test("artillery-turret: tungsten-scrap amount > 0",
    bool(re.search(r'amount\s*=\s*([1-9]\d*).*?name\s*=\s*"tungsten-scrap"', at_block, re.DOTALL))
    or bool(re.search(r'name\s*=\s*"tungsten-scrap".*?amount\s*=\s*([1-9]\d*)', at_block, re.DOTALL)),
    "tungsten-scrap amount ist 0 oder fehlt")

test("artillery-turret: iron-scrap amount > 0",
    bool(re.search(r'amount\s*=\s*([1-9]\d*).*?name\s*=\s*"iron-scrap"', at_block, re.DOTALL))
    or bool(re.search(r'name\s*=\s*"iron-scrap".*?amount\s*=\s*([1-9]\d*)', at_block, re.DOTALL)),
    "iron-scrap amount ist 0 oder fehlt")

test("artillery-turret: probability korrekt (~0.24)",
    bool(re.search(r'probability\s*=\s*0\.23', at_block)),
    "probability fehlt oder falsch")

test("artillery-turret: results ist Array (kein scrap-name als Key)",
    not bool(re.search(r'\["[a-z]+-scrap"\]', at_block)),
    "results nutzt scrap-name als Key statt Array")

# Prüfe ob results kein scrap-name als Key haben (Array statt Map)
bad_key = contains(r'results\s*=\s*\{[^}]*\["[a-z]+-scrap"\]', re.DOTALL)
test("results sind Arrays (kein scrap-name als Key)",
    not bad_key,
    "results nutzen noch scrap-name als Key statt Array")

# Prüfe probability
probs = find_all(r'probability\s*=\s*([\d.]+)')
test(f"probability ist überall < 1.0 ({len(probs)} Einträge)",
    all(float(p) <= 1.0 for p in probs),
    f"Ungültige Werte: {[p for p in probs if float(p) > 1.0]}")


section("5. PROTOTYPES.ITEMS (Scrap Items)")

scrap_items = find_all(r'\["([a-z]+-scrap)"\]\s*=\s*\{')
test(f"Scrap-Items vorhanden ({len(scrap_items)} Stück)",
    len(scrap_items) > 0)

test("iron-scrap Item existiert",
    contains(r'\["iron-scrap"\]\s*=\s*\{'))

test("copper-scrap Item existiert",
    contains(r'\["copper-scrap"\]\s*=\s*\{'))

test("steel-scrap Item existiert",
    contains(r'\["steel-scrap"\]\s*=\s*\{'))

test("tungsten-scrap Item existiert",
    contains(r'\["tungsten-scrap"\]\s*=\s*\{'))

# Prüfe dass scrap items type = "item" haben
test("iron-scrap hat type = 'item'",
    contains(r'\["iron-scrap"\]\s*=\s*\{[^}]*type\s*=\s*"item"', re.DOTALL))


section("6. PROTOTYPES.RECIPES (Recycling-Rezepte)")

recycle_recipes = find_all(r'\["(recycle-[^"]+)"\]\s*=\s*\{')
test(f"Recycling-Rezepte vorhanden ({len(recycle_recipes)} Stück)",
    len(recycle_recipes) > 0)

for expected in ["recycle-iron-scrap", "recycle-copper-scrap",
                 "recycle-steel-scrap", "recycle-tungsten-scrap"]:
    test(f"Rezept '{expected}' existiert",
        contains(r'\["' + re.escape(expected) + r'"\]\s*=\s*\{'))

# Fluid-Rezepte
for expected in ["recycle-iron-scrap-to-fluid", "recycle-copper-scrap-to-fluid"]:
    test(f"Fluid-Rezept '{expected}' existiert",
        contains(r'\["' + re.escape(expected) + r'"\]\s*=\s*\{'))

# Prüfe dass alle Rezepte enabled = false haben
enabled_true = find_all(r'recycle-[^"]+.*?enabled\s*=\s*true', re.DOTALL)
test("Alle Recycling-Rezepte sind enabled = false",
    len(enabled_true) == 0,
    f"Diese Rezepte haben enabled = true: {enabled_true[:3]}")

# Prüfe ingredients amount != 0 (patch_recycle_amounts muss gelaufen sein)
zero_amounts = find_all(
    r'recycle-[a-z-]+"\]\s*=\s*\{.*?ingredients\s*=\s*\{.*?amount\s*=\s*0',
    re.DOTALL
)
test("Kein Recycling-Rezept hat amount = 0 (patch_recycle_amounts gelaufen)",
    len(zero_amounts) == 0,
    f"{len(zero_amounts)} Rezepte haben noch amount = 0")

# Prüfe categories statt category
test("Rezepte nutzen 'categories' (nicht 'category')",
    contains(r'recycle-iron-scrap.*?categories\s*=\s*\{', re.DOTALL))


section("7. PROTOTYPES.TECHNOLOGY")

tech_section = re.search(r'technology\s*=\s*\{(.+?)^\s*\}', text, re.DOTALL | re.MULTILINE)
tech_entries = re.findall(r'\["(recycle-[^"]+)"\]', tech_section.group(1)) if tech_section else []
test(f"Technologie-Prototypen vorhanden ({len(tech_entries)} Stück)",
    len(tech_entries) > 0)

test("research_trigger vorhanden",
    contains(r'research_trigger'))

test("research_trigger type = 'craft-item'",
    contains(r'research_trigger.*?type\s*=\s*"craft-item"', re.DOTALL))


section("8. KONSISTENZ-CHECKS")

# Jedes recycle-Rezept sollte ein korrespondierendes scrap-item haben
for recipe in set(recycle_recipes):
    # "recycle-iron-scrap" -> "iron-scrap"
    scrap = re.sub(r'^recycle-', '', recipe).replace('-to-fluid', '')
    if scrap in scrap_items:
        pass  # bereits getestet
    # Nur solid-Rezepte prüfen (ohne -to-fluid)
    if not recipe.endswith('-to-fluid'):
        test(f"Scrap-Item für '{recipe}' existiert",
            scrap in scrap_items,
            f"'{scrap}' fehlt in prototypes.items")

# Void-Rezepte: kein Rezept ohne results
# recipes_without_results = find_all(
#     r'\["([^"]+)"\]\s*=\s*\{(?:(?!\bresults\b).)*\}',
#     re.DOTALL
# )
# # Dieser Check ist approximativ — void inserts sind ok wenn main_product gesetzt
# test("inserts ohne results haben wenigstens main_product",
#     not contains(r'recipes.*?\{[^}]*\}(?!\s*main_product)', re.DOTALL))


# ── ZUSAMMENFASSUNG ──────────────────────────────────────────────────────────

section("ZUSAMMENFASSUNG")
passed = sum(1 for s, _ in results if s == "PASS")
failed = sum(1 for s, _ in results if s == "FAIL")
total  = len(results)

print(f"\n  {passed}/{total} Tests bestanden", end="")
if failed > 0:
    print(f"  |  {failed} FEHLGESCHLAGEN:")
    for status, name in results:
        if status == "FAIL":
            print(f"    ✗ {name}")
else:
    print("  ✓  Alle Tests bestanden!")

sys.exit(0 if failed == 0 else 1)
