--[[
  Data table which holds every ingredient by type.
  scrap_results are accessible by recipe name.
]]

yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
--#region debug
local timing = require("code.lib.timing")
timing.mark("data-updates", "start")
--#endregion
local material_overrides = require("code.lib.material-overrides")
local category_overrides = require("code.lib.category-overrides")
local ancestry_settings = require("code.lib.ancestry-settings")
local startup_settings = require("code.lib.startup-settings")
local generated_api = require("code.lib.generated-api")
local data_table_init = require("code.core.data-table.init")
require("code.compat.vanilla-categories")
require("code.lib.recipe-chain-overrides")
require("code.lib.source-overrides")
require("code.compat.vanilla-materials")
require("code.compat.mod-materials")
--#region debug
if IS_DEBUG then
  require("tools.test.material-overrides")
end
timing.mark("data-updates", "load-compat")
--#endregion

category_overrides.apply_registered_rules({
  solid = "yis-recycle-to-item",
  fluid = "yis-recycle-to-fluid",
})
--#region debug
timing.mark("data-updates", "patch-crafting-categories")
--#endregion

startup_settings.load(material_overrides, ancestry_settings)

yokmods.ingredient_scrap.data_table = data_table_init.create(material_overrides)
--#region debug
yokmods.ingredient_scrap.data_table.debug.performance = yokmods.ingredient_scrap.performance
timing.mark("data-updates", "init-data-table")
--#endregion

generated_api.publish(yokmods.ingredient_scrap.data_table)

local materials_collector = require("code.core.materials")
require("code.lib.utils")
local scrap_resolver = require("code.core.scrap-resolver")
local patcher = require("code.core.patcher")
local recipe_chain_runner = require("code.core.recipe-chain-runner")
--#region debug
timing.mark("data-updates", "load-core")
--#endregion

materials_collector.collect(yokmods.ingredient_scrap.data_table)
--#region debug
timing.mark("data-updates", "collect-materials", {
  count = #yokmods.ingredient_scrap.data_table.materials.solid + #yokmods.ingredient_scrap.data_table.materials.fluid,
})
--#endregion
local baseline_report = scrap_resolver.collect_baseline(yokmods.ingredient_scrap.data_table)
--#region debug
timing.mark("data-updates", "collector", {
  count = baseline_report.inserts,
})
--#endregion

local active_ancestry_report = scrap_resolver.apply_active_ancestry(
  yokmods.ingredient_scrap.data_table,
  ISsettings.ancestry_policy
)
--#region debug
timing.mark("data-updates", "active-ancestry", {
  count = (active_ancestry_report.summary or {}).applied_rows or 0,
})
--#endregion

patcher.patch_recycle_amounts(yokmods.ingredient_scrap.data_table)
--#region debug
timing.mark("data-updates", "patch-recycle-amounts", {
  count = table_size(yokmods.ingredient_scrap.data_table.prototypes.recipes),
})
--#endregion

recipe_chain_runner.run(yokmods.ingredient_scrap.data_table, timing)

---Validates generated prototypes and applies the final data.raw patch when safe.
---@param data_table ISdata_table
local function validate_and_patch(data_table)
  yokmods.ingredient_scrap.preflight_errors = patcher.validate_generated_prototypes(data_table)
  --#region debug
  timing.mark("data-updates", "validate-generated-prototypes", {
    count = #yokmods.ingredient_scrap.preflight_errors,
  })
  --#endregion

  if #yokmods.ingredient_scrap.preflight_errors > 0 then
    if IS_DEBUG then
      log("[IS-TEST] Preflight failed; skipping data:extend patch so the JSON report can be written.")
    else
      error("Ingredient Scrap generated invalid prototypes: " .. serpent.line(yokmods.ingredient_scrap.preflight_errors))
    end
    return
  end

  patcher.patch(data_table)
  --#region debug
  timing.mark("data-updates", "patch-data-raw", {
    count = table_size(data_table.prototypes.items)
      + table_size(data_table.prototypes.recipes)
      + table_size(data_table.prototypes.technology),
  })
  --#endregion
end

validate_and_patch(yokmods.ingredient_scrap.data_table)
--#region debug
timing.mark("data-updates", "complete")
--#endregion
