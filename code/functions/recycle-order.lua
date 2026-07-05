local data_table_reader = require("code.data_table.reader")
local naming = require("code.functions.naming")

local recycle_order = {}

local known_rank = {
  coal = 10,
  stone = 10,
  iron = 20,
  copper = 20,
  plastic = 30,
  steel = 40,
  uranium = 45,
  calcite = 50,
  tungsten = 70,
  holmium = 80,
  lithium = 90,
}

---Returns a normalized material token for ordering.
---@param scrap_type string|nil
---@return string
local function material_token(scrap_type)
  if type(scrap_type) ~= "string" or scrap_type == "" then return "unknown" end
  return naming.without_yis_prefix(scrap_type)
end

---Returns the expected staged scrap weight for one material.
---@param data_table ISdata_table
---@param scrap_type string
---@return number
local function scrap_weight(data_table, scrap_type)
  local weights = data_table_reader.scrap_result_weights(data_table)
  return weights[naming.get_scrap_name(scrap_type)] or 0
end

---Returns a bounded inverse weight bucket so higher weights sort earlier.
---@param weight number
---@return integer
local function inverse_weight_bucket(weight)
  local bucket = math.min(math.floor((weight or 0) * 100), 999999)
  return 999999 - bucket
end

---Returns true when the recipe is the generated mixed-scrap sorter.
---@param recipe_name string|nil
---@return boolean
function recycle_order.is_mixed_recycle_recipe(recipe_name)
  return recipe_name == naming.get_recycle_recipe_name("yis-mixed")
end

---Builds a deterministic display order for generated recycle recipes.
---@param data_table ISdata_table
---@param scrap_type string
---@param recipe_name string
---@param recipe_suffix string|nil
---@return string
function recycle_order.recipe(data_table, scrap_type, recipe_name, recipe_suffix)
  if recycle_order.is_mixed_recycle_recipe(recipe_name) then
    return "is-z[" .. recipe_name .. "]"
  end

  local material = material_token(scrap_type)
  local rank = known_rank[material] or 500
  local variant = recipe_suffix == "-to-fluid" and 1 or 0
  local inverse_weight = inverse_weight_bucket(scrap_weight(data_table, scrap_type))

  return string.format("is-%03d-%06d-%d[%s]", rank, inverse_weight, variant, recipe_name)
end

---Refreshes generated recycle recipe order keys after all source inserts are final.
---@param data_table ISdata_table
function recycle_order.refresh_generated_recipes(data_table)
  for recipe_name, recipe in pairs(data_table_reader.generated_recipes(data_table) or {}) do
    local source = data_table_reader.generated_source(data_table, "recipes", recipe_name) or {}
    local scrap_type = source.scrap_type
    if scrap_type and recipe_name:match("^yis%-recycle%-") then
      local recipe_suffix = recipe_name:match("%-to%-fluid$") and "-to-fluid" or nil
      recipe.order = recycle_order.recipe(data_table, scrap_type, recipe_name, recipe_suffix)
    end
  end
end

return recycle_order
