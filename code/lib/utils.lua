local data_table_writer = require("code.core.data-table.writer")
local icon_layers = require("code.lib.icon-layers")
local is_log = require("code.lib.is-log")
local naming = require("code.lib.naming")
local scrap_amount = require("code.lib.scrap-amount")

local utils = {}

---Creates or accumulates the scrap result entry for the specified recipe.
---@param data_table ISdata_table
---@param ingredient ISIngredientPrototype
---@param recipe ISRecipePrototype
---@param scrap_type string
function utils.add_recipe_results(data_table, ingredient, recipe, scrap_type)
  data_table_writer.add_scrap_result(data_table, ingredient, recipe, scrap_type)
end

---Finds, stores, and returns the recipe main product, falling back to the first result.
---@param data_table ISdata_table
---@param recipe ISRecipePrototype
---@return string|nil
function utils.get_main_product(data_table, recipe)
  return data_table_writer.set_main_product(data_table, recipe)
end

utils.is_log = is_log.write
utils.scrap_amount_range = scrap_amount.range
utils.get_recycle_recipe_name = naming.get_recycle_recipe_name
utils.get_scrap_name = naming.get_scrap_name
utils.get_import_location = naming.get_import_location

---Returns the icon layers used by recycle recipes for the given scrap type.
---@param scrap_type string
---@param tech_icon? boolean
---@param result_type? string
---@param result_name? string
---@return table
function utils.get_icon_layers(scrap_type, tech_icon, result_type, result_name)
  return icon_layers.get(
    yokmods.ingredient_scrap.data_table,
    scrap_type,
    tech_icon,
    result_type,
    result_name
  )
end

---Publishes public compatibility helpers on the Ingredient Scrap namespace.
function utils.publish()
  yokmods.ingredient_scrap.add_recipe_results = utils.add_recipe_results
  yokmods.ingredient_scrap.get_main_product = utils.get_main_product
  yokmods.ingredient_scrap.is_log = utils.is_log
  yokmods.ingredient_scrap.scrap_amount_range = utils.scrap_amount_range
  yokmods.ingredient_scrap.get_recycle_recipe_name = utils.get_recycle_recipe_name
  yokmods.ingredient_scrap.get_scrap_name = utils.get_scrap_name
  yokmods.ingredient_scrap.get_import_location = utils.get_import_location
  yokmods.ingredient_scrap.get_icon_layers = utils.get_icon_layers
end

utils.publish()

return utils
