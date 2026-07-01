yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}

local overrides = {}

overrides.forced_targets = {
  solid = {},
  fluid = {},
}

overrides.blocked_targets = {
  solid = {},
  fluid = {},
}

---Returns true when a recipe-chain mode is supported by the API.
---@param mode string|nil
---@return boolean
local function is_valid_mode(mode)
  return mode == "solid" or mode == "fluid"
end

---Normalizes one recipe-chain target result definition.
---@param mode "solid"|"fluid"
---@param result_type string|nil
---@param result_name string|nil
---@return table
local function target_result(mode, result_type, result_name)
  local normalized_type = result_type or (mode == "fluid" and "fluid" or "item")
  if normalized_type ~= "item" and normalized_type ~= "fluid" then
    error("Ingredient Scrap recipe-chain target result_type must be 'item' or 'fluid'")
  end
  if type(result_name) ~= "string" or result_name == "" then
    error("Ingredient Scrap recipe-chain target requires a non-empty result name")
  end
  return {
    result_type = normalized_type,
    result_name = result_name,
  }
end

---Registers an explicit recipe-chain recycle target for one material and mode.
---See API examples: https://github.com/Yokmp/Ingredient_Scrap
---@param material_name string
---@param mode "solid"|"fluid"
---@param result_type string|nil
---@param result_name string
---@param options table|nil
function overrides.register_target(material_name, mode, result_type, result_name, options)
  if type(material_name) ~= "string" or material_name == "" then
    error("Ingredient Scrap recipe-chain target requires a non-empty material name")
  end
  if not is_valid_mode(mode) then
    error("Ingredient Scrap recipe-chain target mode must be 'solid' or 'fluid'")
  end

  local target = target_result(mode, result_type, result_name)
  options = options or {}
  target.source = options.source
  target.reason = options.reason
  overrides.forced_targets[mode][material_name] = target
  overrides.blocked_targets[mode][material_name] = nil
end

---Blocks automatic recipe-chain target application for one material and mode.
---@param material_name string
---@param mode "solid"|"fluid"
---@param reason string|nil
function overrides.block_target(material_name, mode, reason)
  if type(material_name) ~= "string" or material_name == "" then
    error("Ingredient Scrap recipe-chain target block requires a non-empty material name")
  end
  if not is_valid_mode(mode) then
    error("Ingredient Scrap recipe-chain target block mode must be 'solid' or 'fluid'")
  end

  overrides.blocked_targets[mode][material_name] = {
    reason = reason or "api-blocked",
  }
  overrides.forced_targets[mode][material_name] = nil
end

---Returns an explicit target override for a material and mode.
---@param mode "solid"|"fluid"
---@param material_name string
---@return table|nil
function overrides.forced_target(mode, material_name)
  return overrides.forced_targets[mode] and overrides.forced_targets[mode][material_name] or nil
end

---Returns a block override for a material and mode.
---@param mode "solid"|"fluid"
---@param material_name string
---@return table|nil
function overrides.blocked_target(mode, material_name)
  return overrides.blocked_targets[mode] and overrides.blocked_targets[mode][material_name] or nil
end

---Returns all materials with explicit recipe-chain overrides for one mode.
---@param mode "solid"|"fluid"
---@return string[]
function overrides.materials_for_mode(mode)
  local names = {}
  local seen = {}

  for material_name in pairs(overrides.forced_targets[mode] or {}) do
    seen[material_name] = true
    table.insert(names, material_name)
  end
  for material_name in pairs(overrides.blocked_targets[mode] or {}) do
    if not seen[material_name] then
      table.insert(names, material_name)
    end
  end

  table.sort(names)
  return names
end

---Publishes the public recipe-chain override API.
local function publish_recipe_chain_api()
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.register = api.register or {}
  api.register.recipe_chain = api.register.recipe_chain or {}
  api.ignore = api.ignore or {}
  api.ignore.recipe_chain = api.ignore.recipe_chain or {}

  api.register.recipe_chain.target = overrides.register_target
  api.register.recipe_chain.solid_target = function(material_name, result_name, options)
    overrides.register_target(material_name, "solid", "item", result_name, options)
  end
  api.register.recipe_chain.fluid_target = function(material_name, result_name, options)
    overrides.register_target(material_name, "fluid", "fluid", result_name, options)
  end

  api.ignore.recipe_chain.target = overrides.block_target
  api.ignore.recipe_chain.solid_target = function(material_name, reason)
    overrides.block_target(material_name, "solid", reason)
  end
  api.ignore.recipe_chain.fluid_target = function(material_name, reason)
    overrides.block_target(material_name, "fluid", reason)
  end
end

publish_recipe_chain_api()

return overrides
