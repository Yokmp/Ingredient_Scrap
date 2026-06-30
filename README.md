# Ingredient Scrap

Ingredient Scrap adds scrap byproducts to recipes based on their ingredients.
The generated scrap can be recycled back into the matching source material.

| Example recipes | Modded recipes |
| :-: | :-: |
| ![](shot_01.png)<br>![](shot_02.png) | ![](shot_03.png) |

The mod is built for Factorio 2.0 and runs its generation logic during the
data stage. It collects solid and fluid material families, generates scrap
items, recycle recipes, and unlock technologies, then patches matching recipes
with additional scrap results.

## Current behavior

- Detects solid materials from resources, known item suffixes, and explicit whitelists.
- Detects fluid material families such as `molten-*` and `liquid-*` when fluid support is enabled.
- Generates scrap items like `iron-scrap` or `testium-scrap`.
- Generates recycle recipes like `recycle-iron-scrap`.
- Generates fluid recycle recipes like `recycle-testium-scrap-to-fluid` when applicable.
- Adds scrap results to recipes based on matching solid and fluid ingredients.
- Accumulates mixed solid/fluid inputs into one scrap result per scrap type.
- Copies the source recipe `main_product` into the patch table before applying result inserts.
- Validates generated prototypes before calling `data:extend`, so invalid generated objects can be reported before Factorio rejects them.

## Settings

Startup settings are defined in `settings.lua`.

| Setting | Default | Description |
| --- | ---: | --- |
| `yis-needed` | `5` | Base amount of scrap needed by generated recycle recipes. |
| `yis-probability` | `24` | Scrap probability in percent. |
| `yis-fixed-amount` | `false` | Uses fixed `amount` instead of `amount_min`/`amount_max`. |
| `yis-amount-limit` | `true` | Keeps generated amounts smoothed instead of scaling large recipes linearly. |
| `yis-shallow-log` | `true` | Writes short generation summaries to the Factorio log. |
| `yis-fluid-recipes` | `true` | Enables fluid ingredient detection and generated fluid recycle recipes. |
| `yis-hide-tech` | `true` | Hides generated recycling technologies unless shallow logging is enabled. |
| `yis-material-*` | varies | Per-material override mode: `auto`, `solid`, `fluid`, `both`, or `none`. |

## Public API

The material registry lives in `lib/material-overrides.lua`. Vanilla, Space Age,
and optional mod support live in `compat/` modules and use the same public API
that other mods can use. Material overrides generate per-material startup
settings and decide whether a material is handled as solid, fluid, both, or
ignored.

Mods can register additional known materials during the settings stage:

```lua
require("__Ingredient_Scrap__.lib.material-overrides")

local api = yokmods.ingredient_scrap.api

api.register.material.both("rare-metal", {
  localized_setting_name = true,
  source = { name = "Example Mod", color = "#78C850" },
  tint = "#8031A7",
  prototype_aliases = {
    item = { "example-rare-metals" },
  },
  prototype_affixes = {
    item = {
      prefixes = {},
      suffixes = { "-plate", "-ingot", "-ore", "" },
    },
    fluid = {
      prefixes = { "molten-", "liquid-" },
      suffixes = { "-solution", "-slurry" },
    },
  },
})
```

The full override form is still available for unusual cases:

```lua
api.register.material.override({
  name = "rare-metal",
  default = "both",
  localized_setting_name = true,
  source = { name = "Example Mod", color = "#78C850" },
  tint = "#8031A7",
  prototype_aliases = {
    item = { "example-rare-metals" },
    fluid = { "example-rare-metal-slurry" },
  },
  prototype_affixes = {
    item = {
      prefixes = {},
      suffixes = { "-plate", "-ingot", "-ore", "" },
    },
    fluid = {
      prefixes = { "molten-", "liquid-" },
      suffixes = { "-solution", "-slurry" },
    },
  },
})
```

Modes:

| Mode | Meaning |
| --- | --- |
| `auto` | Use normal material detection. |
| `solid` | Force solid handling and ignore fluid handling. |
| `fluid` | Force fluid handling and ignore solid handling. |
| `both` | Force both solid and fluid handling. |
| `none` | Ignore the material completely. |

Convenience wrappers:

```lua
api.register.material.auto("iron", options)
api.register.material.solid("steel", options)
api.register.material.fluid("dirty-water", options)
api.register.material.both("rare-metal", options)
api.register.material.tint("rare-metal", "#8031A7")
api.register.material.alias("rare-metal", "item", "example-rare-metals")
api.ignore.material("uranium", options)
```

`prototype_affixes` describe how real prototype names are built from the material
name. For `rare-metal`, the suffix `"-plate"` checks for `rare-metal-plate`,
while the prefix `"molten-"` checks for `molten-rare-metal`. These affixes are
also aggregated into the data-stage resolver. The core affix set intentionally
stays close to vanilla and Space Age, including fluid names such as
`lithium-brine`; mod-specific affixes such as `"-ingot"` or `"liquid-"` belong
in compat registrations.

`prototype_aliases` maps exact prototype names to a material when affixes are
not enough or would be too broad. This is useful for mods with names such as
`kr-rare-metals`, where treating `kr-` or plural `s` as a global affix would
create false positives. The direct wrapper
`api.register.material.alias(material, "item"|"fluid", prototype_name)` adds one
alias at a time.

`localized_setting_name = true` tells Ingredient Scrap to use
`mod-setting-name.yis-material-<name>` from the locale files as the icon part of
the generated startup setting. Locale entries should contain only the rich-text
icon, for example `[item=iron-plate]` or `[fluid=crude-oil]`; Ingredient Scrap
adds the material name and the generic "Material mode" text. If no localized
setting name is registered, Ingredient Scrap uses `[img=none]` as a neutral
fallback so the settings list stays aligned without showing broken rich-text
icons.

`tint` sets the generated scrap icon tint for the material. It accepts a
Factorio color table or a hex color string such as `"#8031A7"`.

`source` annotates the generated material startup setting description with the
mod or DLC that registered the material. It can be a plain string or a table
such as `{ name = "Krastorio 2", color = "#78C850" }`; the color is written as
rich text so related settings stand out in Factorio's settings UI.

Startup settings are generated during Factorio's settings stage. If a mod
registers overrides only in the data stage, those overrides can affect later
data-stage logic only if that integration loads before Ingredient Scrap collects
materials; they cannot create new startup settings for the same load.

Crafting category support is also registered through the public API and is kept
separate by prototype type:

```lua
require("__Ingredient_Scrap__.lib.category-overrides")

local api = yokmods.ingredient_scrap.api

api.register.category.furnace({
  source_categories = { "smelting", "recycling" },
  add_item_recycling = true,
})

api.register.category.assembling_machine({
  source_categories = { "crafting", "crafting-with-fluid" },
  add_item_recycling = true,
  add_fluid_recycling_if_fluid_boxes = true,
})
```

## Project layout

| Path | Purpose |
| --- | --- |
| `data.lua` | Registers recipe categories, applies crafting category rules, loads debug fixtures when `IS_DEBUG` is enabled. |
| `data-updates.lua` | Initializes settings and the shared data table, then runs collection/generation/patching. |
| `data-final-fixes.lua` | Builds debug test and data-table dumps as `mod-data`. |
| `control.lua` | Writes debug reports to `script-output` when a temporary game is created. |
| `core/materials.lua` | Collects solid and fluid material families. |
| `core/collector.lua` | Scans recipes and queues scrap result inserts and generated prototypes. |
| `core/patcher.lua` | Validates and applies generated prototypes and recipe patches. |
| `compat/vanilla-materials.lua` | Registers Base and Space Age material support through the public API. |
| `compat/vanilla-categories.lua` | Registers Base, Quality, and Space Age crafting category support through the public API. |
| `compat/mod-materials.lua` | Registers optional mod material overrides through the public API. |
| `lib/material-overrides.lua` | Public material registry and material setting helpers. |
| `lib/category-overrides.lua` | Public crafting category registry and duplicate-safe category helpers. |
| `lib/generator.lua` | Builds scrap items, recycle recipes, technologies, and scrap result entries. |
| `lib/utils.lua` | Shared helpers for scrap amounts, names, icon layers, and import locations. |
| `lib/item-tints.lua` | Scrap tint definitions. Hex color codes are intentionally kept for VS Code color previews. |

## Debug and tests

The current test harness runs inside Factorio instead of parsing the Factorio log.

When `IS_DEBUG = true` in `data.lua`:

- `test/test-data.lua` creates synthetic `testium` fixtures.
- `test/material-overrides.lua` registers synthetic materials through the public material override API.
- `test/runner.lua` compares normalized expected objects against `data.raw` and `yokmods.ingredient_scrap.data_table`.
- `data-final-fixes.lua` stores the report and data-table dump as `mod-data`.
- `control.lua` writes the files into `script-output/Ingredient_Scrap`.

Generated runtime files:

| File | Description |
| --- | --- |
| `script-output/Ingredient_Scrap/test-report.json` | Machine-readable test report. |
| `script-output/Ingredient_Scrap/data-table.lua` | Lua dump of `yokmods.ingredient_scrap.data_table` for manual inspection. |

Run one profile:

```powershell
python test\run_tests.py --profile default
```

Run all standard profiles:

```powershell
python test\run_tests.py --all
```

Keep temporary saves for debugging:

```powershell
python test\run_tests.py --profile default --keep-saves
```

By default, temporary saves under `test/tmp` are removed after the run.

### Test profiles

`test/run_tests.py --all` runs:

- `default`
- `fixed_amount`
- `limit_off`
- `probability_min`
- `probability_full`
- `needed_min`
- `needed_high`
- `toggles_off`

### Active test files

| File | Purpose |
| --- | --- |
| `test/run_tests.py` | Starts Factorio, creates temporary saves, reads and prints the JSON report. |
| `test/test-data.lua` | Defines synthetic test prototypes. |
| `test/expected.lua` | Builds expected normalized objects for the current profile. |
| `test/runner.lua` | Runs data-stage assertions and returns the report. |

Older Python/log-parsing test files are no longer part of the current harness.

## VS Code / LuaLS support

The local Factorio documentation can be converted into LuaLS annotations for
autocomplete, hover text, and type navigation.

Source documentation:

```text
F:\Games\Factorio_ModTest\doc-html\prototype-api.json
F:\Games\Factorio_ModTest\doc-html\runtime-api.json
```

Generate editor annotations:

```powershell
python tools\generate_factorio_luals.py
```

Generated files:

| File | Description |
| --- | --- |
| `.vscode/factorio-types/factorio-prototype.lua` | Prototype/data-stage annotations. |
| `.vscode/factorio-types/factorio-runtime.lua` | Runtime/control-stage annotations. |
| `.luarc.json` | LuaLS configuration that adds the generated files as a workspace library. |

The raw JSON files cannot be used directly by LuaLS. The generator converts them
into `---@class`, `---@field`, `---@param`, and `---@type` comments that the Lua
language server understands.

## Development notes

- Keep generated prototype changes staged in `yokmods.ingredient_scrap.data_table` until validation has run.
- `data_table.inserts.recipes[recipe_name].main_product` should contain the source recipe main product whenever the patcher adds results to an existing recipe.
- Fluid ingredients use their fluid name as the recycle result, but a matching item such as `<scrap_type>-plate`, `<scrap_type>-ingot`, or `<scrap_type>` is used as the scrap item's visual and stack-size source.
- Do not rely on Factorio log parsing for tests; use `test-report.json`.

## Languages

- English
- Deutsch

## Contributing

Please use GitHub issues or pull requests for bug reports, ideas, and code
changes.
