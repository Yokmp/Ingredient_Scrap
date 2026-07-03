local graph = require("code.core.ancestry.graph")
local roots = require("code.core.ancestry.roots")
local composition_resolver = require("code.core.ancestry.resolver")
local material_resolver = require("code.core.materials.resolver")

local recipe_forms = {}

local MATERIAL_SOURCE_CLASSES = {
  resource_output = true,
  named_material_product = true,
  first_material_product = true,
  possible_alloy = true,
}

local CLASS_PRIORITY = {
  resource_output = 100,
  first_material_product = 90,
  named_material_product = 85,
  possible_alloy = 80,
  multi_material_product = 60,
  component_candidate = 50,
  placeable_product = 40,
  unresolved = 0,
}

local ALLOY_TERMS = {
  "alloy",
  "solder",
  "brass",
  "bronze",
  "invar",
  "nitinol",
  "gunmetal",
  "cobalt-steel",
  "copper-tungsten",
}

---Returns a sorted copy of map keys.
---@param values table|nil
---@return string[]
local function sorted_keys(values)
  local keys = {}
  for key, _ in pairs(values or {}) do table.insert(keys, key) end
  table.sort(keys)
  return keys
end

---Counts map keys.
---@param values table|nil
---@return integer
local function map_size(values)
  local count = 0
  for _, _ in pairs(values or {}) do count = count + 1 end
  return count
end

---Returns true when a string contains one of the listed plain terms.
---@param value string|nil
---@param terms string[]
---@return boolean
local function contains_any(value, terms)
  if type(value) ~= "string" then return false end
  local lowered = string.lower(value)
  for _, term in ipairs(terms) do
    if lowered:find(term, 1, true) then return true end
  end
  return false
end

---Returns true when recipe metadata names a likely alloy material process.
---@param recipe table
---@param result table
---@return boolean
local function looks_like_alloy_process(recipe, result)
  return contains_any(recipe.category, ALLOY_TERMS)
    or contains_any(recipe.name, ALLOY_TERMS)
    or contains_any(result.name, ALLOY_TERMS)
end

---Builds a typed production-node lookup table.
---@param production_flow table|nil
---@return table<string, table>
local function build_node_lookup(production_flow)
  local nodes = {}
  for _, node in ipairs((production_flow and production_flow.prototypes and production_flow.prototypes.nodes) or {}) do
    if node.key then nodes[node.key] = node end
  end
  return nodes
end

---Returns true when a prototype node places an entity, tile, or equipment.
---@param node table|nil
---@return boolean
local function is_placeable_node(node)
  return node ~= nil and (node.place_result ~= nil or node.place_as_tile ~= nil or node.place_as_equipment_result ~= nil)
end

---Resolves a result name to a configured material by affix or alias.
---@param result table
---@param materials table|nil
---@return string|nil
local function result_material(result, materials)
  if not (result and result.name and materials) then return nil end
  return material_resolver.resolve_solid(result.name, materials, false)
end

---Returns true when the material is configured as an exact component scrap family.
---@param material string|nil
---@param materials table|nil
---@return boolean
local function is_exact_component_material(material, materials)
  return material ~= nil
    and materials ~= nil
    and materials.solid_exact_scrap ~= nil
    and materials.solid_exact_scrap[material] == true
end

---Adds all material keys from source into target.
---@param target table<string, number>
---@param source table<string, number>|nil
local function merge_materials(target, source)
  for material, amount in pairs(source or {}) do
    target[material] = (target[material] or 0) + (amount or 1)
  end
end

---Adds a resource output unless a stronger material-flow root already exists.
---@param outputs table<string, table>
---@param result_name string
---@param material string
---@param resource_name string
---@param category string|nil
---@param source string
local function add_resource_output(outputs, result_name, material, resource_name, category, source)
  outputs[result_name] = outputs[result_name] or {
    type = "item",
    name = result_name,
    material = material,
    resource = resource_name,
    resource_category = category,
    source = source,
  }
end

---Adds item outputs from raw resource prototypes.
---@param outputs table<string, table>
---@param data_table table|nil
local function add_raw_resource_outputs(outputs, data_table)
  local materials = data_table and data_table.materials or {}
  for resource_name, resource in pairs(data.raw.resource or {}) do
    local minable = resource.minable
    if minable then
      if minable.result then
        local result_name = minable.result
        local material = material_resolver.resolve_solid(result_name, materials, true) or result_name
        add_resource_output(outputs, result_name, material, resource_name, resource.category, "data.raw.resource")
      end
      for _, result in ipairs(minable.results or {}) do
        if (result.type or "item") == "item" and result.name then
          local material = material_resolver.resolve_solid(result.name, materials, true) or result.name
          add_resource_output(outputs, result.name, material, resource_name, resource.category, "data.raw.resource")
        end
      end
    end
  end
end

---Builds direct item resource outputs from material-flow and raw resource evidence.
---@param material_flow table
---@param data_table table|nil
---@return table<string, table>
local function build_resource_outputs(material_flow, data_table)
  local outputs = {}
  for material, resources in pairs((material_flow and material_flow.resources_by_material) or {}) do
    for _, resource in ipairs(resources or {}) do
      local result = resource.result or {}
      if (result.type or "item") == "item" and result.name then
        add_resource_output(outputs, result.name, material, resource.resource, resource.category, "material-flow")
      end
    end
  end
  add_raw_resource_outputs(outputs, data_table)
  return outputs
end

---Returns true when a recipe is usable for passive recipe-form classification.
---@param recipe table|nil
---@return boolean
local function is_usable_recipe(recipe)
  return recipe ~= nil
    and not graph.is_generated_recipe(recipe)
    and not graph.looks_like_side_chain(recipe)
end

---Returns item results from a normalized production recipe.
---@param recipe table
---@return table[]
local function item_results(recipe)
  local results = {}
  for _, result in ipairs(recipe.results or {}) do
    if (result.type or "item") == "item" and result.name then
      table.insert(results, result)
    end
  end
  return results
end

---Returns item ingredients from a normalized production recipe.
---@param recipe table
---@return table[]
local function item_ingredients(recipe)
  local ingredients = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if (ingredient.type or "item") == "item" and ingredient.name then
      table.insert(ingredients, ingredient)
    end
  end
  return ingredients
end

---Returns true when a recipe has any non-item ingredient.
---@param recipe table
---@return boolean
local function has_non_item_ingredient(recipe)
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if (ingredient.type or "item") ~= "item" then return true end
  end
  return false
end

---Returns a compact ingredient classification using already-known item classes.
---@param ingredient table
---@param item_classes table<string, table>
---@return table
local function classify_ingredient(ingredient, item_classes)
  local known = item_classes[ingredient.name]
  if not known then
    return {
      type = ingredient.type or "item",
      name = ingredient.name,
      amount = graph.amount_of(ingredient),
      class = "unknown",
      materials = {},
    }
  end
  return {
    type = ingredient.type or "item",
    name = ingredient.name,
    amount = graph.amount_of(ingredient),
    class = known.class,
    material = known.material,
    materials = composition_resolver.rounded_composition(known.materials or {}),
  }
end

---Builds a candidate item classification for one recipe result.
---@param recipe table
---@param result table
---@param item_classes table<string, table>
---@param node_classes table<string, table>|nil
---@param nodes table<string, table>|nil
---@param materials table|nil
---@return table
local function classify_result(recipe, result, item_classes, node_classes, nodes, materials)
  local ingredients = {}
  local material_sources = {}
  local source_materials = {}
  local source_class_counts = {}
  local has_alloy_source = false
  local has_unknown_item = false
  local item_ingredient_count = 0

  for _, ingredient in ipairs(item_ingredients(recipe)) do
    item_ingredient_count = item_ingredient_count + 1
    local classified = classify_ingredient(ingredient, item_classes)
    table.insert(ingredients, classified)
    source_class_counts[classified.class] = (source_class_counts[classified.class] or 0) + 1

    if classified.class == "unknown" then
      has_unknown_item = true
    end
    if classified.class == "possible_alloy" then
      has_alloy_source = true
    end
    if MATERIAL_SOURCE_CLASSES[classified.class] then
      table.insert(material_sources, classified)
      merge_materials(source_materials, classified.materials)
    end
  end

  local distinct_materials = map_size(source_materials)
  local node_classification = node_classes and node_classes["item/" .. result.name]
  local node_class = node_classification and node_classification.class
  local node = nodes and nodes["item/" .. result.name]
  local named_material = result_material(result, materials)
  local class = "unresolved"
  local reason = "no-material-source"
  if item_ingredient_count == 1
      and source_class_counts.resource_output == 1
      and not has_non_item_ingredient(recipe) then
    class = "first_material_product"
    reason = "resource-output-to-item"
  elseif item_ingredient_count == 1
      and named_material
      and source_materials[named_material]
      and not has_non_item_ingredient(recipe) then
    class = "first_material_product"
    reason = "material-line-transform"
    source_materials = { [named_material] = 1 }
    distinct_materials = 1
  elseif is_exact_component_material(named_material, materials) then
    class = "component_candidate"
    reason = "exact-scrap-component"
    source_materials = { [named_material] = 1 }
    distinct_materials = 1
  elseif named_material and distinct_materials >= 1 then
    class = "named_material_product"
    reason = "result-name-material"
    source_materials = { [named_material] = 1 }
    distinct_materials = 1
  elseif node_class == "placeable" or is_placeable_node(node) then
    class = "placeable_product"
    reason = "prototype-placeable"
  elseif distinct_materials >= 2 then
    if looks_like_alloy_process(recipe, result) then
      class = "possible_alloy"
      reason = has_alloy_source and "material-plus-alloy" or "multiple-material-sources"
    else
      class = "multi_material_product"
      reason = has_alloy_source and "non-metallurgical-material-plus-alloy" or "non-metallurgical-multiple-materials"
    end
  elseif has_alloy_source and #material_sources >= 1 then
    class = "possible_alloy"
    reason = "alloy-derived"
  elseif distinct_materials == 1 then
    class = "component_candidate"
    reason = has_unknown_item and "single-material-with-unknowns" or "single-material-source"
  end

  return {
    class = class,
    reason = reason,
    recipe = recipe.name,
    result = {
      type = result.type or "item",
      name = result.name,
      amount = graph.amount_of(result),
    },
    materials = composition_resolver.rounded_composition(source_materials),
    material_count = distinct_materials,
    source_class_counts = source_class_counts,
    ingredients = ingredients,
    has_non_item_ingredient = has_non_item_ingredient(recipe) or nil,
    production_class = node_class,
  }
end

---Stores a classification when it improves the previous item evidence.
---@param item_classes table<string, table>
---@param candidate table
---@param iteration integer
---@return boolean
local function record_if_better(item_classes, candidate, iteration)
  local item_name = candidate.result and candidate.result.name
  if not item_name then return false end
  local existing = item_classes[item_name]
  local candidate_priority = CLASS_PRIORITY[candidate.class] or 0
  local existing_priority = existing and (CLASS_PRIORITY[existing.class] or 0) or -1
  if existing and existing_priority >= candidate_priority then return false end

  item_classes[item_name] = {
    class = candidate.class,
    reason = candidate.reason,
    recipe = candidate.recipe,
    material = sorted_keys(candidate.materials)[1],
    materials = candidate.materials,
    material_count = candidate.material_count,
    source_class_counts = candidate.source_class_counts,
    iteration = iteration,
  }
  return true
end

---Returns sorted recipe-form rows for final output.
---@param recipes table<string, table>
---@param item_classes table<string, table>
---@param node_classes table<string, table>|nil
---@param nodes table<string, table>|nil
---@param materials table|nil
---@return table[]
local function build_rows(recipes, item_classes, node_classes, nodes, materials)
  local rows = {}
  for _, recipe in pairs(recipes or {}) do
    if is_usable_recipe(recipe) then
      for _, result in ipairs(item_results(recipe)) do
        local row = classify_result(recipe, result, item_classes, node_classes, nodes, materials)
        row.current_item_class = item_classes[result.name] and item_classes[result.name].class
        table.insert(rows, row)
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.class ~= b.class then return a.class < b.class end
    if a.result.name ~= b.result.name then return a.result.name < b.result.name end
    return (a.recipe or "") < (b.recipe or "")
  end)
  return rows
end

---Builds a compact class summary.
---@param rows table[]
---@param item_classes table<string, table>
---@param resource_outputs table<string, table>
---@return table
local function summarize(rows, item_classes, resource_outputs)
  local row_classes = {}
  for _, row in ipairs(rows or {}) do
    row_classes[row.class] = (row_classes[row.class] or 0) + 1
  end

  local item_class_counts = {}
  for _, entry in pairs(item_classes or {}) do
    item_class_counts[entry.class] = (item_class_counts[entry.class] or 0) + 1
  end

  return {
    resource_outputs = map_size(resource_outputs),
    item_classes = item_class_counts,
    recipe_result_classes = row_classes,
  }
end

---Builds passive recipe-form classifications from resource roots and item recipes.
---@param material_flow table
---@param production_flow table
---@param data_table table|nil
---@return table
function recipe_forms.build(material_flow, production_flow, data_table)
  local resource_outputs = build_resource_outputs(material_flow, data_table)
  local recipes = (production_flow and production_flow.recipes) or {}
  local materials = data_table and data_table.materials or {}
  local node_classes = production_flow
    and production_flow.classification
    and production_flow.classification.nodes
    or {}
  local nodes = build_node_lookup(production_flow)
  local item_classes = {}

  for item_name, output in pairs(resource_outputs) do
    item_classes[item_name] = {
      class = "resource_output",
      reason = "resource-minable-result",
      resource = output.resource,
      material = output.material,
      materials = { [output.material] = 1 },
      material_count = 1,
      iteration = 0,
    }
  end

  local iterations = {}
  local max_iterations = 12
  for iteration = 1, max_iterations do
    local changed = 0
    for _, recipe in pairs(recipes) do
      if is_usable_recipe(recipe) then
        for _, result in ipairs(item_results(recipe)) do
          local candidate = classify_result(recipe, result, item_classes, node_classes, nodes, materials)
          if record_if_better(item_classes, candidate, iteration) then
            changed = changed + 1
          end
        end
      end
    end
    table.insert(iterations, { iteration = iteration, changed = changed })
    if changed == 0 then break end
  end

  local rows = build_rows(recipes, item_classes, node_classes, nodes, materials)

  return {
    schema = "ingredient-scrap-recipe-forms/v1",
    profile = yokmods.ingredient_scrap.test_profile,
    active_mods = material_flow and material_flow.active_mods or {},
    root_philosophy = "recipe-derived-with-edge-case-overrides",
    resource_outputs = resource_outputs,
    item_classes = item_classes,
    recipe_results = rows,
    iterations = iterations,
    summary = summarize(rows, item_classes, resource_outputs),
  }
end

return recipe_forms
