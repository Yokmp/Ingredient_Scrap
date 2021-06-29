scrap_types = {"iron", "copper", "steel"}
item_types = {"plate"}

local yutil = require("functions")
-------------------
--    UTILITY    --
-------------------


-- local debug_test_item = "gun-turret"
-- local debug_test_item = "electronic-circuit"
local debug_test_item = "tank"

---holds the return table template
local _return_template_ = {
    name = "_return_template_",
    recipe = {    -- determine and cache                                     get -> modify -> replace
                    ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = "",
      normal    = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = "", },
      expensive = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = "", },

    },
  }
function new_return(recipe_name)
  local _t = util.table.deepcopy(_return_template_)
  _t.name = recipe_name
  return _t
end



function filter_scrap_types()
  local _return = {}
  log("Filtering scrap types")
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
-- filter_scrap_types()
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




local _return = new_return(debug_test_item)


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
-- get_recipe_ingredients(debug_test_item)
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
-- get_recipe_ingredient_types(debug_test_item)
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
-- get_recipe_results(debug_test_item)
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "get_recipe_results()")


function recipe_is_enabled(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

      if data_recipe.enabled == false then _return.recipe.enabled = false end
      if data_recipe.normal and data_recipe.normal.enabled == false then _return.recipe.normal.enabled = false end
      if data_recipe.expensive and data_recipe.expensive.enabled == false then _return.recipe.expensive.enabled = false end

  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end
  return _return.recipe
end
-- recipe_is_enabled(debug_test_item)
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

      if data_recipe.normal and data_recipe.normal.main_product and not data_recipe.normal.main_product == "" then
        _return.recipe.normal.main_product = data_recipe.normal.main_product
      elseif _return.recipe.normal.results[1] then
        _return.recipe.normal.main_product = _return.recipe.normal.results[1].name
      end

      if data_recipe.expensive and data_recipe.expensive.main_product and not data_recipe.expensive.main_product == "" then
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
-- recipe_get_main_product(debug_test_item)
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "recipe_get_main_product()")




-----------------
--    SCRAP    --
-----------------



local function get_recycle_result_name(scrap_type)
  if type(scrap_type) ~= "string" then return nil end
    for _, i_type in ipairs(item_types) do
      if data.raw.item[scrap_type.."-"..i_type] then
        return scrap_type.."-"..i_type
      end
    end
end
-- log(serpent.block( get_recycle_result_name("copper") ))
-- assert(1==2, "get_recycle_result_name()")


local function get_scrap_recycle_tech(result_name) -- TODO: normal, expensive
  local _techs = { effects={enabled=true}, normal={}, expensive={} }
  for tech_name, value in pairs(data.raw.technology) do
    if value.effects then
      for i, effect in ipairs(value.effects) do
        if effect.recipe and effect.recipe == result_name then
          _techs.effects.enabled = false
          _techs.effects[i] = tech_name
        end
      end
    end
    --normal
    --expensive
  end
  return _techs
end
-- log(serpent.block( get_scrap_recycle_tech("steel-plate") ))
-- assert(1==2, "get_scrap_recycle_tech()")


function make_scrap(scrap_type, scrap_icon, stack_size)
  local scrap_name = scrap_type.. "-scrap"

  if not data.raw.item[scrap_name] then
    local _data
    local recipe_name = "recycle-" ..scrap_type.. "-scrap"
    local result_name = get_recycle_result_name(scrap_type)
    local item_order = "z["..scrap_name.."]"
    local recipe_order = "z["..recipe_name.."]"

    local enabled = _return.recipe.enabled or get_scrap_recycle_tech(result_name).effects.enabled
    local normal_enabled = _return.recipe.normal.enabled or get_scrap_recycle_tech(result_name).effects.enabled
    local expensive_enabled = _return.recipe.expensive.enabled or get_scrap_recycle_tech(result_name).effects.enabled

    if not data.raw.recipe[recipe_name] then -- TODO normal, expensive
      local tech_table = get_scrap_recycle_tech(result_name)
      for _, tech_name in ipairs(tech_table.effects) do
        log(tech_name.." unlocks "..recipe_name)
        table.insert(data.raw.technology[tech_name].effects,
          { type = "unlock-recipe", recipe = recipe_name } )
      end
    end

    _data = {
      {
        type = "item",
        name = scrap_name,
        icon = scrap_icon or yutil.get_icon(scrap_type),
        icon_size = 64, icon_mipmaps = 4,
        subgroup = "raw-material",
        order = item_order,
        stack_size = stack_size or 100
      },
      {
        type = "recipe",
        name = recipe_name,
        localised_name = {"recipe-name."..recipe_name},
        icons = yutil.get_scrap_icons(scrap_type, scrap_name),
        subgroup = "raw-material",
        category = "smelting",
        order = recipe_order,
        energy_required = 3.2,
        always_show_products = true,
        allow_as_intermediate = false,
        enabled = enabled,
        normal = {
          enabled = normal_enabled,
          ingredients = {{ name = scrap_name, amount = settings.startup["ingredient-scrap-needed"].value}},
          results = {{ name = result_name, amount = 1 }}
        },
        expensive = {
          enabled = expensive_enabled,
          ingredients = {{ name = scrap_name, amount = settings.startup["ingredient-scrap-needed"].value*2}},
          results = {{ name = result_name, amount = 1 }}
        }
      },
    }
  data:extend(_data)
  return _data
  end
end
-- log(serpent.block( make_scrap("iron") ))
-- assert(1==2, "make_scrap_items()")


-- log(serpent.block(data.raw.recipe["sulfuric-acid"]))
-- assert(1==2)

filter_scrap_types()
for _, s_type in ipairs(scrap_types) do
  log("Generating "..s_type.."-scrap item and recipe")
  make_scrap(s_type)
end

for recipe_name, recipe_data in pairs(data.raw.recipe) do
  if not recipe_data.subgroup == "fluid-recipes" then

    local _return = new_return(recipe_name)
    get_recipe_ingredients(recipe_name)
    get_recipe_ingredient_types(recipe_name)
    get_recipe_results(recipe_name)
    recipe_is_enabled(recipe_name)
    recipe_get_main_product(recipe_name)

log(serpent.block(_return))
assert(1==2)

    if recipe_data.result or recipe_data.results then
      data.raw.recipe[recipe_name].results = _return.recipe.results
      recipe_data.main_product = _return.recipe.main_product
    end
    if recipe_data.normal and recipe_data.normal.results then
      data.raw.recipe[recipe_name].results = _return.recipe.normal.results
      data.raw.recipe[recipe_name].main_product = _return.recipe.normal.main_product
    end
    if recipe_data.expensive and recipe_data.expensive.results then
      data.raw.recipe[recipe_name].results = _return.recipe.expensive.results
      data.raw.recipe[recipe_name].main_product = _return.recipe.expensive.main_product
    end

  end
end

log(serpent.block(data.raw.recipe["iron-gear-wheel"]))


