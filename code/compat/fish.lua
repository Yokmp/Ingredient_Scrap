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
  if data.raw.recipe["yis-recycle-raw-fish"] or data_table_reader.generated_recipe(data_table, "yis-recycle-raw-fish") then
    return
  end

  mixed.ensure_scrap_item(data_table)
  mixed.ensure_recycle_recipe(data_table)

  local recipe = {
    type = "recipe",
    name = "yis-recycle-raw-fish",
    localised_name = {
      "recipe-name.yis-recycle-name",
      { "item-name.recycle" },
      { "item-name.raw-fish" },
    },
    icons = icon_layers.get(data_table, mixed.material, false, "item", mixed.scrap_name()),
    subgroup = "raw-material",
    category = data_table_reader.constants(data_table).recycle_categories.solid,
    order = "is-a[yis-recycle-raw-fish]",
    enabled = false,
    always_show_products = true,
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

  data_table_writer.set_generated_technology(data_table, recipe.name, {
    type = "technology",
    name = recipe.name,
    localised_name = {
      "technology-name.yis-recycling-name",
      { "item-name.recycling" },
      { "item-name.raw-fish" },
    },
    localised_description = { "technology-description.yis-recycling-description" },
    icons = icon_layers.get(data_table, mixed.material, true, "item", mixed.scrap_name()),
    enabled = true,
    hidden = ISsettings.hide_tech == true and ISsettings.shallow_log == false,
    effects = {
      { type = "unlock-recipe", recipe = recipe.name },
    },
    research_trigger = {
      type = "build-entity",
      entity = "recycler",
    },
  })

  is_log.write(
    "compat",
    "info",
    "fish-mixed-scrap",
    "Added raw fish recycling into mixed scrap.",
    { recipe = recipe.name, result = mixed.scrap_name() }
  )
end

return fish
