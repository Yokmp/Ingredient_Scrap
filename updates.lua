-- TODO: If a result matches a _type then add that _type instead of result component (eg steel-plate -> steel-scrap NOT iron-scrap)
-- ? add some fluid waste ? -> would require heavy recipe adjustments or additional pipe_connections
-- TODO? maybe make it local and provide an interface if this ever becomes a stand-alone or even public

-- require("lldebugger").start()
local debug = false -- use this to spam your log

local Scrap = {}

--[[  This table holds the phrases and looks into the recipes with string.match() to find them.
  So iron will match iron-plate and hardenend-iron-plate. Even superironbar would be a match.
  To exclude like copper-plate but still use copper-cables just be more specific. It is also used
  to contruct the scrap-items like ``iron-scrap``.]]
local _types = {"iron", "copper", "steel"}
--[[  This table holds the result suffix which is then be constructed to ``_types.."-".._results`` (eg iron-plate).
  Like the _types table, this one also goes by priority, so position 1 is taken if possible, if not pos 2 will be checked until
  it runs out of options, then the script will log it and **ignore** the recipe.
  As there will be no recycling of this scrap-item place some kind of fallback at the end. "*plate*"" is a good candidate.]]
local _results = {"plate"} --, "ingot"}

local mod = require("mods")


_types = table.extend(mod[1], _types)
_results = table.extend(mod[2], _results)

-- log(serpent.block(_types))
-- assert(1==2)

--- Adds the ingredients (uses difficulty if possible) to the scrap_results table.
---@return table ``{[_types.."-scrap"] = amount}``
local function add_to_results(scrap_results, recipe, ingredients, mode)
  for _, v in ipairs(ingredients) do
    for i=1, #_types do
      if string.match(tostring(v[1]), _types[i]) then
        scrap_results[recipe] = scrap_results[recipe] or {}
        scrap_results[recipe][mode] = scrap_results[recipe][mode] or {}
        if mode ~= "results" then
          scrap_results[recipe][mode].results = scrap_results[recipe][mode].results or {}
          local scrap = scrap_results[recipe][mode].results[_types[i].."-scrap"]
          scrap_results[recipe][mode].results[_types[i].."-scrap"] = scrap and scrap + 1 or 1
        else
          local scrap = scrap_results[recipe][mode][_types[i].."-scrap"]
          scrap_results[recipe][mode][_types[i].."-scrap"] = scrap and scrap + 1 or 1
        end
        break
      end
    end
  end
end
---Returns a table which holds all items and their ingredients. If there is a difficulty it will also be included.
---@return table ``{results = {name = name, amount_min = 1, amount_max = amount}}``
function Scrap.get_scrap_results()
  local scrap_results = {}
  local scrap_probability = settings.startup["ingredient-scrap-probability"].value/100
  for recipe, value in pairs(data.raw.recipe) do

    if value.expensive then
      local insert = {}
      add_to_results(scrap_results, recipe, value.expensive.ingredients, "expensive")
      if scrap_results[recipe] and scrap_results[recipe].expensive then
        for name, amount in pairs(scrap_results[recipe].expensive.results) do
          table.insert( insert, {name = name, amount_min = 1, amount_max = amount, probability = scrap_probability} )
        end
        scrap_results[recipe].expensive.results = insert
      else if debug then log(tostring(recipe)..".expensive -> not found") end
        scrap_results[recipe] = nil
      end
    end

    if value.normal then
      local insert = {}
      add_to_results(scrap_results, recipe, value.normal.ingredients, "normal")
      if scrap_results[recipe] and scrap_results[recipe].normal then
        for name, amount in pairs(scrap_results[recipe].normal.results) do
          table.insert( insert, {name = name, amount_min = 1, amount_max = amount, probability = scrap_probability} )
        end
        scrap_results[recipe].normal.results = insert
      else if debug then log(tostring(recipe)..".normal -> not found") end
        scrap_results[recipe] = nil
      end
    end

    if value.ingredients then
      local insert = {}
      add_to_results(scrap_results, recipe, value.ingredients, "results")
      if scrap_results[recipe] and scrap_results[recipe].results then
        for name, amount in pairs(scrap_results[recipe].results) do
          table.insert( insert, {name = name, amount_min = 1, amount_max = amount, probability = scrap_probability} )
        end
        scrap_results[recipe].results = insert
      else if debug then log(tostring(recipe)..".results -> not found") end
        scrap_results[recipe] = nil
      end
    end

  end
  return scrap_results
end
-- log(serpent.block(data.raw.recipe["iron-gear-wheel"], {comment = false}))
-- log(serpent.block(Scrap.get_scrap_results()["iron-gear-wheel"], {comment = false}))
-- log(serpent.block(Scrap.get_scrap_results()["gun-turret"], {comment = false}))
-- assert(1==2, " D I E")

--- Create the scrap item from ``_types`` and return the table.
---@return table items
function Scrap.get_scrap_item()
  local scrap_item = {}
  for _, item in ipairs(_types) do
    if type(item) == "string" then
      table.insert(
        scrap_item,
        {
          type = "item",
          name = item.. "-scrap",
          icon = get_icon(item),
          icon_size = 64, icon_mipmaps = 4,
          subgroup = "raw-material",
          order = "z-b",
          stack_size = 100
        }
      )
    else
      log(debug.traceback())
      log("String expected, got " ..type(item))
      return nil
    end
  end
  return scrap_item
end
-- log(serpent.block(Scrap.get_scrap_item(), {comment = false}))
-- assert(1==2, " D I E")

--- Adds a scrap recipe to an existing Technology if available
---@param item string the item to look for in ``effects.recipe``
---@param name string the name of the recipe to add
---@return table technologies returns matching technologies as array
function Scrap.insert_technology(item, name, raw_item)
local unlock = { recipe = name, type = "unlock-recipe" }
local techs = {}
  for key, value in pairs(data.raw.technology) do
    -- log(value.name.." - " ..item.." - " ..name.. " - " ..raw_item)
    if string.match(tostring(value.name), raw_item) then
-- log(value.name .. " - " ..name)
    end
    if value.effects and #value.effects > 0 then
      for _, effects in pairs(value.effects) do
        if (effects.recipe and effects.recipe == item) then
          techs[#techs+1] = key
          break
        end
      end
    elseif string.match(tostring(value.name), raw_item) then
      techs[#techs+1] = key
      break
    end
  end
  for _,v in ipairs(techs) do
    table.insert( data.raw.technology[v].effects, unlock )
  end
  return techs
end
-- log(serpent.block(Scrap.insert_technology("zinc-plate", "recycle-zinc-scrap", "zinc"), {comment = false}))
-- log(serpent.block(data.raw.technology["zinc-processing"], {comment = false}))
-- assert(1==2, " D I E")

--- Create the scrap items recycling recipe from ``_types`` and return the table.
---@param result? table ``_types.. "-" ..result`` eg: iron-plate
---@param enabled? boolean default depends on available technologies
---@return table recipes
function Scrap.get_scrap_recipes(result, enabled)
  local scrap_recipes = {}
  result = result or _results
  local _result
  enabled = enabled or false
  for _, item in ipairs(_types) do
    if type(item) == "string" then
      local name = "recycle-" ..item.. "-scrap"

      for _, v in ipairs(result) do
        -- if not data.raw.item[item] then
          _result = item.."-"..v
        -- else
        --   _result = item
        -- end
        if data.raw.item[_result] then
          if not enabled then
            local tech = Scrap.insert_technology(_result, name, item)
            if #tech == 0 and not data.raw.recipe[name] then enabled = true end
            -- log("Scrap.insert_technology() " ..name.. ": " ..serpent.block(tech))
            -- log(_result.. " : " ..tostring(enabled))
          end
          break
        else
          result._result = nil
          -- error("Item '" ..item.. "' not found!") -- this is bad
          if debug then
            log("item " ..serpent.block(_result).. "not found!")
          end
        end
      end
      -- log(serpent.block(_result))
      -- log(serpent.block(item))
      local order = "z" --data.raw.item[_result].order.. "-a" or "z"

      -- if not enabled then
      --   local tech = Scrap.insert_technology(_result, name)
      --   if #tech == 0 then enabled = true end
      --   -- log("Scrap.insert_technology() " ..name.. ": " ..serpent.dump(tech))
      --   -- log(_result.. " : " ..tostring(enabled))
      -- end

      table.insert(
        scrap_recipes,
        {
          type = "recipe",
          name = name,
          localised_name = {"recipe-name."..name},
          icons = get_scrap_icons(item, _result),
          subgroup = "raw-material",
          category = "smelting",
          order = order,
          enabled = enabled,
          energy_required = 3.2,
          always_show_products = true,
          allow_as_intermediate = false,
          ingredients = {{ item.. "-scrap", settings.startup["ingredient-scrap-needed"].value}},
          results = {{ _result, 1 }}
        }
      )
      enabled = false
    else
      log(debug.traceback())
      log("String expected, got " ..type(item))
      return nil
    end
  end
  return scrap_recipes
end
-- data:extend(Scrap.get_scrap_item())
-- Scrap.get_scrap_recipes()
-- -- log(serpent.block(Scrap.get_scrap_recipes(), {comment = false}))
-- assert(1==2, " D I E")


--- Create and add scrap items *(preferably in data-updates stage)*
---@param scrap_results table Expected format see ``get_scrap_results()``
---@param items table Expected format see ``get_scrap_item()``
---@param recipes table Expected format see ``get_scrap_recipes()``
function Scrap.add_scrap(scrap_results, items, recipes)
-- TODO data.raw.recipe[item].results - big nono

-- log(serpent.block(scrap_results))

  for item, result in pairs(scrap_results) do

    if result and result.results then -- No diffculty
      -- if data.raw.recipe[item].results then -- this might never happen except it was set by a mod
      --   table.insert(scrap_results[item].results, data.raw.recipe[item].results)
      -- end
      if data.raw.recipe[item].result then
        data.raw.recipe[item].main_product = data.raw.recipe[item].result
        local data_result = data.raw.recipe[item].result
        local data_amount = data.raw.recipe[item].result_count or 1
        table.insert( result.results, {data_result, data_amount})
        data.raw.recipe[item].results = result.results
-- log(serpent.block(data.raw.recipe[item]))
      end
    end

    if result.expensive then -- expensive difficulty
      -- if data.raw.recipe[item].expensive.results then -- this might never happen except it was set by a mod
      --   table.insert(scrap_results[item].expensive.results, data.raw.recipe[item].expensive.results)
      -- end
      if data.raw.recipe[item].expensive.result then
          data.raw.recipe[item].expensive.main_product = data.raw.recipe[item].expensive.result
        local  data_result = data.raw.recipe[item].expensive.result
        local  data_amount = data.raw.recipe[item].expensive.result_count or 1

        -- if scrap_results[item].expensive.results then
          table.insert( result.expensive.results, {data_result, data_amount})
          data.raw.recipe[item].expensive.results = result.expensive.results
--         else
-- log(serpent.block(tostring(scrap_results[item])..".expensive.results not found!"))
--         end
      end
-- log(serpent.block(data.raw.recipe[item]))
    end

    if result.normal then -- normal diffculty
      -- if data.raw.recipe[item].normal.results then -- this might never happen except it was set by a mod
      --   table.insert(scrap_results[item].normal.results, data.raw.recipe[item].normal.results)
      -- end
      if data.raw.recipe[item].normal.result then
          data.raw.recipe[item].normal.main_product = data.raw.recipe[item].normal.result
        local  data_result = data.raw.recipe[item].normal.result
        local  data_amount = data.raw.recipe[item].normal.result_count or 1

        -- if scrap_results[item].normal.results then
          table.insert( scrap_results[item].normal.results, {data_result, data_amount})
          data.raw.recipe[item].normal.results = result.normal.results
--         else
-- log(serpent.block(data.raw.recipe[item].name..".normal.results not found!"))
--         end
      end
    end
  end
  data:extend(items)
  data:extend(recipes)
end

Scrap.add_scrap(
  Scrap.get_scrap_results(),
  Scrap.get_scrap_item(),
  Scrap.get_scrap_recipes() )

-- log(serpent.block(data.raw.technology["steel-processing"], {comment = false}))
-- assert(1==2, " D I E")

-- local startResult = require('vscode-debuggee').start()
-- print('debuggee start result: ', startResult)

if debug then return Scrap end

--[[
data:extend({

  {
    type = "recipe",
    name = "recycle-inserter",
	  subgroup = "scrap",
    category = "chemistry",
    icons = {
      {
        icon = "__base__/graphics/icons/inserter.png",
        icon_size = 64, icon_mipmaps = 4,
        scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
      },
      {
        icon = "__Ingredient_Scrap__/graphics/icons/recycle.png",
        icon_size = 64, icon_mipmaps = 4,
        scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 0.8, g = 1.0, b = 0.8, a = 1.0 }
      },
    },
    energy_required = 3,
    enabled = false,
    ingredients =
    {
      {type="fluid", name="water", amount=30},
      {type="fluid", name="sulfuric-acid", amount=5},
      {name = "inserter-scrap", amount=1}
    },
    results=
    {
      {type="item", name="circuit-scrap", amount=1},
      {type="item", name="iron-plate-scrap", amount=3},
      {type="fluid", name="waste-water", amount=30}
    },
    crafting_machine_tint =
    {
      primary = {r = 1.000, g = 1.000, b = 0.990, a = 0.000},   -- REVIEW COLORS
      secondary = {r = 1.000, g = 0.990, b = 1.000, a = 0.000}, -- REVIEW COLORS
      tertiary = {r = 0.990, g = 1.000, b = 1.000, a = 0.000},  -- REVIEW COLORS
    }
  },
]]