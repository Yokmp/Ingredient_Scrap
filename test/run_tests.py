"""
Run the Ingredient Scrap Factorio integration tests.

The Factorio mod writes a JSON report from control.lua to:
    script-output/Ingredient_Scrap/test-report.json

Usage:
    python test/run_tests.py --profile default
    python test/run_tests.py --all
    python test/run_tests.py --factorio F:/Games/Factorio_ModTest/bin/x64/factorio.exe --all
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
MOD_DIR = SCRIPT_DIR.parent
TOOLS_DIR = MOD_DIR / "tools"
sys.path.insert(0, str(TOOLS_DIR))

import settingsparser

MODS_DIR = MOD_DIR.parent
DEFAULT_FACTORIO = Path(r"F:/Games/Factorio_ModTest/bin/x64/factorio.exe")
REPORT_RELATIVE = Path("Ingredient_Scrap") / "test-report.json"
DATA_TABLE_RELATIVE = Path("Ingredient_Scrap") / "data-table.lua"
PROFILE_FILE = SCRIPT_DIR / "profile.lua"
TMP_DIR = SCRIPT_DIR / "tmp"
MOD_SETTINGS_FILE = MODS_DIR / "mod-settings.dat"
MOD_SETTINGS_BACKUP_FILE = MODS_DIR / "mod-settings.dat.codex-test-backup"
MOD_LIST_FILE = MODS_DIR / "mod-list.json"
MOD_LIST_BACKUP_FILE = MODS_DIR / "mod-list-old.json"
TIMEOUT = 180

PROFILES = {
    "default": {},
    "fixed_amount": {"fixed_amount": True},
    "limit_off": {"limit": False},
    "probability_min": {"probability": 1},
    "probability_full": {"probability": 100},
    "needed_min": {"needed": 1},
    "needed_high": {"needed": 20},
    "toggles_off": {"limit": False, "fluids": False},
}

BASELINE_MODS = [
    "base",
    "elevated-rails",
    "quality",
    "space-age",
    "Ingredient_Scrap",
]

COMPAT_MODS = {
    "krastorio2": {
        "label": "Krastorio 2",
        "mods": [
            "flib",
            "Krastorio2",
            "Krastorio2Assets",
            "Krastorio2MenuSimulations",
            "ChangeInserterDropLane",
        ],
    },
}

COLOR = {
    "reset": "\033[0m",
    "bold": "\033[1m",
    "dim": "\033[2m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "cyan": "\033[36m",
    "gray": "\033[90m",
}


def colored(text: str, color: str, enabled: bool = True) -> str:
    if not enabled:
        return text
    return f"{COLOR[color]}{text}{COLOR['reset']}"


def status_label(status: str | None, color: bool = True) -> str:
    if status == "pass":
        return colored("PASS", "green", color)
    if status == "fail":
        return colored("FAIL", "red", color)
    return colored(str(status or "UNKNOWN").upper(), "yellow", color)


def lua_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(value)


def write_profile(profile_name: str, settings: dict[str, object]) -> None:
    lines = ["return {", f"  name = {json.dumps(profile_name)},", "  settings = {"]
    for key, value in sorted(settings.items()):
        lines.append(f"    {key} = {lua_value(value)},")
    lines.extend(["  },", "}", ""])
    PROFILE_FILE.write_text("\n".join(lines), encoding="utf-8")


def with_debug_setting_enabled() -> bytes | None:
    original = MOD_SETTINGS_FILE.read_bytes() if MOD_SETTINGS_FILE.exists() else None
    if original is not None:
        MOD_SETTINGS_BACKUP_FILE.write_bytes(original)
    try:
        settingsparser.set_startup_setting(MOD_SETTINGS_FILE, "yis-IS_DEBUG", True)
    except Exception:
        if original is not None:
            MOD_SETTINGS_FILE.write_bytes(original)
        raise
    return original


def restore_mod_settings(original: bytes | None) -> None:
    backup = MOD_SETTINGS_BACKUP_FILE.read_bytes() if MOD_SETTINGS_BACKUP_FILE.exists() else original
    if backup is None:
        try:
            MOD_SETTINGS_FILE.unlink()
        except FileNotFoundError:
            pass
    else:
        MOD_SETTINGS_FILE.write_bytes(backup)
    try:
        MOD_SETTINGS_BACKUP_FILE.unlink()
    except FileNotFoundError:
        pass


def remove_profile() -> None:
    try:
        PROFILE_FILE.unlink()
    except FileNotFoundError:
        pass


def remove_temp_saves() -> None:
    if TMP_DIR.exists():
        shutil.rmtree(TMP_DIR)


def remove_settingsparser_cache() -> None:
    cache_file = TOOLS_DIR / "__pycache__" / "settingsparser.cpython-39.pyc"
    try:
        cache_file.unlink()
    except FileNotFoundError:
        pass


def mod_name_from_zip(zip_path: Path) -> str | None:
    try:
        with zipfile.ZipFile(zip_path) as archive:
            info_names = [name for name in archive.namelist() if name.endswith("/info.json")]
            if not info_names:
                return None
            with archive.open(info_names[0]) as info_file:
                info = json.loads(info_file.read().decode("utf-8-sig"))
                return info.get("name")
    except (OSError, zipfile.BadZipFile, json.JSONDecodeError, KeyError, UnicodeDecodeError):
        return None


def mod_name_from_directory(directory: Path) -> str | None:
    info_path = directory / "info.json"
    if not info_path.exists():
        return None
    try:
        info = json.loads(info_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    return info.get("name")


def installed_mod_names(factorio_exe: Path) -> set[str]:
    names = {"base"}
    data_dir = factorio_root(factorio_exe) / "data"
    if data_dir.exists():
        for path in data_dir.iterdir():
            if path.is_dir() and (path / "info.json").exists():
                name = mod_name_from_directory(path)
                if isinstance(name, str) and name:
                    names.add(name)
    for path in MODS_DIR.iterdir():
        name = None
        if path.is_dir():
            name = mod_name_from_directory(path)
        elif path.suffix.lower() == ".zip":
            name = mod_name_from_zip(path)
        if isinstance(name, str) and name:
            names.add(name)
    return names


def write_mod_list(enabled_mods: set[str], installed_mods: set[str]) -> None:
    all_mods = sorted(installed_mods | enabled_mods, key=str.lower)
    payload = {
        "mods": [
            {"name": name, "enabled": name in enabled_mods}
            for name in all_mods
        ]
    }
    MOD_LIST_FILE.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def prepare_test_mod_list(factorio_exe: Path, compat_name: str | None) -> None:
    enabled_mods = set(BASELINE_MODS)
    if compat_name is not None:
        enabled_mods.update(COMPAT_MODS[compat_name]["mods"])
    installed_mods = installed_mod_names(factorio_exe)
    missing = sorted(enabled_mods - installed_mods, key=str.lower)
    if missing:
        raise RuntimeError(f"Test-Mods fehlen im Mods-Ordner oder Factorio-data: {', '.join(missing)}")
    if MOD_LIST_BACKUP_FILE.exists():
        raise RuntimeError(f"Sicherungsdatei existiert bereits, breche ab: {MOD_LIST_BACKUP_FILE}")
    if MOD_LIST_FILE.exists():
        shutil.copy2(MOD_LIST_FILE, MOD_LIST_BACKUP_FILE)
    write_mod_list(enabled_mods, installed_mods)


def restore_test_mod_list() -> None:
    if MOD_LIST_BACKUP_FILE.exists():
        shutil.copy2(MOD_LIST_BACKUP_FILE, MOD_LIST_FILE)
        MOD_LIST_BACKUP_FILE.unlink()
    else:
        try:
            MOD_LIST_FILE.unlink()
        except FileNotFoundError:
            pass


def factorio_root(factorio_exe: Path) -> Path:
    # Portable Factorio layout: root/bin/x64/factorio.exe
    if factorio_exe.parent.name.lower() == "x64" and factorio_exe.parent.parent.name.lower() == "bin":
        return factorio_exe.parent.parent.parent
    return factorio_exe.parent.parent


def script_output_path(factorio_exe: Path, relative_path: Path) -> Path:
    root = factorio_root(factorio_exe)
    candidates = [
        root / "script-output" / relative_path,
        Path.home() / "AppData" / "Roaming" / "Factorio" / "script-output" / relative_path,
    ]
    for candidate in candidates:
        if candidate.parent.exists():
            return candidate
    return candidates[0]


def report_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, REPORT_RELATIVE)


def data_table_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, DATA_TABLE_RELATIVE)


def compact_json(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(", ", ": "))


def progress_bar(passed: int, total: int, width: int = 28, color: bool = True) -> str:
    if total <= 0:
        return colored("[no tests]", "yellow", color)
    filled = round((passed / total) * width)
    bar = "#" * filled + "-" * (width - filled)
    bar_color = "green" if passed == total else "red"
    return colored(f"[{bar}]", bar_color, color)


def group_cases(cases: list[dict]) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = {}
    for case in cases:
        case_id = str(case.get("id", "misc"))
        group = case_id.split(".", 1)[0]
        groups.setdefault(group, []).append(case)
    return groups


def log_color(level: str) -> str:
    level = level.lower()
    if level == "error":
        return "red"
    if level in {"warning", "warn"}:
        return "yellow"
    return "gray"


def print_report_logs(logs: object, color: bool = True, show_passes: bool = False) -> None:
    if isinstance(logs, dict):
        logs = list(logs.values())
    if not isinstance(logs, list):
        return

    visible_logs = [
        entry for entry in logs
        if isinstance(entry, dict)
        if show_passes or str(entry.get("level", "info")).lower() in {"warning", "warn", "error"}
    ]
    if not visible_logs:
        return

    print()
    print(colored("[logs]", "blue", color))
    for entry in visible_logs:
        level = str(entry.get("level", "info")).upper()
        source = entry.get("source", "unknown")
        step = entry.get("step", "unknown")
        description = entry.get("description", "")
        line_color = log_color(level)
        print(f"  {colored(level, line_color, color)} {source}.{step}: {description}")
        details = entry.get("details")
        if details is not None:
            print(colored(f"       details: {compact_json(details)}", "gray", color))


def print_pretty_report(report: dict, color: bool = True, show_passes: bool = False) -> None:
    summary = report.get("summary", {})
    total = int(summary.get("total", 0) or 0)
    passed = int(summary.get("passed", 0) or 0)
    failed = int(summary.get("failed", 0) or 0)
    status = report.get("status")
    profile = report.get("profile", "unknown")

    title = f"Report: {profile}"
    print()
    print(colored("=" * 72, "cyan", color))
    print(colored(title, "bold", color))
    print(colored("=" * 72, "cyan", color))
    print(f"Status:  {status_label(status, color)}")
    print(f"Mod:     {report.get('mod', 'unknown')}")
    if report.get("compat"):
        print(f"Compat:  {report.get('compat_label', report.get('compat'))}")
    print(f"Schema:  {report.get('schema', 'unknown')}")
    print(f"Factorio:{report.get('factorio_version', 'unknown'):>9}")
    print(f"Summary: {progress_bar(passed, total, color=color)} {passed}/{total} passed, {failed} failed")

    cases = report.get("cases", [])
    logs = report.get("logs", [])
    if failed == 0 and not show_passes:
        print(colored("All assertions passed. Use --show-passes to print every case.", "green", color))
        print_report_logs(logs, color=color, show_passes=show_passes)
        return

    print()
    for group, group_cases_list in sorted(group_cases(cases).items()):
        visible_cases = [case for case in group_cases_list if show_passes or case.get("status") != "pass"]
        if not visible_cases:
            continue
        print(colored(f"[{group}]", "blue", color))
        for case in visible_cases:
            case_status = case.get("status")
            case_color = "green" if case_status == "pass" else "red"
            print(f"  {colored(status_label(case_status, color=False), case_color, color)} {case.get('id')}: {case.get('name')}")
            message = case.get("message")
            if message and message != "ok":
                print(colored(f"       {message}", "yellow", color))
            details = case.get("details")
            if details is not None and (show_passes or case_status != "pass"):
                print(colored(f"       details: {compact_json(details)}", "gray", color))
    print_report_logs(logs, color=color, show_passes=show_passes)


def run_factorio_profile(factorio_exe: Path, profile_name: str, settings: dict[str, object]) -> tuple[bool, dict | None]:
    TMP_DIR.mkdir(exist_ok=True)
    save_path = TMP_DIR / f"ingredient-scrap-{profile_name}.zip"
    output_path = report_path(factorio_exe)
    dump_path = data_table_path(factorio_exe)

    if save_path.exists():
        save_path.unlink()
    if output_path.exists():
        output_path.unlink()
    if dump_path.exists():
        dump_path.unlink()

    write_profile(profile_name, settings)
    start_time = time.time()

    command = [
        str(factorio_exe),
        "--mod-directory", str(MODS_DIR),
        "--create", str(save_path),
        "--disable-audio",
    ]

    print(f"\n=== {profile_name} ===")
    print(f"Factorio: {factorio_exe}")
    print(f"Report:   {output_path}")
    print(f"Data:     {dump_path}")

    try:
        proc = subprocess.run(command, timeout=TIMEOUT, capture_output=True, text=True)
    except subprocess.TimeoutExpired:
        print(f"FEHLER: Factorio hat nach {TIMEOUT}s nicht beendet.")
        return False, None

    elapsed = time.time() - start_time
    print(f"Factorio exit code {proc.returncode} nach {elapsed:.1f}s")

    if not output_path.exists():
        print("FEHLER: Kein JSON-Report erzeugt.")
        if proc.stdout:
            print("--- stdout tail ---")
            print(proc.stdout[-2000:])
        if proc.stderr:
            print("--- stderr tail ---")
            print(proc.stderr[-2000:])
        return False, None

    try:
        report = json.loads(output_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"FEHLER: JSON-Report ist ungueltig: {exc}")
        return False, None

    summary = report.get("summary", {})
    status = report.get("status")
    print(f"Status: {status} | {summary.get('passed', 0)}/{summary.get('total', 0)} bestanden")
    if dump_path.exists():
        print(f"Data table dump: {dump_path}")
    else:
        print("WARNUNG: data-table.lua wurde nicht erzeugt.")
    return status == "pass", report


def compat_label(compat_name: str | None) -> str:
    if compat_name is None:
        return "none"
    return str(COMPAT_MODS[compat_name]["label"])


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Ingredient Scrap Factorio tests")
    parser.add_argument("--factorio", type=Path, default=DEFAULT_FACTORIO)
    parser.add_argument("--profile", choices=sorted(PROFILES), default="default")
    parser.add_argument("--all", action="store_true", help="run all standard profiles")
    parser.add_argument("--compat", choices=sorted(COMPAT_MODS), help="run with an explicit third-party mod set")
    parser.add_argument("--no-color", action="store_true", help="disable ANSI colors")
    parser.add_argument("--show-passes", action="store_true", help="print every passing assertion in the final report")
    parser.add_argument("--keep-saves", action="store_true", help="keep temporary Factorio saves under test/tmp")
    args = parser.parse_args()

    factorio_exe = args.factorio
    if not factorio_exe.exists():
        print(f"FEHLER: Factorio nicht gefunden: {factorio_exe}")
        return 2

    selected = list(PROFILES) if args.all else [args.profile]
    failed = []
    reports: list[dict] = []
    original_mod_settings = None

    try:
        prepare_test_mod_list(factorio_exe, args.compat)
        if args.compat:
            print(f"Compat: {compat_label(args.compat)}")
        original_mod_settings = with_debug_setting_enabled()
        for profile_name in selected:
            ok, report = run_factorio_profile(factorio_exe, profile_name, PROFILES[profile_name])
            if report is not None:
                if args.compat:
                    report["compat"] = args.compat
                    report["compat_label"] = compat_label(args.compat)
                reports.append(report)
            if not ok:
                failed.append(profile_name)
    finally:
        restore_mod_settings(original_mod_settings)
        restore_test_mod_list()
        remove_profile()
        remove_settingsparser_cache()
        if not args.keep_saves:
            remove_temp_saves()

    print("\n=== Zusammenfassung ===")
    if failed:
        print("Fehlgeschlagen: " + ", ".join(failed))
    else:
        print(f"Alle {len(selected)} Profil(e) bestanden.")

    if reports:
        print("\n=== JSON Reports ===")
        for report in reports:
            print_pretty_report(report, color=not args.no_color, show_passes=args.show_passes)

    if args.keep_saves:
        print(f"\nTemp saves kept: {TMP_DIR}")
    else:
        print("\nTemp saves removed.")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

