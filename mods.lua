
local _types = {}
local _results = {}
local mod_name = "__Ingredient_Scrap__"
function table.extend(t1, t2)
  for i = 1, #t2 do t1[#t1+1] = t2[i] end
end

function get_icon(name)
  local icon_path = mod_name.. "/graphics/icons/"
  local icon = icon_path..name.."-scrap.png"
  local icons = {
    missing   = icon_path.."missing-icon.png",
    recycle   = icon_path.."recycle.png",
    iron      = icon,
    copper    = icon,
    steel     = icon,
    titanium  = icon,
    lead      = icon,
    tungsten  = icon,
    imersium  = icon,
  }
  return icons[name] or icons.missing
end

if (mods['Molten_Metals']) then
  table.insert(_results, "ingot")
end
if (mods['Krastorio2']) then
  table.insert(_types, "imersium")
  table.insert(_results, "beam")
end
if (mods['angelssmelting']) then
  table.insert(_results, "ingot")
end
if (mods['bztitanium']) then
  table.insert(_types, "titanium")
end
if (mods['bztungsten']) then
  table.insert(_types, "tungsten")
end
if (mods['bzlead']) then
  table.insert(_types, "lead")
end
if (mods["bobplates"]) then
  
end

return {_types, _results}