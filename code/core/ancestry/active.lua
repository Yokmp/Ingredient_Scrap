local comparison = require("code.core.ancestry.comparison")
local data_table_writer = require("code.core.data-table.writer")
local is_log = require("code.lib.is-log")
local naming = require("code.lib.naming")
local mixed = require("code.core.ancestry.mixed")
local prototype_builder = require("code.core.prototype-builder")

local active = {}

---Returns a sorted list of map keys.
---@param values table|nil
---@return string[]
local function sorted_keys(values)
  local keys = {}
  for key, _ in pairs(values or {}) do table.insert(keys, key) end
  table.sort(keys)
  return keys
end

---Returns true when an output material map includes the mixed fallback material.
---@param values table<string, number>|nil
---@return boolean
local function has_mixed_material(values)
  return values and values[mixed.material] ~= nil
end

---Returns an internal result name with a debug suffix for one mixed source ingredient.
---@param ingredient_name string|nil
---@return string
local function mixed_result_name_for_ingredient(ingredient_name)
  return mixed.scrap_name() .. "_" .. tostring(ingredient_name or "unknown")
end

---Returns a priority score for item prototypes that can visually and mechanically represent a material.
---@param material string
---@param item_name string
---@return integer
local function target_priority(material, item_name)
  if item_name == material .. "-plate" then return 100 end
  if item_name == material .. "-alloy" then return 95 end
  if item_name == material .. "-ingot" then return 90 end
  if item_name == material .. "-bar" then return 85 end
  if item_name == material .. "-ore" then return 80 end
  if item_name == material then return 75 end
  if item_name:match("%-plate$") then return 70 end
  if item_name:match("%-alloy$") then return 65 end
  if item_name:match("%-ingot$") then return 60 end
  if item_name:match("%-bar$") then return 50 end
  if item_name:match("%-ore$") then return 40 end
  return 10
end

---Finds a solid item prototype that can represent a material in generated scrap and recycle recipes.
---@param data_table ISdata_table
---@param material string
---@param fallback_name string|nil
---@return string|nil, table|nil
local function source_item_for_material(data_table, material, fallback_name)
  local candidates = {
    material .. "-plate",
    material .. "-alloy",
    material .. "-ingot",
    material .. "-bar",
    material .. "-ore",
    material,
  }

  for alias, alias_material in pairs(data_table.materials.solid_aliases or {}) do
    if alias_material == material then
      table.insert(candidates, alias)
    end
  end

  if fallback_name then table.insert(candidates, fallback_name) end

  table.sort(candidates, function(a, b)
    local priority_a = target_priority(material, a)
    local priority_b = target_priority(material, b)
    if priority_a ~= priority_b then return priority_a > priority_b end
    return a < b
  end)

  local seen = {}
  for _, candidate in ipairs(candidates) do
    if not seen[candidate] then
      seen[candidate] = true
      if data.raw.item[candidate] then
        return candidate, data.raw.item[candidate]
      end
    end
  end

  return nil, nil
end

---Returns true when active ancestry should replace this comparison row.
---@param row table
---@return boolean
local function should_apply_row(row)
  return row.status ~= "same"
    and row.ingredient_type == "item"
    and row.effective_output
    and (row.effective_output.kind == "direct" or row.effective_output.kind == "mixed")
    and row.effective_output.materials
end

---Returns the materials that should be written for one source-flow row.
---@param row table
---@return table<string, number>, string
local function output_materials_for_row(row)
  if should_apply_row(row) then
    if has_mixed_material(row.effective_output.materials) then
      return row.effective_output.materials, "ancestry-mixed"
    end
    return row.effective_output.materials, "ancestry-direct"
  end
  return row.current or {}, "kept-current"
end

---Builds recipe-keyed comparison row buckets and marks recipes that need a rewrite.
---@param rows table[]
---@return table<string, table[]>, table<string, boolean>
local function group_rows_by_recipe(rows)
  local by_recipe = {}
  local rewrite_recipes = {}
  for _, row in ipairs(rows or {}) do
    if row.recipe then
      by_recipe[row.recipe] = by_recipe[row.recipe] or {}
      table.insert(by_recipe[row.recipe], row)
      if should_apply_row(row) then
        rewrite_recipes[row.recipe] = true
      end
    end
  end
  return by_recipe, rewrite_recipes
end

---Creates generated scrap item, recycle recipe, and technology prototypes for an output material.
---@param data_table ISdata_table
---@param material string
---@param recipe table
---@param fallback_item_name string|nil
---@return boolean
local function ensure_material_prototypes(data_table, material, recipe, fallback_item_name)
  if material == mixed.material then
    mixed.ensure_scrap_item(data_table)
    return true
  end

  local source_item_name, source_item = source_item_for_material(data_table, material, fallback_item_name)
  if not source_item_name or not source_item then return false end

  local hidden = recipe.hidden == true or source_item.hidden == true
  prototype_builder.ensure_scrap_item(data_table, {
    name = source_item_name,
    scrap_type = material,
    hidden = hidden,
    stack_size = util.clamp((source_item.stack_size or 100) * ISsettings.needed, 10, 200),
  })
  prototype_builder.ensure_recycle_recipe(data_table, {
    result_type = "item",
    result_name = source_item_name,
    scrap_type = material,
    categories = { data_table.constants.recycle_categories.solid },
    hidden = hidden,
  })
  prototype_builder.ensure_technology({
    data_table = data_table,
    recipe_name = recipe.name,
    scrap_type = material,
  })
  return true
end

---Rewrites one source recipe's scrap insert from ancestry-effective material rows.
---@param data_table ISdata_table
---@param recipe_name string
---@param rows table[]
---@param details table[]
---@return integer, integer
local function rewrite_recipe(data_table, recipe_name, rows, details)
  local recipe = data.raw.recipe[recipe_name]
  if not recipe then return 0, 0 end

  local insert = data_table_writer.recipe_insert(data_table, recipe_name)
  local sources = data_table_writer.debug_sources(data_table)
  insert.results = {}
  if sources then sources.inserts[recipe_name] = {} end

  local applied = 0
  local skipped = 0
  local mixed_rows = 0
  for _, row in ipairs(rows or {}) do
    local output_materials, action = output_materials_for_row(row)
    if action == "ancestry-direct" or action == "ancestry-mixed" then
      applied = applied + 1
      if action == "ancestry-mixed" then mixed_rows = mixed_rows + 1 end
    elseif action ~= "kept-current" then
      skipped = skipped + 1
    end

    for _, material in ipairs(sorted_keys(output_materials)) do
      local weight = output_materials[material] or 1
      if weight > 0 and ensure_material_prototypes(data_table, material, recipe, row.ingredient) then
        local source_amount = math.max((row.ingredient_amount or 1) * weight, 0.000001)
        if material == mixed.material then
          data_table_writer.add_scrap_result(
            data_table,
            {
              type = row.ingredient_type or "item",
              name = row.ingredient,
              result_name = mixed_result_name_for_ingredient(row.ingredient),
              amount = source_amount,
              defer_amount = true,
            },
            recipe,
            material
          )
        else
          data_table_writer.add_scrap_result(
            data_table,
            {
              type = row.ingredient_type or "item",
              name = row.ingredient,
              amount = source_amount,
            },
            recipe,
            material
          )
        end
        table.insert(details, {
          recipe = recipe_name,
          ingredient = row.ingredient,
          material = material,
          weight = weight,
          source_amount = source_amount,
          action = action,
        })
      end
    end
  end
  local normalized_mixed_results = mixed.normalize_pseudo_result_amounts(insert)

  return applied, skipped, mixed_rows, normalized_mixed_results
end

---Returns the generated scrap item names that are still produced by source inserts.
---@param data_table ISdata_table
---@return table<string, boolean>
local function used_scrap_names(data_table)
  local used = {}
  for _, insert in pairs(data_table.inserts.recipes or {}) do
    for _, result in ipairs((insert and insert.results) or {}) do
      if result.name then used[data_table_writer.final_result_name(result.name)] = true end
    end
  end
  return used
end

---Returns the material token from a generated scrap item name.
---@param scrap_name string
---@return string
local function scrap_type_from_name(scrap_name)
  return scrap_name:gsub("^yis%-", ""):gsub("%-scrap$", "")
end

---Removes generated scrap prototypes that no longer have any source insert.
---@param data_table ISdata_table
---@return integer
local function remove_orphan_generated_scrap(data_table)
  local used = used_scrap_names(data_table)
  local removed = 0
  for scrap_name, _ in pairs(data_table.prototypes.items or {}) do
    if scrap_name:match("^yis%-.*%-scrap$") and not used[scrap_name] then
      local scrap_type = scrap_type_from_name(scrap_name)
      local recycle_recipe_name = naming.get_recycle_recipe_name(scrap_type)
      data_table_writer.remove_generated_item(data_table, scrap_name)
      data_table_writer.remove_generated_recipe(data_table, recycle_recipe_name)
      data_table_writer.remove_generated_recipe(data_table, recycle_recipe_name .. "-to-fluid")
      data_table_writer.remove_generated_technology(data_table, recycle_recipe_name)
      removed = removed + 1
    end
  end
  return removed
end

---Applies ancestry-effective direct material output to generated source recipe inserts.
---@param data_table ISdata_table
---@param material_flow table
---@param production_flow table
---@param policy table
---@return table
function active.apply(data_table, material_flow, production_flow, policy)
  policy = policy or {}
  local ancestry = comparison.build(material_flow, production_flow, policy)
  local by_recipe, rewrite_recipes = group_rows_by_recipe(ancestry.comparisons)
  local details = {}
  local applied_rows = 0
  local skipped_rows = 0
  local mixed_rows = 0
  local normalized_mixed_results = 0
  local rewritten_recipes = 0

  for _, recipe_name in ipairs(sorted_keys(rewrite_recipes)) do
    local applied, skipped, mixed_applied, normalized_mixed = rewrite_recipe(data_table, recipe_name, by_recipe[recipe_name], details)
    if applied > 0 then
      rewritten_recipes = rewritten_recipes + 1
      applied_rows = applied_rows + applied
      skipped_rows = skipped_rows + skipped
      mixed_rows = mixed_rows + mixed_applied
      normalized_mixed_results = normalized_mixed_results + normalized_mixed
    end
  end
  local removed_orphans = applied_rows > 0 and remove_orphan_generated_scrap(data_table) or 0
  local used_scrap = used_scrap_names(data_table)
  if used_scrap[mixed.scrap_name()] then
    local mixed_recipe_sources = {}
    for _, detail in ipairs(details) do
      if detail.material == mixed.material then
        mixed_recipe_sources[detail.recipe] = true
      end
    end
    mixed.ensure_recycle_recipe(data_table, used_scrap)
    mixed.ensure_technologies(data_table, mixed_recipe_sources)
  end

  local report = {
    schema = "ingredient-scrap-active-ancestry/v1",
    mode = ancestry.mode,
    root_policy = ancestry.root_policy,
    mixed_limit = ancestry.mixed_limit,
    max_depth = ancestry.max_depth,
    summary = {
      rewritten_recipes = rewritten_recipes,
      applied_rows = applied_rows,
      skipped_rows = skipped_rows,
      mixed_rows = mixed_rows,
      normalized_mixed_results = normalized_mixed_results,
      removed_orphans = removed_orphans,
    },
    comparison_summary = ancestry.summary,
    details = details,
  }

  data_table.debug = data_table.debug or {}
  data_table.debug.active_ancestry = report

  if applied_rows > 0 then
    is_log.write(
      "ancestry",
      "warn",
      "apply-active",
      "Applied ancestry-derived direct scrap outputs.",
      report.summary
    )
  end

  return report
end

return active
