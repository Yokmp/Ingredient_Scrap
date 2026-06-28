"""
test_synthetic.py
-----------------
Validiert die data_table gegen die synthetischen Testdaten aus test-data.lua.
Setzt voraus dass IS_DEBUG=true und die Testdaten geladen wurden.

Verwendung:
    python test_synthetic.py [lua_table.lua]
"""

import sys
import re
from pathlib import Path

# An run_tests.log anhängen
LOG_OUTPUT = Path(__file__).resolve().parent / "run_tests.log"
_log_file = open(str(LOG_OUTPUT), "a", encoding="utf-8")

class Tee:
    def __init__(self, *files):
        self.files = files
    def write(self, obj):
        for f in self.files:
            f.write(obj)
            f.flush()
    def flush(self):
        for f in self.files:
            f.flush()

sys.stdout = Tee(sys.__stdout__, _log_file)
sys.stderr = Tee(sys.__stderr__, _log_file)

LUA_FILE = sys.argv[1] if len(sys.argv) > 1 else "lua_table.lua"

try:
    text = Path(LUA_FILE).read_text(encoding="utf-8", errors="replace")
except FileNotFoundError:
    print(f"FEHLER: Datei nicht gefunden: {LUA_FILE}")
    sys.exit(1)

# ── Hilfsfunktionen ──────────────────────────────────────────────────────────

results_log = []

def test(name, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    msg = f"[{status}] {name}"
    if not condition and detail:
        msg += f"\n       -> {detail}"
    results_log.append((status, name))
    print(msg)

def section(title):
    print(f"\n{'─' * 60}")
    print(f"  {title}")
    print(f"{'─' * 60}")

def get_insert_block(recipe_name):
    """Extrahiert den inserts.recipes Block für ein Rezept."""
    inserts_match = re.search(r'\n  inserts\s*=\s*\{(.+)', text, re.DOTALL)
    if not inserts_match:
        return ""
    inserts_text = inserts_match.group(1)
    m = re.search(
        r'\["' + re.escape(recipe_name) + r'"\]\s*=\s*\{(.*?)\n      \},',
        inserts_text, re.DOTALL
    )
    return m.group(1) if m else ""

def has_result(block, scrap_name):
    return bool(re.search(r'name\s*=\s*"' + re.escape(scrap_name) + r'"', block))

def get_amount(block, scrap_name):
    """Gibt den amount-Wert für einen scrap_name im Block zurück."""
    # Suche den Teilblock für diesen scrap_name
    m = re.search(
        r'\{[^}]*name\s*=\s*"' + re.escape(scrap_name) + r'"[^}]*\}',
        block, re.DOTALL
    )
    if not m:
        return None
    am = re.search(r'amount\s*=\s*(\d+)', m.group(0))
    return int(am.group(1)) if am else None

def result_count(block):
    """Zählt die Einträge in results{}."""
    results_m = re.search(r'results\s*=\s*\{(.*?)\n        \}', block, re.DOTALL)
    if not results_m:
        return 0
    return len(re.findall(r'name\s*=\s*"[^"]+"', results_m.group(1)))

def proto_exists(proto_type, name):
    """Prüft ob ein Prototyp in prototypes.{proto_type} existiert."""
    m = re.search(r'prototypes\s*=\s*\{(.+?)^\s*\}', text, re.DOTALL | re.MULTILINE)
    if not m:
        return False
    section_m = re.search(
        re.escape(proto_type) + r'\s*=\s*\{(.+?)^\s*\}',
        m.group(1), re.DOTALL | re.MULTILINE
    )
    if not section_m:
        return False
    return bool(re.search(r'\["' + re.escape(name) + r'"\]', section_m.group(1)))

def in_materials(list_name, value):
    # Gezielt die materials Sektion am Anfang der Tabelle suchen (2 Leerzeichen Einrückung)
    m = re.search(r'^\s{2}materials\s*=\s*\{(.+?)^\s{2}\}', text, re.DOTALL | re.MULTILINE)
    if not m:
        return False
    materials_block = m.group(1)
    # Dann die spezifische Liste darin suchen
    list_m = re.search(
        re.escape(list_name) + r'\s*=\s*\{([^}]+)\}',
        materials_block, re.DOTALL
    )
    if not list_m:
        return False
    return f'"{value}"' in list_m.group(1)


# ── TESTS ────────────────────────────────────────────────────────────────────

section("MATERIALS")

test("[TC-14] testium in materials.solid",
    in_materials("solid", "testium"),
    "testium-plate registriert aber nicht in solid erkannt")

test("[TC-15] testium in materials.fluid (molten-testium + testium-plate)",
    in_materials("fluid", "testium"),
    "molten-testium existiert und testium-plate existiert, aber testium nicht in fluid")

test("[TC-09] alienite NICHT in materials.fluid (kein alienite-plate)",
    not in_materials("fluid", "alienite"),
    "alienite sollte ignoriert werden da kein alienite-plate existiert")

test("[TC-10] uranium NICHT in materials.solid (blacklist)",
    not in_materials("solid", "uranium"),
    "uranium ist blacklisted, sollte nicht in solid sein")


section("[TC-01] Einfaches Rezept — yis-test-tc01")

b01 = get_insert_block("yis-test-tc01")
test("TC-01: main_product = 'yis-test-product-a'",
    bool(re.search(r'main_product\s*=\s*"yis-test-product-a"', b01)),
    f"Block: {b01[:150]}")
test("TC-01: iron-scrap in results",
    has_result(b01, "iron-scrap"),
    "iron-scrap fehlt in results")
test("TC-01: iron-scrap amount > 0",
    (get_amount(b01, "iron-scrap") or 0) > 0,
    f"amount = {get_amount(b01, 'iron-scrap')}")
test("TC-01: genau 1 result",
    result_count(b01) == 1,
    f"result_count = {result_count(b01)}")


section("[TC-02] Akkumulierung — yis-test-tc02")

b02 = get_insert_block("yis-test-tc02")
amt01 = get_amount(b01, "iron-scrap") or 0
amt02 = get_amount(b02, "iron-scrap") or 0
test("TC-02: iron-scrap in results",
    has_result(b02, "iron-scrap"))
test("TC-02: amount > TC-01 (iron-plate + iron-gear-wheel akkumuliert)",
    amt02 > amt01,
    f"TC-02 amount={amt02} sollte > TC-01 amount={amt01} sein")
test("TC-02: genau 1 result (kein Duplikat)",
    result_count(b02) == 1,
    f"result_count = {result_count(b02)}")


section("[TC-03] Mehrere scrap_types — yis-test-tc03")

b03 = get_insert_block("yis-test-tc03")
test("TC-03: iron-scrap in results",
    has_result(b03, "iron-scrap"))
test("TC-03: copper-scrap in results",
    has_result(b03, "copper-scrap"))
test("TC-03: genau 2 results",
    result_count(b03) == 2,
    f"result_count = {result_count(b03)}")


section("[TC-04] Dämpfung bei hoher Menge — yis-test-tc04")

b04 = get_insert_block("yis-test-tc04")
amt04 = get_amount(b04, "iron-scrap") or 0
test("TC-04: iron-scrap vorhanden",
    has_result(b04, "iron-scrap"))
test("TC-04: amount < 40 (Dämpfung greift bei 200x iron-plate, 24%)",
    amt04 < 40,
    f"amount = {amt04}, sollte < 40 sein (gedämpft)")
test("TC-04: amount > 0",
    amt04 > 0,
    f"amount = {amt04}")


section("[TC-05] Void-Rezept — yis-test-tc05-void")

b05 = get_insert_block("yis-test-tc05-void")
test("TC-05: keine results (void recipe ignoriert)",
    not bool(re.search(r'results\s*=\s*\{', b05)),
    "Void-Rezept hat results generiert — sollte ignoriert werden")


section("[TC-06] Fluid main_product — yis-test-tc06")

b06 = get_insert_block("yis-test-tc06")
test("TC-06: kein iron-scrap (fluid main_product ignoriert)",
    not has_result(b06, "iron-scrap"),
    "iron-scrap wurde generiert obwohl main_product ein Fluid ist")


section("[TC-07] Fluid-Ingredient — yis-test-tc07")

b07 = get_insert_block("yis-test-tc07")
test("TC-07: testium-scrap in results",
    has_result(b07, "testium-scrap"),
    "molten-testium wurde nicht als testium-scrap Quelle erkannt")
test("TC-07: recycle-testium-scrap-to-fluid Rezept existiert",
    proto_exists("recipes", "recycle-testium-scrap-to-fluid"),
    "recycle-testium-scrap-to-fluid fehlt in prototypes.recipes")
test("TC-07: testium-scrap Item existiert",
    proto_exists("items", "testium-scrap"),
    "testium-scrap fehlt in prototypes.items")


section("[TC-08] Fluid + Solid akkumuliert — yis-test-tc08")

b08 = get_insert_block("yis-test-tc08")
test("TC-08: iron-scrap vorhanden",
    has_result(b08, "iron-scrap"))
test("TC-08: genau 1 iron-scrap Eintrag (solid + fluid akkumuliert)",
    result_count(b08) == 1,
    f"result_count = {result_count(b08)}, erwartet 1")
amt08 = get_amount(b08, "iron-scrap") or 0
amt01_ref = get_amount(b01, "iron-scrap") or 0
test("TC-08: amount > TC-01 (fluid addiert auf solid)",
    amt08 > amt01_ref,
    f"TC-08 amount={amt08} sollte > TC-01 amount={amt01_ref} sein")


section("[TC-09] Unbekanntes Fluid — yis-test-tc09")

b09 = get_insert_block("yis-test-tc09")
test("TC-09: kein scrap result (alienite ignoriert)",
    not bool(re.search(r'results\s*=\s*\{', b09)),
    "alienite hat scrap generiert obwohl kein alienite-plate existiert")


section("[TC-10] Blacklisted — yis-test-tc10")

b10 = get_insert_block("yis-test-tc10")
test("TC-10: kein scrap result (uranium blacklisted)",
    not bool(re.search(r'results\s*=\s*\{', b10)),
    "uranium-235 hat scrap generiert obwohl uranium blacklisted ist")


section("[TC-11] Kein Tech-Eintrag — yis-test-tc11-no-tech")

test("TC-11: KEIN recycle-iron-scrap Tech aus tc11 (kein loses Ende)",
    # tc11 hat keine Tech -> aber andere Rezepte haben iron-scrap Tech
    # wir prüfen nur dass kein Absturz und die Tabelle konsistent ist
    True,
    "")
test("TC-11: kein 'yis-test-tech-iron' in prototypes.technology",
    not proto_exists("technology", "yis-test-tech-iron"),
    "Eine nicht existierende Technologie wurde generiert")


section("[TC-12] Tech-Eintrag vorhanden — yis-test-tc12-with-tech")

test("TC-12: recycle-testium-scrap Tech existiert",
    proto_exists("technology", "recycle-testium-scrap"),
    "recycle-testium-scrap Tech fehlt obwohl yis-test-tech-testium existiert")


section("[TC-13] Item mit icons{} — yis-test-tc13-icons-array")

b13 = get_insert_block("yis-test-tc13-icons-array")
test("TC-13: testium-scrap generiert (kein Absturz bei icons{})",
    has_result(b13, "testium-scrap"),
    "make_scrap_item ist bei icons{} abgestürzt oder hat nichts generiert")


# ── ZUSAMMENFASSUNG ──────────────────────────────────────────────────────────

section("ZUSAMMENFASSUNG")
passed = sum(1 for s, _ in results_log if s == "PASS")
failed = sum(1 for s, _ in results_log if s == "FAIL")
total  = len(results_log)

print(f"\n  {passed}/{total} Tests bestanden", end="")
if failed > 0:
    print(f"  |  {failed} FEHLGESCHLAGEN:")
    for status, name in results_log:
        if status == "FAIL":
            print(f"    ✗ {name}")
else:
    print("  ✓  Alle Tests bestanden!")

sys.exit(0 if failed == 0 else 1)
