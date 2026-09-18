---Converts a hex color string into Factorio's runtime color table format.
local function color(hex)
  return util.color(hex)
end

local function apply_registered_tints(scrap_tints)
  local material_overrides = require("code.override.materials")
  for material_name, tint in pairs(material_overrides.tints or {}) do
    if type(tint) == "string" then
      scrap_tints[material_name] = color(tint)
    else
      scrap_tints[material_name] = tint
    end
  end
end

local tint_colors = {
  ["blue"]     = color("#1560bd"),
  ["brown"]    = color("#43464b"),
  ["cyan"]     = color("#00BCE3"),
  ["green"]    = color("#006E33"),
  ["grey"]     = color("#888b8d"),
  ["lgrey"]    = color("#dbe2e9"),
  ["dgrey"]    = { r = 123, g = 134, b = 122, a = 0.9 },
  ["orange"]   = color("#CB6015"),
  ["lpurple"]  = color("#B946F2"),
  ["purple"]   = color("#8031A7"),
  ["dpurple"]  = { r = 101, g = 85, b = 177, a = 0.8 },
  ["red"]      = color("#AB2328"),
  ["teal"]     = color("#00B2A9"),
  ["lyellow"]  = color("#FEDD00"),
  ["yellow"]   = color("#FECD00"),

  ["brass"]    = color("#AC9F3C"),
  ["bronze"]   = color("#a97142"),
  ["glass"]    = color("#afeeee"),
  ["gold"]     = color("#FFB81C"),
  ["chrome"]   = color("#DBE2E9"),
  ["platinum"] = color("#E5E1E6"),
  ["zinc"]     = color("#BAC4C8"),
  ["titan"]    = color("#DADBCF"),
  ["nickel"]   = color("#CCD3D8"),
  ["mangan"]   = color("#D3BC8D"),
}

local scrap_tints = {
  adamantite          = tint_colors["purple"],
  aluminum            = tint_colors["lgrey"],
  aluminium           = tint_colors["lgrey"],
  antitate            = tint_colors["red"],
  brass               = tint_colors["brass"],
  bronze              = tint_colors["bronze"],
  chromium            = tint_colors["chrome"],
  cobalt              = tint_colors["blue"],
  ["cobalt-steel"]    = tint_colors["blue"],
  ["copper-tungsten"] = tint_colors["red"],
  elionagate          = tint_colors["teal"],
  glass               = { r = 0.35, g = 0.78, b = 0.72, a = 0.85 },
  gold                = tint_colors["yellow"],
  gunmetal            = tint_colors["yellow"],
  imersium            = tint_colors["purple"],
  invar               = tint_colors["grey"],
  lead                = tint_colors["brown"],
  manganic            = tint_colors["mangan"],
  ["meta-garnierite"] = tint_colors["yellow"],
  nickel              = tint_colors["nickel"],
  nitinol             = tint_colors["grey"],
  ["nova-leucoxene"]  = tint_colors["dgrey"],
  orichalcite         = tint_colors["orange"],
  osmium              = tint_colors["purple"],
  phosphic            = tint_colors["teal"],
  phosphorite         = tint_colors["grey"],
  plumbic             = tint_colors["purple"],
  ["pro-galena"]      = tint_colors["dgrey"],
  sanguinate          = tint_colors["red"],
  silicon             = { r = 0.38, g = 0.48, b = 0.68, a = 1 },
  silver              = tint_colors["grey"],
  stannic             = tint_colors["green"],
  tellurium           = tint_colors["purple"],
  tin                 = tint_colors["grey"],
  titanic             = tint_colors["titan"],
  titanium            = tint_colors["dgrey"],
  zinc                = tint_colors["zinc"],
}

apply_registered_tints(scrap_tints)

---Registers or updates the scrap tint for a material.
---@param material_name string
---@param tint table|string|nil
function scrap_tints.register(material_name, tint)
  if type(material_name) ~= "string" or material_name == "" or tint == nil then return end
  if type(tint) == "string" then
    scrap_tints[material_name] = color(tint)
  else
    scrap_tints[material_name] = tint
  end
end

---Returns shared named tint colors for API consumers that want them.
---@return table
function scrap_tints.colors()
  return tint_colors
end


local tints = scrap_tints
local overrides = require("code.override.materials")
local visuals = {}
local definitions = {}
for name, tint in pairs(tints) do
  if type(tint) == "table" then definitions[name] = { tint = tint } end
end

local classes = {
  ["metal-soft"] = { families = 2 },
  ["metal-light"] = { families = 2 },
  ["metal-hard"] = { families = 3 },
  brittle = { families = 1, prefix = "scrap-broken-glass" },
  granules = { families = 1, prefix = "scrap-synthetic-granules" },
  shreds = { families = 1, prefix = "scrap-synthetic-shreds" },
}
local known = {
  ["metal-soft"] = { "copper", "lead", "tin", "zinc", "gold", "silver", "brass", "bronze" },
  ["metal-light"] = { "aluminium", "aluminum", "magnesium", "titanium", "nitinol" },
  ["metal-hard"] = { "iron", "steel", "tungsten", "chromium", "nickel", "cobalt", "invar", "gunmetal", "cobalt-steel", "copper-tungsten", "holmium" },
  brittle = { "glass", "silicon" },
  granules = { "plastic" },
  shreds = { "rubber" },
}
for class, names in pairs(known) do
  for index, name in ipairs(names) do
    definitions[name] = definitions[name] or {}
    definitions[name].scrap_class = class
    definitions[name].family = (index - 1) % classes[class].families + 1
  end
end
definitions.aluminum.family = definitions.aluminium.family

local metal_pool = {
  { "metal-hard", 1 }, { "metal-soft", 1 }, { "metal-light", 1 },
  { "metal-hard", 2 }, { "metal-soft", 2 }, { "metal-light", 2 },
  { "metal-hard", 3 },
}
local nonmetals = { coal = true, stone = true, sulfur = true, wood = true, concrete = true }

-- Use the complete sorted material set so prototype build order cannot change assignments.
function visuals.get(name, materials)
  local definition = definitions[name] or {}
  local custom = overrides.visuals[name] or {}
  local class = custom.scrap_class or definition.scrap_class
  local family = custom.scrap_family or (not custom.scrap_class and definition.family) or 1
  if not class and not nonmetals[name] and not (materials.solid_exact_scrap or {})[name] then
    local names, seen = {}, {}
    for _, list in ipairs({ materials.solid or {}, materials.fluid or {} }) do
      for _, candidate in ipairs(list) do
        if not seen[candidate] and not (definitions[candidate] or {}).scrap_class
          and not (overrides.visuals[candidate] or {}).scrap_class
          and not nonmetals[candidate] and not (materials.solid_exact_scrap or {})[candidate] then
          seen[candidate] = true
          names[#names + 1] = candidate
        end
      end
    end
    table.sort(names)
    for index, candidate in ipairs(names) do
      if candidate == name then
        local slot = metal_pool[(index - 1) % #metal_pool + 1]
        class, family = slot[1], slot[2]
        break
      end
    end
  end
  family = custom.scrap_family or family
  local spec = classes[class]
  if spec and family > spec.families then error("Ingredient Scrap: invalid scrap_family for " .. name) end
  local tint = overrides.tints[name] or definition.tint or { r = 0.7, g = 0.7, b = 0.7, a = 1 }
  if type(tint) == "string" then tint = util.color(tint) end
  return { tint = tint, size = spec and (spec.size or 128) or 64,
    prefix = spec and (spec.prefix or ("scrap-" .. class .. "-" .. family)) or nil }
end

function visuals.graphics(name, materials, icon_path)
  local visual = visuals.get(name, materials)
  local pictures = {}
  local size = visual.size
  local prefix = visual.prefix and (icon_path .. "scrap/" .. visual.prefix) or (icon_path .. "scrap")
  for index = 1, 3 do
    pictures[index] = {
      filename = prefix .. "-" .. index .. (visual.prefix and ".png" or "-64.png"),
      size = size, scale = 32 / size, tint = visual.tint,
      mipmap_count = visual.prefix and 3 or nil,
      flags = visual.prefix and { "icon" } or nil,
    }
  end
  return { icon = visual.prefix and (prefix .. "-1.png") or (icon_path .. "scrap-64.png"),
    icon_size = size, scale = 32 / size, tint = visual.tint }, pictures
end

visuals.legacy_tints = scrap_tints
return visuals
