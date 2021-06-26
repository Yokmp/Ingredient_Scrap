
--[[  This table holds the phrases and looks into the recipes with string.match() to find them.
  So iron will match iron-plate and hardenend-iron-plate. Even superironbar would be a match.
  To exclude like copper-plate but still use copper-cables just be more specific. It is also used
  to contruct the scrap-items like ``iron-scrap``.]]
scrap_types = {"iron", "copper", "steel"}
--[[  This table holds the result suffix which is then be constructed to ``_types.."-".._results`` (eg iron-plate).
  Like the _types table, this one also goes by priority, so position 1 is taken if possible, if not pos 2 will be checked until
  it runs out of options, then the script will log it and **ignore** the recipe.
  As there will be no recycling of this scrap-item place some kind of fallback at the end. "*plate*"" is a good candidate.]]
item_types = {"plate"} --, "ingot"}




-- require("functions.functions")
-- require("functions.util-recipe")
-- require("functions.util-technology")
-- require("functions.util-scrap")

-- local mod = require("mods")
-- _types = table.extend(mod[1], _types)
-- _results = table.extend(mod[2], _results)

-- log(serpent.block(_types))
-- assert(1==2)

-- local scrap_item = {}
-- local scrap_recipe = {}
-- local techs = {}

-- --prototype scrap item
-- --prototype scrap recipe
-- --add to recipe results
-- --add to technology effects



-- for _, scrap_type in ipairs(scrap_types) do
--   log("Creating Items")
--   table.insert(scrap_item, get_scrap_prototype_item(scrap_type))
--   log("Creating Recipes")
--   table.insert(scrap_recipe, get_scrap_prototype_recipe(scrap_type))

--   log("Adding Technology Effect for: "..scrap_type)
--   for _, item_type in ipairs(item_types) do
--     local t = get_technology_by_recipe(scrap_type.."-"..item_type)
--     if #t > 0 then techs[scrap_type] = t end
--   end

--   if techs[scrap_type] then
--     for techs_index, tech_name in ipairs(techs[scrap_type]) do
--         log("Inserting Technology: "..tech_name)
--         technology_add_effect(tech_name, "recycle-"..scrap_type.."-scrap" )
--     end
--   end

-- end

-- log("Adding Scrap Results")
--   for recipe_name, data_recipe in pairs(data.raw.recipe) do
--     scrap_add_result(data_recipe)
--   end


-- data:extend(scrap_item)
-- data:extend(scrap_recipe)

-- log(serpent.block(data.raw.technology["steel-processing"].effects))
-- log(serpent.block(data.raw.recipe["steel-plate"]))
-- log(serpent.block(data.raw.recipe["speed-module"]))
-- log(serpent.block(data.raw.recipe["basic-oil-procesing"]))
-- log(serpent.block(scrap_item))
-- for i, recipes in ipairs(scrap_recipe) do
--   log(serpent.block(recipes.name))
--   -- data.raw.recipe[recipes.name] = recipes
-- end


-- assert(1==2, "data-updates")