local item_sounds = require("__base__.prototypes.item_sounds")
local data_table_reader = require("code.data_table.reader")
local data_table_writer = require("code.data_table.writer")
local icon_layers = require("code.functions.icon-layers")
local naming = require("code.functions.naming")
local prototype_builder = require("code.patcher.prototype-builder")
local scrap_amount = require("code.functions.scrap-amount")
local recycle_order = require("code.functions.recycle-order")

local mixed = {}

mixed.material = "yis-mixed"
mixed.tint = { r = 0.42, g = 0.31, b = 0.58, a = 1 }
mixed.recycle_total_probability = 0.60
mixed.recycle_top_share = 1 / 3

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
    pictures[i] = { size = 64, filename = icon_path .. "mixed-scrap-" .. i .. "-64.png", scale = 0.5, shift = { 0, 0 } }
  end
  return pictures
end

---Ensures the generated mixed scrap item prototype exists.
---@param data_table ISdata_table
function mixed.ensure_scrap_item(data_table)
  local scrap_name = mixed.scrap_name()
  if data.raw.item[scrap_name] or data_table_reader.generated_item(data_table, scrap_name) then return end

  local constants = data_table_reader.constants(data_table)
  local icon_path = constants.icon_path
  local scrap_item = {
    type = "item",
    name = scrap_name,
    localised_name = {
      "item-name.yis-scrap-name",
      { "item-name.yis-mixed" },
      { "item-name.scrap" },
    },
    localised_description = { "item-description.yis-mixed-scrap" },
    icons = {
      {
        icon = icon_path .. "mixed-scrap-64.png",
        icon_size = 64,
      },
    },
    pictures = scrap_pictures(icon_path, constants.scrap_pictures),
    subgroup = "raw-material",
    order = "is-a[" .. scrap_name .. "]",
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

---Returns weighted scrap targets from the currently staged source recipe inserts.
---@param data_table ISdata_table
---@return table[]
function mixed.weighted_targets(data_table)
  local mixed_scrap_name = mixed.scrap_name()
  local weights = data_table_reader.scrap_result_weights(data_table, mixed_scrap_name)

  local targets = {}
  for scrap_name, weight in pairs(weights) do
    if weight > 0 then
      table.insert(targets, {
        name = scrap_name,
        weight = weight,
      })
    end
  end

  table.sort(targets, function(a, b)
    if a.weight ~= b.weight then return a.weight > b.weight end
    return a.name < b.name
  end)

  return targets
end

---Returns a rank curve that keeps total output at 60% and the first result near Vanilla scrap's 20%.
---@param result_count integer
---@return number[]
local function rank_probabilities(result_count)
  if result_count <= 0 then return {} end
  if result_count <= 3 then
    local probability = mixed.recycle_total_probability / result_count
    local probabilities = {}
    for i = 1, result_count do probabilities[i] = probability end
    return probabilities
  end

  local desired_top_share = mixed.recycle_top_share
  local low = 0
  local high = 5
  for _ = 1, 64 do
    local exponent = (low + high) / 2
    local total_weight = 0
    for rank = 1, result_count do
      total_weight = total_weight + (rank ^ -exponent)
    end
    local top_share = 1 / total_weight
    if top_share < desired_top_share then
      low = exponent
    else
      high = exponent
    end
  end

  local exponent = (low + high) / 2
  local total_weight = 0
  local probabilities = {}
  for rank = 1, result_count do
    probabilities[rank] = rank ^ -exponent
    total_weight = total_weight + probabilities[rank]
  end
  for rank = 1, result_count do
    probabilities[rank] = mixed.recycle_total_probability * probabilities[rank] / total_weight
  end
  return probabilities
end

---Builds a compact summary for the weighted mixed recycle distribution.
---@param targets table[]
---@param results table[]
---@return table
local function mixed_recycle_distribution(targets, results)
  local total_probability = 0
  local min_probability = nil
  local max_probability = 0
  local top_targets = {}

  for index, result in ipairs(results or {}) do
    local probability = result.probability or 1
    total_probability = total_probability + probability
    min_probability = min_probability and math.min(min_probability, probability) or probability
    max_probability = math.max(max_probability, probability)
    if index <= 10 then
      table.insert(top_targets, {
        rank = index,
        name = result.name,
        probability = probability,
        expected_weight = targets[index] and targets[index].weight or nil,
      })
    end
  end

  return {
    target_count = #results,
    total_probability = total_probability,
    min_probability = min_probability or 0,
    max_probability = max_probability,
    top_targets = top_targets,
  }
end

---Builds the result list for mixed scrap recycling from weighted scrap families.
---@param targets table[]
---@return table[]
local function mixed_recycle_results(targets)
  local results = {}
  local mixed_scrap_name = mixed.scrap_name()
  local probabilities = rank_probabilities(#(targets or {}))

  for index, target in ipairs(targets or {}) do
    table.insert(results, {
      type = "item",
      name = target.name,
      amount = 1,
      probability = probabilities[index],
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
---@return table
function mixed.ensure_recycle_recipe(data_table)
  mixed.ensure_scrap_item(data_table)

  local recipe_name = naming.get_recycle_recipe_name(mixed.material)
  local recycle_recipe = data_table_reader.generated_recipe(data_table, recipe_name)
  local targets = mixed.weighted_targets(data_table)
  local results = mixed_recycle_results(targets)
  local distribution = mixed_recycle_distribution(targets, results)

  if recycle_recipe then
    recycle_recipe.category = "recycling"
    recycle_recipe.enabled = false
    recycle_recipe.results = results
    recycle_recipe.icons = icon_layers.get(data_table, mixed.material, false)
    recycle_recipe.always_show_products = true
    recycle_recipe.hide_from_player_crafting = true
    data_table_writer.merge_recipe_source(data_table, recipe_name, {
      scrap_type = mixed.material,
      result_type = "item",
      result_name = "mixed-scrap-pool",
      mixed_results = #results,
      distribution = distribution,
    })
    return distribution
  end

  recycle_recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = {
      "recipe-name.yis-recycle-name",
      { "item-name.recycle" },
      {
        "item-name.yis-scrap-name",
        { "item-name.yis-mixed" },
        { "item-name.scrap" },
      },
    },
    icons = icon_layers.get(data_table, mixed.material, false),
    subgroup = "raw-material",
    category = "recycling",
    order = recycle_order.recipe(data_table, mixed.material, recipe_name),
    enabled = false,
    always_show_products = true,
    allow_as_intermediate = false,
    hide_from_player_crafting = true,
    ingredients = {
      { type = "item", name = mixed.scrap_name(), amount = 1 },
    },
    results = results,
  }

  data_table_writer.set_generated_recipe(data_table, recipe_name, recycle_recipe, {
    scrap_type = mixed.material,
    result_type = "item",
    result_name = "mixed-scrap-pool",
    mixed_results = #results,
    distribution = distribution,
  })
  return distribution
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

---Creates an empty aggregate table for mixed-scrap rounding calibration.
---@return table
function mixed.new_rounding_stats()
  return {
    floor = { count = 0, total = 0, min = nil, max = 0, avg = 0 },
    ceil = { count = 0, total = 0, min = nil, max = 0, avg = 0 },
  }
end

---Adds one rounded mixed-scrap sample to one aggregate bucket.
---@param bucket table
---@param sample table
local function add_rounding_bucket_sample(bucket, sample)
  bucket.count = bucket.count + 1
  bucket.total = bucket.total + sample.avg
  bucket.min = bucket.min and math.min(bucket.min, sample.min) or sample.min
  bucket.max = math.max(bucket.max or 0, sample.max)
end

---Records floor/ceil rounding alternatives for one mixed source amount.
---@param stats table|nil
---@param source_amount number
function mixed.add_rounding_sample(stats, source_amount)
  if not stats then return end
  local variants = scrap_amount.rounding_variants(source_amount)
  add_rounding_bucket_sample(stats.floor, variants.floor)
  add_rounding_bucket_sample(stats.ceil, variants.ceil)
end

---Finalizes aggregate rounding stats for JSON and terminal reporting.
---@param stats table|nil
---@return table|nil
function mixed.finalize_rounding_stats(stats)
  if not stats then return nil end
  for _, bucket in pairs(stats) do
    bucket.min = bucket.min or 0
    bucket.avg = bucket.count > 0 and (bucket.total / bucket.count) or 0
  end
  return stats
end

---Sets final amount fields on staged mixed pseudo-results after all recipe results exist.
---@param insert table
---@param rounding_stats table|nil
---@return integer
function mixed.normalize_pseudo_result_amounts(insert, rounding_stats)
  local normalized = 0
  for _, result in ipairs((insert and insert.results) or {}) do
    if result.yis_deferred_amount == true and mixed.is_pseudo_result_name(result.name) then
      local source_amount = math.max(result.yis_source_amount or 0, 0.000001)
      mixed.add_rounding_sample(rounding_stats, source_amount)
      local amount, min, max = scrap_amount.mixed_floor_range(source_amount)
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
