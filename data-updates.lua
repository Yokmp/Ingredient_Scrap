--[[
  Data table which holds every ingredient by type.
  scrap_results are accessible by recipe name.
]]

yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
local material_overrides = require("code.lib.material-overrides")
require("code.lib.recipe-chain-overrides")
require("code.compat.vanilla-materials")
require("code.compat.mod-materials")
if IS_DEBUG then
  require("tools.test.material-overrides")
end

yokmods.ingredient_scrap.settings = yokmods.ingredient_scrap.settings or {}
yokmods.ingredient_scrap.settings.fixed_amount = settings.startup["yis-fixed-amount"].value
yokmods.ingredient_scrap.settings.probability = settings.startup["yis-probability"].value
yokmods.ingredient_scrap.settings.limit = settings.startup["yis-amount-limit"].value
yokmods.ingredient_scrap.settings.needed = settings.startup["yis-needed"].value
yokmods.ingredient_scrap.settings.fluids = settings.startup["yis-fluid-recipes"].value
yokmods.ingredient_scrap.settings.hide_tech = settings.startup["yis-hide-tech"].value
yokmods.ingredient_scrap.settings.shallow_log = settings.startup["yis-shallow-log"].value
yokmods.ingredient_scrap.settings.barreling = settings.startup["yis-barreling"].value -- recycling scrap needs a barrel for fluids
yokmods.ingredient_scrap.settings.recipe_chain_targets = settings.startup["yis-use-recipe-chain-targets"].value
yokmods.ingredient_scrap.settings.material_modes = {}
for _, material_name in ipairs(material_overrides.sorted_materials()) do
  local setting = settings.startup[material_overrides.setting_name(material_name)]
  yokmods.ingredient_scrap.settings.material_modes[material_name] = setting and setting.value or material_overrides.default_modes[material_name]
end

if IS_DEBUG then
  local ok, profile = pcall(require, "tools.test.profile")
  if ok and type(profile) == "table" then
    yokmods.ingredient_scrap.test_profile = profile.name or "custom"
    for key, value in pairs(profile.settings or {}) do
      if yokmods.ingredient_scrap.settings[key] ~= nil then
        yokmods.ingredient_scrap.settings[key] = value
      end
    end
    for material_name, default_mode in pairs(material_overrides.default_modes) do
      yokmods.ingredient_scrap.settings.material_modes[material_name] = default_mode
    end
    for material_name, mode in pairs(profile.material_modes or {}) do
      if material_overrides.default_modes[material_name] then
        yokmods.ingredient_scrap.settings.material_modes[material_name] = mode
      end
    end
    log("[IS-TEST] Loaded profile: " .. yokmods.ingredient_scrap.test_profile)
  else
    yokmods.ingredient_scrap.test_profile = "default"
  end
end

ISsettings = yokmods.ingredient_scrap.settings

---Creates the shared data table used to collect inputs, generated prototypes, inserts, and debug sources.
function yokmods.ingredient_scrap.init_data_table()
  local affixes = material_overrides.resolver_affixes()
  local aliases = material_overrides.resolver_aliases()

  return {
    constants = {
      icon_path = "__Ingredient_Scrap__/graphics/icons/",
      recycle_categories = { solid = "yis-recycle-to-item", fluid = "yis-recycle-to-fluid" },
      icon_scrap = { "scrap-64" },
      scrap_pictures = 3,
    },
    ingredients = {
      items = {},
      fluids = {},
    },
    prototypes = {
      recipes = {},
      items = {},
      technology = {},
    },
    inserts = {
      recipes = {},
    },
    materials = {
      solid_prefixes = affixes.solid_prefixes,
      solid_suffixes = affixes.solid_suffixes,
      solid_aliases = aliases.item,
      fluid_prefixes = affixes.fluid_prefixes,
      fluid_suffixes = affixes.fluid_suffixes,
      fluid_aliases = aliases.fluid,
      solid = {},
      fluid = {},
    },
    debug = {
      logs = {},
      sources = {
        items = {},
        recipes = {},
        inserts = {},
      },
    },
  }
end

yokmods.ingredient_scrap.data_table = yokmods.ingredient_scrap.init_data_table()

---Publishes read/write accessors for generated prototype staging tables.
function yokmods.ingredient_scrap.publish_generated_api()
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.generated = api.generated or {}

  api.generated.items = function()
    return yokmods.ingredient_scrap.data_table.prototypes.items
  end

  api.generated.recipes = function()
    return yokmods.ingredient_scrap.data_table.prototypes.recipes
  end

  api.generated.technologies = function()
    return yokmods.ingredient_scrap.data_table.prototypes.technology
  end
  api.generated.techs = api.generated.technologies

  api.generated.fluids = function()
    local fluids = {}
    local sources = yokmods.ingredient_scrap.data_table.debug
      and yokmods.ingredient_scrap.data_table.debug.sources
      and yokmods.ingredient_scrap.data_table.debug.sources.recipes
      or {}

    for _, source in pairs(sources) do
      if source.result_type == "fluid" and source.result_name then
        fluids[source.result_name] = data.raw.fluid[source.result_name] or true
      end
    end

    return fluids
  end
end

yokmods.ingredient_scrap.publish_generated_api()

require("code.core.materials")
require("code.lib.utils")
require("code.lib.generator")
require("code.core.collector")
require("code.core.patcher")

yokmods.ingredient_scrap.collect_materials()
yokmods.ingredient_scrap.collector()
yokmods.ingredient_scrap.patch_recycle_amounts()

if IS_DEBUG or ISsettings.recipe_chain_targets then
  local recipe_chain_analysis = require("code.core.analysis.recipe-chain")
  local recipe_chain_decider = require("code.core.analysis.recipe-chain-decider")
  yokmods.ingredient_scrap.data_table.debug.recipe_chain_analysis =
    recipe_chain_analysis.build(yokmods.ingredient_scrap.data_table)
  yokmods.ingredient_scrap.data_table.debug.recipe_chain_decisions =
    recipe_chain_decider.build(
      yokmods.ingredient_scrap.data_table.debug.recipe_chain_analysis,
      yokmods.ingredient_scrap.data_table
    )
end

---Applies high-confidence passive recipe-chain target decisions to generated recycle recipes.
---@param decisions table|nil
local function apply_recipe_chain_targets(decisions)
  if not ISsettings.recipe_chain_targets or not decisions then return end

  local staged_recipes = decisions.staged_data_table
    and decisions.staged_data_table.prototypes
    and decisions.staged_data_table.prototypes.recipes or {}
  local staged_sources = decisions.staged_data_table
    and decisions.staged_data_table.debug
    and decisions.staged_data_table.debug.sources
    and decisions.staged_data_table.debug.sources.recipes or {}

  for recipe_name, staged_source in pairs(staged_sources) do
    local decision = staged_source.recipe_chain_decision
    local recipe = yokmods.ingredient_scrap.data_table.prototypes.recipes[recipe_name]
    local staged_recipe = staged_recipes[recipe_name]
    local staged_result = staged_recipe and staged_recipe.results and staged_recipe.results[1]
    if decision and decision.active_candidate == true and recipe and staged_result then
      recipe.results = {
        {
          type = staged_result.type,
          name = staged_result.name,
          amount = staged_result.amount,
        },
      }
      if yokmods.ingredient_scrap.get_icon_layers then
        recipe.icons = yokmods.ingredient_scrap.get_icon_layers(decision.material, false, staged_result.type, staged_result.name)
      end

      local source = yokmods.ingredient_scrap.data_table.debug
        and yokmods.ingredient_scrap.data_table.debug.sources
        and yokmods.ingredient_scrap.data_table.debug.sources.recipes
        and yokmods.ingredient_scrap.data_table.debug.sources.recipes[recipe_name]
      if source then
        source.result_type = staged_result.type
        source.result_name = staged_result.name
        source.recipe_chain_decision = decision
      end

      if yokmods.ingredient_scrap.is_log then
        yokmods.ingredient_scrap.is_log(
          "recipe-chain",
          "warn",
          "apply-active-target",
          "Applied high-confidence recipe-chain recycle target.",
          {
            recipe = recipe_name,
            material = decision.material,
            result_type = staged_result.type,
            result_name = staged_result.name,
            current = decision.current,
            score = decision.suggested_score,
          }
        )
      end
    end
  end
end

apply_recipe_chain_targets(yokmods.ingredient_scrap.data_table.debug.recipe_chain_decisions)

yokmods.ingredient_scrap.preflight_errors = yokmods.ingredient_scrap.validate_generated_prototypes()
if #yokmods.ingredient_scrap.preflight_errors > 0 then
  if IS_DEBUG then
    log("[IS-TEST] Preflight failed; skipping data:extend patch so the JSON report can be written.")
  else
    error("Ingredient Scrap generated invalid prototypes: " .. serpent.line(yokmods.ingredient_scrap.preflight_errors))
  end
else
  yokmods.ingredient_scrap.patch()
end
