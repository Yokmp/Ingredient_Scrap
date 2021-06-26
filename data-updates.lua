scrap_types = {"iron", "copper", "steel"}
item_types = {"plate"}

local yutil = require("functions.functions")
-------------------
--    UTILITY    --
-------------------

-- local table = {
--   "result",
--   { "results-amount", 2},
--   { name = "pairs", amount = 12},
--   {},
-- }

-- -- local add_pairs = {  __call = function(self, name, amount)
-- --     if type(name) == "string" then
-- --       local _tname = tostring(type(name))
-- --       if type(amount) == "number" then amount = amount else
-- --         local _tamount = tostring(type(amount))
-- --         amount = 1
-- --         log(" Warning: add_pairs(".._tname..", ".._tamount..") - amount: implicitly set to 1")
-- --       end
-- --       return { name = name, amount = amount} end
-- --       log(" Warning: add_pairs("..type(name)..", "..type(amount)..") - skipped")
-- --       return name end,}
-- -- setmetatable(add_pairs, add_pairs)


-- setmetatable(table, {
--     __index = table,
--     __newindex = function(self, key, value) error("Attempt to modify read-only table") end,
--     __metatable = false
--   })

-- -- table[5] = {"test"}

-- local test = {}
-- for index, value in ipairs(table) do
--   local _t = util.add_pairs(value)
--   test[index] = _t
-- end

-- log(serpent.block(test))
-- assert(1==2, "TEST")

-- ---adds name and amount keys to ingredients and returns a new table
-- ---@param _table table ``{string, number?}``
-- ---@return table ``{ name = "name", amount = n }``
-- function add_pairs(_table)
--   if _table and _table.name then return _table end      --they can be empty and would be "valid"
--   if not _table[1] or _table[3] then return _table end  --exclude malformed/unfinished tables

--   local _t = _table

--   _t.type   = "item"
--   _t.name   = _t[1]      ;  _t[1] = nil
--   _t.amount = _t[2] or 1 ;  _t[2] = nil

--   return _t
-- end

-- local debug_test_item = "gun-turret"
local debug_test_item = "electronic-circuit"

---holds the return table template
local _return_template_ = {
    recipe = {
                    ingredient_types = {}, ingredients = {}, results = {}, enabled = true,
      normal    = { ingredient_types = {}, ingredients = {}, results = {}, enabled = true,},
      expensive = { ingredient_types = {}, ingredients = {}, results = {}, enabled = true,},

    },

    technology = {
                    effects = {}, prerequisites = {}, unit = {},
      normal    = { effects = {}, prerequisites = {}, unit = {}, },
      expensive = { effects = {}, prerequisites = {}, unit = {}, },
    },

  }
new_template = util.table.deepcopy(_return_template_)



-- start loop here
local _return = new_template


function get_scrap_types(scrap_types)
  local scrap_results = {}

  setmetatable(scrap_results, { __newindex = function(self, k, v)
    rawset(self, k, { type = k, scrap = k.."-scrap", item = v, })
  end })

  for _, s_type in ipairs(scrap_types) do
    for i, i_type in ipairs(item_types) do
      local _name = s_type.."-"..i_type
      if data.raw.item[_name] then
        scrap_results[s_type] = _name
      end
    end
  end

  return scrap_results
end
-- log(serpent.block(get_scrap_types(scrap_types)))
-- assert(1==2, "get_scrap_types()")


function get_recipe_ingredients(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

    if data_recipe.ingredients and data_recipe.ingredients[1] then
      for i, ingredient in ipairs(data_recipe.ingredients) do
        _return.recipe.ingredients[i] = yutil.add_pairs(ingredient)
      end
    end
    if data_recipe.normal and data_recipe.normal.ingredients[1] then
      for i, ingredient in ipairs(data_recipe.normal.ingredients) do
        _return.recipe.normal.ingredients[i] = yutil.add_pairs(ingredient)
      end
    end
    if data_recipe.expensive and data_recipe.expensive.ingredients[1] then
      for i, ingredient in ipairs(data_recipe.expensive.ingredients) do
        _return.recipe.expensive.ingredients[i] = yutil.add_pairs(ingredient)
      end
    end
  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end

  return _return.recipe
end
get_recipe_ingredients(debug_test_item)
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "get_recipe_ingredients()")


function get_recipe_ingredient_types(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then

      if _return.recipe.ingredients[1] then
        for _, ingredient in ipairs(_return.recipe.ingredients) do
          for _, _type in ipairs(scrap_types) do

            _return.recipe.ingredient_types[_type] = _return.recipe.ingredient_types[_type] or 0
            if string.match(ingredient.name, _type) then
              _return.recipe.ingredient_types[_type] = _return.recipe.ingredient_types[_type] +1
            end
            if _return.recipe.ingredient_types[_type] < 1 then _return.recipe.ingredient_types[_type] = nil end

          end
        end
      end

      if _return.recipe.normal.ingredients[1] then
        for _, ingredient in ipairs(_return.recipe.normal.ingredients) do
          for _, _type in ipairs(scrap_types) do

            _return.recipe.normal.ingredient_types[_type] = _return.recipe.normal.ingredient_types[_type] or 0
            if string.match(ingredient.name, _type) then
              _return.recipe.normal.ingredient_types[_type] = _return.recipe.normal.ingredient_types[_type] +1
            end
            if _return.recipe.normal.ingredient_types[_type] < 1 then _return.recipe.normal.ingredient_types[_type] = nil end

          end
        end
      end

      if _return.recipe.expensive.ingredients[1] then
        for _, ingredient in ipairs(_return.recipe.expensive.ingredients) do
          for _, _type in ipairs(scrap_types) do

            _return.recipe.expensive.ingredient_types[_type] = _return.recipe.expensive.ingredient_types[_type] or 0
            if string.match(ingredient.name, _type) then
              _return.recipe.expensive.ingredient_types[_type] = _return.recipe.expensive.ingredient_types[_type] +1
            end
            if _return.recipe.expensive.ingredient_types[_type] < 1 then _return.recipe.expensive.ingredient_types[_type] = nil end

          end
        end
      end

  end
  return _return.recipe
end
get_recipe_ingredient_types(debug_test_item)
-- log(serpent.block(_return.recipe))
-- assert(1==2, "get_recipe_ingredient_types()")


function get_recipe_results(recipe_name)

  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

    if data_recipe.result then
      _return.recipe.results[1] = yutil.add_pairs( {data_recipe.result, data_recipe.result_count} )
    end
    if data_recipe.results and data_recipe.results[1] then
      for i, result in ipairs(data_recipe.ingredients) do
        _return.recipe.results[i] = yutil.add_pairs( result )
      end
    end
    if data_recipe.normal then
      if data_recipe.normal.results and data_recipe.normal.results[1] then
        for i, result in ipairs(data_recipe.normal.results) do
          _return.recipe.normal.results[i] = yutil.add_pairs( result )
        end
      elseif data_recipe.normal.result then
        _return.recipe.normal.results[1] = yutil.add_pairs( {data_recipe.normal.result, data_recipe.normal.result_count} )
      end
    end
    if data_recipe.expensive then
      if data_recipe.expensive.results and data_recipe.expensive.results[1] then
        for i, result in ipairs(data_recipe.expensive.results) do
          _return.recipe.expensive.results[i] = yutil.add_pairs( result )
        end
      elseif data_recipe.expensive.result then
        _return.recipe.expensive.results[1] = yutil.add_pairs( {data_recipe.expensive.result, data_recipe.expensive.result_count} )
      end
    end
  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end

  return _return.recipe
end
get_recipe_results(debug_test_item)
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "get_recipe_results()")


function recipe_is_enabled(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

    if data_recipe.enabled then
      _return.recipe.enabled = data_recipe.enabled
    end
    if data_recipe.normal.enabled then
      _return.recipe.normal.enabled = data_recipe.normal.enabled
    end
    if data_recipe.expensive.enabled  then
      _return.recipe.expensive.enabled = data_recipe.expensive.enabled
    end

  end
  return _return.recipe
end
recipe_is_enabled(debug_test_item)
log(serpent.block( _return.recipe ))
assert(1==2, "recipe_is_enabled()")




--[[
  for each recipe:

  - generate possible scrap recycle results

  - get recipe ingredients OK
  - get scrap types OK
  - get recipe results OK
  - get enabled

  -generate scrap

  -insert scrap

  - search in technologies for matching scrap recycle results
    - get enabled of recipe
    - set disabled for recycle recipe if found in tech

  - generate recycle recipe
    - insert in tech if disabled
]]
