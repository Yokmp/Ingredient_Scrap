yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}

local overrides = {}

overrides.allowed_values = { "auto", "solid", "fluid", "both", "none" }

overrides.default_modes = {}
overrides.localized_setting_names = {}
overrides.tints = {}
overrides.prototype_affixes = {
  default = {
    item = {
      prefixes = {},
      suffixes = { "-plate", "-ore", "" },
    },
    fluid = {
      prefixes = { "molten-" },
      suffixes = { "-solution", "-brine" },
    },
  },
}

overrides.mode_channels = {
  auto = { solid = "auto", fluid = "auto" },
  solid = { solid = "force", fluid = "ignore" },
  fluid = { solid = "ignore", fluid = "force" },
  both = { solid = "force", fluid = "force" },
  none = { solid = "ignore", fluid = "ignore" },
}

---Copies a list-like table.
---@param values string[]|nil
---@return string[]
local function copy_list(values)
  local out = {}
  for _, value in ipairs(values or {}) do
    table.insert(out, value)
  end
  return out
end

---Returns true when the material mode is supported.
---@param mode string|nil
---@return boolean
local function is_allowed_mode(mode)
  for _, allowed_value in ipairs(overrides.allowed_values) do
    if mode == allowed_value then return true end
  end
  return false
end

---Normalizes prototype affixes for one prototype type.
---@param affixes table|nil
---@return {prefixes: string[], suffixes: string[]}
local function normalize_affixes(affixes)
  return {
    prefixes = copy_list(affixes and affixes.prefixes),
    suffixes = copy_list(affixes and affixes.suffixes),
  }
end

---Adds a value to a list only once.
---@param values string[]
---@param seen table<string, boolean>
---@param value string
local function add_unique(values, seen, value)
  if value == "" or seen[value] then return end
  seen[value] = true
  table.insert(values, value)
end

---Returns the configured affixes for a material.
---@param material_name string
---@return table
function overrides.affixes_for(material_name)
  return overrides.prototype_affixes[material_name] or overrides.prototype_affixes.default
end

---Registers or updates a material override definition.
---See API examples: https://github.com/Yokmp/Ingredient_Scrap
---@param definition {name: string, default?: string, prototype_affixes?: table, localized_setting_name?: boolean, tint?: table|string}
function overrides.register_material_override(definition)
  if type(definition) ~= "table" or type(definition.name) ~= "string" or definition.name == "" then
    error("Ingredient Scrap material override requires a non-empty name")
  end

  local mode = definition.default or "auto"
  if not is_allowed_mode(mode) then
    error("Ingredient Scrap material override '" .. definition.name .. "' has invalid default mode: " .. tostring(mode))
  end

  overrides.default_modes[definition.name] = mode
  if definition.localized_setting_name == true then
    overrides.localized_setting_names[definition.name] = true
  elseif definition.localized_setting_name == false then
    overrides.localized_setting_names[definition.name] = nil
  end

  if definition.prototype_affixes then
    overrides.prototype_affixes[definition.name] = {
      item = normalize_affixes(definition.prototype_affixes.item),
      fluid = normalize_affixes(definition.prototype_affixes.fluid),
    }
  end

  if definition.tint ~= nil then
    overrides.tints[definition.name] = definition.tint
  end
end

---Builds a material override definition from a wrapper call.
---@param name string
---@param mode string
---@param options table|nil
---@return table
local function material_definition(name, mode, options)
  options = options or {}
  return {
    name = name,
    default = mode,
    localized_setting_name = options.localized_setting_name,
    prototype_affixes = options.prototype_affixes,
    tint = options.tint,
  }
end

---Registers a material override with a fixed default mode.
---@param name string
---@param mode string
---@param options table|nil
local function register_material_mode(name, mode, options)
  overrides.register_material_override(material_definition(name, mode, options))
end

---Publishes the small public material override API.
local function publish_material_api()
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.register = api.register or {}
  api.register.material = api.register.material or {}
  api.ignore = api.ignore or {}

  api.register.material.override = overrides.register_material_override
  api.register.material.auto = function(name, options) register_material_mode(name, "auto", options) end
  api.register.material.solid = function(name, options) register_material_mode(name, "solid", options) end
  api.register.material.fluid = function(name, options) register_material_mode(name, "fluid", options) end
  api.register.material.both = function(name, options) register_material_mode(name, "both", options) end
  api.register.material.tint = function(name, tint)
    if type(name) == "string" and name ~= "" and tint ~= nil then
      overrides.tints[name] = tint
    end
  end
  api.ignore.material = function(name, options) register_material_mode(name, "none", options) end
end

publish_material_api()

---Returns the startup setting name used for a material override.
---@param material_name string
---@return string
function overrides.setting_name(material_name)
  return "yis-material-" .. material_name
end

---Returns true when a prototype with this type and name exists.
---@param prototype_type "item"|"fluid"
---@param prototype_name string
---@return boolean
local function prototype_exists(prototype_type, prototype_name)
  return data and data.raw and data.raw[prototype_type] and data.raw[prototype_type][prototype_name] ~= nil
end

---Returns prototype candidate names from a material name and affix set.
---@param material_name string
---@param prototype_type "item"|"fluid"
---@return string[]
function overrides.prototype_candidates(material_name, prototype_type)
  local candidates = {}
  local affixes = (overrides.affixes_for(material_name)[prototype_type]) or {}

  for _, prefix in ipairs(affixes.prefixes or {}) do
    table.insert(candidates, prefix .. material_name)
  end
  for _, suffix in ipairs(affixes.suffixes or {}) do
    table.insert(candidates, material_name .. suffix)
  end

  return candidates
end

---Returns all non-empty affixes registered for resolver use.
---@return {solid_prefixes: string[], solid_suffixes: string[], fluid_prefixes: string[], fluid_suffixes: string[]}
function overrides.resolver_affixes()
  local result = {
    solid_prefixes = {},
    solid_suffixes = {},
    fluid_prefixes = {},
    fluid_suffixes = {},
  }
  local seen = {
    solid_prefixes = {},
    solid_suffixes = {},
    fluid_prefixes = {},
    fluid_suffixes = {},
  }

  for _, affixes in pairs(overrides.prototype_affixes) do
    for _, prefix in ipairs((affixes.item and affixes.item.prefixes) or {}) do
      add_unique(result.solid_prefixes, seen.solid_prefixes, prefix)
    end
    for _, suffix in ipairs((affixes.item and affixes.item.suffixes) or {}) do
      add_unique(result.solid_suffixes, seen.solid_suffixes, suffix)
    end
    for _, prefix in ipairs((affixes.fluid and affixes.fluid.prefixes) or {}) do
      add_unique(result.fluid_prefixes, seen.fluid_prefixes, prefix)
    end
    for _, suffix in ipairs((affixes.fluid and affixes.fluid.suffixes) or {}) do
      add_unique(result.fluid_suffixes, seen.fluid_suffixes, suffix)
    end
  end

  table.sort(result.solid_prefixes)
  table.sort(result.solid_suffixes)
  table.sort(result.fluid_prefixes)
  table.sort(result.fluid_suffixes)
  return result
end

---Returns the first available rich-text icon tag for a material.
---@param material_name string
---@return string|nil
function overrides.icon_tag(material_name)
  for _, item_name in ipairs(overrides.prototype_candidates(material_name, "item")) do
    if prototype_exists("item", item_name) then
      return "[item=" .. item_name .. "]"
    end
  end

  for _, fluid_name in ipairs(overrides.prototype_candidates(material_name, "fluid")) do
    if prototype_exists("fluid", fluid_name) then
      return "[fluid=" .. fluid_name .. "]"
    end
  end

  return nil
end

---Returns the localized setting name for a material override.
---Item/fluid rich-text icons are intentionally omitted here because Factorio's
---startup settings GUI does not reliably render them in setting names.
---@param material_name string
---@return table
function overrides.localised_setting_name(material_name)
  if overrides.localized_setting_names[material_name] then
    return { "", { "mod-setting-name." .. overrides.setting_name(material_name) }, " - ", material_name, ": ", { "mod-setting-name.yis-material-mode" } }
  end
  return { "", "[img=none]", " - ", material_name, ": ", { "mod-setting-name.yis-material-mode" } }
end

---Returns material names in stable alphabetical order.
---@return string[]
function overrides.sorted_materials()
  local names = {}
  for material_name, _ in pairs(overrides.default_modes) do
    table.insert(names, material_name)
  end
  table.sort(names)
  return names
end

---Returns the solid/fluid channel modes for a material mode.
---@param mode string|nil
---@return {solid: string, fluid: string}
function overrides.channels_for_mode(mode)
  return overrides.mode_channels[mode or "auto"] or overrides.mode_channels.auto
end

---Returns true when a material mode blocks the requested channel.
---@param mode string|nil
---@param channel "solid"|"fluid"
---@return boolean
function overrides.is_ignored(mode, channel)
  return overrides.channels_for_mode(mode)[channel] == "ignore"
end

---Returns true when a material mode forces the requested channel.
---@param mode string|nil
---@param channel "solid"|"fluid"
---@return boolean
function overrides.is_forced(mode, channel)
  return overrides.channels_for_mode(mode)[channel] == "force"
end

return overrides
