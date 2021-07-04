require("functions")


------------------
--    PRESETS   --
------------------

local _types = {}
local _results = {}


if (mods['Molten_Metals']) then
  yutil.table.extend(_results, {"ingot"})
end
if (mods['Krastorio2']) then
  yutil.table.extend(_types, {"imersium", "lithium", "rare"})
  yutil.table.extend(_results, {"plate", "beam", "metals", "chloride"})
end
if (mods['angelssmelting']) then
  yutil.table.extend(_results, {"ingot"})
end
if (mods["bobplates"]) then
  yutil.table.extend(_types, {"cobalt-steel", "copper-tungsten", "lead", "titanium", "zinc", "nickel", "aluminium", "tungsten", "tin", "silver", "gold",
  "brass", "bronze", "nitinol", "invar", "cobalt", "quartz", "silicon", "gunmetal", "aluminium" })
  yutil.table.extend(_results, {"alloy", "glass"})
end
if (mods['bztitanium']) then
  yutil.table.extend(_types, {"titanium"})
end
if (mods['bztungsten']) then
  yutil.table.extend(_types, {"tungsten"})
end
if (mods['bzlead']) then
  yutil.table.extend(_types, {"lead"})
end


------------------
--    PATCHES   --
------------------


local patch ={

recipes = function ()
  if (mods['bztitanium'] and not mods["bobplates"] and not mods["Krastorio2"]) then
    data.raw.recipe["recycle-titanium-scrap"].icons[1].icon = yutil.get_icon_bycolor("dgrey", 2)
    data.raw.item["titanium-scrap"].icon = yutil.get_icon_bycolor("dgrey", 2)
  end
  if (mods["bobplates"]) then
      data.raw.item["lead-scrap"].icon = yutil.get_icon_bycolor("blue", 1)
      data.raw.recipe["recycle-lead-scrap"].icons[1].icon = yutil.get_icon_bycolor("blue", 1)
  end
  if (mods['Krastorio2']) then
      data.raw.recipe["recycle-lithium-scrap"].normal.results[1] = {name="lithium", amount=1}
      data.raw.recipe["recycle-lithium-scrap"].normal.ingredients[2] = {type="fluid",name="chlorine", amount=10}
      data.raw.recipe["recycle-lithium-scrap"].normal.main_product = "lithium"
      data.raw.recipe["recycle-lithium-scrap"].expensive = nil -- uses normal
      data.raw.recipe["recycle-rare-scrap"].icons[1].icon = yutil.get_icon_bycolor("dgrey", 1)
      data.raw.item["rare-scrap"].icon = yutil.get_icon_bycolor("dgrey", 1)
  end
end,
technology = function (tech_name)
  local _return = true
  if (mods['Krastorio2'] or mods['bzlead']) then
    if tech_name == "kr-lithium-sulfur-battery"
    or tech_name == "kr-iron-pickaxe"
    or tech_name == "kr-matter-iron-processing"
    or tech_name == "kr-matter-copper-processing"
    or tech_name == "kr-matter-rare-metals-processing"
    or tech_name == "lead-matter-processing"
    then _return = false end
  end
  return _return
end
}

return {_types, _results, patch}