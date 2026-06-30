--[[
  Data table which holds every ingredient by type.
  scrap_results are accessible by recipe name.
]]

yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
local material_overrides = require("lib.material-overrides")
require("compat.vanilla-materials")
require("compat.mod-materials")
if IS_DEBUG then
  require("test.material-overrides")
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
yokmods.ingredient_scrap.settings.material_modes = {}
for _, material_name in ipairs(material_overrides.sorted_materials()) do
  local setting = settings.startup[material_overrides.setting_name(material_name)]
  yokmods.ingredient_scrap.settings.material_modes[material_name] = setting and setting.value or material_overrides.default_modes[material_name]
end

if IS_DEBUG then
  local ok, profile = pcall(require, "test.profile")
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

require("core.materials")
require("lib.utils")
require("lib.generator")
require("core.collector")
require("core.patcher")

yokmods.ingredient_scrap.collect_materials()
yokmods.ingredient_scrap.collector()
yokmods.ingredient_scrap.patch_recycle_amounts()

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
