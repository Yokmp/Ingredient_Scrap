local item_sounds = require("__base__.prototypes.item_sounds")
local data_table_writer = require("code.core.data-table.writer")
local icon_layers = require("code.lib.icon-layers")
local naming = require("code.lib.naming")
local prototype_builder = require("code.core.prototype-builder")
local scrap_amount = require("code.lib.scrap-amount")

local mixed = {}

mixed.material = "yis-mixed"
mixed.tint = { r = 0.42, g = 0.31, b = 0.58, a = 1 }

---Returns the generated mixed scrap item name.
---@return string
function mixed.scrap_name()
  return naming.get_scrap_name(mixed.material)
end

---Returns true when the staged result name is a mixed scrap pseudo-result.
---@param result_name string|nil
---@return boolean
function mixed.is_pseudo_result_name(result_name)
  local prefix = mixed.scrap_name() .. "_"
  return type(result_name) == "string" and result_name:sub(1, #prefix) == prefix
end

---Returns a sorted list of map keys.
---@param values table|nil
---@return string[]
local function sorted_keys(values)
  local keys = {}
  for key, _ in pairs(values or {}) do table.insert(keys, key) end
  table.sort(keys)
  return keys
end

---Creates the picture variations used by the mixed scrap item.
---@param icon_path string
---@param count integer
---@return table[]
local function scrap_pictures(icon_path, count)
  local pictures = {}
  for i = 1, count, 1 do
    pictures[i] = { size = 64, filename = icon_path .. "scrap-" .. i .. "-64.png", scale = 0.5, shift = { 0, 0 } }
  end
  return pictures
end

---Ensures the generated mixed scrap item prototype exists.
---@param data_table ISdata_table
function mixed.ensure_scrap_item(data_table)
  local scrap_name = mixed.scrap_name()
  if data.raw.item[scrap_name] or data_table_writer.generated_item(data_table, scrap_name) then return end

  local icon_path = data_table.constants.icon_path
  local scrap_item = {
    type = "item",
    name = scrap_name,
    localised_name = { "", { "item-name.yis-mixed" }, " ", { "item-name.scrap" } },
    icons = {
      {
        icon = icon_path .. "scrap-64.png",
        icon_size = 64,
        tint = mixed.tint,
      },
    },
    pictures = scrap_pictures(icon_path, data_table.constants.scrap_pictures),
    subgroup = "raw-material",
    order = "is-[" .. scrap_name .. "]",
    stack_size = 100,
    inventory_move_sound = item_sounds.metal_small_inventory_move,
    pick_sound = item_sounds.metal_small_inventory_pickup,
    drop_sound = item_sounds.metal_small_inventory_move,
  }

  data_table_writer.set_generated_item(data_table, scrap_name, scrap_item, {
    scrap_type = mixed.material,
    source = "ancestry-mixed",
  })
end

---Returns a probability that keeps the expected mixed recycle output near one item.
---@param result_count integer
---@return number|nil
local function recycle_result_probability(result_count)
  if result_count <= 1 then return nil end
  return 1 / result_count
end

---Builds the result list for mixed scrap recycling from currently used scrap families.
---@param used_scrap_names table<string, boolean>
---@return table[]
local function mixed_recycle_results(used_scrap_names)
  local results = {}
  local mixed_scrap_name = mixed.scrap_name()
  local target_names = {}

  for scrap_name, _ in pairs(used_scrap_names or {}) do
    if scrap_name ~= mixed_scrap_name and scrap_name:match("^yis%-.*%-scrap$") then
      table.insert(target_names, scrap_name)
    end
  end
  table.sort(target_names)

  local probability = recycle_result_probability(#target_names)
  for _, scrap_name in ipairs(target_names) do
    table.insert(results, {
      type = "item",
      name = scrap_name,
      amount = 1,
      probability = probability,
    })
  end

  if not results[1] then
    table.insert(results, {
      type = "item",
      name = mixed_scrap_name,
      amount = 1,
      probability = 0.25,
    })
  end

  return results
end

---Ensures the generated recipe for sorting mixed scrap into known scrap families exists.
---@param data_table ISdata_table
---@param used_scrap_names table<string, boolean>
function mixed.ensure_recycle_recipe(data_table, used_scrap_names)
  mixed.ensure_scrap_item(data_table)

  local recipe_name = naming.get_recycle_recipe_name(mixed.material)
  local recycle_recipe = data_table_writer.generated_recipe(data_table, recipe_name)
  local results = mixed_recycle_results(used_scrap_names)

  if recycle_recipe then
    recycle_recipe.results = results
    recycle_recipe.icons = icon_layers.get(data_table, mixed.material, false)
    data_table_writer.merge_recipe_source(data_table, recipe_name, {
      scrap_type = mixed.material,
      result_type = "item",
      result_name = "mixed-scrap-pool",
      mixed_results = #results,
    })
    return
  end

  recycle_recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = { "", { "item-name.recycle" }, " ", { "item-name.yis-mixed" }, " ", { "item-name.scrap" } },
    icons = icon_layers.get(data_table, mixed.material, false),
    subgroup = "raw-material",
    category = data_table.constants.recycle_categories.solid,
    order = "is-[" .. recipe_name .. "]",
    always_show_products = true,
    allow_as_intermediate = false,
    hide_from_player_crafting = false,
    ingredients = {
      { type = "item", name = mixed.scrap_name(), amount = 0 },
    },
    results = results,
  }

  data_table_writer.set_generated_recipe(data_table, recipe_name, recycle_recipe, {
    scrap_type = mixed.material,
    result_type = "item",
    result_name = "mixed-scrap-pool",
    mixed_results = #results,
  })
end

---Creates technology unlocks for the mixed recycling recipe from all contributing source recipes.
---@param data_table ISdata_table
---@param recipe_names table<string, boolean>
function mixed.ensure_technologies(data_table, recipe_names)
  for _, recipe_name in ipairs(sorted_keys(recipe_names)) do
    prototype_builder.ensure_technology({
      data_table = data_table,
      recipe_name = recipe_name,
      scrap_type = mixed.material,
    })
  end
end

---Sets final amount fields on staged mixed pseudo-results after all recipe results exist.
---@param insert table
---@return integer
function mixed.normalize_pseudo_result_amounts(insert)
  local normalized = 0
  for _, result in ipairs((insert and insert.results) or {}) do
    if result.yis_deferred_amount == true and mixed.is_pseudo_result_name(result.name) then
      local source_amount = math.max(result.yis_source_amount or 0, 0.000001)
      local amount, min, max = scrap_amount.range(source_amount)
      result.amount = ISsettings.fixed_amount and amount or nil
      result.amount_min = ISsettings.fixed_amount and nil or min
      result.amount_max = ISsettings.fixed_amount and nil or max
      result.yis_deferred_amount = nil
      result.yis_normalized_after_results = true
      normalized = normalized + 1
    end
  end
  return normalized
end

return mixed
