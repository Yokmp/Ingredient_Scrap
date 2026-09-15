local data_table_reader = require("code.data_table.reader")
local data_table_writer = require("code.data_table.writer")
local icon_layers = require("code.functions.icon-layers")
local is_log = require("code.functions.is-log")
local mixed = require("code.resolver.ancestry.mixed")

local fish = {}

---Returns true when the raw fish inventory item exists.
---@return boolean
local function raw_fish_exists()
  return (data.raw.item and data.raw.item["raw-fish"] ~= nil)
    or (data.raw.capsule and data.raw.capsule["raw-fish"] ~= nil)
end

---Adds a small direct recycling recipe for raw fish into mixed scrap.
---@param data_table ISdata_table
function fish.apply(data_table)
  if not raw_fish_exists() then return end

  mixed.ensure_scrap_item(data_table)
  mixed.ensure_recycle_recipe(data_table)

  local active_recipe_name = "yis-recycle-raw-fish"
  local existing_recipe = data.raw.recipe["raw-fish-recycling"]
  if existing_recipe then
    existing_recipe.categories = { "recycling" }
    existing_recipe.category = nil
    existing_recipe.enabled = false
    existing_recipe.hidden = true
    existing_recipe.hide_from_player_crafting = true
    existing_recipe.allow_as_intermediate = false
    existing_recipe.allow_intermediates = false
    existing_recipe.auto_recycle = false
  end

  if data.raw.recipe[active_recipe_name] or data_table_reader.generated_recipe(data_table, active_recipe_name) then
    return
  end

  local recipe = {
    type = "recipe",
    name = active_recipe_name,
    localised_name = {
      "recipe-name.yis-recycle-name",
      { "item-name.recycle" },
      { "item-name.raw-fish" },
    },
    icons = icon_layers.get(data_table, mixed.material, false, "item", mixed.scrap_name()),
    subgroup = "raw-material",
    categories = { "recycling" },
    order = "is-a[yis-recycle-raw-fish]",
    enabled = true,
    hidden = true,
    allow_as_intermediate = false,
    allow_intermediates = false,
    hide_from_player_crafting = true,
    ingredients = {
      { type = "item", name = "raw-fish", amount = 1 },
    },
    results = {
      { type = "item", name = mixed.scrap_name(), amount = 1 },
    },
  }
  data_table_writer.set_generated_recipe(data_table, recipe.name, recipe, {
    scrap_type = mixed.material,
    result_type = "item",
    result_name = mixed.scrap_name(),
    source = "fish-compat",
  })

  if not (data.raw.achievement and data.raw.achievement["yis-fish-arent-real"]) then
    data:extend({
      {
        type = "achievement",
        name = "yis-fish-arent-real",
        localised_name = { "achievement-name.yis-fish-arent-real" },
        localised_description = { "achievement-description.yis-fish-arent-real" },
        order = "z[ingredient-scrap]-a[fish-arent-real]",
        hidden = true,
        icon = "__Ingredient_Scrap__/graphics/fish-arent-real.png",
        icon_size = 128,
      },
    })
  end

  is_log.write(
    "compat",
    "info",
    "fish-mixed-scrap",
    "Added hidden raw fish recycling into mixed scrap.",
    { recipe = active_recipe_name, result = mixed.scrap_name() }
  )
end

return fish
