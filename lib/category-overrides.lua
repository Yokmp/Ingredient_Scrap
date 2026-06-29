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

---Registers a category patch rule for a prototype group.
---@param prototype_group "furnace"|"assembling_machine"
---@param definition {source_categories: string[]|table<string, boolean>, add_item_recycling?: boolean, add_fluid_recycling_if_fluid_boxes?: boolean}
local function register_rule(prototype_group, definition)
  if type(definition) ~= "table" then
    error("Ingredient Scrap category override requires a definition table")
  end

  table.insert(category_overrides.rules[prototype_group], {
    source_categories = normalize_categories(definition.source_categories),
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

---Adds a crafting category only when the machine does not already have it.
---@param machine table
---@param category string
function category_overrides.add_category_once(machine, category)
  machine.crafting_categories = machine.crafting_categories or {}
  if not category_overrides.has_category(machine, { [category] = true }) then
    table.insert(machine.crafting_categories, category)
  end
end

return category_overrides
