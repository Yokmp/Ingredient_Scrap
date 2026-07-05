# Ingredient Scrap Development Notes

This file describes local development assets. It is intended for the dev branch
and GitHub source, not for the Mod Portal zip.

## Local Test Harness

The Factorio harness lives under `tools/test`.

Common commands:

```powershell
python tools\test\run_tests.py --profile default --no-color
python tools\test\run_tests.py --all --no-color
python tools\test\run_tests.py --mod-profile krastorio_is --profile default --no-color
python tools\test\run_tests.py --mod-profile bob_angels_full_is --profile default --no-color
```

The harness starts Factorio with temporary saves, enables the hidden debug
setting, reads JSON reports from `script-output/Ingredient_Scrap`, and formats
the result in the terminal. It does not use Factorio log parsing as the primary
test result mechanism.

Important debug profiles include:

| Profile | Purpose |
| --- | --- |
| `default` | Normal baseline behavior. |
| `ancestry_width_1` | Stress mixed-scrap fallback width. |
| `ancestry_material_heavy` | Strict resource-root material resolution. |
| `fixed_amount` | Fixed scrap amounts. |
| `needed_min` / `needed_high` | Recycling base value bounds. |

## Debug Dumps

Debug mode can emit several reports under:

```text
script-output/Ingredient_Scrap/
```

Useful files:

| File | Purpose |
| --- | --- |
| `test-report.json` | Harness assertions and summaries. |
| `data-table.lua` | Searchable Lua dump of internal staged data. |
| `material-flow*.json` | Recipe/material flow for the HTML viewer. |
| `production-flow*.json` | Production graph dump. |
| `technology-flow*.json` | Generated technology/unlock flow. |

Large dumps are intentionally development-only and must not ship in the Mod
Portal zip.

## Toolset

General tools live under `tools/toolset`.

Useful entry points:

```powershell
python tools\toolset\ui.py
python tools\toolset\deploy.py check --verbose
python tools\toolset\deploy.py build
python tools\toolset\deploy.py publish-public --dry-run
```

The UI provides shortcuts for profile selection, dump creation, JSON viewing,
debug test runs, and deploy commands. It is a local helper and is excluded from
release artifacts.

## Deploy Artifacts

`deploy.py build` creates two zips under `_release_`:

| Artifact | Contents |
| --- | --- |
| `Ingredient_Scrap_<version>.zip` | Mod Portal zip. No Markdown, screenshots, tools, debug dumps, or dev-only files. |
| `public.zip` | Clean GitHub `main` source zip. Includes README/API/DEV docs and production source. |

`publish-public` unpacks `public.zip` into a temporary worktree, commits it to
the target branch, pushes, and removes the temporary worktree again. The current
dev worktree is not switched.

## Debug Regions

Release-only stripping uses Lua region markers:

```lua
--#region debug
-- debug-only code
--#endregion
```

The Mod Portal zip strips these regions. Keep region boundaries balanced; the
deploy check fails on unmatched starts or ends.

## Local Documentation And Definitions

LuaLS helper definitions and generated Factorio type annotations are development
assets. They may exist in the dev branch but should not be copied into the
released Mod Portal zip.

The offline Factorio docs used during development are usually available at:

```text
F:\Games\Factorio_ModTest\doc-html\prototype-api.json
F:\Games\Factorio_ModTest\doc-html\runtime-api.json
```

## Release Checklist

Before publishing:

1. Run the default profile.
2. Run all standard profiles.
3. Run targeted K2 and Bob/Angels profiles if those mods are installed.
4. Run `deploy.py check --verbose`.
5. Run `deploy.py build`.
6. Start Factorio once with the Mod Portal zip.
7. Inspect `_release_/Ingredient_Scrap_<version>.zip` for accidental dev files.
