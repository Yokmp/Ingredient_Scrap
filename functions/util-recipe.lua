
-------------------
--    RECIPES    --
-------------------

---@param data_recipe table ``data.raw.recipe["name"]``
---@return table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_get_keywords(data_recipe)
  local _return = {ingredients = nil, normal = nil, expensive = nil, result = nil, result_count = nil, results = nil}

  if data_recipe then
    if data_recipe.ingredients and #data_recipe.ingredients > 0 then
      _return.ingredients = true
    end
    if data_recipe.normal and #data_recipe.normal > 0 then
      _return.normal = true
    end
    if data_recipe.expensive and #data_recipe.expensive > 0 then
      _return.expensive = true
    end
    if data_recipe.result then
      _return.result = true
    end
    if data_recipe.result_count then
      _return.result_count = true
    end
    if data_recipe.results and #data_recipe.results > 0 then
      _return.results = true
    end
  end

  return _return
end
-- log(serpent.block(recipe_get_keywords( data.raw.recipe["uranium-processing"] )))
-- log(serpent.block(recipe_get_keywords( data.raw.recipe["iron-gear-wheel"] )))
-- log(serpent.block(recipe_get_keywords( data.raw.recipe["bob-liquid-air"] )))
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

---Returns a formatted ingredients table
---@param data_recipe table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
---@return table ingredients returns named pairs
function recipe_get_ingredients(data_recipe, keywords)
  local _keywords = keywords or recipe_get_keywords(data_recipe)
  local _ingredients = { normal = {}, expensive = {}, ingredients = {}}

  if _keywords.normal then
    for i, value in ipairs(data_recipe.normal.ingredients) do
      _ingredients.normal[i] = yutil.add_pairs(value)
    end
  end
  if _keywords.expensive then
    for i, value in ipairs(data_recipe.expensive.ingredients) do
      _ingredients.expensive[i] = yutil.add_pairs(value)
    end
  end
  if _keywords.ingredients then
    for i, value in ipairs(data_recipe.ingredients) do
      _ingredients.ingredients[i] = yutil.add_pairs(value)
    end
  end

  if not next(_ingredients.normal, nil) then _ingredients.normal = nil end
  if not next(_ingredients.expensive, nil) then _ingredients.expensive = nil end
  if not next(_ingredients.ingredients, nil) then _ingredients.ingredients = nil end

  return _ingredients
end
-- log(serpent.block( recipe_get_ingredients( data.raw.recipe["uranium-processing"]), {comment = false}))
-- log(serpent.block( recipe_get_ingredients( data.raw.recipe["iron-gear-wheel"]), {comment = false}))
-- log(serpent.block( recipe_get_ingredients( data.raw.recipe["gun-turret"]), {comment = false}))
-- assert(1==2, "recipe_get_ingredients()")


---@param data_recipe table ``data.raw.recipe["name"]``
---@param ingredient_types? table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function get_ingredient_type(data_recipe, ingredient_types, keywords)
  local _ingredients = recipe_get_ingredients(data_recipe)
  local _ingredient_types = ingredient_types or scrap_types
  local _keywords = keywords or recipe_get_keywords(data_recipe)
  local _return = {ingredients = {}, normal = {}, expensive = {}}

  for _, _types in ipairs(_ingredient_types) do

    if _keywords.ingredients then
      _return.ingredients[_types] = 0
      for i, ingredients in ipairs(_ingredients.ingredients) do
        if string.match(tostring(ingredients.name), _types) then
          _return.ingredients[_types] = _return.ingredients[_types] + 1
        end
      end
      if _return.ingredients[_types] == 0 then  _return.ingredients[_types] = nil end
    end

    if _keywords.normal then
      _return.normal[_types] = 0
      for i, normal in ipairs(_ingredients.normal) do
        if string.match(tostring(normal.name), _types) then
          _return.normal[_types] = _return.normal[_types] + 1
        end
      end
      if _return.normal[_types] == 0 then  _return.normal[_types] = nil end
    end

    if _keywords.expensive then
      _return.expensive[_types] = 0
      for i, expensive in ipairs(_ingredients.expensive) do
        if string.match(tostring(expensive.name), _types) then
          _return.expensive[_types] = _return.expensive[_types] + 1
        end
      end
      if _return.expensive[_types] == 0 then  _return.expensive[_types] = nil end
    end

  end

  if not next(_return.normal, nil) then  _return.normal = nil end
  if not next(_return.expensive, nil) then  _return.expensive = nil end
  if not next(_return.ingredients, nil) then  _return.ingredients = nil end

  return _return
end
-- log(serpent.block( get_ingredient_type( data.raw.recipe["gun-turret"] ), {comment = false}))
-- log(serpent.block( get_ingredient_type( data.raw.recipe["steel-plate"] ), {comment = false}))
-- log(serpent.block( get_ingredient_type( data.raw.recipe["basic-oil-processing"] ), {comment = false}))
-- assert(1==2, "get_ingredient_type()")


---Formats a recipes ingredients data to named keys
---@param data_recipe table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_format_ingredients(data_recipe, keywords)
  local _ingredients = recipe_get_ingredients(data_recipe)
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
-- recipe_format_ingredients(data.raw.recipe["iron-gear-wheel"])
-- log(serpent.block(data.raw.recipe["iron-gear-wheel"], {comment = false}))
-- recipe_format_ingredients(data.raw.recipe["uranium-processing"])
-- log(serpent.block(data.raw.recipe["uranium-processing"], {comment = false}))
-- recipe_format_ingredients(data.raw.recipe["kovarex-enrichment-process"])
-- log(serpent.block(data.raw.recipe["kovarex-enrichment-process"], {comment = false}))
-- assert(1==2, "recipe_format_ingredients()")




-- get_ingredients
-- set_ingredients
-- get_results
-- set_results




--    RESULTS    --

---Returns the results of the given recipe as key=value pairs
---@param data_recipe table ``data.raw.recipe["name"]``
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_get_results(data_recipe, keywords)
  local _results = {results = {}, normal = {}, expensive = {}}
  local _keywords = keywords or recipe_get_keywords(data_recipe)

  if _keywords.result then
    _results.results[1] = yutil.add_pairs({data_recipe.result, data_recipe.result_count})
  end
  if _keywords.results then
    for i, value in ipairs(data_recipe.results) do
      _results.results[i] = yutil.add_pairs(value)
    end
  end
  if _keywords.normal then
    if data_recipe.normal.result then
      _results.normal[1] = yutil.add_pairs({data_recipe.normal.result, data_recipe.normal.result_count})
    else
      for i, value in ipairs(data_recipe.normal.results) do
        _results.normal[i] = yutil.add_pairs(value)
      end
    end
  end
  if _keywords.expensive then
    if data_recipe.expensive.result then
      _results.expensive[1] = yutil.add_pairs({data_recipe.expensive.result, data_recipe.expensive.result_count})
    else
      for i, value in ipairs(data_recipe.expensive.results) do
        _results.expensive[i] = yutil.add_pairs(value)
      end
    end
  end

  return _results
end
-- log(serpent.block(recipe_get_results(data.raw.recipe["iron-gear-wheel"]), {comment = false}))
-- log(serpent.block(recipe_get_results(data.raw.recipe["uranium-processing"]), {comment = false}))
-- log(serpent.block(recipe_get_results(data.raw.recipe["kovarex-enrichment-process"]), {comment = false}))
-- assert(1==2, "recipe_get_results()")


---Returns a formatted recipes results data
---@param recipe_results table ``{ result, result_count, results={}, normal={}, expensive={} }``
function recipe_format_results(recipe_results)
  local _t = util.copy(recipe_results)
  local _return = { results = {} }

  if _t.result then
    _t.result_count = _t.result_count or 1
    _return.results = yutil.add_pairs({_t.result, _t.result_count})
  else
    for i, results in ipairs(_t) do
      _return.results[i] = yutil.add_pairs(results)
    end
  end

  return _return
end
-- log(serpent.block( recipe_format_results(data.raw.recipe["iron-gear-wheel"].normal) ))
-- -- log(serpent.block( data.raw.recipe["iron-gear-wheel"], {comment = false} ))
-- log(serpent.block( recipe_format_results(data.raw.recipe["uranium-processing"].results) ))
-- -- log(serpent.block( data.raw.recipe["uranium-processing"], {comment = false} ))
-- log(serpent.block( recipe_format_results(data.raw.recipe["kovarex-enrichment-process"].results) ))
-- -- log(serpent.block( data.raw.recipe["kovarex-enrichment-process"].results, {comment = false} ))
-- assert(1==2, " recipe_format_results()")


---@param data_recipe table ``data.raw.recipe["name"]``
---@param recipe_results table ``recipe_get_results(data_recipe)``
function recipe_add_results(data_recipe, recipe_results)
  local _results = recipe_results or recipe_get_results(data_recipe)

  if recipe_results.results then
    table.insert(data_recipe.results, recipe_results.results)
  end
  if recipe_results.normal then
    table.insert(data_recipe.normal.results, _results.normal)
  end
  if recipe_results.expensive then
    table.insert(data_recipe.expensive.results, _results.expensive)
  end

end


---@param data_recipe table ``data.raw.recipe["name"]``
---@param recipe_results table ``{results={}, normal={}, expensive={}}``
function recipe_replace_results(data_recipe, recipe_results)
  local _results = recipe_format_results(recipe_results)

  if recipe_results.results then
    data_recipe.results = _results.results
  end
  if recipe_results.normal then
    data_recipe.normal.results = _results.normal
  end
  if recipe_results.expensive then
    data_recipe.expensive.results = _results.expensive
  end

end

