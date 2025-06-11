require("definitions")
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
    name = "yis-recycle"
  },
  {
    type = "recipe-category",
    name = "yis-recycle-to-fluid"
  },
})
for k,v in pairs(data.raw["furnace"]) do
  table.insert(v.crafting_categories, "yis-recycle")
end
for k,v in pairs(data.raw["assembling-machine"]) do
log(v.name)
  if v.name == "foundry" then
    table.insert(v.crafting_categories, "yis-recycle-to-fluid")
  end
end
-- log(serpent.block(data.raw["furnace"]["steel-furnace"], {maxlevel = 2}))
log(serpent.block(data.raw["assembling-machine"]["foundry"], {maxlevel = 2}))
