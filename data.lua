--#region debug
require("code.lib.definitions")
--#endregion
--#region debug
local timing = require("code.lib.timing")
timing.mark("data", "start")
--#endregion
data:extend({
  {
    type = "sprite",
    name = "sigma-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/sigma-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "percent-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/percent-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "sum-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/sum-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "gears-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/gears-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "fixed-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/fixed-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "unlock-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/unlock-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "drop-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/drop-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "recipe-symbol",
    filename = "__Ingredient_Scrap__/graphics/icons/recipe-symbol.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
  {
    type = "sprite",
    name = "none",
    filename = "__Ingredient_Scrap__/graphics/icons/none.png",
    priority = "extra-high",
    width = 64,
    height = 64,
    shift = { 0, 02 }
  },
})
data:extend({
  {
    type = "recipe-category",
    name = "yis-recycle-to-item"
  },
  {
    type = "recipe-category",
    name = "yis-recycle-to-fluid"
  },
})

local recycle_item_category = "yis-recycle-to-item"
local recycle_fluid_category = "yis-recycle-to-fluid"
local category_overrides = require("code.lib.category-overrides")
require("code.compat.vanilla-categories")

category_overrides.apply_registered_rules({
  solid = recycle_item_category,
  fluid = recycle_fluid_category,
})
--#region debug
timing.mark("data", "patch-crafting-categories")
--#endregion



-- Debug-Flag: in data-updates.lua auf true setzen zum Testen
-- IS_DEBUG = true  (global, damit data-updates.lua es auch sieht)
IS_DEBUG = settings.startup["yis-IS_DEBUG"].value

--#region debug
if IS_DEBUG then
  require("tools.test.test-data")
  log("[IS-TEST] Debug-Modus aktiv")
  timing.mark("data", "load-test-data")
end
timing.mark("data", "complete")
--#endregion
