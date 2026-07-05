--#region debug
require("code.functions.definitions")
--#endregion
--#region debug
local timing = require("code.functions.timing")
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

local public_api = require("code.api.public")
local api_modules = public_api.load()
local material_overrides = api_modules.materials
local ancestry_settings = require("code.functions.ancestry-settings")
local startup_settings = require("code.functions.startup-settings")

require("code.compat.vanilla-categories")
require("code.compat.vanilla-materials")
require("code.compat.mod-materials")
require("code.compat.recycler.ensure").recycler()
require("code.compat.recycler.tips-and-tricks")

IS_DEBUG = settings.startup["yis-IS_DEBUG"].value
--#region debug
if IS_DEBUG then
  require("tools.test.material-overrides")
end
--#endregion
startup_settings.load(material_overrides, ancestry_settings)

local internal_api = require("code.api.internal")
local context = internal_api.create(material_overrides)
yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
yokmods.ingredient_scrap.internal = context
public_api.publish_generated(context)
public_api.publish_queue(context)
require("code.functions.utils")

--#region debug
yokmods.ingredient_scrap.data_table = context:debug_data_table()
yokmods.ingredient_scrap.data_table.debug.performance = yokmods.ingredient_scrap.performance
timing.mark("data", "init-api-context")
if IS_DEBUG then
  require("tools.test.test-data")
  log("[IS-TEST] Debug-Modus aktiv")
  timing.mark("data", "load-test-data")
end
timing.mark("data", "complete")
--#endregion
