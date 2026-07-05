local writer = {}
local item_prototypes = require("code.functions.item-prototypes")
local naming = require("code.functions.naming")
local scrap_amount = require("code.functions.scrap-amount")

---Returns the recipe insert staging table and creates it when needed.
---@param data_table ISdata_table
---@param recipe_name string
---@return table
function writer.recipe_insert(data_table, recipe_name)
  data_table.inserts.recipes[recipe_name] = data_table.inserts.recipes[recipe_name] or {}
  return data_table.inserts.recipes[recipe_name]
end

---Returns the debug source table when debug sources are available.
---@param data_table ISdata_table
---@return table|nil
function writer.debug_sources(data_table)
  return data_table.debug and data_table.debug.sources or nil
end

---Returns the final Factorio result name for an internal staged result name.
---Internal staging may append a debug suffix after the last underscore.
---@param name string|nil
---@return string|nil
function writer.final_result_name(name)
  if not name then return nil end
  if name:match("^yis%-mixed%-scrap_") then
    return name:match("^(.*)_[^_]*$") or name
  end
  return name
end

---Records an ingredient that contributed scrap to a source recipe.
---@param data_table ISdata_table
---@param recipe_name string
---@param mode "solid"|"fluid"
---@param ingredient table
function writer.record_ingredient(data_table, recipe_name, mode, ingredient)
  local bucket = mode == "fluid" and data_table.ingredients.fluids or data_table.ingredients.items
  bucket[recipe_name] = bucket[recipe_name] or {}
  table.insert(bucket[recipe_name], ingredient)
end

---Creates the staging tables used while collecting one source recipe.
---@param data_table ISdata_table
---@param recipe_name string
function writer.begin_recipe_collection(data_table, recipe_name)
  data_table.ingredients.items[recipe_name] = data_table.ingredients.items[recipe_name] or {}
  data_table.ingredients.fluids[recipe_name] = data_table.ingredients.fluids[recipe_name] or {}
  writer.recipe_insert(data_table, recipe_name)
end

---Records why a possible source ingredient was skipped.
---@param data_table ISdata_table
---@param recipe table
---@param ingredient table
---@param scrap_type string
---@param mode "solid"|"fluid"
---@param reason string
function writer.record_skipped_source(data_table, recipe, ingredient, scrap_type, mode, reason)
  local sources = writer.debug_sources(data_table)
  if not sources then return end
  sources.skipped = sources.skipped or {}
  table.insert(sources.skipped, {
    recipe = recipe.name,
    category = recipe.category,
    ingredient = ingredient.name,
    ingredient_type = ingredient.type or "item",
    amount = ingredient.amount,
    scrap_type = scrap_type,
    mode = mode,
    reason = reason or "source-filter",
  })
end

---Records the source details for a generated scrap result insert.
---@param data_table ISdata_table
---@param recipe_name string
---@param ingredient table
---@param scrap_type string
function writer.record_insert_source(data_table, recipe_name, ingredient, scrap_type)
  local sources = writer.debug_sources(data_table)
  if not sources then return end
  sources.inserts[recipe_name] = sources.inserts[recipe_name] or {}
  table.insert(sources.inserts[recipe_name], {
    ingredient = ingredient.name,
    ingredient_type = ingredient.type,
    amount = ingredient.amount,
    scrap_type = scrap_type,
  })
end

---Creates or accumulates a scrap result entry for a source recipe insert.
---@param data_table ISdata_table
---@param ingredient ISIngredientPrototype
---@param recipe ISRecipePrototype
---@param scrap_type string
function writer.add_scrap_result(data_table, ingredient, recipe, scrap_type)
  local scrap_name = ingredient.result_name or naming.get_scrap_name(scrap_type)
  local insert = writer.recipe_insert(data_table, recipe.name)
  local deferred_amount = ingredient.defer_amount == true
  local amount, min, max
  if not deferred_amount then
    amount, min, max = scrap_amount.range(ingredient.amount)
  end

  writer.record_insert_source(data_table, recipe.name, ingredient, scrap_type)
  insert.results = insert.results or {}

  local existing = nil
  for _, result in ipairs(insert.results) do
    if result.name == scrap_name then
      existing = result
      break
    end
  end

  if existing then
    if deferred_amount then
      existing.yis_source_amount = (existing.yis_source_amount or 0) + (ingredient.amount or 0)
    elseif ISsettings.fixed_amount then
      existing.amount = existing.amount + amount
    else
      existing.amount_min = existing.amount_min + min
      existing.amount_max = existing.amount_max + max
    end
    return
  end

  local result = {
    type        = "item",
    name        = scrap_name,
    probability = ISsettings.probability > 0 and (ISsettings.probability / 100) or nil,
  }

  if deferred_amount then
    result.yis_deferred_amount = true
    result.yis_source_amount = ingredient.amount or 0
    result.yis_source_ingredient = ingredient.name
  else
    result.amount = ISsettings.fixed_amount and amount or nil
    result.amount_min = ISsettings.fixed_amount and nil or min
    result.amount_max = ISsettings.fixed_amount and nil or max
  end

  table.insert(insert.results, result)
end

---Returns true when the product name still exists as an item-like or fluid prototype.
---@param product_name string|nil
---@return boolean
local function product_exists(product_name)
  return item_prototypes.exists(product_name) or (product_name and data.raw.fluid and data.raw.fluid[product_name] ~= nil) or false
end

---Finds, validates, stores, and returns a recipe main product, falling back to the first result.
---@param data_table ISdata_table
---@param recipe ISRecipePrototype
---@return string|nil
function writer.set_main_product(data_table, recipe)
  local insert = writer.recipe_insert(data_table, recipe.name)

  if not recipe.results or not recipe.results[1] then
    insert.main_product = nil
    return nil
  end

  local main_product = recipe.main_product or recipe.results[1].name
  insert.main_product = product_exists(main_product) and main_product or nil
  return insert.main_product
end

---Removes empty collector staging tables for a recipe.
---@param data_table ISdata_table
---@param recipe_name string
function writer.cleanup_recipe_collection(data_table, recipe_name)
  if data_table.ingredients.items[recipe_name] and not next(data_table.ingredients.items[recipe_name]) then
    data_table.ingredients.items[recipe_name] = nil
  end
  if data_table.ingredients.fluids[recipe_name] and not next(data_table.ingredients.fluids[recipe_name]) then
    data_table.ingredients.fluids[recipe_name] = nil
  end

  local insert = data_table.inserts.recipes[recipe_name]
  if insert and (not insert.main_product or not insert.results or not insert.results[1]) then
    data_table.inserts.recipes[recipe_name] = nil
  end
end

---Returns a generated item prototype by name.
---@param data_table ISdata_table
---@param item_name string
---@return table|nil
function writer.generated_item(data_table, item_name)
  return data_table.prototypes.items[item_name]
end

---Stores a generated item prototype and optional debug source.
---@param data_table ISdata_table
---@param item_name string
---@param prototype table
---@param source table|nil
function writer.set_generated_item(data_table, item_name, prototype, source)
  if source then
    local sources = writer.debug_sources(data_table)
    if sources then sources.items[item_name] = source end
  end
  data_table.prototypes.items[item_name] = prototype
end

---Removes a generated item prototype and its debug source.
---@param data_table ISdata_table
---@param item_name string
function writer.remove_generated_item(data_table, item_name)
  data_table.prototypes.items[item_name] = nil
  local sources = writer.debug_sources(data_table)
  if sources then sources.items[item_name] = nil end
end

---Returns a generated recipe prototype by name.
---@param data_table ISdata_table
---@param recipe_name string
---@return table|nil
function writer.generated_recipe(data_table, recipe_name)
  return data_table.prototypes.recipes[recipe_name]
end

---Stores a generated recipe prototype and optional debug source.
---@param data_table ISdata_table
---@param recipe_name string
---@param prototype table
---@param source table|nil
function writer.set_generated_recipe(data_table, recipe_name, prototype, source)
  if source then
    local sources = writer.debug_sources(data_table)
    if sources then sources.recipes[recipe_name] = source end
  end
  data_table.prototypes.recipes[recipe_name] = prototype
end

---Removes a generated recipe prototype and its debug source.
---@param data_table ISdata_table
---@param recipe_name string
function writer.remove_generated_recipe(data_table, recipe_name)
  data_table.prototypes.recipes[recipe_name] = nil
  local sources = writer.debug_sources(data_table)
  if sources then sources.recipes[recipe_name] = nil end
end

---Merges debug source fields into a generated recipe source entry.
---@param data_table ISdata_table
---@param recipe_name string
---@param source table
function writer.merge_recipe_source(data_table, recipe_name, source)
  local sources = writer.debug_sources(data_table)
  if not sources then return end
  sources.recipes[recipe_name] = sources.recipes[recipe_name] or {}
  for key, value in pairs(source) do
    sources.recipes[recipe_name][key] = value
  end
end

---Returns a generated technology prototype by name.
---@param data_table ISdata_table
---@param technology_name string
---@return table|nil
function writer.generated_technology(data_table, technology_name)
  return data_table.prototypes.technology[technology_name]
end

---Stores a generated technology prototype.
---@param data_table ISdata_table
---@param technology_name string
---@param prototype table
function writer.set_generated_technology(data_table, technology_name, prototype)
  data_table.prototypes.technology[technology_name] = prototype
end

---Removes a generated technology prototype.
---@param data_table ISdata_table
---@param technology_name string
function writer.remove_generated_technology(data_table, technology_name)
  data_table.prototypes.technology[technology_name] = nil
end

---Stores furnace result inventory audit information.
---@param data_table ISdata_table
---@param audit table
function writer.set_furnace_result_inventory_audit(data_table, audit)
  data_table.debug = data_table.debug or {}
  data_table.debug.furnace_result_inventory = audit
end

---Stores the active ancestry resolver report.
---@param data_table ISdata_table
---@param report table
function writer.set_active_ancestry_report(data_table, report)
  data_table.debug = data_table.debug or {}
  data_table.debug.active_ancestry = report
end

---Updates the input amount of a staged generated recipe.
---@param data_table ISdata_table
---@param recipe_name string
---@param amount number
---@return boolean
function writer.set_generated_recipe_input_amount(data_table, recipe_name, amount)
  local recipe = writer.generated_recipe(data_table, recipe_name)
  if not recipe or not recipe.ingredients or not recipe.ingredients[1] then return false end
  recipe.ingredients[1].amount = amount
  return true
end

---Adds a collected solid material if it has not been recorded yet.
---@param data_table ISdata_table
---@param material_name string
function writer.add_solid_material(data_table, material_name)
  table.insert(data_table.materials.solid, material_name)
end

---Adds a collected fluid material if it has not been recorded yet.
---@param data_table ISdata_table
---@param material_name string
function writer.add_fluid_material(data_table, material_name)
  table.insert(data_table.materials.fluid, material_name)
end

return writer
