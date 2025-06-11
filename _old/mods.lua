local util = require("functions")


------------------
--    PRESETS   --
------------------

local _types = {}
local _results = {}
local _blacklist = {}

-- if (mods['Molten_Metals']) then
--   yutil.table.extend(_results, {"ingot"})
-- end
if (mods['Krastorio2']) then
  util.table.extend(_types, { "imersium", "lithium", "rare" })
  util.table.extend(_results, { "plate", "beam", "metals", "chloride" })
end
if (mods['angelssmelting']) then
  util.table.extend(_types,
    { "aluminium", "brass", "bronze", "chrome", "cobalt-steel", "cobalt", "gold", "gunmetal", "invar", "lead",
      "manganese", "nickel",
      "nitinol", "platinum", "silicon", "silver", "tin", "titanium", "tungsten", "zinc" })
  util.table.extend(_results, { "ingot" })
end
if (mods["bobplates"]) then
  util.table.extend(_types,
    { "cobalt-steel", "copper-tungsten", "lead", "titanium", "zinc", "nickel", "aluminium", "tungsten-carbide", "tin",
      "silver", "gold",
      "brass", "bronze", "nitinol", "invar", "cobalt", "quartz", "silicon", "gunmetal", "tungsten" })
  util.table.extend(_results, { "alloy", "glass" })
end
-- if (mods['Clowns-Extended-Minerals']) then --//TODO reverse match/generation of recipes like plates-iron
--     yutil.table.extend(_types, {"adamantite", "orichalcite", "phosphorite", "eliongate"})
--     if clowns and not clowns.special_vanilla then
--         yutil.table.extend(_types, {"antitate", "pro-galena", "saguinate", "meta-garnierite", "nova-leucoxene", "stannic", "plumbic", "manganic", "titanic", "phosphic"})
--     end
-- end
if (mods['bztitanium']) then
  util.table.extend(_types, { "titanium" })
end
if (mods['bztungsten']) then
  util.table.extend(_types, { "tungsten" })
end
if (mods['bzaluminum']) then
  util.table.extend(_types, { "aluminum" })
end
if (mods['bzlead']) then
  util.table.extend(_types, { "lead" })
end
if (mods['IndustrialRevolution']) then
  util.table.extend(_types,
    { "tin", "bronze", "gold", "lead", "cupronickel", "invar", "chromium", "stainless", "tellurium", "glass" })
  util.table.extend(_results, { "ingot", "mix" })
end



----------------
--    ICONS   --
----------------



if (mods['bztungsten'] and not mods["bobplates"] and not mods["Krastorio2"]) then
  util.scrap_icons["tungsten"] = util.get_icon_bycolor("grey", 1)
end
if (mods['bztitanium'] and not mods["Krastorio2"]) then
  util.scrap_icons["titanium"] = util.get_icon_bycolor("grey", 2)
end
if (mods['bzaluminum']) then
  util.scrap_icons["aluminum"] = util.get_icon_bycolor("grey", 1)
end
if (mods["bobplates"] and not mods['angelssmelting']) then
  util.scrap_icons["lead"] = util.get_icon_bycolor("blue", 1)
end
if (mods['angelssmelting']) then
  util.scrap_icons["lead"] = util.get_icon_bycolor("dgrey", 1)
  util.scrap_icons["tin"] = util.get_icon_bycolor("green", 1)
  util.scrap_icons["titanium"] = util.get_icon_bycolor("purple", 1)
end
if (mods['Krastorio2']) then
  util.scrap_icons["rare"] = util.get_icon_bycolor("dgrey", 1)
end



--------------------
--    BLACKLIST   --
--------------------


local str = tostring(settings.startup["yis-unlock-scraps"].value)
-- str = type(str) == "string" and str or ""
for word in string.gmatch(str, '[^,%s]+') do
  _blacklist[#_blacklist + 1] = word
end
-- use ingame settings if possible!
-- if (mods['SeaBlock'] ) then
-- yutil.table.extend(_blacklist, { "copper-scrap", "iron-scrap" })
-- end


------------------
--    PATCHES   --
------------------


local patch = {
  is_blacklisted = function(item)
    if #_blacklist > 0 then
      for _, v in ipairs(_blacklist) do
        if item == v then return true end
      end
    end
    return false
  end,

  recipes = function()
    -- if (mods['angelssmelting']) then
    -- end
    if (mods['Krastorio2']) then
      data.raw.recipe["recycle-lithium-scrap"].results[1] = { type="item", name = "lithium", amount = 1 } ---@type table
      data.raw.recipe["recycle-lithium-scrap"].ingredients = util.copy(data.raw.recipe["lithium-chloride"].ingredients)
      data.raw.recipe["recycle-lithium-scrap"].ingredients[3] = { type="item", name = "lithium-scrap", amount = settings.startup
      ["yis-needed"].value } ---@type number
      data.raw.recipe["recycle-lithium-scrap"].main_product = "lithium"
      data.raw.recipe["recycle-lithium-scrap"].category = "chemistry"
    end
    if (mods['IndustrialRevolution']) then
      util.set_item_icon("tellurium-scrap", "__Ingredient_Scrap__/graphics/icons/mods/recycle-tellurium-scrap.png")
      util.set_recipe_icon("recycle-tellurium-scrap",
        "__Ingredient_Scrap__/graphics/icons/mods/recycle-tellurium-scrap.png")
      util.set_item_icon("recycle-chromium-scrap", "__Ingredient_Scrap__/graphics/icons/mods/recycle-chromium-scrap.png")
      util.set_recipe_icon("recycle-chromium-scrap",
        "__Ingredient_Scrap__/graphics/icons/mods/recycle-chromium-scrap.png")
    end
    -- if (mods['bzaluminum'] ) then
    --   -- I CRY SILENTLY
    -- end
    -- if (mods['SeaBlock'] ) then -- or is this caused by angels?
    --   ylib.recipe.add_result("assembling-machine-2", "iron-scrap", 2)
    --   ylib.recipe.add_result("pipe", "iron-scrap", 1)
    --   ylib.recipe.add_result("iron-gear-wheel", "iron-scrap", 2)
    --   ylib.recipe.add_result("steam-engine", "iron-scrap", 18)
    --   ylib.recipe.add_result("electric-ore-crusher", "iron-scrap", 15)
    --   ylib.recipe.add_result("copper-pipe", "copper-scrap", 1)
    -- end
  end,

  technology = function(tech_name)
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
      then
        _return = false
      end
      if mods["bzaluminum"] and tech_name == "aluminum-matter-processing" then
        _return = false
      end
    end

    return _return
  end
}

return { _types, _results, patch }
