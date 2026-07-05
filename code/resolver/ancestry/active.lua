local comparison = require("code.resolver.ancestry.comparison")
local data_table_reader = require("code.data_table.reader")
local data_table_writer = require("code.data_table.writer")
local is_log = require("code.functions.is-log")
local naming = require("code.functions.naming")
local mixed = require("code.resolver.ancestry.mixed")
local prototype_builder = require("code.patcher.prototype-builder")
local item_prototypes = require("code.functions.item-prototypes")
local lookup_builder = require("code.resolver.ancestry.lookup")
local graph = require("code.resolver.ancestry.graph")
local source_overrides = require("code.override.sources")
local recipe_chain_overrides = require("code.override.recipe-chain")
local material_resolver = require("code.resolver.materials.resolver")

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

---Returns true when the material is allowed to produce solid scrap.
---@param data_table ISdata_table
---@param material string
---@return boolean
local function is_allowed_output_material(data_table, material)
  if material == mixed.material then return true end
  local materials = data_table_reader.materials(data_table)
  for _, allowed in ipairs((materials and materials.solid) or {}) do
    if allowed == material then return true end
  end
  return false
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
  local materials = data_table_reader.materials(data_table)
  local candidates = {
    material .. "-plate",
    material .. "-alloy",
    material .. "-ingot",
    material .. "-bar",
    material .. "-ore",
    material,
  }

  for alias, alias_material in pairs(materials.solid_aliases or {}) do
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
      local prototype = item_prototypes.get(candidate)
      if prototype then
        return candidate, prototype
      end
    end
  end

  return nil, nil
end

---Finds a fluid prototype that can represent a material in generated fluid recycling recipes.
---@param data_table ISdata_table
---@param material string
---@param fallback_name string|nil
---@return string|nil
local function source_fluid_for_material(data_table, material, fallback_name)
  local materials = data_table_reader.materials(data_table)
  local candidates = {}

  for alias, alias_material in pairs(materials.fluid_aliases or {}) do
    if alias_material == material then
      table.insert(candidates, alias)
    end
  end
  if fallback_name then table.insert(candidates, fallback_name) end
  for _, prefix in ipairs(materials.fluid_prefixes or {}) do
    table.insert(candidates, prefix .. material)
  end
  for _, suffix in ipairs(materials.fluid_suffixes or {}) do
    table.insert(candidates, material .. suffix)
  end

  local seen = {}
  for _, candidate in ipairs(candidates) do
    if not seen[candidate] then
      seen[candidate] = true
      if data.raw.fluid and data.raw.fluid[candidate] then
        return candidate
      end
    end
  end

  return nil
end

---Returns a valid explicit recycle target registered through the compat/API layer.
---@param material string
---@param mode "solid"|"fluid"
---@return table|nil
local function forced_recycle_target(material, mode)
  local target = recipe_chain_overrides.forced_target(mode, material)
  if not target then return nil end
  if target.active ~= true then return nil end

  local prototype = nil
  if target.result_type == "fluid" then
    prototype = data.raw.fluid and data.raw.fluid[target.result_name]
  elseif target.result_type == "item" then
    prototype = item_prototypes.get(target.result_name)
  end

  if prototype then
    return {
      result_type = target.result_type,
      result_name = target.result_name,
      prototype = prototype,
      source = target.source,
      reason = target.reason,
      active = target.active == true,
    }
  end

  is_log.write(
    "ancestry.ensure-material-prototypes",
    "warn",
    "missing-forced-recycle-target",
    "Ignored explicit recycle target because the requested prototype does not exist.",
    {
      material = material,
      mode = mode,
      result_type = target.result_type,
      result_name = target.result_name,
      source = target.source,
      reason = target.reason,
    }
  )
  return nil
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
local function ensure_material_prototypes(data_table, material, recipe, fallback_item_name, fallback_fluid_name, fluid_amount, force_hidden)
  if material == mixed.material then
    mixed.ensure_scrap_item(data_table)
    return true
  end

  local source_item_name, source_item = source_item_for_material(data_table, material, fallback_item_name)
  if not source_item_name or not source_item then return false end

  local hidden = recipe.hidden == true or source_item.hidden == true or force_hidden == true
  local solid_target = forced_recycle_target(material, "solid") or {
    result_type = "item",
    result_name = source_item_name,
    prototype = source_item,
  }
  hidden = hidden or solid_target.prototype.hidden == true
  prototype_builder.ensure_scrap_item(data_table, {
    name = source_item_name,
    scrap_type = material,
    hidden = hidden,
    stack_size = util.clamp((source_item.stack_size or 100) * ISsettings.needed, 10, 200),
  })
  prototype_builder.ensure_recycle_recipe(data_table, {
    result_type = solid_target.result_type,
    result_name = solid_target.result_name,
    scrap_type = material,
    categories = { data_table_reader.constants(data_table).recycle_categories.solid },
    hidden = hidden,
  })
  if ISsettings.fluids then
    local fluid_target = forced_recycle_target(material, "fluid")
    local source_fluid_name = fluid_target and fluid_target.result_name
      or source_fluid_for_material(data_table, material, fallback_fluid_name)
    if source_fluid_name then
      prototype_builder.ensure_recycle_recipe(data_table, {
        result_type = fluid_target and fluid_target.result_type or "fluid",
        result_name = source_fluid_name,
        scrap_type = material,
        categories = { data_table_reader.constants(data_table).recycle_categories.fluid },
        result_amount = math.max((fluid_amount or 0) / ISsettings.needed, 10),
        recipe_suffix = "-to-fluid",
        hidden = hidden or (data.raw.fluid[source_fluid_name] and data.raw.fluid[source_fluid_name].hidden == true),
      })
      prototype_builder.ensure_technology({
        data_table = data_table,
        recipe_name = recipe.name,
        scrap_type = material,
        recipe_suffix = "-to-fluid",
      })
    end
  end
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
---@param rounding_stats table|nil
---@return integer, integer
local function rewrite_recipe(data_table, recipe_name, rows, details, rounding_stats)
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
  local normalized_mixed_results = mixed.normalize_pseudo_result_amounts(insert, rounding_stats)

  return applied, skipped, mixed_rows, normalized_mixed_results
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
  local used = data_table_reader.used_scrap_names(data_table)
  local removed = 0
  for scrap_name, _ in pairs(data_table_reader.generated_items(data_table) or {}) do
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

---Returns true when a recipe has any fluid ingredient.
---@param recipe table
---@return boolean
local function has_fluid_ingredient(recipe)
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if (ingredient.type or "item") == "fluid" then return true end
  end
  return false
end

---Returns the main product name for a recipe without mutating the data table.
---@param recipe table
---@return string|nil
local function recipe_main_product(recipe)
  if not recipe.results or not recipe.results[1] then return nil end
  return recipe.main_product or recipe.results[1].name
end

---Returns true when a source recipe should be rewritten from iterative lookup evidence.
---@param recipe table
---@return boolean
local function should_process_source_recipe(recipe)
  if not recipe or graph.is_generated_recipe(recipe) or graph.looks_like_side_chain(recipe) then return false end
  if not recipe.ingredients or not recipe.ingredients[1] then return false end

  local main_product = recipe_main_product(recipe)
  if item_prototypes.get(main_product) then return true end
  return ISsettings.fluids and main_product and data.raw.fluid[main_product] ~= nil
end

---Returns the mixed fallback weight represented by unresolved lookup ingredients.
---@param entry table|nil
---@return number
local function unresolved_mixed_weight(entry)
  if not entry then return 1 end
  local total = 0
  for _, unresolved in ipairs(entry.unresolved or {}) do
    total = total + (unresolved.factor or 1)
  end
  if total <= 0 and not entry.resolved then return 1 end
  return total
end

---Returns the material composition to write for a source ingredient lookup entry.
---@param entry table|nil
---@return table<string, number>, string
local function output_materials_for_lookup_entry(entry)
  local output = {}
  local action = "lookup-direct"
  if entry then
    for material, amount in pairs(entry.scrap or {}) do
      if amount > 0 then output[material] = amount end
    end
    if not entry.resolved then
      local mixed_weight = unresolved_mixed_weight(entry)
      if mixed_weight > 0 then
        output[mixed.material] = (output[mixed.material] or 0) + mixed_weight
        action = next(entry.scrap or {}) and "lookup-partial-mixed" or "lookup-mixed"
      end
    end
  else
    output[mixed.material] = 1
    action = "lookup-missing-mixed"
  end
  return output, action
end

---Records a source-filter skip from the active lookup resolver.
---@param data_table ISdata_table
---@param recipe table
---@param ingredient table
---@param scrap_type string
local function record_lookup_skip(data_table, recipe, ingredient, scrap_type)
  data_table_writer.record_skipped_source(
    data_table,
    recipe,
    ingredient,
    scrap_type,
    "solid",
    "lookup-source-filter"
  )
end

---Rewrites one source recipe from iterative lookup evidence.
---@param data_table ISdata_table
---@param recipe table
---@param lookup_report table
---@param details table[]
---@param rounding_stats table|nil
---@return integer, integer, integer, integer
local function rewrite_recipe_from_lookup(data_table, recipe, lookup_report, details, rounding_stats)
  local insert = data_table_writer.recipe_insert(data_table, recipe.name)
  local sources = data_table_writer.debug_sources(data_table)
  insert.results = {}
  if sources then sources.inserts[recipe.name] = {} end
  data_table_writer.set_main_product(data_table, recipe)

  local applied = 0
  local skipped = 0
  local mixed_rows = 0
  local normalized_mixed_results = 0

  for _, ingredient in ipairs(recipe.ingredients or {}) do
    local ingredient_type = ingredient.type or "item"
    if ingredient_type == "item" and ingredient.name then
      local lookup_entry = lookup_report.entries and lookup_report.entries[ingredient.name]
      local output_materials, action = output_materials_for_lookup_entry(lookup_entry)
      local wrote_ingredient = false

      for _, material in ipairs(sorted_keys(output_materials)) do
        local ignored_source = source_overrides.ignored_source(recipe, ingredient, material, "solid")
        if ignored_source then
          skipped = skipped + 1
          record_lookup_skip(data_table, recipe, ingredient, material)
        elseif not is_allowed_output_material(data_table, material) then
          skipped = skipped + 1
          data_table_writer.record_skipped_source(
            data_table,
            recipe,
            ingredient,
            material,
            "solid",
            "lookup-material-not-enabled"
          )
        else
          local weight = output_materials[material] or 1
          if weight > 0 and ensure_material_prototypes(data_table, material, recipe, ingredient.name) then
            if not wrote_ingredient then
              data_table_writer.record_ingredient(data_table, recipe.name, "solid", ingredient)
              wrote_ingredient = true
            end
            applied = applied + 1
            if material == mixed.material then mixed_rows = mixed_rows + 1 end
            local source_amount = math.max((ingredient.amount or 1) * weight, 0.000001)
            if material == mixed.material then
              data_table_writer.add_scrap_result(
                data_table,
                {
                  type = "item",
                  name = ingredient.name,
                  result_name = mixed_result_name_for_ingredient(ingredient.name),
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
                  type = "item",
                  name = ingredient.name,
                  amount = source_amount,
                },
                recipe,
                material
              )
            end
            table.insert(details, {
              recipe = recipe.name,
              ingredient = ingredient.name,
              material = material,
              weight = weight,
              source_amount = source_amount,
              action = action,
              lookup_status = lookup_entry and (lookup_entry.resolved and "resolved" or "unresolved") or "missing",
              lookup_recipe = lookup_entry and lookup_entry.source_recipe or nil,
              lookup_reasons = lookup_entry and lookup_entry.reasons or nil,
            })
          end
        end
      end
    elseif ingredient_type == "fluid" and ingredient.name and ISsettings.fluids then
      local material = material_resolver.resolve_fluid(ingredient.name, data_table_reader.materials(data_table))
      if material then
        local ignored_source = source_overrides.ignored_source(recipe, ingredient, material, "fluid")
        if ignored_source then
          skipped = skipped + 1
          data_table_writer.record_skipped_source(
            data_table,
            recipe,
            ingredient,
            material,
            "fluid",
            ignored_source.reason or "lookup-source-filter"
          )
        elseif not is_allowed_output_material(data_table, material) then
          skipped = skipped + 1
          data_table_writer.record_skipped_source(
            data_table,
            recipe,
            ingredient,
            material,
            "fluid",
            "lookup-material-not-enabled"
          )
        else
          local fluid_hidden = data.raw.fluid[ingredient.name] and data.raw.fluid[ingredient.name].hidden == true
          if ensure_material_prototypes(data_table, material, recipe, nil, ingredient.name, ingredient.amount or 0, fluid_hidden) then
            data_table_writer.record_ingredient(data_table, recipe.name, "fluid", ingredient)
            applied = applied + 1
            local source_amount = math.max((ingredient.amount or 1) / 10, 0.000001)
            data_table_writer.add_scrap_result(
              data_table,
              {
                type = "fluid",
                name = ingredient.name,
                amount = source_amount,
              },
              recipe,
              material
            )
            table.insert(details, {
              recipe = recipe.name,
              ingredient = ingredient.name,
              material = material,
              weight = 1,
              source_amount = source_amount,
              action = "lookup-fluid-direct",
              lookup_status = "fluid-direct",
            })
          end
        end
      end
    end
  end

  normalized_mixed_results = mixed.normalize_pseudo_result_amounts(insert, rounding_stats)
  data_table_writer.cleanup_recipe_collection(data_table, recipe.name)
  return applied, skipped, mixed_rows, normalized_mixed_results
end

---Rewrites eligible source recipes from iterative lookup evidence.
---@param data_table ISdata_table
---@param lookup_report table
---@param details table[]
---@param rounding_stats table|nil
---@return table
local function rewrite_sources_from_lookup(data_table, lookup_report, details, rounding_stats)
  local summary = {
    rewritten_recipes = 0,
    applied_rows = 0,
    skipped_rows = 0,
    mixed_rows = 0,
    normalized_mixed_results = 0,
    skipped_fluid_recipes = 0,
  }

  for _, recipe_name in ipairs(sorted_keys(data.raw.recipe or {})) do
    local recipe = data.raw.recipe[recipe_name]
    if recipe and has_fluid_ingredient(recipe) and not graph.is_generated_recipe(recipe) and not graph.looks_like_side_chain(recipe) then
      summary.skipped_fluid_recipes = summary.skipped_fluid_recipes + 1
    end
    if should_process_source_recipe(recipe) then
      local applied, skipped, mixed_rows, normalized_mixed = rewrite_recipe_from_lookup(
        data_table,
        recipe,
        lookup_report,
        details,
        rounding_stats
      )
      if applied > 0 then
        summary.rewritten_recipes = summary.rewritten_recipes + 1
        summary.applied_rows = summary.applied_rows + applied
        summary.skipped_rows = summary.skipped_rows + skipped
        summary.mixed_rows = summary.mixed_rows + mixed_rows
        summary.normalized_mixed_results = summary.normalized_mixed_results + normalized_mixed
      end
    end
  end

  return summary
end

---Applies ancestry-effective direct material output to generated source recipe inserts.
---@param data_table ISdata_table
---@param material_flow table
---@param production_flow table
---@param policy table
---@return table
function active.apply(data_table, material_flow, production_flow, policy)
  policy = policy or {}
  local comparison_options = {}
  for key, value in pairs(policy) do comparison_options[key] = value end
  comparison_options.materials = data_table_reader.materials(data_table)
  local ancestry = comparison.build(material_flow, production_flow, comparison_options)
  if IS_DEBUG and yokmods and yokmods.ingredient_scrap then
    yokmods.ingredient_scrap.debug_pre_active_ancestry = ancestry
  end
  local lookup_options = {}
  for key, value in pairs(policy) do lookup_options[key] = value end
  lookup_options.materials = data_table_reader.materials(data_table)
  local lookup_report = lookup_builder.build(material_flow, production_flow, lookup_options)
  local details = {}
  local mixed_rounding_stats = mixed.new_rounding_stats()
  local mixed_recycle_distribution = nil

  local summary = rewrite_sources_from_lookup(data_table, lookup_report, details, mixed_rounding_stats)
  mixed_rounding_stats = mixed.finalize_rounding_stats(mixed_rounding_stats)
  local removed_orphans = summary.applied_rows > 0 and remove_orphan_generated_scrap(data_table) or 0
  local used_scrap = data_table_reader.used_scrap_names(data_table)
  if used_scrap[mixed.scrap_name()] then
    local mixed_recipe_sources = {}
    for _, detail in ipairs(details) do
      if detail.material == mixed.material then
        mixed_recipe_sources[detail.recipe] = true
      end
    end
    mixed_recycle_distribution = mixed.ensure_recycle_recipe(data_table)
    mixed.ensure_technologies(data_table, mixed_recipe_sources)
  end
  summary.removed_orphans = removed_orphans

  local report = {
    schema = "ingredient-scrap-active-ancestry/v1",
    mode = ancestry.mode,
    root_policy = ancestry.root_policy,
    mixed_limit = ancestry.mixed_limit,
    max_depth = ancestry.max_depth,
    summary = summary,
    lookup = {
      schema = lookup_report.schema,
      summary = lookup_report.summary,
      entries = lookup_report.entries,
    },
    mixed_rounding = mixed_rounding_stats,
    mixed_recycle_distribution = mixed_recycle_distribution,
    comparison_summary = ancestry.summary,
    details = details,
  }

  data_table_writer.set_active_ancestry_report(data_table, report)

  if summary.applied_rows > 0 then
    is_log.write(
      "ancestry",
      "warn",
      "apply-active",
      "Applied iterative lookup-derived scrap outputs.",
      report.summary
    )
  end

  return report
end

return active
