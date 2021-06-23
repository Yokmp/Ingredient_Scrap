
-----------------
--    SCRAP    --
-----------------

---Generate a scrap item
---@param ingredient_type table ``{ name=_type, stack_size=n }``
---@param stack_size? number
---@param scrap_icon? string Prototype/icon
function get_scrap_prototype_item(ingredient_type, stack_size, scrap_icon)
  return {
    type = "item",
    name = ingredient_type.. "-scrap",
    icon = scrap_icon or get_icon(ingredient_type),
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "raw-material",
    order = "z-b",
    stack_size = stack_size or 100
  }
end
-- log(serpent.block(get_scrap_prototype_item( {"test-type"} ), {comment = false}))
-- log(serpent.block(get_scrap_prototype_item( {"copper", 42} ), {comment = false}))
-- assert(1==2, "get_scrap_prototype_item()")


---Returns the recycle scrap result name if the item can be found or false
function get_scrap_recycle_result(scrap_type)
  for _, result_type in ipairs(item_types) do
    if data.raw.item[scrap_type.."-"..result_type] then
      return scrap_type.."-"..result_type
    end
  end
  return false
end
-- log(serpent.block(get_scrap_recycle_result( "copper" ), {comment = false}))
-- log(serpent.block(get_scrap_recycle_result( "iron" ), {comment = false}))
-- log(serpent.block(get_scrap_recycle_result( "steel" ), {comment = false}))
-- assert(1==2, "get_scrap_recycle_result()")


---@param scrap_type string ingredient_type
---@param recycle_result? string ingredient_type
---@return table recipe
function get_scrap_prototype_recipe(scrap_type, recycle_result)
  local _item, _order
  if recycle_result then
    _item = scrap_type.."-"..recycle_result
  else
    _item = get_scrap_recycle_result(scrap_type) or scrap_type.."-missing"
  end
  if data.raw.recipe[_item] then
    _order = data.raw.recipe[_item].order
  end
  local _name = "recycle-" ..scrap_type.. "-scrap"
  local _enabled = recipe_is_enabled(data.raw.recipe[_item])

  return {
    type = "recipe",
    name = _name,
    localised_name = {"recipe-name.".._name},
    icons = get_scrap_icons(scrap_type, _item),
    subgroup = "raw-material",
    category = "smelting",
    order = _order or "z",
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
-- log(serpent.block(get_scrap_prototype_recipe( "copper" ), {comment = false}))
-- log(serpent.block(get_scrap_prototype_recipe( "steel" ), {comment = false}))
-- assert(1==2, "get_scrap_prototype_recipe()")


---Does an ingredient match one of the types
---@param data_recipe table ``data.raw.recipe["name"]``
---@param scrap_type string ingredient_types[n]
---@param keywords? table ``{ingredients = boolean, normal = number, expensive = number, result = number, result_count = number, results = number}``
-- function get_scrap_amount(data_recipe, scrap_type, keywords)
--   local _amount = { match = false, ingredients = 0, normal = 0, expensive = 0 }
--   local _keywords = keywords or recipe_get_keywords(data_recipe)

--   if _keywords.normal then
--     for i, value in ipairs(data_recipe.normal.ingredients) do
--       value = add_pairs(value)
--       if string.match(tostring(value.name), scrap_type) then
--         _amount.normal      = _amount.normal + 1
--         _amount.match       = true
--       end
--     end
--   end
--   if _keywords.expensive then
--     for i, value in ipairs(data_recipe.expensive.ingredients) do
--       value = add_pairs(value)
--       if string.match(tostring(value.name), scrap_type) then
--         _amount.expensive   = _amount.expensive + 1
--         _amount.match       = true
--       end
--     end
--   end
--   if _keywords.ingredients then
--     for i, value in ipairs(data_recipe.ingredients) do
--       value = add_pairs(value)
--       if string.match(tostring( value.name ), scrap_type) then
--         _amount.ingredients = _amount.ingredients + 1
--         _amount.match       = true
--       end
--     end
--   end

--   if _amount.normal == 0 then _amount.normal = nil end
--   if _amount.expensive == 0 then _amount.expensive = nil end
--   if _amount.ingredients == 0 then _amount.ingredients = nil end

--   return _amount
-- end
-- log(serpent.block( get_scrap_amount( data.raw.recipe["uranium-processing"], "iron" ), {comment = false}))
-- log(serpent.block( get_scrap_amount( data.raw.recipe["iron-gear-wheel"], "iron" ), {comment = false}))
-- log(serpent.block( get_scrap_amount( data.raw.recipe["gun-turret"], "iron" ), {comment = false}))
-- log(serpent.block( get_scrap_amount( data.raw.recipe["steel-plate"], "steel" ), {comment = false}))
-- assert(1==2, "get_scrap_amount()")


---returns a results table
---@param data_recipe table ``data.raw.recipe["name"]``
---@param scrap_type? string get_ingredient_type()
---@param scrap_amount_max? table { match = false, ingredients = n, normal = n, expensive = n }
---@return table ``difficulty = {name = _name, amount_min = 1, amount_max = _amount, probability = setting.value/100}``
function get_scrap_result(data_recipe, scrap_type, scrap_amount_max)
  local _scrap_type = scrap_type or get_ingredient_type(data_recipe)
  local _scrap_probability = settings.startup["ingredient-scrap-probability"].value/100
  local _return = {results = {}, normal = {}, expensive = {}}

  if _scrap_type.ingredients then
    for _type, _amount in pairs(_scrap_type.ingredients) do
      table.insert(_return.results, {name = _type.."-scrap", amount_min = 1, amount_max = _amount, probability = _scrap_probability})
    end
  end
  if _scrap_type.normal then
    for _type, _amount in pairs(_scrap_type.normal) do
      table.insert(_return.normal, {name = _type.."-scrap", amount_min = 1, amount_max = _amount, probability = _scrap_probability})
    end
  end
  if _scrap_type.expensive then
    for _type, _amount in pairs(_scrap_type.expensive) do
      table.insert(_return.expensive, {name = _type.."-scrap", amount_min = 1, amount_max = _amount, probability = _scrap_probability})
    end
  end

  if not next(_return.normal, nil) then  _return.normal = nil end
  if not next(_return.expensive, nil) then  _return.expensive = nil end
  if not next(_return.results, nil) then  _return.results = nil end

  return _return
end
-- log( serpent.block( get_scrap_result( data.raw.recipe["iron-gear-wheel"], {ingredients={["test-type"] = 99}} ), {comment = false}))
-- log( serpent.block( get_scrap_result( data.raw.recipe["gun-turret"]), {comment = false}))
-- log( serpent.block( get_scrap_result( data.raw.recipe["steel-plate"]), {comment = false}))
-- log( serpent.block( get_scrap_result( data.raw.recipe["basic-oil-processing"]), {comment = false}))
-- assert(1==2, "get_scrap_result()")


---**Results of the given recipe will be formatted!**
---@param data_recipe table ``data.raw.recipe["name"]``
---@param scrap_type? string scrap_ingredient_type
---@param keywords? table ``{ingredients = boolean, normal = boolean, expensive = boolean, result = boolean, result_count = boolean, results = boolean}``
function recipe_add_scrap_result(data_recipe, scrap_type, keywords)
  recipe_format_ingredients(data_recipe)
  recipe_format_results(data_recipe)

  local _keywords = keywords or recipe_get_keywords(data_recipe)
  local _scrap_type = scrap_type or get_ingredient_type(data_recipe)
  local _result = get_scrap_result(data.raw.recipe[data_recipe.name])

  if data_recipe.name == "gun-turret" then
    log("_keywords: "..serpent.block(_keywords))
    log("_scrap_type: "..serpent.block(_scrap_type))
    log("_result: "..serpent.block(_result))
  end

  if _keywords.results and _result.results then
    if data_recipe.results[1].name then
      data_recipe.main_product = data_recipe.results[1].name or data_recipe.name
    end
    for _, results in ipairs(_result.results) do
      table.insert(data_recipe.results, results)
    end
  end

  if _keywords.normal and _result.normal then
    if data_recipe.normal.results[1].name then
      data_recipe.normal.main_product = data_recipe.normal.results[1].name or data_recipe.name
    end
    for _, results in ipairs(_result.normal) do
      table.insert(data_recipe.normal.results, results)
    end
  end
  if _keywords.expensive and _result.expensive then
    if data_recipe.expensive.results[1].name then
      data_recipe.expensive.main_product = data_recipe.expensive.results[1].name or data_recipe.name
    end
    for _, results in ipairs(_result.expensive) do
      table.insert(data_recipe.expensive.results, results)
    end
  end


end
-- recipe_add_scrap_result(data.raw.recipe["steel-plate"])
-- recipe_add_scrap_result(data.raw.recipe["basic-oil-processing"])
-- recipe_add_scrap_result(data.raw.recipe["gun-turret"])
-- log(serpent.block(data.raw.recipe["steel-plate"]))
-- log(serpent.block(data.raw.recipe["basic-oil-processing"]))
-- log(serpent.block(data.raw.recipe["gun-turret"]))
-- assert(1==2, "recipe_add_scrap_result()")






-- ---@param keywords? table ``{ingredients = boolean, normal = number, expensive = number, result = number, result_count = number, results = number}``
-- function scrap_add_to_results(data_recipe, scrap_type, keywords)
--   local scrap_result = get_scrap_result(data_recipe, scrap_type)
--   local _keywords = keywords or recipe_get_keywords(data_recipe)

--   if _keywords.results then
--     table.insert(data_recipe.results, scrap_result.results)
--   end
--   if _keywords.normal then
--     table.insert(data_recipe.normal.results, scrap_result.normal)
--   end
--   if _keywords.expensive then
--     table.insert(data_recipe.expensive.results, scrap_result.expensive)
--   end
-- end
--   scrap_add_to_results(data.raw.recipe["iron-gear-wheel"], "iron")
-- log(serpent.block(data.raw.recipe["iron-gear-wheel"]))
-- scrap_add_to_results(data.raw.recipe["gun-turret"], "copper")
-- log(serpent.block(data.raw.recipe["gun-turret"]))
-- assert(1==2, "scrap_add_to_results()")
