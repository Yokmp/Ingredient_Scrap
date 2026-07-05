yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}

local category_overrides = {}

category_overrides.rules = {
  furnace = {},
  assembling_machine = {},
}

---Normalizes a list or set of source categories into a set.
---@param categories string[]|table<string, boolean>|nil
---@return table<string, boolean>
local function normalize_categories(categories)
  local normalized = {}
  for key, value in pairs(categories or {}) do
    if type(key) == "number" then
      normalized[value] = true
    elseif value then
      normalized[key] = true
    end
  end
  return normalized
end

---Normalizes a list or set of fast-replaceable groups into a set.
---@param groups string[]|table<string, boolean>|nil
---@return table<string, boolean>
local function normalize_groups(groups)
  local normalized = {}
  for key, value in pairs(groups or {}) do
    if type(key) == "number" then
      normalized[value] = true
    elseif value then
      normalized[key] = true
    end
  end
  return normalized
end

---Registers a category patch rule for a prototype group.
---@param prototype_group "furnace"|"assembling_machine"
---@param definition {source_categories?: string[]|table<string, boolean>, fast_replaceable_groups?: string[]|table<string, boolean>, add_item_recycling?: boolean, add_fluid_recycling_if_fluid_boxes?: boolean}
local function register_rule(prototype_group, definition)
  if type(definition) ~= "table" then
    error("Ingredient Scrap category override requires a definition table")
  end

  table.insert(category_overrides.rules[prototype_group], {
    source_categories = normalize_categories(definition.source_categories),
    fast_replaceable_groups = normalize_groups(definition.fast_replaceable_groups),
    add_item_recycling = definition.add_item_recycling ~= false,
    add_fluid_recycling_if_fluid_boxes = definition.add_fluid_recycling_if_fluid_boxes == true,
  })
end

---Publishes the small public crafting category API.
local function publish_category_api()
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.register = api.register or {}
  api.register.category = api.register.category or {}

  api.register.category.furnace = function(definition) register_rule("furnace", definition) end
  api.register.category.assembling_machine = function(definition) register_rule("assembling_machine", definition) end
end

publish_category_api()

---Returns true when a crafting machine has at least one requested category.
---@param machine table
---@param source_categories table<string, boolean>
---@return boolean
function category_overrides.has_category(machine, source_categories)
  for _, crafting_category in ipairs(machine.crafting_categories or {}) do
    if source_categories[crafting_category] then return true end
  end
  return false
end

---Returns true when a crafting machine has one of the requested fast-replaceable groups.
---@param machine table
---@param fast_replaceable_groups table<string, boolean>
---@return boolean
function category_overrides.has_fast_replaceable_group(machine, fast_replaceable_groups)
  return machine.fast_replaceable_group ~= nil and fast_replaceable_groups[machine.fast_replaceable_group] == true
end

---Adds a crafting category only when the machine does not already have it.
---@param machine table
---@param category string
function category_overrides.add_category_once(machine, category)
  machine.crafting_categories = machine.crafting_categories or {}
  if not category_overrides.has_category(machine, { [category] = true }) then
    table.insert(machine.crafting_categories, category)
  end
end

---Applies registered category rules to one prototype type.
---@param prototype_type string
---@param rules table[]
---@param recycle_item_category string
---@param recycle_fluid_category string
function category_overrides.apply_category_rules(prototype_type, rules, recycle_item_category, recycle_fluid_category)
  for _, machine in pairs(data.raw[prototype_type] or {}) do
    for _, rule in ipairs(rules or {}) do
      if category_overrides.has_category(machine, rule.source_categories)
          or category_overrides.has_fast_replaceable_group(machine, rule.fast_replaceable_groups) then
        if rule.add_item_recycling then
          category_overrides.add_category_once(machine, recycle_item_category)
        end
        if rule.add_fluid_recycling_if_fluid_boxes and machine.fluid_boxes then
          category_overrides.add_category_once(machine, recycle_fluid_category)
        end
      end
    end
  end
end

---Keeps machine tiers in the same fast-replaceable group category-compatible.
---@param prototype_type string
---@param recycle_item_category string
---@param recycle_fluid_category string
function category_overrides.propagate_fast_replaceable_group_categories(prototype_type, recycle_item_category, recycle_fluid_category)
  local group_flags = {}

  for _, machine in pairs(data.raw[prototype_type] or {}) do
    local group = machine.fast_replaceable_group
    if group then
      local flags = group_flags[group] or { item = false, fluid = false }
      flags.item = flags.item or category_overrides.has_category(machine, { [recycle_item_category] = true })
      flags.fluid = flags.fluid or category_overrides.has_category(machine, { [recycle_fluid_category] = true })
      group_flags[group] = flags
    end
  end

  for _, machine in pairs(data.raw[prototype_type] or {}) do
    local group = machine.fast_replaceable_group
    local flags = group and group_flags[group]
    if flags then
      if flags.item then
        category_overrides.add_category_once(machine, recycle_item_category)
      end
      if flags.fluid and machine.fluid_boxes then
        category_overrides.add_category_once(machine, recycle_fluid_category)
      end
    end
  end
end

---Applies all registered category rules to Factorio crafting-machine prototypes.
---@param recycle_categories {solid: string, fluid: string}
function category_overrides.apply_registered_rules(recycle_categories)
  category_overrides.apply_category_rules(
    "furnace",
    category_overrides.rules.furnace,
    recycle_categories.solid,
    recycle_categories.fluid
  )
  category_overrides.propagate_fast_replaceable_group_categories(
    "furnace",
    recycle_categories.solid,
    recycle_categories.fluid
  )
  category_overrides.apply_category_rules(
    "assembling-machine",
    category_overrides.rules.assembling_machine,
    recycle_categories.solid,
    recycle_categories.fluid
  )
  category_overrides.propagate_fast_replaceable_group_categories(
    "assembling-machine",
    recycle_categories.solid,
    recycle_categories.fluid
  )
end

return category_overrides
