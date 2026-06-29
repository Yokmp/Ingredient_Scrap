require("lib.definitions")
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
local category_overrides = require("lib.category-overrides")
require("compat.vanilla-categories")

---Applies registered category rules to one prototype type.
local function apply_category_rules(prototype_type, rules)
  for _, machine in pairs(data.raw[prototype_type] or {}) do
    for _, rule in ipairs(rules or {}) do
      if category_overrides.has_category(machine, rule.source_categories) then
        if rule.add_item_recycling then
          category_overrides.add_category_once(machine, recycle_item_category)
        end
        if rule.add_fluid_recycling_if_fluid_boxes and machine.fluid_boxes then
          category_overrides.add_category_once(machine, recycle_fluid_category)
        end
      end
    end
  end
end

apply_category_rules("furnace", category_overrides.rules.furnace)
apply_category_rules("assembling-machine", category_overrides.rules.assembling_machine)



-- Debug-Flag: in data-updates.lua auf true setzen zum Testen
-- IS_DEBUG = true  (global, damit data-updates.lua es auch sieht)
IS_DEBUG = settings.startup["yis-IS_DEBUG"].value

if IS_DEBUG then
  require("test/test-data")
  log("[IS-TEST] Debug-Modus aktiv")
end
