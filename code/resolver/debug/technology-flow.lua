local technology_flow = {}

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

---Returns a compact prototype reference with icon metadata when the prototype exists.
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

---Returns an item or fluid prototype reference by checking both prototype tables safely.
---@param name string|nil
---@return table|nil
local function item_or_fluid_ref_by_name(name)
  if not name then return nil end
  if data.raw.item and data.raw.item[name] then
    return prototype_ref("item", name)
  end
  if data.raw.fluid and data.raw.fluid[name] then
    return prototype_ref("fluid", name)
  end
  return nil
end

---Returns a compact recipe reference for technology unlock display.
---@param recipe_name string|nil
---@return table|nil
local function recipe_ref(recipe_name)
  if not recipe_name then return nil end
  local recipe = data.raw.recipe and data.raw.recipe[recipe_name]
  return {
    type = "recipe",
    name = recipe_name,
    category = recipe and recipe.category,
    enabled = recipe and recipe.enabled,
    hidden = recipe and recipe.hidden,
    localised_name = recipe and recipe.localised_name,
    icon = icon_signature(recipe),
  }
end

---Returns active mods with their versions for local asset lookup in the viewer.
---@return table
local function active_mod_versions()
  local active = {}
  for mod_name, version in pairs(mods or {}) do
    active[mod_name] = version
  end
  return active
end

---Returns a shallow scalar-only copy of a Factorio prototype table.
---@param source table|nil
---@param keys string[]
---@return table|nil
local function scalar_fields(source, keys)
  if not source then return nil end
  local result = {}
  for _, key in ipairs(keys) do
    local value = source[key]
    if value ~= nil and type(value) ~= "table" and type(value) ~= "function" then
      result[key] = value
    end
  end
  return result
end

---Returns a normalized research trigger signature for debug JSON output.
---@param trigger table|nil
---@return table|nil
local function trigger_signature(trigger)
  if not trigger then return nil end
  local result = scalar_fields(trigger, {
    "type",
    "item",
    "entity",
    "fluid",
    "count",
    "quality",
    "amount",
    "name",
  }) or {}
  local subject_name = result.item or result.fluid or result.entity or result.name
  result.subject = subject_name
  result.prototype = item_or_fluid_ref_by_name(subject_name)
  return result
end

---Returns a compact technology research unit signature.
---@param unit table|nil
---@return table|nil
local function unit_signature(unit)
  if not unit then return nil end
  local ingredients = {}
  for _, ingredient in ipairs(unit.ingredients or {}) do
    local ingredient_name = ingredient.name or ingredient[1]
    local ingredient_amount = ingredient.amount or ingredient[2]
    table.insert(ingredients, {
      name = ingredient_name,
      type = ingredient.type or "item",
      amount = ingredient_amount,
      prototype = item_or_fluid_ref_by_name(ingredient_name),
    })
  end
  return {
    count = unit.count,
    count_formula = unit.count_formula,
    time = unit.time,
    ingredients = ingredients,
  }
end

---Returns a normalized technology effect signature.
---@param effect table|nil
---@return table|nil
local function effect_signature(effect)
  if not effect then return nil end
  local result = scalar_fields(effect, {
    "type",
    "recipe",
    "modifier",
    "ammo_category",
    "turret_id",
    "lab",
    "entity",
  }) or {}
  if result.recipe then
    result.prototype = recipe_ref(result.recipe)
  end
  return result
end

---Returns true when the technology is part of Ingredient Scrap's generated unlock chain.
---@param technology_name string
---@param technology table
---@return boolean
local function is_ingredient_scrap_technology(technology_name, technology)
  if technology_name:match("^yis%-") then return true end
  for _, effect in ipairs(technology.effects or {}) do
    if effect.type == "unlock-recipe" and type(effect.recipe) == "string" and effect.recipe:match("^yis%-") then
      return true
    end
  end
  return false
end

---Returns origin entries from research triggers and prerequisite technologies.
---@param technology table
---@return table[]
local function origin_entries(technology)
  local origins = {}
  local trigger = trigger_signature(technology.research_trigger)
  if trigger then
    table.insert(origins, {
      type = "research-trigger",
      name = trigger.subject or trigger.type or "research-trigger",
      trigger = trigger,
      prototype = trigger.prototype,
      amount = trigger.count or trigger.amount,
    })
  end
  for _, prerequisite in ipairs(technology.prerequisites or {}) do
    table.insert(origins, {
      type = "technology",
      name = prerequisite,
      prototype = prototype_ref("technology", prerequisite),
    })
  end
  return origins
end

---Returns unlock entries from recipe unlock effects.
---@param effects table[]
---@return table[]
local function unlock_entries(effects)
  local unlocks = {}
  for _, effect in ipairs(effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe then
      table.insert(unlocks, {
        type = "recipe",
        name = effect.recipe,
        prototype = recipe_ref(effect.recipe),
      })
    end
  end
  return unlocks
end

---Builds a compact technology flow dump for generated Ingredient Scrap technologies.
---@return table
function technology_flow.build()
  local technologies = {}
  local technology_list = {}
  local unlock_count = 0
  local trigger_count = 0

  for technology_name, technology in pairs(data.raw.technology or {}) do
    if is_ingredient_scrap_technology(technology_name, technology) then
      local effects = {}
      for _, effect in ipairs(technology.effects or {}) do
        local signature = effect_signature(effect)
        if signature then
          table.insert(effects, signature)
        end
      end

      local unlocks = unlock_entries(effects)
      unlock_count = unlock_count + #unlocks
      if technology.research_trigger then
        trigger_count = trigger_count + 1
      end

      local entry = {
        type = "technology",
        name = technology_name,
        localised_name = technology.localised_name,
        localised_description = technology.localised_description,
        enabled = technology.enabled,
        hidden = technology.hidden,
        visible_when_disabled = technology.visible_when_disabled,
        order = technology.order,
        icon = icon_signature(technology),
        research_trigger = trigger_signature(technology.research_trigger),
        origins = origin_entries(technology),
        prerequisites = technology.prerequisites,
        unit = unit_signature(technology.unit),
        effects = effects,
        unlocks = unlocks,
      }
      technologies[technology_name] = entry
      table.insert(technology_list, entry)
    end
  end

  table.sort(technology_list, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)

  return {
    schema = "ingredient-scrap-technology-flow/v1",
    active_mods = active_mod_versions(),
    technologies = technologies,
    technology_list = technology_list,
    summary = {
      technologies = #technology_list,
      unlocks = unlock_count,
      research_triggers = trigger_count,
    },
  }
end

return technology_flow
