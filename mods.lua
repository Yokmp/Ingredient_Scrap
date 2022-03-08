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
  yutil.table.extend(_types, {"aluminium", "brass", "bronze", "chrome", "cobalt-steel", "cobalt", "gold", "gunmetal", "invar", "lead", "manganese", "nickel",
  "nitinol", "platinum", "silicon", "silver", "tin", "titanium", "tungsten", "zinc"})
  yutil.table.extend(_results, {"ingot"})
end
if (mods["bobplates"]) then
  yutil.table.extend(_types, {"cobalt-steel", "copper-tungsten", "lead", "titanium", "zinc", "nickel", "aluminium", "tungsten-carbide", "tin", "silver", "gold",
  "brass", "bronze", "nitinol", "invar", "cobalt", "quartz", "silicon", "gunmetal", "tungsten" })
  yutil.table.extend(_results, {"alloy", "glass"})
end
-- if (mods['Clowns-Extended-Minerals']) then -- TODO
--     yutil.table.extend(_types, {"adamantite", "orichalcite", "phosphorite", "eliongate"})
--     if clowns and not clowns.special_vanilla then
--         yutil.table.extend(_types, {"antitate", "pro-galena", "saguinate", "meta-garnierite", "nova-leucoxene", "stannic", "plumbic", "manganic", "titanic", "phosphic"})
--     end
-- end
if (mods['bztitanium']) then
  yutil.table.extend(_types, {"titanium"})
end
if (mods['bztungsten']) then
  yutil.table.extend(_types, {"tungsten"})
end
if (mods['bzaluminum']) then
  yutil.table.extend(_types, {"aluminum"})
end
if (mods['bzlead']) then
  yutil.table.extend(_types, {"lead"})
end
if (mods['IndustrialRevolution']) then
  yutil.table.extend(_types, {"tin", "bronze", "gold", "lead", "cupronickel", "invar", "chromium", "stainless", "tellurium", "glass"})
  yutil.table.extend(_results, {"ingot", "mix"})
end



----------------
--    ICONS   --
----------------



if (mods['bztungsten'] and not mods["bobplates"] and not mods["Krastorio2"]) then
  yutil.scrap_icons["tungsten"] = yutil.get_icon_bycolor("grey", 1)
end
if (mods['bztitanium'] and not mods["Krastorio2"]) then
  yutil.scrap_icons["titanium"] = yutil.get_icon_bycolor("grey", 2)
end
if (mods['bzaluminum'] ) then
  yutil.scrap_icons["aluminum"] = yutil.get_icon_bycolor("grey", 1)
end
if (mods["bobplates"] and not mods['angelssmelting']) then
  yutil.scrap_icons["lead"] = yutil.get_icon_bycolor("blue", 1)
end
if (mods['angelssmelting']) then
  yutil.scrap_icons["lead"] = yutil.get_icon_bycolor("dgrey", 1)
  yutil.scrap_icons["tin"] = yutil.get_icon_bycolor("green", 1)
  yutil.scrap_icons["titanium"] = yutil.get_icon_bycolor("purple", 1)
end
if (mods['Krastorio2']) then
  yutil.scrap_icons["rare"] = yutil.get_icon_bycolor("dgrey", 1)
end



------------------
--    PATCHES   --
------------------


local patch ={

recipes = function ()
  -- if (mods['angelssmelting']) then
  -- end
  if (mods['Krastorio2']) then
    data.raw.recipe["recycle-lithium-scrap"].normal.results[1] = {name="lithium", amount=1}
    data.raw.recipe["recycle-lithium-scrap"].normal.ingredients = util.copy(data.raw.recipe["lithium-chloride"].ingredients)
    data.raw.recipe["recycle-lithium-scrap"].normal.ingredients[3] = { name = "lithium-scrap", amount = settings.startup["ingredient-scrap-needed"].value}
    data.raw.recipe["recycle-lithium-scrap"].normal.main_product = "lithium"
    data.raw.recipe["recycle-lithium-scrap"].expensive = nil -- uses normal
    data.raw.recipe["recycle-lithium-scrap"].category = "chemistry"
  end
  if (mods['IndustrialRevolution']) then
    yutil.set_item_icon("tellurium-scrap", "__Ingredient_Scrap__/graphics/icons/mods/recycle-tellurium-scrap.png")
    yutil.set_recipe_icon("recycle-tellurium-scrap", "__Ingredient_Scrap__/graphics/icons/mods/recycle-tellurium-scrap.png")
    yutil.set_item_icon("recycle-chromium-scrap", "__Ingredient_Scrap__/graphics/icons/mods/recycle-chromium-scrap.png")
    yutil.set_recipe_icon("recycle-chromium-scrap", "__Ingredient_Scrap__/graphics/icons/mods/recycle-chromium-scrap.png")
  end
  -- if (mods['bzaluminum'] ) then
  --   -- I CRY SILENTLY
  -- end
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
