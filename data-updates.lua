-- require("lldebugger").start()
local debug = false -- use this to spam your log

-- local Scrap = {}

--[[  This table holds the phrases and looks into the recipes with string.match() to find them.
  So iron will match iron-plate and hardenend-iron-plate. Even superironbar would be a match.
  To exclude like copper-plate but still use copper-cables just be more specific. It is also used
  to contruct the scrap-items like ``iron-scrap``.]]
local ingredient_types = {"iron", "copper", "steel"}
--[[  This table holds the result suffix which is then be constructed to ``_types.."-".._results`` (eg iron-plate).
  Like the _types table, this one also goes by priority, so position 1 is taken if possible, if not pos 2 will be checked until
  it runs out of options, then the script will log it and **ignore** the recipe.
  As there will be no recycling of this scrap-item place some kind of fallback at the end. "*plate*"" is a good candidate.]]
local result_types = {"plate"} --, "ingot"}


local mod = require("mods")
-- _types = table.extend(mod[1], _types)
-- _results = table.extend(mod[2], _results)

-- log(serpent.block(_types))
-- assert(1==2)




-------------------
--    RECIPES    --
-------------------
--#region

---adds name and amount keys to ingredients and returns a new table
---@param table table ``{"name", n?}``
---@return table ``{ name = "name", amount = n }``
local function add_pairs(table)
  if table.name then return table end
  local _t = table

  _t.name   = _t[1]      ;  _t[1] = nil
  _t.amount = _t[2] or 1 ;  _t[2] = nil

  return _t
end
-- log(serpent.block( add_pairs({ "iron-gear-wheel", 10 }) ))
-- log(serpent.block( add_pairs({ "copper-plate", 10 }) ))
-- log(serpent.block( add_pairs({ name="iron-plate", amount=20 }) ))
-- log(serpent.block( add_pairs({ name = "uranium-235", probability = 0.007, amount = 1 }) ))
-- assert(1==2, "add_pairs()")

---@param data_recipe table ``data.raw.recipe["name"]``
function recipe_get_keywords(data_recipe)
  local _return = {ingredients = nil, normal = nil, expensive = nil, result = nil, result_count = nil, results = nil}

    if data_recipe.ingredients then
      _return.ingredients = true
    end
    if data_recipe.normal then
      _return.normal = true
    end
    if data_recipe.expensive then
      _return.expensive = true
    end
    if data_recipe.result then
      _return.result = true
    end
    if data_recipe.result_count then
      _return.result_count = true
    end
    if data_recipe.results then
      _return.results = true
    end

  return _return
end
-- log(serpent.block(recipe_get_keywords( data.raw.recipe["uranium-processing"] )))
-- log(serpent.block(recipe_get_keywords( data.raw.recipe["iron-gear-wheel"] )))
-- assert(1==2, "recipe_get_keywords()")

---@param data_recipe table ``data.raw.recipe["name"]``
---@param difficulty? table ``{ingredients = boolean, normal = boolean, expensive = boolean}``
function recipe_is_enabled(data_recipe, difficulty)
  local _return = {ingredients = false, normal = false, expensive = false}
  local _difficulty = difficulty or recipe_get_keywords(data_recipe)

    if _difficulty.ingredients and (data_recipe.enabled or data_recipe.enabled == nil) then
      _return.ingredients = true
    end
    if _difficulty.normal and data_recipe.normal.enabled == nil then
      _return.normal = true
    end
    if _difficulty.expensive and data_recipe.expensive.enabled == nil then
      _return.expensive = true
    end

  return _return
end
-- log(serpent.block(recipe_is_enabled( data.raw.recipe["iron-stick"] )))
-- log(serpent.block(recipe_is_enabled( data.raw.recipe["flamethrower-turret"] )))
-- log(serpent.block(recipe_is_enabled( data.raw.recipe["iron-gear-wheel"] )))
-- assert(1==2, "recipe_is_enabled()")


---Does an ingredient match one of the types
---@param data_recipe table ``data.raw.recipe["name"]``
---@param _type string ingredient_types[n]
---@param difficulty? table ``{ingredients = boolean, normal = boolean, expensive = boolean}``
function recipe_ingredient_has_type(data_recipe, _type, difficulty)
  local _amount = { match = false, ingredients = 0, normal = 0, expensive = 0 }
  local _difficulty = difficulty or recipe_get_keywords(data_recipe)

  if _difficulty.normal then
    for i, value in ipairs(data_recipe.normal.ingredients) do
      value = add_pairs(value)
      if string.match(tostring(value.name), _type) then
        _amount.normal    = _amount.normal + 1
        _amount.match     = true
      end
    end
  end
  if _difficulty.expensive then
    for i, value in ipairs(data_recipe.expensive.ingredients) do
      value = add_pairs(value)
      if string.match(tostring(value.name), _type) then
        _amount.expensive = _amount.expensive + 1
        _amount.match     = true
      end
    end
  end
  if _difficulty.ingredients then
    for i, value in ipairs(data_recipe.ingredients) do
      value = add_pairs(value)
      if string.match(tostring( value.name ), _type) then
        _amount.ingredients    = _amount.ingredients + 1
        _amount.match     = true
      end
    end
  end

  return _amount
end
-- log(serpent.block( recipe_ingredient_has_type( data.raw.recipe["uranium-processing"], "iron" ), {comment = false}))
-- log(serpent.block( recipe_ingredient_has_type( data.raw.recipe["iron-gear-wheel"], "iron" ), {comment = false}))
-- log(serpent.block( recipe_ingredient_has_type( data.raw.recipe["gun-turret"], "iron" ), {comment = false}))
-- assert(1==2, "recipe_ingredient_has_type()")




---Gets the results and their difficulty if possible
---@param data_recipe table ``data.raw.recipe["name"]``
---@param difficulty? table ``{result = boolean, results = boolean, normal = boolean, expensive = boolean}``
function recipe_get_results(data_recipe, difficulty)
  local _results = {results = {}, normal = {}, expensive = {}}
  local _difficulty = difficulty or recipe_get_keywords(data_recipe)

  if _difficulty.results then
    for i, value in ipairs(data_recipe.results) do
      _results.results[i] = add_pairs(value)
    end
  end
  if _difficulty.result then
    _results.results.name = data_recipe.result
    _results.results.amount = data_recipe.result_count or 1
  end
  if _difficulty.normal then
    if data_recipe.normal.result then
      _results.normal.name = data_recipe.normal.result
      _results.normal.amount = data_recipe.normal.result_amount or 1
    else
      for i, value in ipairs(data_recipe.normal.results) do
        _results.normal[i] = add_pairs(value)
      end
    end
  end
  if _difficulty.expensive then
    if data_recipe.expensive.result then
      _results.expensive.name = data_recipe.expensive.result
      _results.expensive.amount = data_recipe.result_count or 1
    else
      for i, value in ipairs(data_recipe.expensive.results) do
        _results.expensive[i] = add_pairs(value)
      end
    end
  end

  return _results
end
log(serpent.block(recipe_get_results(data.raw.recipe["iron-gear-wheel"]), {comment = false}))
log(serpent.block(recipe_get_results(data.raw.recipe["uranium-processing"]), {comment = false}))
log(serpent.block(recipe_get_results(data.raw.recipe["kovarex-enrichment-process"]), {comment = false}))
assert(1==2, "recipe_get_results()")
-- #endregion




----------------------
--    TECHNOLOGY    --
----------------------
--#region

function technology_has_recipe(_technology, _recipe)

  if _technology.effects then
    for i, value in ipairs(_technology.effects) do
      if value.recipe == _recipe then
        return true
      end
    end
  end

  return false
end
-- log(serpent.block(technology_has_recipe(data.raw.technology["sulfur-processing"], "sulfur"), {comment = false}))
-- log(serpent.block(technology_has_recipe(data.raw.technology["steel-processing"], "steel-plate"), {comment = false}))
-- log(serpent.block(technology_has_recipe(data.raw.technology["modules"] ,"modules"), {comment = false}))
-- assert(1==2, "updates")



function get_technology_by_recipe(_recipe)
  local _tech = {}

  for name, value in pairs(data.raw.technology) do
    if technology_has_recipe(value, _recipe) then
      table.insert(_tech, name)
    end
  end

  return _tech
end
-- log(serpent.block(get_technology_by_recipe("steel-plate"), {comment = false}))
-- assert(1==2, "updates")
--#endregion




-----------------
--    SCRAP    --
-----------------

---Generate a scrap item
---@param _scrap table ``{ name=_type, stack_size=n }``
function get_scrap_item(_scrap)
  return {
    type = "item",
    name = _scrap[1].. "-scrap",
    icon = get_icon(_scrap[1]),
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "raw-material",
    order = "z-b",
    stack_size = _scrap[2] or 100
  }
end
-- log(serpent.block(get_scrap_item( {"test-type"} )))
-- log(serpent.block(get_scrap_item( {"copper", 42} )))
-- assert(1==2, "updates")


---@param _ingredient_type string ingredient_type
---@param _result_type string result_type
---@return table recipe
function get_scrap_recipe(_ingredient_type, _result_type)
  local _item = _ingredient_type.."-".._result_type
  local _name = "recycle-" .._ingredient_type.. "-scrap"
  return {
    type = "recipe",
    name = _name,
    localised_name = {"recipe-name.".._name},
    icons = get_scrap_icons(_ingredient_type, _item),
    subgroup = "raw-material",
    category = "smelting",
    order = data.raw.recipe[_item].order,
    enabled = data.raw.recipe[_item].enabled,
    energy_required = 3.2,
    always_show_products = true,
    allow_as_intermediate = false,
    ingredients = {{ _ingredient_type.. "-scrap", settings.startup["ingredient-scrap-needed"].value}},
    results = {{ _item, 1 }}
  }
end
-- log(serpent.block(get_scrap_recipe( "copper", "plate" )))
-- assert(1==2, "updates")


---Insert return table into an items results.
--
---Use ``recipe_ingredient_match_amount(_recipe_name, _types)`` for max_amount.
---@param _name string
---@param _amount number
---@return table ``{name = _name, amount_min = 1, amount_max = _amount, probability = scrap_probability}``
function get_scrap_result(_name, _amount)
  local scrap_probability = settings.startup["ingredient-scrap-probability"].value/100
  return {name = _name, amount_min = 1, amount_max = _amount, probability = scrap_probability}
end





---@param _scrap table {type="type", stack_size=n}
---@param _result string result_type ( "plate" )
function add_scrap(_scrap, _result)
  local _scrap_item = get_scrap_item({name=_scrap.type, stack_size=_scrap.stack_size})
  local _scrap_recipe = get_scrap_recipe(_scrap.type_type, _result)

  -- add_scrap_to_techtree
end








for recipe, value in pairs(data.raw.recipe) do

  for it, _ingredient in ipairs(ingredient_types) do

    for ir, _result in ipairs(result_types) do

      local _res = recipe_get_results(recipe)
      local _amount = recipe_ingredient_match_amount(recipe, _ingredient)
      local _s_result = get_scrap_result(_name, _amount)
      local _r_results = {}

      if _res.difficulty then
        
      else
        _r_results = _res.results
      end

    end

  end

end
