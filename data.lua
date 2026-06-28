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

---TODO add recycler from quality dlc
local recycle_item_category = "yis-recycle-to-item"
local recycle_fluid_category = "yis-recycle-to-fluid"
local assembling_recycle_source_categories = {
  ["basic-crafting"] = true,
  ["crafting"] = true,
  ["advanced-crafting"] = true,
  ["metallurgy"] = true,
  ["crafting-with-fluid-or-metallurgy"] = true,
  ["metallurgy-or-assembling"] = true,
}

---Returns true when a crafting machine already has the requested category.
local function has_category(machine, category)
  for _, crafting_category in ipairs(machine.crafting_categories or {}) do
    if crafting_category == category then return true end
  end
  return false
end

---Returns true when a crafting machine has any category in the allowed set.
local function has_any_category(machine, allowed_categories)
  for _, crafting_category in ipairs(machine.crafting_categories or {}) do
    if allowed_categories[crafting_category] then return true end
  end
  return false
end

---Adds a crafting category only when the machine does not already have it.
local function add_category_once(machine, category)
  machine.crafting_categories = machine.crafting_categories or {}
  if not has_category(machine, category) then
    table.insert(machine.crafting_categories, category)
  end
end

for _, furnace in pairs(data.raw["furnace"] or {}) do
  if has_category(furnace, "smelting") then
    add_category_once(furnace, recycle_item_category)
  end
end

for _, assembling_machine in pairs(data.raw["assembling-machine"] or {}) do
  if has_any_category(assembling_machine, assembling_recycle_source_categories) then
    add_category_once(assembling_machine, recycle_item_category)
    if assembling_machine.fluid_boxes then
      add_category_once(assembling_machine, recycle_fluid_category)
    end
  end
end



-- Debug-Flag: in data-updates.lua auf true setzen zum Testen
-- IS_DEBUG = true  (global, damit data-updates.lua es auch sieht)
IS_DEBUG = settings.startup["yis-IS_DEBUG"].value

if IS_DEBUG then
  require("test/test-data")
  log("[IS-TEST] Debug-Modus aktiv")
end
