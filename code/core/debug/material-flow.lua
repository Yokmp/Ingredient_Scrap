local resolver = require("code.core.materials.resolver")

local material_flow = {}

---Splits a Factorio icon path like "__base__/graphics/foo.png" into source metadata.
---@param path string|nil
---@return table|nil
local function icon_source(path)
  if not path then return nil end
  local mod_name, inner_path = string.match(path, "^__([^_][^/]*)__/(.+)$")
  if mod_name and inner_path then
    return {
      mod = mod_name,
      inner_path = inner_path,
    }
  end
  return {
    inner_path = path,
  }
end

---Returns a compact icon signature from a prototype.
---@param prototype table|nil
---@return table|nil
local function icon_signature(prototype)
  if not prototype then return nil end
  if prototype.icon then
    return {
      path = prototype.icon,
      source = icon_source(prototype.icon),
      icon_size = prototype.icon_size,
    }
  end
  if prototype.icons and prototype.icons[1] then
    local layers = {}
    for _, layer in ipairs(prototype.icons) do
      table.insert(layers, {
        path = layer.icon,
        source = icon_source(layer.icon),
        icon_size = layer.icon_size or layer.size,
        tint = layer.tint,
        scale = layer.scale,
        shift = layer.shift,
      })
    end
    return {
      path = prototype.icons[1].icon,
      source = icon_source(prototype.icons[1].icon),
      icon_size = prototype.icons[1].icon_size or prototype.icons[1].size,
      layers = layers,
    }
  end
  return nil
end

---Returns a compact prototype reference with its first available icon path.
---@param prototype_type string
---@param name string|nil
---@return table|nil
local function prototype_ref(prototype_type, name)
  if not name then return nil end
  local prototype_group = data.raw[prototype_type]
  local prototype = prototype_group and prototype_group[name]
  return {
    type = prototype_type,
    name = name,
    icon = icon_signature(prototype),
  }
end

---Returns a compact item/fluid reference for a typed result or ingredient.
---@param prototype_type string|nil
---@param name string|nil
---@return table|nil
local function item_or_fluid_ref(prototype_type, name)
  if prototype_type == "fluid" then
    return prototype_ref("fluid", name)
  end
  return prototype_ref("item", name)
end

---Returns an item or fluid prototype reference by checking both prototype tables safely.
---@param name string|nil
---@return table|nil
local function item_or_fluid_ref_by_name(name)
  if not name then return nil end
  if data.raw.fluid and data.raw.fluid[name] then
    return prototype_ref("fluid", name)
  end
  return prototype_ref("item", name)
end

---Returns a compact recipe result signature for debug JSON output.
---@param result table|nil
---@return table|nil
local function result_signature(result)
  if not result then return nil end
  return {
    type = result.type,
    name = result.name,
    amount = result.amount,
    amount_min = result.amount_min,
    amount_max = result.amount_max,
    probability = result.probability,
    prototype = item_or_fluid_ref(result.type, result.name),
  }
end

---Returns a compact recipe ingredient signature for debug JSON output.
---@param ingredient table|nil
---@return table|nil
local function ingredient_signature(ingredient)
  if not ingredient then return nil end
  return {
    type = ingredient.type or "item",
    name = ingredient.name,
    amount = ingredient.amount,
    amount_min = ingredient.amount_min,
    amount_max = ingredient.amount_max,
    probability = ingredient.probability,
    prototype = item_or_fluid_ref(ingredient.type or "item", ingredient.name),
  }
end

---Returns all recipe ingredients with the matched scrap source flagged.
---@param recipe table|nil
---@param matched_input table
---@return table[]
local function recipe_ingredients(recipe, matched_input)
  local ingredients = {}
  for _, ingredient in ipairs((recipe and recipe.ingredients) or {}) do
    local signature = ingredient_signature(ingredient)
    if signature then
      signature.matched_scrap_input = matched_input
        and signature.name == matched_input.ingredient
        and signature.type == (matched_input.ingredient_type or "item")
        or nil
      table.insert(ingredients, signature)
    end
  end
  return ingredients
end

---Returns all recipe results with prototype/icon metadata.
---@param recipe table|nil
---@return table[]
local function recipe_results(recipe)
  local results = {}
  for _, result in ipairs((recipe and recipe.results) or {}) do
    local signature = result_signature(result)
    if signature then
      table.insert(results, signature)
    end
  end
  return results
end

---Inserts a value into an array-like table and returns it.
---@param target table
---@param value any
---@return any
local function push(target, value)
  table.insert(target, value)
  return value
end

---Returns all normalized results from old-style or new-style recipe result fields.
---@param recipe table|nil
---@return table[]
local function all_recipe_results(recipe)
  local results = recipe_results(recipe)
  if recipe and recipe.result then
    push(results, result_signature({
      type = "item",
      name = recipe.result,
      amount = recipe.result_count or 1,
    }))
  end
  return results
end

---Returns true for Ingredient Scrap generated scrap item names.
---@param name string|nil
---@return boolean
local function is_generated_scrap_name(name)
  return type(name) == "string" and name:match("^yis%-.*%-scrap$") ~= nil
end

---Returns true for generated Ingredient Scrap recycling recipes.
---@param recipe table
---@return boolean
local function is_generated_recycle_recipe(recipe)
  return recipe.category == "yis-recycle-to-item"
    or recipe.category == "yis-recycle-to-fluid"
    or (type(recipe.name) == "string" and recipe.name:match("^yis%-recycle%-") ~= nil)
end

---Removes Ingredient Scrap injected scrap byproducts from neutral production graph results.
---@param results table[]
---@return table[]
local function without_generated_scrap_results(results)
  local filtered = {}
  for _, result in ipairs(results or {}) do
    if not is_generated_scrap_name(result.name) then
      table.insert(filtered, result)
    end
  end
  return filtered
end

---Returns nil for empty array-like tables so Factorio JSON does not encode them as objects.
---@param values table|nil
---@return table|nil
local function nil_if_empty(values)
  if not values or #values == 0 then return nil end
  return values
end

---Adds a marker entry to a debug custom marker list.
---@param markers table[]
---@param key string
---@param value any
---@param label string|nil
local function add_marker(markers, key, value, label)
  table.insert(markers, {
    key = key,
    value = value,
    label = label or (key .. "=" .. tostring(value)),
  })
end

---Returns viewer-friendly custom metadata for a recipe prototype.
---@param recipe table|nil
---@return table|nil
local function recipe_custom_metadata(recipe)
  if not recipe then return nil end
  local markers = {}

  if recipe.category then
    add_marker(markers, "category:" .. recipe.category, recipe.category, recipe.category)
  end
  if recipe.hidden then
    add_marker(markers, "hidden", true, "hidden")
  end
  if recipe.enabled == false then
    add_marker(markers, "enabled:false", false, "disabled")
  end
  if recipe.auto_recycle == false then
    add_marker(markers, "auto_recycle:false", false, "auto_recycle=false")
  end
  if recipe.allow_decomposition == false then
    add_marker(markers, "allow_decomposition:false", false, "allow_decomposition=false")
  end
  if recipe.allow_as_intermediate == false then
    add_marker(markers, "allow_as_intermediate:false", false, "allow_as_intermediate=false")
  end
  if recipe.hide_from_player_crafting then
    add_marker(markers, "hide_from_player_crafting", true, "hide_from_player_crafting")
  end

  if #markers == 0 then return nil end
  return {
    markers = markers,
  }
end

---Returns stable sorted array output by name-like keys.
---@param values table[]
---@return table[]
local function sorted(values)
  table.sort(values, function(a, b)
    return tostring(a.name or a.recipe or a.material or "") < tostring(b.name or b.recipe or b.material or "")
  end)
  return values
end

---Returns the currently active mods and their versions for external tooling.
---@return table
local function active_mod_versions()
  local active = {}
  for mod_name, version in pairs(mods or {}) do
    active[mod_name] = version
  end
  return active
end

---Returns all minable result entries from a resource.
---@param resource table
---@return table[]
local function minable_results(resource)
  local minable = resource.minable or {}
  local results = {}
  if minable.result then
    push(results, {
      type = "item",
      name = minable.result,
      amount = minable.count,
    })
  end
  for _, result in ipairs(minable.results or {}) do
    if result.name then
      push(results, {
        type = result.type or "item",
        name = result.name,
        amount = result.amount,
        amount_min = result.amount_min,
        amount_max = result.amount_max,
        probability = result.probability,
      })
    end
  end
  return results
end

---Builds a material-keyed resource index from data.raw.resource.
---@param data_table ISdata_table
---@return table
local function build_resource_index(data_table)
  local by_material = {}
  local materials = data_table.materials

  for resource_name, resource in pairs(data.raw.resource or {}) do
    for _, result in ipairs(minable_results(resource)) do
      local material
      if result.type == "fluid" then
        material = resolver.resolve_fluid(result.name, materials)
      else
        material = resolver.resolve_solid(result.name, materials, true)
      end

      if material then
        by_material[material] = by_material[material] or {}
        push(by_material[material], {
          resource = resource_name,
          resource_icon = icon_signature(resource),
          category = resource.category or "basic-solid",
          result = result,
          result_prototype = item_or_fluid_ref(result.type, result.name),
        })
      end
    end
  end

  for _, entries in pairs(by_material) do
    sorted(entries)
  end
  return by_material
end

---Builds a material-keyed generated recycle recipe index.
---@param data_table ISdata_table
---@return table
local function build_recycle_index(data_table)
  local by_material = {}
  local recipe_sources = data_table.debug and data_table.debug.sources and data_table.debug.sources.recipes or {}

  for recipe_name, source in pairs(recipe_sources) do
    local material = source.scrap_type
    local recipe = data_table.prototypes.recipes and data_table.prototypes.recipes[recipe_name]
    local result = recipe and recipe.results and recipe.results[1]
    if material then
      by_material[material] = by_material[material] or {}
      push(by_material[material], {
        recipe = recipe_name,
        recipe_icon = icon_signature(recipe),
        category = recipe and recipe.category,
        hidden = recipe and recipe.hidden or false,
        result = result_signature(result),
      })
    end
  end

  for _, entries in pairs(by_material) do
    sorted(entries)
  end
  return by_material
end

---Finds the generated scrap result for a material in a patched source recipe.
---@param insert table|nil
---@param scrap_name string
---@return table|nil
local function find_scrap_result(insert, scrap_name)
  for _, result in ipairs((insert and insert.results) or {}) do
    if result.name == scrap_name then
      return result
    end
  end
  return nil
end

---Builds a tree-viewer friendly JSON table of material flow edges.
---@param data_table ISdata_table
---@return table
function material_flow.build(data_table)
  local resources_by_material = build_resource_index(data_table)
  local recycle_by_material = build_recycle_index(data_table)
  local insert_sources = data_table.debug and data_table.debug.sources and data_table.debug.sources.inserts or {}
  local flows = {}

  for recipe_name, sources in pairs(insert_sources) do
    local insert = data_table.inserts.recipes and data_table.inserts.recipes[recipe_name]
    local source_recipe = data.raw.recipe and data.raw.recipe[recipe_name]
    for _, source in ipairs(sources or {}) do
      local material = source.scrap_type
      local scrap_name = material and yokmods.ingredient_scrap.get_scrap_name(material) or nil
      if material and scrap_name then
        push(flows, {
          material = material,
          mode = source.ingredient_type == "fluid" and "fluid" or "solid",
          resource_results = resources_by_material[material] or {},
          source_recipe = {
            name = recipe_name,
            icon = icon_signature(source_recipe),
            category = source_recipe and source_recipe.category,
            custom = recipe_custom_metadata(source_recipe),
            main_product = insert and insert.main_product,
            main_product_prototype = item_or_fluid_ref_by_name(insert and insert.main_product),
            ingredients = recipe_ingredients(source_recipe, source),
            results = recipe_results(source_recipe),
          },
          input = {
            type = source.ingredient_type,
            name = source.ingredient,
            amount = source.amount,
            prototype = item_or_fluid_ref(source.ingredient_type, source.ingredient),
          },
          scrap = {
            name = scrap_name,
            prototype = prototype_ref("item", scrap_name),
            result = result_signature(find_scrap_result(insert, scrap_name)),
          },
          recycle_recipes = recycle_by_material[material] or {},
        })
      end
    end
  end

  sorted(flows)
  return {
    schema = "ingredient-scrap-material-flow/v1",
    mod = "Ingredient_Scrap",
    active_mods = active_mod_versions(),
    flows = flows,
    resources_by_material = resources_by_material,
    recycle_by_material = recycle_by_material,
  }
end

---Adds a recipe edge name to a prototype node without duplicates.
---@param node table
---@param field string
---@param recipe_name string
local function add_recipe_edge(node, field, recipe_name)
  node[field] = node[field] or {}
  for _, existing in ipairs(node[field]) do
    if existing == recipe_name then return end
  end
  table.insert(node[field], recipe_name)
end

---Returns a stable item/fluid key for production graph indexes.
---@param prototype_type string|nil
---@param name string
---@return string
local function typed_key(prototype_type, name)
  return (prototype_type or "item") .. "/" .. name
end

---Builds a compact item/fluid node for the production graph.
---@param prototype_type string
---@param name string
---@return table
local function production_prototype_node(prototype_type, name)
  local prototype = data.raw[prototype_type] and data.raw[prototype_type][name] or {}
  return {
    type = prototype_type,
    name = name,
    icon = icon_signature(prototype),
    subgroup = prototype.subgroup,
    order = prototype.order,
    hidden = prototype.hidden,
    place_result = prototype.place_result,
    place_as_tile = prototype.place_as_tile,
    place_as_equipment_result = prototype.place_as_equipment_result,
    produced_by = {},
    consumed_by = {},
  }
end

---Returns an existing production graph node or creates it from data.raw metadata.
---@param nodes table
---@param prototype_type string
---@param name string
---@return table
local function ensure_production_node(nodes, prototype_type, name)
  local key = typed_key(prototype_type, name)
  nodes[key] = nodes[key] or production_prototype_node(prototype_type, name)
  return nodes[key]
end

---Returns a compact recipe node for neutral production-chain inspection.
---@param recipe table
---@return table
local function production_recipe_node(recipe)
  return {
    name = recipe.name,
    icon = icon_signature(recipe),
    category = recipe.category,
    subgroup = recipe.subgroup,
    order = recipe.order,
    enabled = recipe.enabled,
    hidden = recipe.hidden,
    auto_recycle = recipe.auto_recycle,
    allow_decomposition = recipe.allow_decomposition,
    allow_as_intermediate = recipe.allow_as_intermediate,
    hide_from_player_crafting = recipe.hide_from_player_crafting,
    hide_from_signal_gui = recipe.hide_from_signal_gui,
    main_product = recipe.main_product,
    ingredients = nil_if_empty(recipe_ingredients(recipe)),
    results = nil_if_empty(without_generated_scrap_results(all_recipe_results(recipe))),
    custom = recipe_custom_metadata(recipe),
  }
end

---Returns all production graph prototype nodes sorted by key.
---@param nodes table
---@return table[]
local function sorted_node_list(nodes)
  local list = {}
  for key, node in pairs(nodes) do
    node.key = key
    table.insert(list, node)
    table.sort(node.produced_by)
    table.sort(node.consumed_by)
    node.produced_by = nil_if_empty(node.produced_by)
    node.consumed_by = nil_if_empty(node.consumed_by)
  end
  table.sort(list, function(a, b) return a.key < b.key end)
  return list
end

---Builds a neutral recipe/item/fluid production graph for external flow viewers.
---@return table
function material_flow.build_production_flow()
  local recipes = {}
  local nodes = {}
  local by_category = {}

  for recipe_name, recipe in pairs(data.raw.recipe or {}) do
    if not is_generated_recycle_recipe(recipe) then
      local recipe_node = production_recipe_node(recipe)
      recipes[recipe_name] = recipe_node
      by_category[recipe_node.category or "crafting"] = by_category[recipe_node.category or "crafting"] or {}
      table.insert(by_category[recipe_node.category or "crafting"], recipe_name)

      for _, ingredient in ipairs(recipe_node.ingredients or {}) do
        local node = ensure_production_node(nodes, ingredient.type or "item", ingredient.name)
        add_recipe_edge(node, "consumed_by", recipe_name)
      end

      for _, result in ipairs(recipe_node.results or {}) do
        local node = ensure_production_node(nodes, result.type or "item", result.name)
        add_recipe_edge(node, "produced_by", recipe_name)
      end
    end
  end

  for _, names in pairs(by_category) do
    table.sort(names)
  end

  return {
    schema = "ingredient-scrap-production-flow/v1",
    mod = "Ingredient_Scrap",
    active_mods = active_mod_versions(),
    recipes = recipes,
    prototypes = {
      nodes = sorted_node_list(nodes),
    },
    indexes = {
      by_category = by_category,
    },
  }
end

return material_flow
