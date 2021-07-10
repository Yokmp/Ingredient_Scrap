local yutil = require("functions")


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
  yutil.table.extend(_types, {"cobalt-steel", "copper-tungsten", "lead", "titanium", "zinc", "nickel", "aluminium", "tungsten-carbide", "tin", "silver", "gold",
  "brass", "bronze", "nitinol", "invar", "cobalt", "quartz", "silicon", "gunmetal", "tungsten" })
  yutil.table.extend(_results, {"alloy", "glass"})
end
if (mods['Clowns-Extended-Minerals']) then
    yutil.table.extend(_types, {"adamantite", "orichalcite", "phosphorite", "eliongate"})
    if clowns and not clowns.special_vanilla then
        yutil.table.extend(_types, {"antitate", "pro-galena", "saguinate", "meta-garnierite", "nova-leucoxene", "stannic", "plumbic", "manganic", "titanic", "phosphic"})
    end
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
if (mods['IndustrialRevolution']) then
  yutil.table.extend(_types, {"tin", "bronze", "gold", "lead", "cupronickel", "invar", "chromium", "stainless", "tellurium", "glass"})
  yutil.table.extend(_results, {"ingot", "mix"})
end


------------------
--    PATCHES   --
------------------


local patch ={

recipes = function ()
  if (mods['bztungsten'] and not mods["bobplates"] and not mods["Krastorio2"]) then
    data.raw.recipe["recycle-tungsten-scrap"].icons[1].icon = yutil.get_icon_bycolor("grey", 1)
    data.raw.item["tungsten-scrap"].icon = yutil.get_icon_bycolor("grey", 1)
  end
  if (mods['bztitanium'] and not mods["Krastorio2"]) then
    data.raw.recipe["recycle-titanium-scrap"].icons[1].icon = yutil.get_icon_bycolor("grey", 2)
    data.raw.item["titanium-scrap"].icon = yutil.get_icon_bycolor("grey", 2)
  end
  if (mods["bobplates"]) then
    data.raw.item["lead-scrap"].icon = yutil.get_icon_bycolor("blue", 1)
    data.raw.recipe["recycle-lead-scrap"].icons[1].icon = yutil.get_icon_bycolor("blue", 1)
  end
  if (mods['Krastorio2']) then
    data.raw.recipe["recycle-lithium-scrap"].normal.results[1] = {name="lithium", amount=1}
    data.raw.recipe["recycle-lithium-scrap"].normal.ingredients = util.copy(data.raw.recipe["lithium-chloride"].ingredients)
    data.raw.recipe["recycle-lithium-scrap"].normal.ingredients[3] = { name = "lithium-scrap", amount = settings.startup["ingredient-scrap-needed"].value}
    data.raw.recipe["recycle-lithium-scrap"].normal.main_product = "lithium"
    data.raw.recipe["recycle-lithium-scrap"].expensive = nil -- uses normal
    data.raw.recipe["recycle-rare-scrap"].icons[1].icon = yutil.get_icon_bycolor("dgrey", 1)
    data.raw.item["rare-scrap"].icon = yutil.get_icon_bycolor("dgrey", 1)
  end
  if (mods['IndustrialRevolution']) then
    data.raw.recipe["recycle-tellurium-scrap"].icon = "__Ingredient_Scrap__/graphics/icons/mods/recycle-tellurium-scrap.png"
    data.raw.recipe["recycle-tellurium-scrap"].icon_size = 64
    data.raw.recipe["recycle-tellurium-scrap"].icon_mipmaps = 4
    data.raw.recipe["recycle-tellurium-scrap"].icons = nil
    data.raw.item["tellurium-scrap"].icon = "__Ingredient_Scrap__/graphics/icons/mods/tellurium-scrap.png"
    data.raw.item["tellurium-scrap"].icon_size = 64
    data.raw.item["tellurium-scrap"].icon_mipmaps = 4
    data.raw.item["tellurium-scrap"].icons = nil
    data.raw.recipe["recycle-chromium-scrap"].icon = "__Ingredient_Scrap__/graphics/icons/mods/recycle-chromium-scrap.png"
    data.raw.recipe["recycle-chromium-scrap"].icon_size = 64
    data.raw.recipe["recycle-chromium-scrap"].icon_mipmaps = 4
    data.raw.recipe["recycle-chromium-scrap"].icons = nil
    data.raw.item["chromium-scrap"].icon = "__Ingredient_Scrap__/graphics/icons/mods/chromium-scrap.png"
    data.raw.item["chromium-scrap"].icon_size = 64
    data.raw.item["chromium-scrap"].icon_mipmaps = 4
    data.raw.item["chromium-scrap"].icons = nil
  end
end,
technology = function (tech_name)
  local _return = true
  if (mods['bzlead']) then
    if tech_name == "lead-matter-processing" then return false end
  end
  if (mods['Krastorio2']) then
    if tech_name == "kr-lithium-sulfur-battery"
    or tech_name == "kr-iron-pickaxe"
    or tech_name == "kr-matter-iron-processing"
    or tech_name == "kr-matter-copper-processing"
    or tech_name == "kr-matter-rare-metals-processing"
    then _return = false end
  end
  return _return
end
}

return {_types, _results, patch}
