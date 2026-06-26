"""
extract_lua_table.py
--------------------
Liest eine Factorio-Logdatei und extrahiert die Lua-Tabelle, die von
"Script @__Ingredient_Scrap__/data-updates.lua" bis zur Zeile
"Error ModManager.cpp" reicht.

Die Startzeile enthält das öffnende "{" der Tabelle als letztes Zeichen.
Die Tabelle endet mit der letzten Zeile VOR der Error-Zeile.

Verwendung:
    python extract_lua_table.py [logfile] [outputfile]

Standardwerte:
    logfile    = factorio-current.log
    outputfile = lua_table.lua
"""

import sys
import re

# ── Konfiguration ────────────────────────────────────────────────────────────

LOG_FILE    = sys.argv[1] if len(sys.argv) > 1 else "factorio-current.log"
OUTPUT_FILE = sys.argv[2] if len(sys.argv) > 2 else "lua_table.lua"

# Muster für Start- und Endmarkierung
START_PATTERN = re.compile(r"Script @__Ingredient_Scrap__/data-updates\.lua")
END_PATTERN   = re.compile(r"Error ModManager\.cpp")

# ── Extraktion ───────────────────────────────────────────────────────────────

def extract_table(log_path: str) -> str:
    """
    Gibt den Lua-Tabelleninhalt als String zurück.
    Wirft ValueError wenn Start oder Ende nicht gefunden werden.
    """
    with open(log_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    start_line_idx = None
    table_start_char = None  # Position des "{" in der Startzeile

    # Startzeile suchen
    for i, line in enumerate(lines):
        if START_PATTERN.search(line):
            # Das "{" ist das letzte lesbare Zeichen der Zeile
            stripped = line.rstrip("\n").rstrip()
            brace_pos = stripped.rfind("{")
            if brace_pos != -1:
                start_line_idx = i
                table_start_char = stripped[brace_pos:]  # "{" und alles danach (meist nur "{")
                break

    if start_line_idx is None:
        raise ValueError(
            "Startmarkierung nicht gefunden: ", str(START_PATTERN)
        )

    # Endmarkierung suchen (erste Zeile MIT Error ModManager.cpp NACH dem Start)
    end_line_idx = None
    for i in range(start_line_idx + 1, len(lines)):
        if END_PATTERN.search(lines[i]):
            end_line_idx = i
            break

    if end_line_idx is None:
        raise ValueError("Endmarkierung nicht gefunden: 'Error ModManager.cpp'")

    # Tabelle zusammenbauen:
    # - Erste Zeile: nur das "{" (und was danach kommt, falls mehrzeilig auf Zeile 1)
    # - Folgezeilen bis (exklusive) der Error-Zeile: Zeilennummer-Präfix entfernen
    #   Factorio-Logzeilen haben das Format "   1.348 Text..."
    #   Tabellenzeilen haben KEIN Zeitstempel-Präfix -> direkt übernehmen

    result_lines = [table_start_char + "\n"]

    for line in lines[start_line_idx + 1 : end_line_idx]:
        result_lines.append(line)

    return "".join(result_lines)


def main():
    print(f"Lese Logdatei:  {LOG_FILE}")
    print(f"Ausgabedatei:   {OUTPUT_FILE}")

    try:
        table_content = extract_table(LOG_FILE)
    except FileNotFoundError:
        print(f"FEHLER: Datei nicht gefunden: {LOG_FILE}")
        sys.exit(1)
    except ValueError as e:
        print(f"FEHLER: {e}")
        sys.exit(1)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("-- Extrahiert aus: " + LOG_FILE + "\n")
        f.write("return ")
        f.write(table_content)

    line_count = table_content.count("\n")
    print(f"Erfolgreich! {line_count} Zeilen extrahiert -> {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
