local yutil = require("functions")
local mod = require("mods")
local patch = mod[3]

local scrap_types = yutil.table.extend(mod[1], {"iron", "copper", "steel"})
local item_types = yutil.table.extend(mod[2], {"plate"})

local settings_amount       = settings.startup["yis-amount-by-ingredients"].value ---@type boolean
local settings_method       = settings.startup["yis-amount-limit"].value ---@type boolean
local settings_probability  = settings.startup["yis-probability"].value/100
local settings_needed       = settings.startup["yis-needed"].value ---@type integer
-- local settings_allow_fluids = settings.startup["yis-allow-fluids"].value ---@type boolean


-------------------
--    UTILITY    --
-------------------



local do_test = false
-- local debug_test_recipe = "gun-turret"
-- local debug_test_recipe = "electronic-circuit"
local debug_test_recipe = "tank"
-- local debug_test_recipe = "empty-barrel"
-- local debug_test_recipe = "iron-gear-wheel"
-- local debug_test_recipe = "radar"
-- local debug_test_recipe = "bronze-alloy"
-- local debug_test_recipe = "aluminum-cable"
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
---get new return template
local function new_return(recipe_name)
  local _t = util.table.deepcopy(_return_template_)
  _t.name = recipe_name
  return _t
end


---remove unused scraptype combinations
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
-- error("filter_scrap_types()")


---Returns a scrap type table or false
---@param scrap_type string
---@param item_types table uses item_types{}
---@return table|boolean ``{ scrap = scrap_type.."-scrap", item = recycle-result, amount = 0 }``
local function get_scrap_types(scrap_type, item_types)
  for _, i_type in ipairs(item_types) do
    local _name = scrap_type.."-"..i_type
    if data.raw.item[_name] then
      return { scrap = scrap_type.."-scrap", item = _name, amount = 0 }
    end
  end
  return false
end
-- if do_test then log(serpent.block(get_scrap_types("iron", item_types))) end
-- error("get_scrap_types()")




------------------
--    RECIPE    --
------------------



--create a new return table
local _return = new_return(debug_test_recipe)



---Gets all ingredients of a recipe, formats it and inserts it into ``_return.recipe{}``
---@param recipe_name string
---@return table _return.recipe
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
-- error("get_recipe_ingredients()")


---determines the ingredient types and amount and inserts them into ``_return.recipe.(difficulty).ingredient_types[type]``
---
---Also filters fluids and sets the method for calculating scrap amounts
---@param recipe_name string
---@return table
local function get_recipe_ingredient_types(recipe_name)
  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then

    if _return.recipe.ingredients[1] then
      for _, ingredient in ipairs(_return.recipe.ingredients) do
        for _, _type in ipairs(scrap_types) do
          if string.find(ingredient.name, _type, 0, true) and get_scrap_types(_type, item_types) then
            _return.recipe.ingredient_types[_type] = _return.recipe.ingredient_types[_type] or get_scrap_types(_type, item_types)
            if settings_amount and not data.raw.fluid[ingredient.name] then
              _return.recipe.ingredient_types[_type].amount = _return.recipe.ingredient_types[_type].amount + ingredient.amount
            else
              _return.recipe.ingredient_types[_type].amount = _return.recipe.ingredient_types[_type].amount +1
            end
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
            if settings_amount and not data.raw.fluid[ingredient.name]  then
              _return.recipe.normal.ingredient_types[_type].amount = _return.recipe.normal.ingredient_types[_type].amount + ingredient.amount
            else
              _return.recipe.normal.ingredient_types[_type].amount = _return.recipe.normal.ingredient_types[_type].amount +1
            end
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
            if settings_amount and not data.raw.fluid[ingredient.name]  then
              _return.recipe.expensive.ingredient_types[_type].amount = _return.recipe.expensive.ingredient_types[_type].amount + ingredient.amount
            else
              _return.recipe.expensive.ingredient_types[_type].amount = _return.recipe.expensive.ingredient_types[_type].amount +1
            end
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
-- get_recipe_ingredient_types(debug_test_recipe)
-- log(serpent.block(_return.recipe))
-- error("get_recipe_ingredient_types()")


---Calculates the binomial coefficient n over p (or choose(n, p))
---@param n integer amount of trials
---@param p integer probability of a Success
---@return string|number
local function binom(n, p) -- if n=1, p=1 -> 0
  local result = 1
  for i = 1, p do
    result = result*(n+1-i)
    result = result/i
  end
  return result
end


---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@param probability number
---@return integer low
---@return integer high
local function get_scrap_amount_range(base_amount, probability)
  local low = -1
  local high = -1
  local acc = 0
  for i = 0, base_amount do
    local prob = math.pow(probability, i)*math.pow(1-probability, base_amount-i)*binom(base_amount, i)
    acc = acc+prob
    if low < 0 and acc > 0.05 then
      low = i
    end
    if high < 0 and acc > 0.95 then
      high = i-1
    end
  end
  return low, high
end


---Adds scrap results, also takes amount into account so that less than 1 scrap is still 1
---@param recipe table recipe data like in ``_return.recipe``
local function add_scrap_results(recipe)
  for _, scrap in pairs(recipe.ingredient_types) do
    if settings_method then
      local low_amount, high_amount = get_scrap_amount_range(scrap.amount, settings_probability)
      if high_amount>1 then
        table.insert(recipe.results, {name = scrap.scrap, amount_min = low_amount, amount_max = high_amount})
      else
        -- If the ingredient amount or scrap chance is low, there may be less
        -- than one scrap by average.  Calculate the chance for a single scrap
        -- instead of using a range.
        table.insert(recipe.results, {name = scrap.scrap, amount = 1, probability = settings_probability*scrap.amount})
      end
    else
      scrap.amount = util.clamp(scrap.amount, 1,( scrap.amount*settings_probability))
      table.insert(recipe.results, {name = scrap.scrap, amount = scrap.amount, probability = settings_probability})
    end
  end
end


---gets the results, creates the scrap results and inserts them into ``_return.recipe.(difficulty).results``
---@param recipe_name string
---@return table
local function get_recipe_results(recipe_name)

  if type(recipe_name) == "string" and data.raw.recipe[recipe_name] then
    local data_recipe = data.raw.recipe[recipe_name]

    if data_recipe.result then
      -- _return.recipe.results[1] = ylib.util.add_pairs( {data_recipe.result, data_recipe.result_count} )
      _return.recipe.results[1] = yutil.add_pairs( {data_recipe.result, data_recipe.result_count} )
      add_scrap_results(_return.recipe)
    end

    if data_recipe.results and data_recipe.results[1] then
      for i, result in ipairs(data_recipe.results) do
        -- _return.recipe.results[i] = ylib.util.add_pairs( result )
        _return.recipe.results[i] = yutil.add_pairs( result )
      end
      add_scrap_results(_return.recipe)
    end

    if data_recipe.normal then
      if data_recipe.normal.results and data_recipe.normal.results[1] then
        for i, result in ipairs(data_recipe.normal.results) do
          -- _return.recipe.normal.results[i] = ylib.util.add_pairs( result )
          _return.recipe.normal.results[i] = yutil.add_pairs( result )
        end
      elseif data_recipe.normal.result then
        -- _return.recipe.normal.results[1] = ylib.util.add_pairs( {data_recipe.normal.result, data_recipe.normal.result_count} )
        _return.recipe.normal.results[1] = yutil.add_pairs( {data_recipe.normal.result, data_recipe.normal.result_count} )
      end
      add_scrap_results(_return.recipe.normal)
    end

    if data_recipe.expensive then
      if data_recipe.expensive.results and data_recipe.expensive.results[1] then
        for i, result in ipairs(data_recipe.expensive.results) do
          -- _return.recipe.expensive.results[i] = ylib.util.add_pairs( result )
          _return.recipe.expensive.results[i] = yutil.add_pairs( result )
        end
      elseif data_recipe.expensive.result then
        -- _return.recipe.expensive.results[1] = ylib.util.add_pairs( {data_recipe.expensive.result, data_recipe.expensive.result_count} )
        _return.recipe.expensive.results[1] = yutil.add_pairs( {data_recipe.expensive.result, data_recipe.expensive.result_count} )
      end
      add_scrap_results(_return.recipe.expensive)
    end

  else
    log(" Recipe not found: "..tostring(recipe_name))
    error(" Recipe not found: "..tostring(recipe_name))
  end
  return _return.recipe
end
-- if do_test then  get_recipe_results(debug_test_recipe) end
-- log(serpent.block( _return.recipe ))
-- error("get_recipe_results()")


local function recipe_is_enabled(recipe_name) -- determined through technology
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
-- error("recipe_is_enabled()")


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
-- error("recipe_get_main_product()")




----------------------
--    TECHNOLOGY    --
----------------------



local function get_scrap_recycle_tech(recipe_name, raw_scrap) -- TODO: normal, expensive
  local _techs = { effects={enabled=true, recipes={}}, normal={enabled=true, recipes={}}, expensive={enabled=true, recipes={}} }
  for tech_name, value in pairs(data.raw.technology) do
    if patch.technology(tech_name) and value.effects then
      for _, effect in ipairs(value.effects) do
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
-- if do_test then  log(serpent.block( get_scrap_recycle_tech("gold-plate", "gold") )) end
-- error("get_scrap_recycle_tech()")





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
-- error("get_recycle_result_name()")


local function make_scrap(scrap_type, scrap_icon, stack_size)
  local scrap_name = scrap_type.. "-scrap"

  if not data.raw.item[scrap_name] then
    local _data
    local recipe_name = "recycle-" ..scrap_name
    local result_name = get_recycle_result_name(scrap_type)
    local item_order = "is-["..scrap_name.."]"
    local recipe_order = "is-["..recipe_name.."]"

-- this makes recipe_is_enabled() somewhat obsolete.
    local enabled = --[[_return.recipe.enabled or]] get_scrap_recycle_tech(result_name, scrap_type).effects.enabled
    local normal_enabled = --[[_return.recipe.normal.enabled or]] get_scrap_recycle_tech(result_name, scrap_type).effects.enabled
    local expensive_enabled = --[[_return.recipe.expensive.enabled or]] get_scrap_recycle_tech(result_name, scrap_type).effects.enabled

-- add recipe to technology, or not --?-//IDEA normal, expensive but noone uses difficulty in technologies
    if not data.raw.recipe[recipe_name]
    and not patch.is_blacklisted(scrap_name) then
      local tech_table = get_scrap_recycle_tech(result_name, scrap_type)
      for _, tech_name in ipairs(tech_table.effects.recipes) do
        log(tech_name.." unlocks "..recipe_name)
        table.insert(data.raw.technology[tech_name].effects,
          { type = "unlock-recipe", recipe = recipe_name } )
      end
    else
      enabled = true
      normal_enabled = true
      expensive_enabled = true
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
          ingredients = {{ name = scrap_name, amount = settings_needed}},
          results = {{ name = result_name, amount = 1 }}
        },
        expensive = {
          enabled = expensive_enabled,
          energy_required = 3.2,
          ingredients = {{ name = scrap_name, amount = settings_needed*2}},
          results = {{ name = result_name, amount = 1 }}
        }
      },
    }
  data:extend(_data)

  return _data
  end
end
-- if do_test then log(serpent.block( make_scrap("steel") )) end
-- error("make_scrap_items()")




filter_scrap_types()
for _, s_type in ipairs(scrap_types) do
  if do_test then log("Generating "..s_type.."-scrap item and recipe") end
  make_scrap(s_type)
end

-- patch.icons()

for recipe_name, recipe_data in pairs(data.raw.recipe) do
  -- if do_test then log(recipe_name.." - "..tostring(recipe_data.subgroup)) end

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
      error("THIS IS THE END")
    end
end

patch.recipes()

-- for key, value in pairs(data.raw.recipe) do
--   if string.match(value.name, "aluminum") then
--     log(serpent.block(data.raw.recipe[value.name]))
--   end
-- end
-- for key, value in pairs(data.raw.technology) do
--   if string.match(value.name, "refining") then
--     log(serpent.block(data.raw.technology[value.name]))
--   end
-- end
-- error("find_name")

