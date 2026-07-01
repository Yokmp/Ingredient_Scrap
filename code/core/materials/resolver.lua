local resolver = {}

---Returns the name without a matching suffix, or nil when none matches.
---@param name string
---@param suffixes string[]
---@return string|nil
local function strip_suffix(name, suffixes)
  for _, suffix in ipairs(suffixes or {}) do
    if name:sub(-#suffix) == suffix then
      return name:sub(1, #name - #suffix)
    end
  end
  return nil
end

---Returns the name without a matching prefix, or nil when none matches.
---@param name string
---@param prefixes string[]
---@return string|nil
local function strip_prefix(name, prefixes)
  for _, prefix in ipairs(prefixes or {}) do
    if name:sub(1, #prefix) == prefix then
      return name:sub(#prefix + 1)
    end
  end
  return nil
end

---Returns the plain name only for simple, non-composite material names.
---@param name string
---@return string|nil
local function plain_name_fallback(name)
  if name:find("-", 1, true) then return nil end
  return name
end

---Resolves a solid item or resource result name into a scrap material type.
---@param name string
---@param materials ISdata_table.materials
---@param allow_plain? boolean
---@return string|nil
function resolver.resolve_solid(name, materials, allow_plain)
  if materials.solid_aliases and materials.solid_aliases[name] then
    return materials.solid_aliases[name]
  end

  local without_prefix = strip_prefix(name, materials.solid_prefixes)
  if without_prefix then
    return strip_suffix(without_prefix, materials.solid_suffixes) or without_prefix
  end

  local without_suffix = strip_suffix(name, materials.solid_suffixes)
  if without_suffix then
    return strip_prefix(without_suffix, materials.solid_prefixes) or without_suffix
  end

  return allow_plain and plain_name_fallback(name) or nil
end

---Resolves a fluid name into a scrap material type.
---@param name string
---@param materials ISdata_table.materials
---@return string|nil
function resolver.resolve_fluid(name, materials)
  if materials.fluid_aliases and materials.fluid_aliases[name] then
    return materials.fluid_aliases[name]
  end

  local without_prefix = strip_prefix(name, materials.fluid_prefixes)
  if without_prefix then
    return strip_suffix(without_prefix, materials.fluid_suffixes)
        or strip_suffix(without_prefix, materials.solid_suffixes)
        or without_prefix
  end

  return strip_suffix(name, materials.fluid_suffixes)
end

return resolver
