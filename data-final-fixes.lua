local _material_types = {"iron", "copper", "steel", "testonium"}
local _result_types = {"plate", "cable"}

-- Remove unused materials
local _t1, _t2 = {}, {}
for _, m_type in ipairs(_material_types) do
  for _, r_type in ipairs(_result_types) do
    if data.raw.item[m_type.."-"..r_type] then
      _t1[m_type] = m_type
    end
  end
end
for _, _type in pairs(_t1) do
  _t2[#_t2+1] = _type
end
_material_types = _t2


-- local yutil = require("functions.functions")
-- local mod = require("mods")
-- local patch = mod[3]

-- local scrap_types = yutil.table.extend(mod[1], _material_types)
-- local item_types = yutil.table.extend(mod[2], _item_types)


---holds the return table template
return_template = {
    name = "_return_template_",
    recipe = {    -- determine and cache                                     get -> modify -> replace
      none      = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil,},
      normal    = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil, },
      expensive = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil, },

    },

    new = function(self, recipe_name)
      if recipe_name and type(recipe_name) == "string" then
        local _t = util.table.deepcopy(return_template)
        _t.name = recipe_name
        return _t
      end
    end
  }


-- ---Removes all material_types which don't have a result when combined with item_types.
-- ---Returns a list of scrap results.
-- ---@param material_types table
-- ---@param result_types table
-- ---@return table scrap_results ``{ingredient = "iron-scrap", result = "iron-plate"}``
-- function get_possible_results(material_types, result_types)
--   local _t1, _t2 = {}, {}
--   info("Filtering scrap types")
--   for _, m_type in ipairs(material_types) do
--     for _, i_type in ipairs(result_types) do
--       if data.raw.item[m_type.."-"..i_type] then

--         if not _t1[m_type] then

--           _t1[m_type] = {ingredient = m_type.."-scrap", result = m_type.."-"..i_type}
--           _t1[m_type] = m_type.."-"..i_type

--         -- elseif data.raw.item[m_type.."-"..i_type].subgroup -- //TODO function to find the "lowest" item
--         --    and data.raw.item[m_type.."-"..i_type].subgroup == "raw-material" then

--         --   _t1[m_type] = m_type.."-"..i_type
--         end

--       end
--     end
--   end
--   for _, v in pairs(_t1) do
--     _t2[#_t2+1] = v
--   end
--   return _t2
-- end
-- log(serpent.block(get_possible_results(_material_types, _result_types)))
-- error("get_possible_results()")


---Returns a list of materials based on the recipes ingredients
---@param ingredients table
---@return table ``{material = { "material-scrap", 10}}``
local function get_recipe_materials(ingredients)
  local materials = {}
  for _, value in pairs(ingredients) do
    value = ylib.util.add_pairs(value)
    for _, m_type in ipairs(_material_types) do
      if string.find(value.name, m_type, 1, true) then
        local amount_old = 0
        if materials[m_type] then
          amount_old = materials[m_type][2]
        end
        materials[m_type] = {m_type.."-scrap", value.amount + amount_old}
      end
    end
  end
  return materials
end
-- ingredients = {{ "iron-gear-wheel", 10 }, { "copper-plate", 10 }, { "iron-plate", 16 }, { "lead-plate", 4 }}
-- log(serpent.block(get_recipe_materials(ingredients)))
-- error("get_recipe_materials()")




--loop through all recipes

for recipe_name, _ in pairs(data.raw.recipe) do

  local _in = ylib.recipe.get_ingredients(recipe_name) --returns ``{ingredients={}, normal={}, expensive={}}``
  local _out = ylib.recipe.get_results(recipe_name)
  local _re = {}

  local scrap_probability = settings.startup["ingredient-scrap-probability"].value/100

  if _in.ingredients then
    _re.ingredients =  get_recipe_materials(_in.ingredients)
    data.raw.recipe[recipe_name].results = _out.results
    for _, value in pairs(_re.ingredients) do
      table.insert(data.raw.recipe[recipe_name].results, {name = value[1], amount_min = 1, amount_max = value[2], probability = scrap_probability})
    end
  end
  if _in.normal then
    _re.normal =  get_recipe_materials(_in.normal)
    data.raw.recipe[recipe_name].normal.results = _out.normal
    for _, value in pairs(_re.normal) do
      table.insert(data.raw.recipe[recipe_name].normal.results, {name = value[1], amount_min = 1, amount_max = value[2], probability = scrap_probability})
    end
  end
  if _in.expensive then
    _re.expensive =  get_recipe_materials(_in.expensive)
    data.raw.recipe[recipe_name].expensive.results = _out.expensive
    for _, value in pairs(_re.expensive) do
      table.insert(data.raw.recipe[recipe_name].expensive.results, {name = value[1], amount_min = 1, amount_max = value[2], probability = scrap_probability})
    end
  end

  if ylib.util.check_table(_re) then
    log(serpent.block(data.raw.recipe[recipe_name]))
  end
end
error()








