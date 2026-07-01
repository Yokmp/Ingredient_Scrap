---Converts a hex color string into Factorio's runtime color table format.
local function color(hex)
  return util.color(hex)
end

local function apply_registered_tints(scrap_tints)
  local material_overrides = require("code.lib.material-overrides")
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
  -- glass            = tint_colors["glass"]
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
  silicon             = tint_colors["brown"],
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

return scrap_tints
