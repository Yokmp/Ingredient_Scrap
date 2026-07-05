local data_table_writer = require("code.data_table.writer")
local item_prototypes = require("code.functions.item-prototypes")
local is_log = require("code.functions.is-log")
local mixed = require("code.resolver.ancestry.mixed")

local satellite = {}

---Returns the number of real ingredient entries in a recipe.
---@param recipe table
---@return integer
local function ingredient_count(recipe)
  local count = 0
  for _, ingredient in ipairs((recipe and recipe.ingredients) or {}) do
    if ingredient.name then count = count + 1 end
  end
  return count
end

---Builds a deterministic mixed-scrap result for the satellite recipe.
---@param amount integer
---@return table
local function mixed_result(amount)
  local result = {
    type = "item",
    name = mixed.scrap_name(),
    probability = ISsettings.probability > 0 and (ISsettings.probability / 100) or nil,
  }

  if ISsettings.fixed_amount then
    result.amount = amount
  else
    result.amount_min = amount
    result.amount_max = amount
  end

  return result
end

---Adds a base-game no-Space-Age satellite mixed-scrap source.
---@param data_table ISdata_table
function satellite.apply(data_table)
  local recipe = data.raw.recipe and data.raw.recipe["satellite"]
  if not recipe or not recipe.ingredients or not recipe.ingredients[1] then
    is_log.write(
      "compat",
      "info",
      "satellite-missing-recipe",
      "Skipped satellite mixed-scrap patch because the satellite recipe does not exist.",
      { recipe = "satellite" }
    )
    return
  end
  if not item_prototypes.exists("satellite") then
    is_log.write(
      "compat",
      "info",
      "satellite-missing-item",
      "Skipped satellite mixed-scrap patch because the satellite item does not exist.",
      { recipe = "satellite", item = "satellite" }
    )
    return
  end

  local amount = ingredient_count(recipe)
  if amount <= 0 then return end

  mixed.ensure_scrap_item(data_table)
  mixed.ensure_recycle_recipe(data_table)
  mixed.ensure_technologies(data_table, { satellite = true })

  local insert = data_table_writer.recipe_insert(data_table, recipe.name)
  insert.main_product = "satellite"
  insert.results = { mixed_result(amount) }

  local sources = data_table_writer.debug_sources(data_table)
  if sources then
    sources.inserts[recipe.name] = {
      {
        ingredient = "satellite",
        ingredient_type = "recipe",
        amount = amount,
        scrap_type = mixed.material,
        reason = "compat-satellite-no-space-age",
      },
    }
  end

  is_log.write(
    "compat",
    "info",
    "satellite-mixed-scrap",
    "Added mixed-scrap output to the no-Space-Age satellite recipe.",
    { recipe = recipe.name, amount = amount }
  )
end

return satellite
