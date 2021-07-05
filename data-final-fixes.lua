local _scrap_types = {"iron", "copper", "steel"}
local _item_types = {"plate"}

local yutil = require("functions")
local mod = require("mods")
local patch = mod[3]

local scrap_types = yutil.table.extend(mod[1], _scrap_types)
local item_types = yutil.table.extend(mod[2], _item_types)


-------------------
--    UTILITY    --
-------------------



local do_test = false
-- local debug_test_recipe = "gun-turret"
-- local debug_test_recipe = "electronic-circuit"
-- local debug_test_recipe = "tank"
-- local debug_test_recipe = "empty-barrel"
-- local debug_test_recipe = "iron-gear-wheel"
-- local debug_test_recipe = "radar"
local debug_test_recipe = "bronze-alloy"
-- log(serpent.block( data.raw.recipe[debug_test_recipe] ))

---holds the return table template
local _return_template_ = {
    name = "_return_template_",
    recipe = {    -- determine and cache                                     get -> modify -> replace
                    ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil,
      normal    = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil, },
      expensive = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil, },

    },
  }
  local function new_return(recipe_name)
  local _t = util.table.deepcopy(_return_template_)
  _t.name = recipe_name
  return _t
end


local function filter_scrap_types()
  local _t1, _t2 = {}, {}
  log("Filtering scrap types")
  for _, s_type in ipairs(scrap_types) do
    for _, i_type in ipairs(item_types) do
      if data.raw.item[s_type.."-"..i_type] then
        -- if do_test then log(" Result for: "..s_type.."-"..i_type) end
        _t1[s_type] = s_type
      end
    end
  end
  for _, _type in pairs(_t1) do
    _t2[#_t2+1] = _type
  end

  scrap_types = _t2
  return _t2
end
-- if do_test then filter_scrap_types() end
-- log(serpent.block(scrap_types))
-- assert(1==2, "filter_scrap_types()")


local function get_scrap_types(scrap_type, item_types)

  for i, i_type in ipairs(item_types) do
    local _name = scrap_type.."-"..i_type
    if data.raw.item[_name] then
      return { scrap = scrap_type.."-scrap", item = _name, amount = 0 }
    end
  end

  return false
end
-- if do_test then log(serpent.block(get_scrap_types("iron", item_types))) end
-- assert(1==2, "get_scrap_types()")




------------------
--    RECIPE    --
------------------




local _return = new_return(debug_test_recipe)


local function get_recipe_ingredients(recipe_name)
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
-- if do_test then get_recipe_ingredients(debug_test_recipe) end
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "get_recipe_ingredients()")


local function get_recipe_ingredient_types(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then

    if _return.recipe.ingredients[1] then
      for _, ingredient in ipairs(_return.recipe.ingredients) do
        for _, _type in ipairs(scrap_types) do

          if string.find(ingredient.name, _type, 0, true) and get_scrap_types(_type, item_types) then
            _return.recipe.ingredient_types[_type] = _return.recipe.ingredient_types[_type] or get_scrap_types(_type, item_types)
            _return.recipe.ingredient_types[_type].amount = _return.recipe.ingredient_types[_type].amount +1
            break
          end
        end
      end
    end

    if _return.recipe.normal.ingredients[1] then
      for _, ingredient in ipairs(_return.recipe.normal.ingredients) do
        for _, _type in ipairs(scrap_types) do

          if string.find(ingredient.name, _type, 0, true) and get_scrap_types(_type, item_types) then
            _return.recipe.normal.ingredient_types[_type] = _return.recipe.normal.ingredient_types[_type] or get_scrap_types(_type, item_types)
            _return.recipe.normal.ingredient_types[_type].amount = _return.recipe.normal.ingredient_types[_type].amount +1
            break
          end
        end
      end
    end

    if _return.recipe.expensive.ingredients[1] then
      for _, ingredient in ipairs(_return.recipe.expensive.ingredients) do
        for _, _type in ipairs(scrap_types) do

          if string.find(ingredient.name, _type, 0, true) and get_scrap_types(_type, item_types) then
            _return.recipe.expensive.ingredient_types[_type] = _return.recipe.expensive.ingredient_types[_type] or get_scrap_types(_type, item_types)
            _return.recipe.expensive.ingredient_types[_type].amount = _return.recipe.expensive.ingredient_types[_type].amount +1
            break
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
-- if do_test then get_recipe_ingredient_types(debug_test_recipe) end
-- get_recipe_ingredient_types("cobalt-steel-alloy")
-- log(serpent.block(_return.recipe))
-- assert(1==2, "get_recipe_ingredient_types()")


local function get_recipe_results(recipe_name)

  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]
    local scrap_probability = settings.startup["ingredient-scrap-probability"].value/100

    if data_recipe.result then
      _return.recipe.results[1] = yutil.add_pairs( {data_recipe.result, data_recipe.result_count} )
      for _, scrap in pairs(_return.recipe.ingredient_types) do
        table.insert(_return.recipe.results, {name = scrap.scrap, amount_min = 1, amount_max = scrap.amount, probability = scrap_probability})
      end
    end

    if data_recipe.results and data_recipe.results[1] then
      for i, result in ipairs(data_recipe.results) do
        _return.recipe.results[i] = yutil.add_pairs( result )
      end
      for _, scrap in pairs(_return.recipe.ingredient_types) do
        table.insert(_return.recipe.results, {name = scrap.scrap, amount_min = 1, amount_max = scrap.amount, probability = scrap_probability})
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
      for _, scrap in pairs(_return.recipe.normal.ingredient_types) do
        table.insert(_return.recipe.normal.results, {name = scrap.scrap, amount_min = 1, amount_max = scrap.amount, probability = scrap_probability})
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
      for _, scrap in pairs(_return.recipe.expensive.ingredient_types) do
        table.insert(_return.recipe.expensive.results, {name = scrap.scrap, amount_min = 1, amount_max = scrap.amount, probability = scrap_probability})
      end
    end

  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end
  return _return.recipe
end
-- if do_test then  get_recipe_results(debug_test_recipe) end
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "get_recipe_results()")


local function recipe_is_enabled(recipe_name) -- determides through technology
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
-- if do_test then recipe_is_enabled(debug_test_recipe) end
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "recipe_is_enabled()")


local function recipe_get_main_product(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

    if not data_recipe.icon or not data_recipe.subgroup then -- ? localized_string - these need their own functions ?

      if data_recipe.main_product and not data_recipe.main_product == "" then
        _return.recipe.main_product = data_recipe.main_product
      elseif data_recipe.result then
        _return.recipe.main_product = data_recipe.result
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
-- if do_test then recipe_get_main_product(debug_test_recipe) end
-- log(serpent.block( _return.recipe ))
-- assert(1==2, "recipe_get_main_product()")




----------------------
--    TECHNOLOGY    --
----------------------



local function get_scrap_recycle_tech(recipe_name, raw_scrap) -- TODO: normal, expensive
  local _techs = { effects={enabled=true, recipes={}}, normal={enabled=true, recipes={}}, expensive={enabled=true, recipes={}} }
  for tech_name, value in pairs(data.raw.technology) do
    if patch.technology(tech_name) and value.effects then
      for i, effect in ipairs(value.effects) do
        if effect.recipe and effect.recipe == recipe_name then
          _techs.effects.enabled = false
          _techs.effects.recipes[#_techs.effects.recipes+1] = tech_name
        end
      end
      if #_techs.effects.recipes < 1 and string.match(tostring(tech_name), raw_scrap) then
        _techs.effects.enabled = false
        _techs.effects.recipes[#_techs.effects.recipes+1] = tech_name
      end
    end
    --normal
    --expensive
  end
  return _techs
end
if do_test then  log(serpent.block( get_scrap_recycle_tech("gold-plate", "gold") )) end
-- assert(1==2, "get_scrap_recycle_tech()")





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
-- if do_test then log(serpent.block( get_recycle_result_name("steel") )) end
-- assert(1==2, "get_recycle_result_name()")


local function make_scrap(scrap_type, scrap_icon, stack_size)
  local scrap_name = scrap_type.. "-scrap"

  if not data.raw.item[scrap_name] then
    local _data
    local recipe_name = "recycle-" ..scrap_type.. "-scrap"
    local result_name = get_recycle_result_name(scrap_type)
    local item_order = "z["..scrap_name.."]"
    local recipe_order = "z["..recipe_name.."]"

    local enabled = --[[_return.recipe.enabled or]] get_scrap_recycle_tech(result_name, scrap_type).effects.enabled
    local normal_enabled = --[[_return.recipe.normal.enabled or]] get_scrap_recycle_tech(result_name, scrap_type).effects.enabled
    local expensive_enabled = --[[_return.recipe.expensive.enabled or]] get_scrap_recycle_tech(result_name, scrap_type).effects.enabled

    if not data.raw.recipe[recipe_name] then -- TODO normal, expensive
      local tech_table = get_scrap_recycle_tech(result_name, scrap_type)
      for _, tech_name in ipairs(tech_table.effects.recipes) do
        log(tech_name.." unlocks "..recipe_name)
        table.insert(data.raw.technology[tech_name].effects,
          { type = "unlock-recipe", recipe = recipe_name } )
      end
    end

    _data = {
      {
        type = "item",
        name = scrap_name,
        icon = scrap_icon or yutil.get_item_icon(scrap_type),
        icon_size = 64, icon_mipmaps = 4,
        subgroup = "raw-material",
        order = item_order,
        stack_size = stack_size or 100
      },
      {
        type = "recipe",
        name = recipe_name,
        localised_name = {"recipe-name."..recipe_name},
        icons = yutil.get_recycle_icons(scrap_type, result_name),
        subgroup = "raw-material",
        category = "smelting",
        order = recipe_order,
        always_show_products = true,
        allow_as_intermediate = false,
        enabled = enabled,
        normal = {
          enabled = normal_enabled,
          energy_required = 3.2,
          ingredients = {{ name = scrap_name, amount = settings.startup["ingredient-scrap-needed"].value}},
          results = {{ name = result_name, amount = 1 }}
        },
        expensive = {
          enabled = expensive_enabled,
          energy_required = 3.2,
          ingredients = {{ name = scrap_name, amount = settings.startup["ingredient-scrap-needed"].value*2}},
          results = {{ name = result_name, amount = 1 }}
        }
      },
    }
  data:extend(_data)

  return _data
  end
end
-- if do_test then log(serpent.block( make_scrap("steel") )) end
-- assert(1==2, "make_scrap_items()")








filter_scrap_types()
for _, s_type in ipairs(scrap_types) do
  if do_test then log("Generating "..s_type.."-scrap item and recipe") end
  make_scrap(s_type)
end

for recipe_name, recipe_data in pairs(data.raw.recipe) do
  -- if do_test then log(recipe_name.." - "..tostring(recipe_data.subgroup)) end
  -- if not settings.startup["ingredient-scrap-handle-fluids"].value
  -- and recipe_data.subgroup
  -- and recipe_data.subgroup == "fluid-recipes"
  -- then
  --   log("Skipping fluid-recipe: "..recipe_name)
  -- else

    _return = new_return(recipe_name)
    get_recipe_ingredients(recipe_name)
    get_recipe_ingredient_types(recipe_name)
    get_recipe_results(recipe_name)
    -- recipe_is_enabled(recipe_name)
    recipe_get_main_product(recipe_name)

    if next(_return.recipe.results) then
      data.raw.recipe[recipe_name].results = util.table.deepcopy(_return.recipe.results)
      recipe_data.main_product = util.table.deepcopy(_return.recipe.main_product)
    end
    if recipe_data.normal and next(_return.recipe.normal.results) then
      data.raw.recipe[recipe_name].normal.results = util.table.deepcopy(_return.recipe.normal.results)
      data.raw.recipe[recipe_name].normal.main_product = util.table.deepcopy(_return.recipe.normal.main_product)
    end
    if recipe_data.expensive and next(_return.recipe.expensive.results) then
      data.raw.recipe[recipe_name].expensive.results = util.table.deepcopy(_return.recipe.expensive.results)
      data.raw.recipe[recipe_name].expensive.main_product = util.table.deepcopy(_return.recipe.expensive.main_product)
    end

    if do_test and recipe_name == debug_test_recipe then
      log(serpent.block( _return.recipe ))
      log(serpent.block(data.raw.recipe[debug_test_recipe]))
      assert(1==2, "THIS IS THE END")
    end
  -- end
end

patch.recipes()

for key, value in pairs(data.raw.recipe) do
  if string.match(value.name, "glass") then
    log(serpent.block(data.raw.recipe[value.name]))
  end
end
-- error("find_name")

