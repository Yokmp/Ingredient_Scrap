scrap_types = {"iron", "copper", "steel"}
item_types = {"plate"}

local yutil = require("functions.functions")
-------------------
--    UTILITY    --
-------------------


-- local debug_test_item = "gun-turret"
-- local debug_test_item = "electronic-circuit"
local debug_test_item = "tank"

---holds the return table template
local _return_template_ = {
    recipe = {    -- determine and cache                                     get -> modify -> replace
                    ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = "",
      normal    = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = "", },
      expensive = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = "", },

    },
  }
new_return = util.table.deepcopy(_return_template_)


function filter_scrap_types()
  local _return = {}
  for index, s_type in ipairs(scrap_types) do
    for _, i_type in ipairs(item_types) do
      if data.raw.item[s_type.."-"..i_type] then
        _return[index] = s_type
      else
        log(" No Result for: "..s_type)
      end
    end
  end
  scrap_types = _return
  return _return
end
filter_scrap_types()
-- assert(1==2, "filter_scrap_types()")


function get_scrap_types(scrap_type, item_types)

  for i, i_type in ipairs(item_types) do
    local _name = scrap_type.."-"..i_type
    if data.raw.item[_name] then
      return { scrap = scrap_type.."-scrap", item = _name, amount = 0 }
    end
  end

  return false
end
-- log(serpent.block(get_scrap_types(scrap_types[1], item_types)))
-- assert(1==2, "get_scrap_types()")




------------------
--    RECIPE    --
------------------



-- start loop here
local _return = new_return


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
    -- local _scrap_types = get_scrap_types(scrap_types, item_types)

    if _return.recipe.ingredients[1] then
      for _, ingredient in ipairs(_return.recipe.ingredients) do
        for _, _type in ipairs(scrap_types) do

          if string.match(ingredient.name, _type) and get_scrap_types(_type, item_types) then
            _return.recipe.ingredient_types[_type] = get_scrap_types(_type, item_types)
            _return.recipe.ingredient_types[_type].amount = _return.recipe.ingredient_types[_type].amount +1
          end
        end
      end
    end

      if _return.recipe.normal.ingredients[1] then
        for _, ingredient in ipairs(_return.recipe.normal.ingredients) do
          for _, _type in ipairs(scrap_types) do

            if string.match(ingredient.name, _type) and get_scrap_types(_type, item_types) then
              _return.recipe.normal.ingredient_types[_type] = get_scrap_types(_type, item_types)
              _return.recipe.normal.ingredient_types[_type].amount = _return.recipe.normal.ingredient_types[_type].amount +1
            end
          end
        end
      end

      if _return.recipe.expensive.ingredients[1] then
        for _, ingredient in ipairs(_return.recipe.expensive.ingredients) do
          for _, _type in ipairs(scrap_types) do

            if string.match(ingredient.name, _type) and get_scrap_types(_type, item_types) then
              _return.recipe.expensive.ingredient_types[_type] = get_scrap_types(_type, item_types)
              _return.recipe.expensive.ingredient_types[_type].amount = _return.recipe.expensive.ingredient_types[_type].amount +1
            end
          end
        end
      end

  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
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

      if data_recipe.enabled == false then _return.recipe.enabled = false end
      if data_recipe.normal.enabled == false then _return.recipe.normal.enabled = false end
      if data_recipe.expensive.enabled == false then _return.recipe.expensive.enabled = false end

  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end
  return _return.recipe
end
recipe_is_enabled(debug_test_item)
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "recipe_is_enabled()")


function recipe_get_main_product(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

    if not data_recipe.icon or not data_recipe.subgroup then -- ? localized_string - these need their own functions ?

      if data_recipe.main_product and not data_recipe.main_product == "" then
        _return.recipe.main_product = data_recipe.main_product
      elseif _return.recipe.results[1] then
        _return.recipe.main_product = _return.recipe.results[1].name
      end

      if data_recipe.normal.main_product and not data_recipe.normal.main_product == "" then
        _return.recipe.normal.main_product = data_recipe.normal.main_product
      elseif _return.recipe.normal.results[1] then
        _return.recipe.normal.main_product = _return.recipe.normal.results[1].name
      end

      if data_recipe.expensive.main_product and not data_recipe.expensive.main_product == "" then
        _return.recipe.expensive.main_product = data_recipe.expensive.main_product
      elseif _return.recipe.expensive.results[1] then
        _return.recipe.expensive.main_product = _return.recipe.expensive.results[1].name
      end

    end

  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end
    return _return.recipe
end
recipe_get_main_product(debug_test_item)
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "recipe_get_main_product()")




-----------------
--    SCRAP    --
-----------------



function get_recycle_recipe_name(scrap_name)
  if data.raw.recipe["recycle-"..scrap_name] then
    return nil
  end
  return "recycle-"..scrap_name
end
-- log(serpent.block( get_recycle_recipe_name("copper-scrap") ))
-- assert(1==2, "get_recycle_recipe_name()")


function get_recycle_result_name(scrap_type)
  if type(scrap_type) ~= "string" then return nil end
    for _, i_type in ipairs(item_types) do
      if data.raw.item[scrap_type.."-"..i_type] then
        return scrap_type.."-"..i_type
      end
    end
end
-- log(serpent.block( get_recycle_result_name("copper") ))
-- assert(1==2, "get_recycle_result_name()")


-- REWRITE! all in one: if result is found make item and recipe

function make_scrap_items(scrap_type, scrap_icon, stack_size)
  local _item = {}
  scrap_type = scrap_type or scrap_types
  for i, s_type in ipairs(scrap_type) do
    local s_name = s_type.. "-scrap"
    if not data.raw.item[s_name] then
      _item[i] = {
        type = "item",
        name = s_name,
        icon = scrap_icon or yutil.get_icon(s_type),
        icon_size = 64, icon_mipmaps = 4,
        subgroup = "raw-material",
        order = "z["..s_type.."-scrap]",
        stack_size = stack_size or 100
      }
    end
  end
  if #_item > 0 then data:extend(_item)
  return _item end
end
-- log(serpent.block( make_scrap_items() ))
-- assert(1==2, "make_scrap_items()")


function make_recycle_recipes(scrap_type)
  scrap_type = {scrap_type} or scrap_types
  local _recipe = {}
  for i, s_type in ipairs(scrap_type) do
    local s_name = s_type.. "-scrap"
    if data.raw.item[s_name] then
      local recipe_name = "recycle-" ..s_type.. "-scrap"
      local result_name = get_recycle_result_name(s_type)
      local _order = data.raw.recipe[s_name].order


      _recipe[i] = {
        type = "recipe",
        name = recipe_name,
        localised_name = {"recipe-name."..recipe_name},
        icons = yutil.get_scrap_icons(scrap_type, s_name),
        subgroup = "raw-material",
        category = "smelting",
        order = _order or "z",
        energy_required = 3.2,
        always_show_products = true,
        allow_as_intermediate = false,
        enabled = _return.recipe.enabled,
        normal = {
          enabled = _return.recipe.normal.enabled,
          ingredients = {{ name = s_name, amount = settings.startup["ingredient-scrap-needed"].value}},
          results = {{ name = result_name, amount = 1 }}
        },
        expensive = {
          enabled = _return.recipe.normal.enabled,
          ingredients = {{ name = s_name, amount = settings.startup["ingredient-scrap-needed"].value*2}},
          results = {{ name = result_name, amount = 1 }}
        }
      }
    end
  end
  if #_recipe > 0 then data:extend(_recipe)
  return _recipe end
end
log(serpent.block( make_recycle_recipes() ))
assert(1==2, "make_recycle_recipes()")


  -- check if scrap item alredy exists
    -- create scrap item for each type
  -- check if recycle recipe already exists
    -- create recycle recipe for each type

  -- insert scrap item into _return.results

    -- insert _return into data.raw.recipe[item]
  -- loop over technologies
    -- if effect recipe == recycle scrap result set recipe enabled=false
    -- insert recycle recipe into effects





----------------------
--    TECHNOLOGY    --
----------------------



function get_technologies_of_recycle_results()
local tech = {}
    for _, data_technology in pairs(data.raw.technology) do

      if data_technology and data_technology.effects then
        for i, value in ipairs(data_technology.effects) do
-- log(serpent.block(value))
          if value.recipe then
-- log(value.recipe)

            for _, _item_type in ipairs(_return.recipe.ingredient_types) do

log(serpent.block(_item_type))

              if value.recipe == _item_type.name then
                table.insert(tech, {_item_type.name, value.name})
              end

            end
          end
        end
      end
      -- if data_technology.normal and data_technology.normal.effects then
      --   for i, value in ipairs(data_technology.normal.effects) do
      --     if value.recipe == recipe_name then
      --       _return.recipe.normal.technology[i] = value.name
      --     end
      --   end
      -- end
      -- if data_technology.expensive and data_technology.expensive.effects then
      --   for i, value in ipairs(data_technology.expensive.effects) do
      --     if value.recipe == recipe_name then
      --       _return.recipe.expensive.technology[i] = value.name
      --     end
      --   end
      -- end

    end
  return tech
end

log(serpent.block( get_technologies_of_recycle_results() ))
log(serpent.block( _return.recipe ))
assert(1==2, "get_technologies_of_recycle_results()")


--[[
  for each recipe:

  - generate possible scrap recycle results

  - get recipe ingredients OK
  - get scrap types OK
  - get recipe results OK
  - get enabled

  - for each possible scrap recycle result search in tech unlocks
    - get enabled of recipe
    - set disabled for recycle recipe if found in tech

  -generate scrap

  -insert scrap

  - generate recycle recipe
    - insert in tech if disabled
]]
