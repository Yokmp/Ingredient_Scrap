require("functions")

local _types = {}
local _results = {}
local mod_name = "__Ingredient_Scrap__"

function table.extend(t1, t2)
  for i = 1, #t2 do t1[#t1+1] = t2[i] end return t1
end

---comment
---@return string
function get_icon(name)
  local icon_path = mod_name.. "/graphics/icons/"
  local icon = icon_path..name.."-scrap.png"
  local icons = {
    missing   = icon_path.."missing-icon.png",
    recycle   = icon_path.."recycle.png",
    iron      = icon,
    copper    = icon,
    steel     = icon,
    imersium      = get_icon_bycolor("purple", 1),
    lead          = get_icon_bycolor("brown", 3),
    titanium      = get_icon_bycolor("dgrey", 2),
    zinc          = get_icon_bycolor("grey", 3),
    nickel        = get_icon_bycolor("grey", 2),
    aluminium     = get_icon_bycolor("grey", 1),
    tungsten      = get_icon_bycolor("grey", 2),
    tin           = get_icon_bycolor("grey", 2),
    silver        = get_icon_bycolor("grey", 1),
    gold          = get_icon_bycolor("yellow", 2),
    brass         = get_icon_bycolor("yellow", 1),
    bronze        = get_icon_bycolor("orange", 1),
    nitinol       = get_icon_bycolor("grey", 2),
    invar         = get_icon_bycolor("grey", 3),
    cobalt        = get_icon_bycolor("blue", 2),
    -- glass      = get_icon_bycolor("purple", 1),
    -- silicon    = get_icon_bycolor("purple", 1),
    gunmetal      = get_icon_bycolor("yellow", 1),
    ["cobalt-steel"]  = get_icon_bycolor("blue", 2),
    ["copper-tungsten"]  = get_icon_bycolor("red", 2),
  }
  return icons[name] or icons.missing
end

function get_scrap_icons(item, result)
  local icon_item, icon_size, icon_mipmaps
  if data.raw.item[result] then
    if data.raw.item[result].icon then
      icon_item = data.raw.item[result].icon
      icon_size = data.raw.item[result].icon_size
      icon_mipmaps = data.raw.item[result].icon_mipmaps
    elseif data.raw.item[item].icon then
      icon_item = data.raw.item[item].icon
      icon_size = data.raw.item[item].icon_size
      icon_mipmaps = data.raw.item[item].icon_mipmaps
    end
  end
  return {
    {
      icon = get_icon(item),
      icon_size = 64, icon_mipmaps = 4,
      scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    },
    {
      icon = icon_item or get_icon("missing"),
      icon_size = icon_size or 64, icon_mipmaps = icon_mipmaps or 4,
      scale = 0.25, shift = util.by_pixel(0, 0), tint = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    },
    {
      icon = get_icon("recycle"),
      icon_size = 64, icon_mipmaps = 4,
      scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 0.8, g = 1.0, b = 0.8, a = 1.0 }
    },
  }
end

if (mods['Molten_Metals']) then
  table.extend(_results, {"ingot"})
end
if (mods['Krastorio2']) then
  table.extend(_types, {"imersium"})
  table.extend(_results, {"beam"})
end
if (mods['angelssmelting']) then
  table.extend(_results, {"ingot"})
end
if (mods['bztitanium']) then
  table.extend(_types, {"titanium"})
end
if (mods['bztungsten']) then
  table.extend(_types, {"tungsten"})
end
if (mods['bzlead']) then
  table.extend(_types, {"lead"})
end
if (mods["bobplates"]) then
  table.extend(_types, {"lead", "titanium", "zinc", "nickel", "aluminium", "copper-tungsten", "tungsten", "tin", "silver", "gold",
  "brass", "bronze", "nitinol", "invar", "cobalt-steel", "cobalt", --[["glass", "silicon",]] "gunmetal" })
  table.extend(_results, {"plate", "alloy", "gear-wheel", "bearing"})

  local tech = { {"cobalt","cobalt"}, {"cobalt-steel","cobalt"}, {"nitinol", "nitinol"},
    {"silver", "lead"}, {"zinc", "zinc"}, {"brass", "zinc"}, {"gunmetal", "zinc"}} -- the bad batch
  for _, name in ipairs(tech) do
    data.raw.recipe["recycle-"..name[1].."-scrap"] = {enabled = false}
    table.insert( data.raw.technology[name[2].."-processing"].effects, { recipe = "recycle-"..name[1].."-scrap", type = "unlock-recipe" } )
  end
end

return {_types, _results}