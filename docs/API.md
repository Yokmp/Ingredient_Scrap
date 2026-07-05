# Ingredient Scrap API

Ingredient Scrap exposes its public data-stage API through:

```lua
local api = yokmods.ingredient_scrap.api
```

The API is available after Ingredient Scrap has loaded its `data.lua`. Register
material and resolver rules as early as possible, preferably from your mod's
`data.lua` or `data-updates.lua`. Late data-final-fixes patches can still use the
typed patch queue, but they cannot create new startup settings.

## Materials

Material rules tell the resolver which material families exist and how they
should be treated.

```lua
api.register.material.solid("rare-metal", {
  localized_setting_name = true,
  setting_icon = "kr-rare-metals",
  tint = "#8031A7",
  source = { mod = "Krastorio2" },
  prototype_aliases = {
    item = { "kr-rare-metals", "kr-rare-metal-plate" },
  },
})

api.register.material.fluid("dirty-water", {
  setting_icon = { type = "fluid", name = "dirty-water" },
})

api.register.material.both("example-metal")
api.ignore.material("uranium", { localized_setting_name = true })
```

Convenience functions:

| Function | Purpose |
| --- | --- |
| `api.register.material.auto(name, options)` | Let Ingredient Scrap decide solid/fluid use. |
| `api.register.material.solid(name, options)` | Force solid handling. |
| `api.register.material.fluid(name, options)` | Force fluid handling. |
| `api.register.material.both(name, options)` | Force both solid and fluid handling. |
| `api.ignore.material(name, options)` | Register the material but default it to ignored. |
| `api.register.material.tint(name, tint)` | Set the generated scrap tint. |
| `api.register.material.alias(name, type, prototype)` | Add an exact item/fluid alias. |
| `api.register.material.setting_icon(name, icon)` | Set the startup setting icon. |

Useful `options` fields:

| Field | Meaning |
| --- | --- |
| `localized_setting_name` | Generate a startup material-mode setting. |
| `setting_icon` / `setting_icons` | Explicit rich-text icon for the startup setting. |
| `prototype_aliases` | Exact item/fluid names that belong to this material. |
| `prototype_affixes` | Prefix/suffix/infix hints for resolver matching. |
| `tint` | Hex string or Factorio tint table for generated scrap icons. |
| `source` | Mod/DLC label shown in setting descriptions and debug output. |

## Source Filters

Source filters prevent specific recipes or recipe categories from producing
scrap. They are resolver registries, not FIFO patches.

```lua
api.ignore.source.recipe("example-ore-crushing", {
  reason = "Ore-processing chain; handled by mixed fallback.",
})

api.ignore.source.category("barreling", {
  ingredient_exclude_suffixes = { "-barrel" },
  reason = "Barreling recipes should not produce material scrap.",
})
```

Common fields:

| Field | Meaning |
| --- | --- |
| `reason` | Human-readable debug reason. |
| `ingredient_exclude_names` | Exact ingredient names to skip. |
| `ingredient_exclude_prefixes` | Ingredient prefixes to skip. |
| `ingredient_exclude_suffixes` | Ingredient suffixes to skip. |

## Recipe-Chain Targets

Recipe-chain targets override where generated recycle recipes should point.

```lua
api.register.recipe_chain.solid.to_item("steel", "kr-steel-beam", {
  source = "Krastorio2",
})

api.register.recipe_chain.solid.to_fluid("holmium", "holmium-solution")
api.register.recipe_chain.fluid.to_fluid("rare-metal", "rare-metal-solution")
api.ignore.recipe_chain.solid("unstable-material", "Manual compat rule")
```

Functions:

| Function | Purpose |
| --- | --- |
| `api.register.recipe_chain.solid.to_item(material, result, options)` | Solid scrap recycles to an item. |
| `api.register.recipe_chain.solid.to_fluid(material, result, options)` | Solid scrap recycles to a fluid. |
| `api.register.recipe_chain.fluid.to_item(material, result, options)` | Fluid scrap recycles to an item. |
| `api.register.recipe_chain.fluid.to_fluid(material, result, options)` | Fluid scrap recycles to a fluid. |
| `api.ignore.recipe_chain.solid(material, reason)` | Block automatic solid target staging. |
| `api.ignore.recipe_chain.fluid(material, reason)` | Block automatic fluid target staging. |

## Crafting Categories

Category rules add Ingredient Scrap recycling categories to matching machines.
Furnaces and assembling machines are intentionally registered separately.

```lua
api.register.category.furnace({
  source_categories = { "smelting", "recycling" },
  add_categories = { "yis-recycle-to-item" },
})

api.register.category.assembling_machine({
  source_categories = { "crafting", "advanced-crafting" },
  add_categories = { "yis-recycle-to-item" },
  fluid_categories = { "yis-recycle-to-fluid" },
})
```

Category rules are applied after the resolver has run. They are duplicate-safe.

## Typed Patch Queue

Use the typed queue for explicit prototype or mutation patches. Queue entries are
FIFO within each phase. Public code can register `prototype` and `mutate`
operations; finalization is internal.

```lua
api.queue.prototype.recipe("example-recycle-recipe", {
  type = "recipe",
  name = "yis-example-recycle",
  category = "yis-recycle-to-item",
  ingredients = { { type = "item", name = "yis-mixed-scrap", amount = 1 } },
  results = { { type = "item", name = "iron-plate", amount = 1 } },
}, {
  source = "ExampleMod",
})

api.queue.mutate.recipe_results("example-extra-scrap", "satellite", {
  { type = "item", name = "yis-mixed-scrap", amount = 6 },
}, {
  requires = { recipe = "satellite" },
  source = "ExampleMod",
})
```

Queue functions:

| Function | Purpose |
| --- | --- |
| `api.queue.prototype.item(label, prototype, options)` | Stage a generated item. |
| `api.queue.prototype.recipe(label, prototype, options)` | Stage a generated recipe. |
| `api.queue.prototype.technology(label, prototype, options)` | Stage a generated technology. |
| `api.queue.mutate.recipe_results(label, recipe, results, options)` | Add or replace recipe results. |
| `api.queue.mutate.machine_category(label, type, name, category, options)` | Add one crafting category to one machine. |
| `api.queue.mutate.unlock_recipe(label, technology, recipe, options)` | Add an unlock effect to a technology. |

`options.requires` or `options.requirements` can declare required prototypes. If a
required prototype does not exist, the patch is skipped and logged instead of
crashing the game.

## Generated Snapshots

After generated prototypes have been staged, compatibility mods can inspect
read-only snapshots:

```lua
local items = api.generated.items()
local recipes = api.generated.recipes()
local technologies = api.generated.technologies()
local fluids = api.generated.fluids()
```

These accessors return copies, not the internal tables. Mutating the returned
tables has no effect. Use the typed queue for changes.

## Utility Functions

Stateless helpers are exposed under `api.functions`:

| Function | Purpose |
| --- | --- |
| `api.functions.scrap_amount_range(amount)` | Return the configured scrap amount or range. |
| `api.functions.scrap_amount_rounding_variants(amount)` | Return floor/ceil calibration variants. |
| `api.functions.get_scrap_name(material)` | Return the generated scrap item name. |
| `api.functions.get_recycle_recipe_name(material)` | Return the generated recycle recipe name. |
| `api.functions.get_import_location(material)` | Return the generated Space Age import location. |
| `api.functions.get_icon_layers(material, tech, result_type, result_name)` | Build generated icon layers. |
| `api.functions.is_log(scope, level, step, message, details)` | Write an Ingredient Scrap log entry. |

Older root-level helpers such as `yokmods.ingredient_scrap.get_scrap_name` are
not public API.
