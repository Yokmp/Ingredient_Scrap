local writer = require("code.data_table.writer")

local reader = {}

---Returns shared constants used by generated prototypes.
---@param data_table ISdata_table
---@return ISdata_table_constants
function reader.constants(data_table)
  return data_table.constants
end

---Returns the collected material tables.
---@param data_table ISdata_table
---@return ISdata_table_materials
function reader.materials(data_table)
  return data_table.materials
end

---Returns staged recipe inserts.
---@param data_table ISdata_table
---@return table<string, ISRecipeInsert>
function reader.recipe_inserts(data_table)
  return data_table.inserts.recipes
end

---Returns staged generated item prototypes.
---@param data_table ISdata_table
---@return ISGeneratedItems
function reader.generated_items(data_table)
  return data_table.prototypes.items
end

---Returns staged generated recipe prototypes.
---@param data_table ISdata_table
---@return ISGeneratedRecipes
function reader.generated_recipes(data_table)
  return data_table.prototypes.recipes
end

---Returns staged generated technology prototypes.
---@param data_table ISdata_table
---@return ISGeneratedTechnologies
function reader.generated_technologies(data_table)
  return data_table.prototypes.technology
end

---Returns a generated item prototype by name.
---@param data_table ISdata_table
---@param item_name string
---@return table|nil
function reader.generated_item(data_table, item_name)
  return writer.generated_item(data_table, item_name)
end

---Returns a generated recipe prototype by name.
---@param data_table ISdata_table
---@param recipe_name string
---@return table|nil
function reader.generated_recipe(data_table, recipe_name)
  return writer.generated_recipe(data_table, recipe_name)
end

---Returns a generated technology prototype by name.
---@param data_table ISdata_table
---@param technology_name string
---@return table|nil
function reader.generated_technology(data_table, technology_name)
  return writer.generated_technology(data_table, technology_name)
end

---Returns debug sources when they are available.
---@param data_table ISdata_table
---@return ISDebugSources|nil
function reader.debug_sources(data_table)
  return data_table.debug and data_table.debug.sources or nil
end

---Returns a generated prototype's debug source details.
---@param data_table ISdata_table
---@param prototype_type "items"|"recipes"
---@param name string
---@return table|nil
function reader.generated_source(data_table, prototype_type, name)
  local sources = reader.debug_sources(data_table)
  return sources and sources[prototype_type] and sources[prototype_type][name] or nil
end

---Returns the final Factorio result name for an internal staged result name.
---@param name string|nil
---@return string|nil
function reader.final_result_name(name)
  return writer.final_result_name(name)
end

---Returns the generated scrap item names that are still produced by source inserts.
---@param data_table ISdata_table
---@return table<string, boolean>
function reader.used_scrap_names(data_table)
  local used = {}
  for _, insert in pairs(reader.recipe_inserts(data_table) or {}) do
    for _, result in ipairs((insert and insert.results) or {}) do
      local final_name = reader.final_result_name(result.name)
      if final_name then used[final_name] = true end
    end
  end
  return used
end

---Returns the expected item amount represented by one result definition.
---@param result table
---@return number
function reader.result_expected_amount(result)
  local amount = result.amount
  if amount == nil and result.amount_min ~= nil and result.amount_max ~= nil then
    amount = (result.amount_min + result.amount_max) / 2
  end
  amount = amount or 1
  return amount * (result.probability or 1)
end

---Returns weighted generated scrap targets from staged source recipe inserts.
---@param data_table ISdata_table
---@param ignored_scrap_name string|nil
---@return table<string, number>
function reader.scrap_result_weights(data_table, ignored_scrap_name)
  local weights = {}
  for _, insert in pairs(reader.recipe_inserts(data_table) or {}) do
    for _, result in ipairs((insert and insert.results) or {}) do
      local scrap_name = reader.final_result_name(result.name)
      if scrap_name
          and scrap_name ~= ignored_scrap_name
          and scrap_name:match("^yis%-.*%-scrap$") then
        weights[scrap_name] = (weights[scrap_name] or 0) + reader.result_expected_amount(result)
      end
    end
  end
  return weights
end

return reader
