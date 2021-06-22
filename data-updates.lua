-- require("lldebugger").start()
local debug = false -- use this to spam your log

-- local Scrap = {}

--[[  This table holds the phrases and looks into the recipes with string.match() to find them.
  So iron will match iron-plate and hardenend-iron-plate. Even superironbar would be a match.
  To exclude like copper-plate but still use copper-cables just be more specific. It is also used
  to contruct the scrap-items like ``iron-scrap``.]]
local scrap_ingredient_types = {"iron", "copper", "steel"}
--[[  This table holds the result suffix which is then be constructed to ``_types.."-".._results`` (eg iron-plate).
  Like the _types table, this one also goes by priority, so position 1 is taken if possible, if not pos 2 will be checked until
  it runs out of options, then the script will log it and **ignore** the recipe.
  As there will be no recycling of this scrap-item place some kind of fallback at the end. "*plate*"" is a good candidate.]]
local scrap_result_types = {"plate"} --, "ingot"}


local mod = require("mods")
-- _types = table.extend(mod[1], _types)
-- _results = table.extend(mod[2], _results)

-- log(serpent.block(_types))
-- assert(1==2)

-- constants = constants or {}
-- constants.difficulty = {
--   ["none"] = 1,
--   ["result"] = 1,
--   ["results"] = 2,
--   ["ingredients"] = 2,
--   ["normal"] = 3,
--   ["expensive"] = 4,
-- }


-------------------
--    RECIPES    --
-------------------
--#region

---adds name and amount keys to ingredients and returns a new table
---@param table table ``{"name", n?}``
---@return table ``{ name = "name", amount = n }``
local function add_pairs(table)
  if table and table.name then return table end --they can be empty and would be "valid"
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
---@return table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
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
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_is_enabled(data_recipe, keywords)
  local _return = {ingredients = false, normal = false, expensive = false}
  local _keywords = keywords or recipe_get_keywords(data_recipe)

    if _keywords.ingredients and (data_recipe.enabled or data_recipe.enabled == nil) then
      _return.ingredients = true
    end
    if _keywords.normal and data_recipe.normal.enabled == nil then
      _return.normal = true
    end
    if _keywords.expensive and data_recipe.expensive.enabled == nil then
      _return.expensive = true
    end

  return _return
end
-- log(serpent.block(recipe_is_enabled( data.raw.recipe["iron-stick"] )))
-- log(serpent.block(recipe_is_enabled( data.raw.recipe["flamethrower-turret"] )))
-- log(serpent.block(recipe_is_enabled( data.raw.recipe["iron-gear-wheel"] )))
-- assert(1==2, "recipe_is_enabled()")

--    INGREDIENTS    --

---@param data_recipe table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_get_ingredients(data_recipe, keywords)
  local _keywords = keywords or recipe_get_keywords(data_recipe)
  local _ingredients = { normal = {}, expensive = {}, ingredients = {}}

  if _keywords.normal then
    for i, value in ipairs(data_recipe.normal.ingredients) do
      _ingredients.normal[i] = add_pairs(value)
    end
  end
  if _keywords.expensive then
    for i, value in ipairs(data_recipe.expensive.ingredients) do
      _ingredients.expensive[i] = add_pairs(value)
    end
  end
  if _keywords.ingredients then
    for i, value in ipairs(data_recipe.ingredients) do
      _ingredients.ingredients[i] = add_pairs(value)
    end
  end

  return _ingredients
end
-- log(serpent.block( recipe_get_ingredients( data.raw.recipe["uranium-processing"]), {comment = false}))
-- log(serpent.block( recipe_get_ingredients( data.raw.recipe["iron-gear-wheel"]), {comment = false}))
-- log(serpent.block( recipe_get_ingredients( data.raw.recipe["gun-turret"]), {comment = false}))
-- assert(1==2, "recipe_get_ingredients()")


---Replaces a recipes results with the given results or just formats them to named keys
---@param data_recipe table ``data.raw.recipe["name"]``
---@param data_ingredients? table ``recipe_get_ingredients(data.raw.recipe["name"])``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_replace_ingredients(data_recipe, data_ingredients, keywords)
  local _ingredients = data_ingredients or recipe_get_ingredients(data_recipe)
  local _keywords = keywords or recipe_get_keywords(data_recipe)

  if _keywords.ingredients then
    data_recipe.ingredients = _ingredients.ingredients
  end
  if _keywords.normal then
    data_recipe.normal.ingredients = _ingredients.normal
  end
  if _keywords.expensive then
    data_recipe.expensive.ingredients = _ingredients.expensive
  end

end
-- recipe_replace_ingredients(data.raw.recipe["iron-gear-wheel"])
-- log(serpent.block(data.raw.recipe["iron-gear-wheel"], {comment = false}))
-- recipe_replace_ingredients(data.raw.recipe["uranium-processing"])
-- log(serpent.block(data.raw.recipe["uranium-processing"], {comment = false}))
-- recipe_replace_ingredients(data.raw.recipe["kovarex-enrichment-process"])
-- log(serpent.block(data.raw.recipe["kovarex-enrichment-process"], {comment = false}))
-- assert(1==2, "recipe_replace_ingredients()")


---Does an ingredient match one of the types
---@param data_recipe table ``data.raw.recipe["name"]``
---@param scrap_type string ingredient_types[n]
---@param keywords? table ``{ingredients = boolean, normal = number, expensive = number, result = number, result_count = number, results = number}``
function recipe_ingredient_get_types(data_recipe, scrap_type, keywords)
  local _amount = { match = false, ingredients = 0, normal = 0, expensive = 0 }
  local _keywords = keywords or recipe_get_keywords(data_recipe)

  if _keywords.normal then
    for i, value in ipairs(data_recipe.normal.ingredients) do
      value = add_pairs(value)
      if string.match(tostring(value.name), scrap_type) then
        _amount.normal = _amount.normal + 1
        _amount.match       = true
      end
    end
  end
  if _keywords.expensive then
    for i, value in ipairs(data_recipe.expensive.ingredients) do
      value = add_pairs(value)
      if string.match(tostring(value.name), scrap_type) then
        _amount.expensive = _amount.expensive + 1
        _amount.match       = true
      end
    end
  end
  if _keywords.ingredients then
    for i, value in ipairs(data_recipe.ingredients) do
      value = add_pairs(value)
      if string.match(tostring( value.name ), scrap_type) then
        _amount.ingredients = _amount.ingredients + 1
        _amount.match       = true
      end
    end
  end

  return _amount
end
-- log(serpent.block( recipe_ingredient_get_types( data.raw.recipe["uranium-processing"], "iron" ), {comment = false}))
-- keys = recipe_get_keywords(data.raw.recipe["iron-gear-wheel"])
-- log(serpent.block( recipe_ingredient_get_types( data.raw.recipe["iron-gear-wheel"], "iron", keys ), {comment = false}))
-- keys = recipe_get_keywords(data.raw.recipe["gun-turret"])
-- log(serpent.block( recipe_ingredient_get_types( data.raw.recipe["gun-turret"], "iron", keys ), {comment = false}))
-- assert(1==2, "recipe_ingredient_get_types()")

--    RESULTS    --

---Gets the results and their keywords if possible
---@param data_recipe table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_get_results(data_recipe, keywords)
  local _results = {results = {}, normal = {}, expensive = {}}
  local _keywords = keywords or recipe_get_keywords(data_recipe)

  if _keywords.result then
    _results.results[1] = {name = data_recipe.result, amount = data_recipe.result_count or 1}
  end
  if _keywords.results then
    for i, value in ipairs(data_recipe.results) do
      _results.results[i] = add_pairs(value)
    end
  end
  if _keywords.normal then
    if data_recipe.normal.result then
      _results.normal[1] = {name = data_recipe.normal.result, amount = data_recipe.normal.result_amount or 1}
    else
      for i, value in ipairs(data_recipe.normal.results) do
        _results.normal[i] = add_pairs(value)
      end
    end
  end
  if _keywords.expensive then
    if data_recipe.expensive.result then
      _results.expensive[1] = {name = data_recipe.expensive.result, amount = data_recipe.result_count or 1}
    else
      for i, value in ipairs(data_recipe.expensive.results) do
        _results.expensive[i] = add_pairs(value)
      end
    end
  end

  return _results
end
-- log(serpent.block(recipe_get_results(data.raw.recipe["iron-gear-wheel"]), {comment = false}))
-- log(serpent.block(recipe_get_results(data.raw.recipe["uranium-processing"]), {comment = false}))
-- log(serpent.block(recipe_get_results(data.raw.recipe["kovarex-enrichment-process"]), {comment = false}))
-- assert(1==2, "recipe_get_results()")


---Replaces a recipes results with the given results or just formats them to named keys
---@param data_recipe table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function  recipe_format_results(data_recipe, keywords)
  local _results = recipe_get_results(data_recipe)
  local _keywords = keywords or recipe_get_keywords(data_recipe)

  if _keywords.results or _keywords.result then
    data_recipe.result = nil
    data_recipe.result_count = nil
    data_recipe.results = _results.results
  end
  if _keywords.normal then
    data_recipe.normal.result = nil
    data_recipe.normal.result_count = nil
    data_recipe.normal.results = _results.normal
  end
  if _keywords.expensive then
    data_recipe.expensive.result = nil
    data_recipe.expensive.result_count = nil
    data_recipe.expensive.results = _results.expensive
  end

end
--  recipe_format_results(data.raw.recipe["iron-gear-wheel"])
-- -- recipe_replace_ingredients(data.raw.recipe["iron-gear-wheel"])
-- log(serpent.block(data.raw.recipe["iron-gear-wheel"], {comment = false}))
--  recipe_format_results(data.raw.recipe["uranium-processing"])
-- -- recipe_replace_ingredients(data.raw.recipe["uranium-processing"])
-- log(serpent.block(data.raw.recipe["uranium-processing"], {comment = false}))
--  recipe_format_results(data.raw.recipe["kovarex-enrichment-process"])
-- -- recipe_replace_ingredients(data.raw.recipe["kovarex-enrichment-process"])
-- log(serpent.block(data.raw.recipe["kovarex-enrichment-process"], {comment = false}))
-- assert(1==2, " recipe_format_results()")
-- #endregion




----------------------
--    TECHNOLOGY    --
----------------------
--#region

---does the given tech unlock the given recipe?
---@param data_technology table ``data.raw.technology["name"]``
---@param recipe_name string
function technology_has_recipe(data_technology, recipe_name)

  if data_technology.effects then
    for i, value in ipairs(data_technology.effects) do
      if value.recipe == recipe_name then
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

---returns a list of all technology names if they unlock the given recipe
---@param recipe_name string
---@return table
function get_technology_by_recipe(recipe_name)
  local _tech = {}

  for name, value in pairs(data.raw.technology) do
    if technology_has_recipe(value, recipe_name) then
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
function get_scrap_prototype_item(_scrap)
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
-- log(serpent.block(get_scrap_prototype_item( {"test-type"} ), {comment = false}))
-- log(serpent.block(get_scrap_prototype_item( {"copper", 42} ), {comment = false}))
-- assert(1==2, "updates")


function get_scrap_recycle_result(scrap_type)
  for _, result_type in ipairs(scrap_result_types) do
    log(result_type)
    if data.raw.item[scrap_type.."-"..result_type] then
      return scrap_type.."-"..result_type
    end
  end
end


---@param scrap_type string ingredient_type
---@return table recipe
function get_scrap_recycle_recipe(scrap_type)
  local _item = get_scrap_recycle_result(scrap_type) or "missing"
  local _name = "recycle-" ..scrap_type.. "-scrap"
  local _enabled = recipe_is_enabled(data.raw.recipe[_item])

  return {
    type = "recipe",
    name = _name,
    localised_name = {"recipe-name.".._name},
    icons = get_scrap_icons(scrap_type, _item),
    subgroup = "raw-material",
    category = "smelting",
    order = data.raw.recipe[_item].order,
    energy_required = 3.2,
    always_show_products = true,
    allow_as_intermediate = false,
    normal = {
      enabled = _enabled.normal or _enabled.ingredients,
      ingredients = {{ name = scrap_type.. "-scrap", amount = settings.startup["ingredient-scrap-needed"].value}},
      results = {{ name = _item, amount = 1 }}
    },
    expensive = {
      enabled = _enabled.expensive or _enabled.ingredients,
      ingredients = {{ name = scrap_type.. "-scrap", amount = settings.startup["ingredient-scrap-needed"].value*2}},
      results = {{ name = _item, amount = 1 }}
    }
  }
end
-- log(serpent.block(get_scrap_recycle_recipe( "copper" ), {comment = false}))
-- log(serpent.block(get_scrap_recycle_recipe( "steel" ), {comment = false}))
-- assert(1==2, "get_scrap_recycle_recipe()")


---returns a results table
---@param data_recipe table ``data.raw.recipe["name"]``
---@param scrap_type string scrap_ingredient_type
---@param scrap_amount_max? table { match = false, ingredients = n, normal = n, expensive = n }
---@return table ``difficulty = {name = _name, amount_min = 1, amount_max = _amount, probability = setting.value/100}``
function get_scrap_result(data_recipe, scrap_type, scrap_amount_max)
  local _amount = scrap_amount_max or recipe_ingredient_get_types(data_recipe, scrap_type)
  local _scrap_probability = settings.startup["ingredient-scrap-probability"].value/100
  local _return = {results = {}, normal = {}, expensive =  {}}

  if _amount.match then
    if _amount.ingredients > 0 then
      _return.results   = {name = scrap_type.."-scrap", amount_min = 2, amount_max = _amount.ingredients, probability = _scrap_probability}
    end
    if _amount.normal > 0 then
      _return.normal    = {name = scrap_type.."-scrap", amount_min = 2, amount_max = _amount.normal, probability = _scrap_probability}
    end
    if _amount.expensive > 0 then
      _return.expensive = {name = scrap_type.."-scrap", amount_min = 2, amount_max = _amount.expensive, probability = _scrap_probability}
    end
  -- else
  --   return false
  end

  return _return
end
-- log(serpent.block( get_scrap_result(data.raw.recipe["iron-gear-wheel"], "iron" ), {comment = false}))
-- log(serpent.block( get_scrap_result(data.raw.recipe["gun-turret"], "copper" ), {comment = false}))
-- assert(1==2, "get_scrap_result()")


---**Results of the given recipe will be formatted!**
---@param data_recipe table ``data.raw.recipe["name"]``
---@param scrap_type string scrap_ingredient_type
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_add_scrap_result(data_recipe, scrap_type, keywords)
  local _keywords = keywords or recipe_get_keywords(data_recipe)
  local _result = get_scrap_result(data_recipe, scrap_type)

   recipe_format_results(data_recipe)

  if _keywords.results and _result then
    data_recipe.main_product = data_recipe.main_product or data_recipe[1].name
    table.insert(data_recipe.results, _result)
  end
  if _keywords.normal and _result.normal then
    data_recipe.normal.main_product = data_recipe.normal.main_product or data_recipe.normal.results[1].name
    table.insert(data_recipe.normal.results, _result.normal)
  end
  if _keywords.expensive and _result.expensive then
    data_recipe.expensive.main_product = data_recipe.expensive.main_product or data_recipe.expensive.results[1].name
    table.insert(data_recipe.expensive.results, _result.expensive)
  end

end
log(serpent.block(recipe_add_scrap_result(data.raw.recipe["iron-gear-wheel"], "iron"), {comment = false}))
log(serpent.block(data.raw.recipe["iron-gear-wheel"]))
assert(1==2, "recipe_add_result()")






