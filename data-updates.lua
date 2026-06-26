
--[[
  Data table which holds every ingredient by type;
  scrap_results are accessible by recipe name;
  probability represents the base probability for scrap_results
  - result amounts are affected by this and a function which "smoothens out" some extreme values;

TODO
probability setting, amount or min/max setting, patcher
depending on addon/dlc:
  item and recycle_recipe generators (quality -> recycler)
  tech injection? (space-age, quality)
]]

yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}


yokmods.ingredient_scrap.settings = yokmods.ingredient_scrap.settings or {}
-- true will set an amount rather than min/max
yokmods.ingredient_scrap.settings.fixed_amount      = settings.startup["yis-fixed-amount"].value --[[@as boolean]]
-- the probability (0 - 100)
yokmods.ingredient_scrap.settings.probability       = settings.startup["yis-probability"].value  --[[@as integer]]
-- how should the scrap amount be calculated (FIX: was wrongly cast as string, is bool-setting)
yokmods.ingredient_scrap.settings.limit             = settings.startup["yis-amount-limit"].value --[[@as boolean]]
-- the scrap amount needed to recycle
yokmods.ingredient_scrap.settings.needed            = settings.startup["yis-needed"].value       --[[@as integer]]
-- enable fluid recipes
yokmods.ingredient_scrap.settings.fluids            = settings.startup["yis-fluid-recipes"].value--[[@as boolean]]
yokmods.ingredient_scrap.settings.fluids_as_barrel  = true  -- unused, combine as dropdown

yokmods.ingredient_scrap.settings.auto_recycle      = false -- unused

ISsettings = yokmods.ingredient_scrap.settings



--------------------------------
--- *INITIALIZE*              --
--------------------------------

--*Inititalizes the data_table*
-- here is where everything goes into the data_table, which is then used by the 
-- collector to register items and recipes and then the patcher to patch existing recipes with scrap results.
---@return ISdata_table
function yokmods.ingredient_scrap.init_data_table()
  return {
    constants = {
      icon_path   = "__Ingredient_Scrap__/graphics/icons/",
      recycle_categories = {solid = "yis-recycle-to-item", fluid = "yis-recycle_to_fluid"},
      icon_scrap = {"scrap"},
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
      suffixes = { "-plate", "-ore", "-ingot", "-alloy", "-sheet", "-gear-wheel", "-cable" },
      solid = {},
      fluid = {}
    },
  }
end
yokmods.ingredient_scrap.data_table = yokmods.ingredient_scrap.init_data_table()

type_blacklist = {
    uranium  = true,
    coal     = true,
    stone    = true,
    crude    = true,
    fluorine = true,
    sulfuric = true,
    bacteria = true,
    scrap    = true,
    calcite  = true,
  }

-- scrap_types = { "iron", "copper", "steel", "tungsten", "lithium" } --? TESTING -> REPLACE ME
scrap_whitelist_solid = { "steel", "brass", "bronze", "invar", "nitinol",  }
scrap_whitelist_fluid = {  }


--------------------------------
---*REQUIRES*                 --
--------------------------------

require("lib.definitions")
require("core.materials")
require("lib.utils")
require("lib.generator")
require("core.collector")
require("core.patcher")


--------------------------------
---*COLLECT GENERATE PATCH*   --
--------------------------------

yokmods.ingredient_scrap.collect_materials()
yokmods.ingredient_scrap.collector()
yokmods.ingredient_scrap.patch_recycle_amounts()

-- yokmods.ingredient_scrap.patch()

-- FIX: helpers.write_file() ist im Data-Stage nicht verfügbar -> log() für Debugging
-- Zum Debuggen auskommentieren:
-- log(serpent.block(yokmods.ingredient_scrap.data_table.prototypes.recipes, {refcomment = true, tablecomment = false}))
-- log(serpent.block(yokmods.ingredient_scrap.data_table.prototypes.technology, {refcomment = true, tablecomment = false}))
-- log(serpent.block(yokmods.ingredient_scrap.data_table.prototypes.items, {refcomment = true, tablecomment = false}))
-- log(serpent.block(yokmods.ingredient_scrap.data_table.materials, {refcomment = true, tablecomment = false}))
-- log(serpent.block(yokmods.ingredient_scrap.data_table, {refcomment = true, tablecomment = false}))
-- error("TEST END")
