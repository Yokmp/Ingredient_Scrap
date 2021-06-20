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


-- local mod = require("mods")
-- _types = table.extend(mod[1], _types)
-- _results = table.extend(mod[2], _results)

-- log(serpent.block(_types))
-- assert(1==2)


---adds name and amount keys to ingredients and returns a new table
---@param table table
---@return table
function add_pairs(table)
  local _t = table

  for i, value in ipairs(_t) do
    if not value.name then
      _t[i].name   = value[1] ;  _t[i][1] = nil
      _t[i].amount = value[2] ;  _t[i][2] = nil
    end
  end

  return _t
end


-------------------
--    RECIPES    --
-------------------

---Get the ingredients of the given recipe
function recipe_get_ingredients(_recipe)
  local _ingredients = {}
  local _enabled = _recipe.enabled or true

  if _recipe.ingredients then
    _ingredients = {difficulty = false, enabled = _enabled}
    _ingredients.simple = add_pairs(_recipe.ingredients)
  end
  if _recipe.normal then
    _ingredients = {difficulty = true, enabled = _enabled}
    _ingredients.normal = add_pairs(_recipe.normal.ingredients)
  end
  if _recipe.expensive then
    _ingredients = {difficulty = true, enabled = _enabled}
    _ingredients.expensive = add_pairs(_recipe.expensive.ingredients)
  end

  return _ingredients
end
-- log(serpent.block(recipe_get_ingredients(data.raw.recipe["gun-turret"]), {comment = false}))
-- log(serpent.block(recipe_get_ingredients(data.raw.recipe["uranium-processing"]), {comment = false}))
-- assert(1==2, "updates")


---Does an ingredient match one of the types
---@param _ingredients table
---@param _types table
function recipe_ingredient_has_type(_ingredients, _types)
  local _amount = { match=false, simple=0, normal=0, expensive=0}

  if _ingredients.difficulty then
    for i, value in ipairs(_ingredients.normal) do
      if string.match(tostring(value.name), _types[i]) then
        _amount.normal = _amount.normal + 1
        _amount.match = true
      end
    end
    for i, value in ipairs(_ingredients.expensive) do
      if string.match(tostring(value.name), _types[i]) then
        _amount.expensive = _amount.expensive + 1
        _amount.match = true
      end
    end
  else
    for i, value in ipairs(_ingredients.simple) do
      if string.match(tostring(value.name), _types[i]) then
        _amount.simple = _amount.simple + 1
        _amount.match = true
      end
    end
  end

  return _amount
end
-- local test = recipe_get_ingredients(data.raw.recipe["gun-turret"])
-- log(serpent.block( recipe_ingredient_has_type( test, ingredient_types ), {comment = false}))
-- test = recipe_get_ingredients(data.raw.recipe["uranium-processing"])
-- log(serpent.block( recipe_ingredient_has_type( test, ingredient_types ), {comment = false}))
-- assert(1==2, "updates")


---Gets the results and their difficulty if possible
function recipe_get_results(_recipe) -- rewrite me because im useless
  local _results = {}
  local _enabled = _recipe.enabled or true -- not a trustful source

  if _recipe.results then
    _results[_recipe.name] = {difficulty = false, enabled = _enabled}
    _results[_recipe.name].results = add_pairs(_recipe.results)
  end
  if _recipe.result then
    _results[_recipe.name] = {difficulty = false, enabled = _enabled}
    _results[_recipe.name].results = {name = _recipe.result, amount = 1}
    if _recipe.result_count then
      _results[_recipe.name].results.amount = _recipe.result_count
    end
  end
  if _recipe.normal then
    _results[_recipe.name] = {difficulty = true, enabled = _enabled}
    _results[_recipe.name].normal = add_pairs(_recipe.normal.ingredients)
  end
  if _recipe.expensive then
    _results[_recipe.name] = {difficulty = true, enabled = _enabled}
    _results[_recipe.name].expensive = add_pairs(_recipe.expensive.ingredients)
  end

  return _results
end
-- log(serpent.block(recipe_get_results(data.raw.recipe["iron-stick"]), {comment = false}))
-- log(serpent.block(recipe_get_results(data.raw.recipe["uranium-processing"]), {comment = false}))
-- log(serpent.block(recipe_get_results(data.raw.recipe["kovarex-enrichment-process"]), {comment = false}))
-- assert(1==2, "updates")


----------------------
--    TECHNOLOGY    --
----------------------

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


