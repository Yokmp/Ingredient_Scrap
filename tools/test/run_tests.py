"""
Run the Ingredient Scrap Factorio integration tests.

The Factorio mod writes a JSON report from control.lua to:
    script-output/Ingredient_Scrap/test-report.json

Usage:
    python tools/test/run_tests.py --profile default
    python tools/test/run_tests.py --all
    python tools/test/run_tests.py --factorio F:/Games/Factorio_ModTest/bin/x64/factorio.exe --all
    python tools/test/run_tests.py --mod-profile angels_is --check-unused-prototype-data --keep-mod-list
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
MOD_DIR = SCRIPT_DIR.parent.parent
TOOLS_DIR = MOD_DIR / "tools"
TOOLSET_DIR = TOOLS_DIR / "toolset"
sys.path.insert(0, str(TOOLSET_DIR))
sys.path.insert(0, str(TOOLS_DIR))

import settings
import modlist

MODS_DIR = MOD_DIR.parent
DEFAULT_FACTORIO = Path(r"F:/Games/Factorio_ModTest/bin/x64/factorio.exe")
REPORT_RELATIVE = Path("Ingredient_Scrap") / "test-report.json"
DATA_TABLE_RELATIVE = Path("Ingredient_Scrap") / "data-table.lua"
MATERIAL_FLOW_RELATIVE = Path("Ingredient_Scrap") / "material-flow.json"
MATERIAL_FLOW_STATE_RELATIVE = Path("Ingredient_Scrap") / "material-flow-data.js"
PRODUCTION_FLOW_RELATIVE = Path("Ingredient_Scrap") / "production-flow.json"
PRODUCTION_FLOW_STATE_RELATIVE = Path("Ingredient_Scrap") / "production-flow-data.js"
ICON_ASSETS_RELATIVE = Path("Ingredient_Scrap") / "icon-assets"
PROFILE_FILE = SCRIPT_DIR / "profile.lua"
TMP_DIR = SCRIPT_DIR / "tmp"
MOD_SETTINGS_FILE = MODS_DIR / "mod-settings.dat"
MOD_SETTINGS_BACKUP_FILE = MODS_DIR / "mod-settings.dat.codex-test-backup"
TIMEOUT = 180
DEFAULT_TEST_MOD_PROFILE = "ingredient_scrap"
DEFAULT_DEBUG_SETTING = "yis-IS_DEBUG"
DEFAULT_SETTINGS_MOD = "Ingredient_Scrap"

PROFILES = {
    "default": {},
    "fixed_amount": {"fixed_amount": True},
    "limit_off": {"limit": False},
    "probability_min": {"probability": 1},
    "probability_full": {"probability": 100},
    "needed_min": {"needed": 1},
    "needed_high": {"needed": 20},
    "recipe_chain_targets": {"recipe_chain_targets": True},
    "toggles_off": {"limit": False, "fluids": False},
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


def with_debug_setting_enabled(setting_name: str) -> bytes | None:
    original = MOD_SETTINGS_FILE.read_bytes() if MOD_SETTINGS_FILE.exists() else None
    if original is not None:
        MOD_SETTINGS_BACKUP_FILE.write_bytes(original)
    try:
        settings.set_startup_setting(MOD_SETTINGS_FILE, setting_name, True)
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


def remove_settings_cache() -> None:
    for cache_dir in (TOOLSET_DIR / "__pycache__", TOOLS_DIR / "__pycache__"):
        if not cache_dir.exists():
            continue
        for pattern in ("settings.cpython-*.pyc", "settingsparser.cpython-*.pyc"):
            for cache_file in cache_dir.glob(pattern):
                try:
                    cache_file.unlink()
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


def material_flow_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, MATERIAL_FLOW_RELATIVE)


def material_flow_state_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, MATERIAL_FLOW_STATE_RELATIVE)


def production_flow_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, PRODUCTION_FLOW_RELATIVE)


def production_flow_state_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, PRODUCTION_FLOW_STATE_RELATIVE)


def icon_assets_path(factorio_exe: Path) -> Path:
    return script_output_path(factorio_exe, ICON_ASSETS_RELATIVE)


def normalize_archive_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("/")


def collect_icon_sources(value: object, by_mod: dict[str, set[str]] | None = None) -> dict[str, set[str]]:
    if by_mod is None:
        by_mod = {}
    if isinstance(value, dict):
        source = value.get("source")
        if isinstance(source, dict) and isinstance(source.get("mod"), str) and isinstance(source.get("inner_path"), str):
            by_mod.setdefault(source["mod"], set()).add(normalize_archive_path(source["inner_path"]))
        for child in value.values():
            collect_icon_sources(child, by_mod)
    elif isinstance(value, list):
        for child in value:
            collect_icon_sources(child, by_mod)
    return by_mod


def builtin_data_mod_path(root: Path, mod_name: str) -> Path | None:
    if mod_name in {"core", "base", "quality", "space-age", "elevated-rails"}:
        path = root / "data" / mod_name
        if path.exists():
            return path
    return None


def local_mod_asset_path(mod_name: str, version: str | None) -> tuple[str, Path] | None:
    candidates: list[tuple[str, Path]] = [
        ("directory", MODS_DIR / mod_name),
    ]
    if version:
        candidates.append(("directory", MODS_DIR / f"{mod_name}_{version}"))
    candidates.extend(("directory", path) for path in sorted(MODS_DIR.glob(f"{mod_name}_*")) if path.is_dir())
    if version:
        candidates.append(("zip", MODS_DIR / f"{mod_name}_{version}.zip"))
    candidates.extend(("zip", path) for path in sorted(MODS_DIR.glob(f"{mod_name}_*.zip")) if path.is_file())
    for kind, path in candidates:
        if path.exists():
            return kind, path
    return None


def common_zip_root(names: list[str]) -> str:
    root = ""
    for name in names:
        normalized = normalize_archive_path(name)
        parts = normalized.split("/", 1)
        if len(parts) < 2:
            return ""
        if not root:
            root = parts[0]
        elif root != parts[0]:
            return ""
    return root


def extract_zip_icon_assets(zip_path: Path, mod_name: str, inner_paths: set[str], output_root: Path) -> Path | None:
    if not inner_paths:
        return None
    target_root = output_root / mod_name
    with zipfile.ZipFile(zip_path) as archive:
        names = archive.namelist()
        root = common_zip_root(names)
        available = {normalize_archive_path(name): name for name in names}
        for inner_path in sorted(inner_paths):
            candidates = [inner_path]
            if root:
                candidates.insert(0, f"{root}/{inner_path}")
            member = next((available[candidate] for candidate in candidates if candidate in available), None)
            if member is None:
                continue
            target_path = target_root / Path(inner_path)
            target_path.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as src, target_path.open("wb") as dst:
                shutil.copyfileobj(src, dst)
    return target_root if target_root.exists() else None


def enrich_material_flow_metadata(factorio_exe: Path, flow_path: Path, state_path: Path | None = None) -> None:
    if not flow_path.exists():
        return
    try:
        data = json.loads(flow_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return
    if not isinstance(data, dict):
        return

    root = factorio_root(factorio_exe)
    icon_output = icon_assets_path(factorio_exe)
    active_mods = data.get("active_mods")
    if not isinstance(active_mods, dict):
        active_mods = {}

    icon_sources = collect_icon_sources(data)
    asset_roots: dict[str, dict[str, str]] = {}
    for mod_name, version in active_mods.items():
        mod_name = str(mod_name)
        version = str(version) if version is not None else None
        builtin_path = builtin_data_mod_path(root, mod_name)
        if builtin_path is not None:
            asset_roots[mod_name] = {"type": "directory", "path": str(builtin_path)}
            continue
        local_path = local_mod_asset_path(mod_name, version)
        if local_path is not None:
            kind, path = local_path
            if kind == "zip":
                extracted = extract_zip_icon_assets(path, mod_name, icon_sources.get(mod_name, set()), icon_output)
                if extracted is not None:
                    asset_roots[mod_name] = {"type": "directory", "path": str(extracted), "source_zip": str(path)}
                else:
                    asset_roots[mod_name] = {"type": kind, "path": str(path)}
            else:
                asset_roots[mod_name] = {"type": kind, "path": str(path)}

    data["factorio_root"] = str(root)
    data["mods_dir"] = str(MODS_DIR)
    data["icon_assets_dir"] = str(icon_output)
    data["asset_roots"] = asset_roots
    flow_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    state_path = state_path or material_flow_state_path(factorio_exe)
    state_path.write_text(
        "window.__INGREDIENT_SCRAP_MATERIAL_FLOW__ = "
        + json.dumps(data, ensure_ascii=False)
        + ";\n",
        encoding="utf-8",
    )


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


def factorio_diagnostic_args(verbose: bool = False, check_unused_prototype_data: bool = False) -> list[str]:
    args = []
    if verbose:
        args.append("--verbose")
    if check_unused_prototype_data:
        args.append("--check-unused-prototype-data")
    return args


def prototype_warning_lines(output: str) -> list[str]:
    warning_markers = (
        "not accessed",
        "unknown key",
    )
    lines = []
    for line in output.splitlines():
        lowered = line.lower()
        if "finished checking unused prototype data" in lowered:
            continue
        if any(marker in lowered for marker in warning_markers):
            lines.append(line)
    return lines


def run_factorio_profile(
    factorio_exe: Path,
    profile_name: str,
    settings: dict[str, object],
    extra_factorio_args: list[str] | None = None,
    strict_prototype_warnings: bool = False,
) -> tuple[bool, dict | None]:
    TMP_DIR.mkdir(exist_ok=True)
    save_path = TMP_DIR / f"ingredient-scrap-{profile_name}.zip"
    output_path = report_path(factorio_exe)
    dump_path = data_table_path(factorio_exe)
    flow_path = material_flow_path(factorio_exe)
    production_path = production_flow_path(factorio_exe)

    for path in (save_path, output_path, dump_path, flow_path, production_path):
        if path.exists():
            path.unlink()

    write_profile(profile_name, settings)
    start_time = time.time()

    command = [
        str(factorio_exe),
        "--mod-directory", str(MODS_DIR),
        *(extra_factorio_args or []),
        "--create", str(save_path),
        "--disable-audio",
    ]

    print(f"\n=== {profile_name} ===")
    print(f"Factorio: {factorio_exe}")
    print(f"Report:   {output_path}")
    print(f"Data:     {dump_path}")
    print(f"Flow:     {flow_path}")
    print(f"Prod:     {production_path}")

    try:
        proc = subprocess.run(command, timeout=TIMEOUT, capture_output=True, text=True)
    except subprocess.TimeoutExpired:
        print(f"FEHLER: Factorio hat nach {TIMEOUT}s nicht beendet.")
        return False, None

    elapsed = time.time() - start_time
    print(f"Factorio exit code {proc.returncode} nach {elapsed:.1f}s")

    diagnostic_warnings = prototype_warning_lines((proc.stdout or "") + "\n" + (proc.stderr or ""))
    if diagnostic_warnings:
        print(f"Prototype diagnostics: {len(diagnostic_warnings)} warning line(s)")
        for line in diagnostic_warnings[:12]:
            print(f"  {line}")
        if len(diagnostic_warnings) > 12:
            print(f"  ... {len(diagnostic_warnings) - 12} more")
        if strict_prototype_warnings:
            print("FEHLER: Prototype diagnostics found and --strict-prototype-warnings is active.")
            return False, None

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
    if flow_path.exists():
        enrich_material_flow_metadata(factorio_exe, flow_path)
        print(f"Material flow:   {flow_path}")
    else:
        print("WARNUNG: material-flow.json wurde nicht erzeugt.")
    if production_path.exists():
        enrich_material_flow_metadata(factorio_exe, production_path, production_flow_state_path(factorio_exe))
        print(f"Production flow: {production_path}")
    else:
        print("WARNUNG: production-flow.json wurde nicht erzeugt.")
    return status == "pass", report


def compat_label(compat_name: str | None, profiles: dict[str, dict[str, object]] | None = None) -> str:
    if compat_name is None:
        return "none"
    return modlist.profile_label(compat_name, profiles)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Ingredient Scrap Factorio tests")
    parser.add_argument("--factorio", type=Path, help="Factorio executable path; defaults to tools/toolset/tool-ui.json or the local portable install")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="default")
    parser.add_argument("--all", action="store_true", help="run all standard profiles")
    parser.add_argument("--compat", help="legacy alias for --mod-profile")
    parser.add_argument("--mod-profile", help="Factorio mod-list profile to enable")
    parser.add_argument("--mod-profiles-json", type=Path, help="optional JSON file with additional mod-list profiles; defaults to modlist.py config")
    parser.add_argument("--list-mod-profiles", action="store_true", help="print known mod-list profiles and exit")
    parser.add_argument("--keep-mod-list", action="store_true", help="leave the selected mod profile enabled after the run")
    parser.add_argument("--settings-mod", default=DEFAULT_SETTINGS_MOD, help="label passed through to the settings tool terminology")
    parser.add_argument("--debug-setting", default=DEFAULT_DEBUG_SETTING, help="startup setting to force to true while tests run")
    parser.add_argument("--factorio-verbose", action="store_true", help="pass --verbose to Factorio")
    parser.add_argument("--check-unused-prototype-data", action="store_true", help="pass --check-unused-prototype-data to Factorio")
    parser.add_argument("--strict-prototype-warnings", action="store_true", help="fail when Factorio prototype diagnostics are printed")
    parser.add_argument("--no-color", action="store_true", help="disable ANSI colors")
    parser.add_argument("--show-passes", action="store_true", help="print every passing assertion in the final report")
    parser.add_argument("--keep-saves", action="store_true", help="keep temporary Factorio saves under tools/test/tmp")
    args = parser.parse_args()

    tool_config = modlist.load_tool_config()
    factorio_exe = args.factorio or modlist.config_path_value(tool_config, "factorio", DEFAULT_FACTORIO)
    mod_profiles_json = args.mod_profiles_json or modlist.config_path_value(tool_config, "profiles_json", modlist.DEFAULT_PROFILES_JSON)
    mod_profiles = modlist.load_profiles(mod_profiles_json)

    if args.list_mod_profiles:
        for name in sorted(mod_profiles):
            print(f"{name}: {modlist.profile_label(name, mod_profiles)}")
        return 0

    if factorio_exe is None:
        print("FEHLER: Kein Factorio-Pfad gesetzt.")
        return 2
    if not factorio_exe.exists():
        print(f"FEHLER: Factorio nicht gefunden: {factorio_exe}")
        return 2

    selected = list(PROFILES) if args.all else [args.profile]
    mod_profile = args.mod_profile or args.compat or DEFAULT_TEST_MOD_PROFILE
    if mod_profile not in mod_profiles:
        print(f"FEHLER: Unbekanntes Mod-Profil: {mod_profile}")
        print("Verfuegbar: " + ", ".join(sorted(mod_profiles)))
        return 2
    extra_factorio_args = factorio_diagnostic_args(
        verbose=args.factorio_verbose,
        check_unused_prototype_data=args.check_unused_prototype_data,
    )
    failed = []
    reports: list[dict] = []
    original_mod_settings = None

    try:
        mod_profile_result = modlist.apply_profile(factorio_exe, mod_profile, mod_profiles_json)
        if mod_profile != DEFAULT_TEST_MOD_PROFILE:
            print(f"Mod profile: {mod_profile_result['label']}")
        print(f"Debug setting: {args.settings_mod}.{args.debug_setting}=true")
        original_mod_settings = with_debug_setting_enabled(args.debug_setting)
        for profile_name in selected:
            ok, report = run_factorio_profile(
                factorio_exe,
                profile_name,
                PROFILES[profile_name],
                extra_factorio_args=extra_factorio_args,
                strict_prototype_warnings=args.strict_prototype_warnings,
            )
            if report is not None:
                if mod_profile != DEFAULT_TEST_MOD_PROFILE:
                    report["compat"] = mod_profile
                    report["compat_label"] = compat_label(mod_profile, mod_profiles)
                reports.append(report)
            if not ok:
                failed.append(profile_name)
    finally:
        restore_mod_settings(original_mod_settings)
        if not args.keep_mod_list:
            modlist.apply_profile(factorio_exe, DEFAULT_TEST_MOD_PROFILE, mod_profiles_json)
        remove_profile()
        remove_settings_cache()
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

