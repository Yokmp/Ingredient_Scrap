
-- scrap_types = {"iron", "copper", "steel"}
-- item_types = {"stick", "plate"}

-- local yutil = require("functions.functions")

-- -- testing
-- local debug_test_recipes = {"gun-turret", "electronic-circuit", "tank"}


-- function get_scrap_types(scrap_type, item_types)

--   for i, i_type in ipairs(item_types) do
--     local _name = scrap_type.."-"..i_type
--     if data.raw.item[_name] then
--       return { scrap = scrap_type.."-scrap", item = _name, amount = 0 }
--     end
--   end

--   return false
-- end


-- function scrap_set_results(data_recipe)
--   local ingredients = {}
--   local results = {}

--   if data_recipe.ingredients and data_recipe.ingredients[1] then

--     if data_recipe.result then
--       results[1] = yutil.add_pairs( {data_recipe.result, data_recipe.result_count} )
--     end
--     if data_recipe.results and data_recipe.results[1] then
--       for ri, result in ipairs(data_recipe.ingredients) do
--         results[ri] = yutil.add_pairs( result )
--       end
--     end

--     for i, ingredient in ipairs(data_recipe.ingredients) do
--       ingredients = yutil.add_pairs(ingredient)
--       for _, _type in ipairs(scrap_types) do
--         if string.match(ingredient.name, _type) and get_scrap_types(_type, item_types) then





--         end
--       end
--     end
--   end


--   if data_recipe.normal and data_recipe.normal.ingredients[1] then
--     for i, ingredient in ipairs(data_recipe.normal.ingredients) do
--       ingredients.normal[i] = yutil.add_pairs(ingredient)
--     end
--   end
--   if data_recipe.expensive and data_recipe.expensive.ingredients[1] then
--     for i, ingredient in ipairs(data_recipe.expensive.ingredients) do
--       ingredients.expensive[i] = yutil.add_pairs(ingredient)
--     end
--   end


-- end
-- for _, value in ipairs(debug_test_recipes) do
--   log(serpent.block( scrap_set_results(data.raw.recipe[value]), {comment = false}))
-- end

-- assert(1==2, " D I E")