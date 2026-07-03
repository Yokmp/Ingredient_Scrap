--------------------------------
---*PATCHER*                  --
--------------------------------

local data_table_writer = require("code.core.data-table.writer")
local is_log = require("code.lib.is-log")
local naming = require("code.lib.naming")

local patcher = {}

---Returns a Factorio-safe copy of an internal staged result.
local function final_result_copy(result, final_name)
  local copy = {}
  for key, value in pairs(result) do
    if type(key) ~= "string" or not key:match("^yis_") then
      copy[key] = value
    end
  end
  copy.name = final_name
  return copy
end

---Returns the number of distinct item results in a recipe after internal names are finalized.
local function item_result_width(recipe)
  local names = {}
  local count = 0
  for _, result in ipairs((recipe and recipe.results) or {}) do
    if (result.type or "item") == "item" and result.name then
      local final_name = data_table_writer.final_result_name(result.name)
      if final_name and not names[final_name] then
        names[final_name] = true
        count = count + 1
      end
    end
  end
  return count
end

---Returns true when a recipe contains an Ingredient Scrap item result.
local function has_ingredient_scrap_item_result(recipe)
  for _, result in ipairs((recipe and recipe.results) or {}) do
    local final_name = data_table_writer.final_result_name(result.name)
    if (result.type or "item") == "item" and final_name and final_name:match("^yis%-.*%-scrap$") then
      return true
    end
  end
  return false
end

---Returns true when a machine supports the requested crafting category.
local function machine_has_category(machine, category)
  for _, crafting_category in ipairs((machine and machine.crafting_categories) or {}) do
    if crafting_category == category then return true end
  end
  return false
end

---Raises furnace output inventories so every supported recipe can fit its item results.
local function update_furnace_result_inventory_sizes(data_table)
  local max_width_by_category = {}
  local max_recipe_by_category = {}

  for recipe_name, recipe in pairs(data.raw.recipe or {}) do
    local category = recipe.category
    if category and has_ingredient_scrap_item_result(recipe) then
      local width = item_result_width(recipe)
      if width > (max_width_by_category[category] or 0) then
        max_width_by_category[category] = width
        max_recipe_by_category[category] = recipe_name
      end
    end
  end

  local changes = {}
  for furnace_name, furnace in pairs(data.raw.furnace or {}) do
    local required_width = 0
    local required_category = nil
    local required_recipe = nil
    for category, width in pairs(max_width_by_category) do
      if width > required_width and machine_has_category(furnace, category) then
        required_width = width
        required_category = category
        required_recipe = max_recipe_by_category[category]
      end
    end

    local current_width = furnace.result_inventory_size or 0
    if required_width > current_width then
      furnace.result_inventory_size = required_width
      table.insert(changes, {
        furnace = furnace_name,
        from = current_width,
        to = required_width,
        category = required_category,
        recipe = required_recipe,
      })
    end
  end

  data_table.debug = data_table.debug or {}
  data_table.debug.furnace_result_inventory = {
    max_width_by_category = max_width_by_category,
    max_recipe_by_category = max_recipe_by_category,
    changes = changes,
  }

  if #changes > 0 then
    is_log.write(
      "patcher",
      "warn",
      "furnace-result-inventory",
      "Raised furnace result inventories to fit generated scrap outputs.",
      { changes = changes }
    )
  end
end

---Appends a normalized validation error to the provided error list.
local function add_error(errors, id, name, message, details)
  table.insert(errors, {
    id = id,
    name = name,
    message = message,
    details = details,
  })
end

---Returns true when a generated prototype uses Ingredient Scrap's owned prefix.
---@param name string|nil
---@return boolean
local function has_yis_prefix(name)
  return type(name) == "string" and name:match("^yis%-") ~= nil
end

---Logs a disabled generated prototype as a warning without failing validation.
local function warn_disabled_prototype(prototype_type, name, prototype, source)
  if prototype.enabled ~= false then return end
  is_log.write(
    "patcher",
    "warn",
    "validate-generated-prototypes",
    "Generated " .. prototype_type .. " is disabled; keeping it because API or compat mods may do this intentionally.",
    { prototype_type = prototype_type, name = name, source = source }
  )
end

---Returns true when a value is a valid RGB or RGBA Factorio color table.
local function is_color(value)
  if type(value) ~= "table" then return false end
  if value.r ~= nil or value.g ~= nil or value.b ~= nil then
    return type(value.r) == "number" and type(value.g) == "number" and type(value.b) == "number"
  end
  local count = 0
  for key, component in pairs(value) do
    if type(key) ~= "number" or type(component) ~= "number" then return false end
    count = count + 1
  end
  return count == 3 or count == 4
end

---Validates generated items, recipes, and technologies before they are registered with Factorio.
---@param data_table ISdata_table
---@return table
function patcher.validate_generated_prototypes(data_table)
  local errors = {}

  for name, item in pairs(data_table.prototypes.items or {}) do
    local source = data_table.debug and data_table.debug.sources and data_table.debug.sources.items[name] or nil
    if item.type ~= "item" then
      add_error(errors, "item.type", name, "Generated item has invalid type", { type = item.type, source = source })
    end
    if item.name ~= name then
      add_error(errors, "item.name", name, "Generated item name does not match table key", { prototype_name = item.name, source = source })
    end
    if not has_yis_prefix(name) or not has_yis_prefix(item.name) then
      add_error(errors, "item.prefix", name, "Generated item must use the yis- prototype prefix", { prototype_name = item.name, source = source })
    end
    if not item.icon and not item.icons then
      add_error(errors, "item.icons", name, "Generated item has neither icon nor icons", { source = source })
    end
    if not item.stack_size or item.stack_size <= 0 then
      add_error(errors, "item.stack_size", name, "Generated item has invalid stack_size", { stack_size = item.stack_size, source = source })
    end
    for index, icon_layer in ipairs(item.icons or {}) do
      if icon_layer.tint and not is_color(icon_layer.tint) then
        add_error(errors, "item.tint", name, "Generated item icon layer has invalid tint", { icon_index = index, tint = icon_layer.tint, source = source })
      end
    end
  end

  for name, recipe in pairs(data_table.prototypes.recipes or {}) do
    local source = data_table.debug and data_table.debug.sources and data_table.debug.sources.recipes[name] or nil
    warn_disabled_prototype("recipe", name, recipe, source)
    if recipe.type ~= "recipe" then
      add_error(errors, "recipe.type", name, "Generated recipe has invalid type", { type = recipe.type, source = source })
    end
    if recipe.name ~= name then
      add_error(errors, "recipe.name", name, "Generated recipe name does not match table key", { prototype_name = recipe.name, source = source })
    end
    if not has_yis_prefix(name) or not has_yis_prefix(recipe.name) then
      add_error(errors, "recipe.prefix", name, "Generated recipe must use the yis- prototype prefix", { prototype_name = recipe.name, source = source })
    end
    if not recipe.ingredients or not recipe.ingredients[1] then
      add_error(errors, "recipe.ingredients", name, "Generated recipe has no ingredients", { source = source })
    end
    if not recipe.results or not recipe.results[1] then
      add_error(errors, "recipe.results", name, "Generated recipe has no results", { source = source })
    end
    if not recipe.category then
      add_error(errors, "recipe.category", name, "Generated recycle recipe has no category", { source = source })
    end
  end

  for name, tech in pairs(data_table.prototypes.technology or {}) do
    warn_disabled_prototype("technology", name, tech)
    if tech.type ~= "technology" then
      add_error(errors, "technology.type", name, "Generated technology has invalid type", { type = tech.type })
    end
    if tech.name ~= name then
      add_error(errors, "technology.name", name, "Generated technology name does not match table key", { prototype_name = tech.name })
    end
    if not has_yis_prefix(name) or not has_yis_prefix(tech.name) then
      add_error(errors, "technology.prefix", name, "Generated technology must use the yis- prototype prefix", { prototype_name = tech.name })
    end
    if not tech.effects or not tech.effects[1] then
      add_error(errors, "technology.effects", name, "Generated technology has no effects")
    end
    if not tech.research_trigger then
      add_error(errors, "technology.research_trigger", name, "Generated technology has no research_trigger")
    end
  end

  return errors
end

---Derives recycle recipe input amounts from the expected scrap output of all patched recipes.
---@param data_table ISdata_table
function patcher.patch_recycle_amounts(data_table)
  local totals = {}

  for _, insert in pairs(data_table.inserts.recipes) do
    if insert.results then
      for _, result in ipairs(insert.results) do
        local scrap_name = data_table_writer.final_result_name(result.name)
        totals[scrap_name] = totals[scrap_name] or { sum = 0, count = 0 }
        local expected
        if ISsettings.fixed_amount then
          expected = (result.amount or 1) * (result.probability or 1)
        else
          local mid = ((result.amount_min or 1) + (result.amount_max or 1)) / 2
          expected = mid * (result.probability or 1)
        end
        totals[scrap_name].sum = totals[scrap_name].sum + expected
        totals[scrap_name].count = totals[scrap_name].count + 1
      end
    end
  end

  for scrap_name, total in pairs(totals) do
    local avg = total.sum / total.count
    local needed = ISsettings.needed
    if avg > 0 then
      needed = math.max(math.floor(ISsettings.needed / avg), 1)
    end
    local scrap_type = scrap_name:gsub("^yis%-", ""):gsub("%-scrap$", "")
    local base_recipe_name = naming.get_recycle_recipe_name(scrap_type)
    local recipe_names = {
      base_recipe_name,
      base_recipe_name .. "-to-fluid",
    }

    for _, recipe_name in ipairs(recipe_names) do
      local recipe = data_table.prototypes.recipes[recipe_name]
      if recipe and recipe.ingredients and recipe.ingredients[1] then
        recipe.ingredients[1].amount = needed
        log("[IS-RECIPE] " .. recipe_name .. " needs " .. needed .. "x " .. scrap_name
          .. " (avg expected: " .. string.format("%.2f", avg) .. ")")
      end
    end
  end
end

---Registers generated prototypes and applies queued scrap result inserts to existing recipes.
---@param data_table ISdata_table
function patcher.patch(data_table)

  local items_to_extend = {}
  for _, item_proto in pairs(data_table.prototypes.items) do
    table.insert(items_to_extend, item_proto)
  end
  if #items_to_extend > 0 then
    data:extend(items_to_extend)
    log("Registered " .. #items_to_extend .. " scrap item(s).")
  end

  local recipes_to_extend = {}
  for _, recipe_proto in pairs(data_table.prototypes.recipes) do
    table.insert(recipes_to_extend, recipe_proto)
  end
  if #recipes_to_extend > 0 then
    data:extend(recipes_to_extend)
    log("Registered " .. #recipes_to_extend .. " recycle recipe(s).")
  end

  local technologies_to_extend = {}
  for _, tech_proto in pairs(data_table.prototypes.technology) do
    table.insert(technologies_to_extend, tech_proto)
  end
  if #technologies_to_extend > 0 then
    data:extend(technologies_to_extend)
    log("Registered " .. #technologies_to_extend .. " technologies(s).")
  end

  local inserts = 0
  for recipe_name, insert_data in pairs(data_table.inserts.recipes) do
    local recipe = data.raw.recipe[recipe_name]
    local is_recycling_recipe = recipe and
      (recipe.category == "recycling" or recipe_name:match("%-recycling$") ~= nil)
    if recipe and insert_data.results and not is_recycling_recipe then
      recipe.main_product = insert_data.main_product
      recipe.results = recipe.results or {}
      for _, result in ipairs(insert_data.results) do
        local final_name = data_table_writer.final_result_name(result.name)
        local already_exists = false
        for _, existing in ipairs(recipe.results) do
          if existing.name == final_name then
            already_exists = true
            if ISsettings.fixed_amount then
              existing.amount = (existing.amount or 0) + (result.amount or 0)
            else
              existing.amount_min = (existing.amount_min or 0) + (result.amount_min or 0)
              existing.amount_max = (existing.amount_max or 0) + (result.amount_max or 0)
            end
            break
          end
        end
        if not already_exists then
          local final_result = final_result_copy(result, final_name)
          table.insert(recipe.results, final_result)
        end
      end
      inserts = inserts + 1
    end
  end
  log("Patched " .. inserts .. " recipe(s) with scrap results.")
  update_furnace_result_inventory_sizes(data_table)
end

return patcher
