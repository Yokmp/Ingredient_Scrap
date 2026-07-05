local data_table_writer = require("code.data_table.writer")
local icon_layers = require("code.functions.icon-layers")
local is_log = require("code.functions.is-log")
local naming = require("code.functions.naming")
local scrap_amount = require("code.functions.scrap-amount")

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
utils.scrap_amount_rounding_variants = scrap_amount.rounding_variants
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
  local context = yokmods and yokmods.ingredient_scrap and yokmods.ingredient_scrap.internal
  local data_table = context and context.debug_data_table and context:debug_data_table()
    or yokmods.ingredient_scrap.data_table
  return icon_layers.get(
    data_table,
    scrap_type,
    tech_icon,
    result_type,
    result_name
  )
end

---Publishes public stateless helpers under the Ingredient Scrap API namespace.
function utils.publish()
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  yokmods.ingredient_scrap.api.functions = yokmods.ingredient_scrap.api.functions or {}
  local api_functions = yokmods.ingredient_scrap.api.functions

  api_functions.is_log = utils.is_log
  api_functions.scrap_amount_range = utils.scrap_amount_range
  api_functions.scrap_amount_rounding_variants = utils.scrap_amount_rounding_variants
  api_functions.get_recycle_recipe_name = utils.get_recycle_recipe_name
  api_functions.get_scrap_name = utils.get_scrap_name
  api_functions.get_import_location = utils.get_import_location
  api_functions.get_icon_layers = utils.get_icon_layers

  yokmods.ingredient_scrap.add_recipe_results = nil
  yokmods.ingredient_scrap.get_main_product = nil
  yokmods.ingredient_scrap.is_log = nil
  yokmods.ingredient_scrap.scrap_amount_range = nil
  yokmods.ingredient_scrap.scrap_amount_rounding_variants = nil
  yokmods.ingredient_scrap.get_recycle_recipe_name = nil
  yokmods.ingredient_scrap.get_scrap_name = nil
  yokmods.ingredient_scrap.get_import_location = nil
  yokmods.ingredient_scrap.get_icon_layers = nil
end

utils.publish()

return utils
