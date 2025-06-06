local yutil = require("functions")

util = util or {}
util.technology = util.technology or {}
util.item = util.item or {}


---Search by pattern
---@param table table
---@param pattern string
---@return table|nil
function util.find(table, pattern)
  for _, value in pairs(table) do
    if string.find(value.name, pattern, 0, true) then return value end
  end
end

--------------------
--    TECHOLOGY   --
--------------------


--#region Technology

---Search technologies by pattern
---@param pattern string
---@return table|nil
function util.technology.find(pattern)
  return util.find(data.raw.item, pattern)
end

---Add a prerequisite to a given technology
---@param tech_name string the technology which to be altered
---@param prerequisite string the technology which to be used as prerequisite
function util.technology.add_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  if technology and data.raw.technology[prerequisite] then
    if technology.prerequisites then
      table.insert(technology.prerequisites, prerequisite)
    else
      technology.prerequisites = { prerequisite }
    end
  end
end

---Add an effect to a given technology
---@param tech_name string the technology which to be altered
---@param effect table https://wiki.factorio.com/Prototype/Technology#effects
function util.technology.add_effect(tech_name, effect)
  local technology = data.raw.technology[tech_name]
  if technology then
    if not technology.effects then technology.effects = {} end
    if effect and effect.type == "unlock-recipe" then
      if data.raw.recipe[effect.recipe] then
        table.insert(technology.effects, effect)
      else
        log("WARNING: " .. tostring(effect) .. " recipe not found!")
      end
    end
  end
end

---Remove a prerequisite from a given technology
---@param tech_name string the technology which to be altered
---@param prerequisite string the technology which to be used as prerequisite
function util.technology.remove_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  if technology then
    for i, prereq in pairs(technology.prerequisites) do
      if prereq == prerequisite then
        table.remove(technology.prerequisites, i)
        break
      end
    end
  end
end

---Remove recipe unlock effect from a given technology
---@param tech_name string the technology which to be altered
---@param recipe_name string
function util.technology.remove_recipe_effect(tech_name, recipe_name)
  local technology = data.raw.technology[tech_name]
  if technology then
    for i, effect in pairs(technology.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        table.remove(technology.effects, i)
        break
      end
    end
  end
end

---Set technology ingredients
---@param tech_name string the technology which to be altered
---@param ingredients table
function util.technology.set_tech_recipe(tech_name, ingredients)
  local technology = data.raw.technology[tech_name]
  if technology then
    technology.unit.ingredients = ingredients
  end
end

--#endregion Technology



----------------
--    SCRAP   --
----------------


---returns the amount
---@param ingredients table
---@param scrap_type string
---@return integer
local function sum_scrap_amount(ingredients, scrap_type)
  local scrap_amount = 0
  for _, table in ipairs(ingredients) do
    if table.name and util.find(table.name, scrap_type) then
      scrap_amount = scrap_amount + table.amount
    elseif util.find(table[1], scrap_type) then
      scrap_amount = scrap_amount + (table[2] or 1)
    end
  end
  return scrap_amount
end

---Returns the amount of scrap based on the recipes ingredients
---@param recipe_name string
---@param scrap_type string eg iron, copper, lead, etc
---@return table
function get_scrap_amount(recipe_name, scrap_type)
  local scrap_amount = { 0, 0, 0 }
  local data_recipe = data.raw.recipe[recipe_name]

  if data_recipe.ingredients[1] then
    scrap_amount[1] = scrap_amount[1] + sum_scrap_amount(data_recipe.ingredients, scrap_type)
  end

  return scrap_amount
end

---Adds scrap as result to recipe
---@param recipe_name string
---@param scrap_type string eg iron, copper etc.
---@param scrap_amount table max amount {ingredients, normal, expensive}
function add_scrap_result(recipe_name, scrap_type, scrap_amount)
  scrap_amount = scrap_amount or get_scrap_amount(recipe_name, scrap_type)
  local data_recipe = data.raw.recipe[recipe_name]
  local scrap_probability = settings.startup["ingredient-scrap-probability"].value / 100

  table.insert(data.raw.recipe[recipe_name].results,
    { name = scrap_type .. "-scrap", amount_min = 1, amount_max = scrap_amount[1], probability = scrap_probability })
end

-- add_scrap_recult("iron-stick", "iron-scrap", {1,1,1})







function util.get_recycle_result_name(scrap_type)
  if type(scrap_type) ~= "string" then return nil end
  ---@diagnostic disable-next-line: undefined-global
  for _, i_type in ipairs(item_types) do   -- set in data stage
    if data.raw.item[scrap_type .. "-" .. i_type] then
      return scrap_type .. "-" .. i_type
    end
  end
end

function util.get_scrap_recycle_tech(recipe_name, raw_scrap) -- TODO: normal, expensive
  local _techs = { effects = { enabled = true, recipes = {} }, normal = { enabled = true, recipes = {} }, expensive = { enabled = true, recipes = {} } }
  for tech_name, value in pairs(data.raw.technology) do
    -- if patch.technology(tech_name) and value.effects then
    --   for i, effect in ipairs(value.effects) do
    --     if effect.recipe and effect.recipe == recipe_name then
    --       _techs.effects.enabled = false
    --       _techs.effects.recipes[#_techs.effects.recipes+1] = tech_name
    --     end
    --   end
    --   if #_techs.effects.recipes < 1 and string.match(tostring(tech_name), raw_scrap) then
    --     _techs.effects.enabled = false
    --     _techs.effects.recipes[#_techs.effects.recipes+1] = tech_name
    --   end
    -- end
    --normal
    --expensive
  end
  return _techs
end

function util.make_scrap(scrap_type, scrap_icon, stack_size)
  local scrap_name = scrap_type .. "-scrap"
  if not data.raw.item[scrap_name] then
    local _data
    local recipe_name = "recycle-" .. scrap_name
    local result_name = util.get_recycle_result_name(scrap_type)
    local item_order = "is-[" .. scrap_name .. "]"
    local recipe_order = "is-[" .. recipe_name .. "]"

    local enabled = --[[_return.recipe.enabled or]] util.get_scrap_recycle_tech(result_name, scrap_type).effects.enabled

    if not data.raw.recipe[recipe_name] then
      local tech_table = util.get_scrap_recycle_tech(result_name, scrap_type)
      for _, tech_name in ipairs(tech_table.effects.recipes) do
        log(tech_name .. " unlocks " .. recipe_name)
        table.insert(data.raw.technology[tech_name].effects,
          { type = "unlock-recipe", recipe = recipe_name })
      end
    end

    _data = {
      {
        type = "item",
        name = scrap_name,
        icon = scrap_icon or yutil.get_item_icon(scrap_type),
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "raw-material",
        order = item_order,
        stack_size = stack_size or 100
      },
      {
        type = "recipe",
        name = recipe_name,
        localised_name = { "recipe-name." .. recipe_name },
        icons = yutil.get_recycle_icons(scrap_type, result_name),
        subgroup = "raw-material",
        category = "smelting",
        order = recipe_order,
        always_show_products = true,
        allow_as_intermediate = false,
        enabled = enabled,
      },
    }
    data:extend(_data)

    return _data
  end
end

return util
