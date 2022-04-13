local _material_types = {"iron", "copper", "steel", "aluminum", "erronium"}
local _result_types = {"plate"}
local _result_recipes = {} --these recipes will not generate srap
local scrap_probability = settings.startup["yis-probability"].value/100


--#region Prepare
-- Remove unused materials
local _t1, _t2 = {}, {}
for _, m_type in ipairs(_material_types) do
  for _, r_type in ipairs(_result_types) do
    if data.raw.item[m_type.."-"..r_type] then
      _result_recipes[#_result_recipes+1] = m_type.."-"..r_type --add to recipe combinations
      _t1[m_type] = m_type
    end
  end
end
for _, _type in pairs(_t1) do
  _t2[#_t2+1] = _type
end
_material_types = _t2
-- log(serpent.block(_material_types))
-- log(serpent.block(_result_recipes))
-- error("Remove unused materials")


scrap_lookup = {
  ---Adds or updates an entry to this table
  ---@param self table
  ---@param recipe_name string
  ---@param material string
  ---@param amount number|table saves as table for difficulty ``{normal, expensive}``
  add = function(self, recipe_name, material, amount)
    if amount and type(amount) == "number" then
      amount = {amount, amount}
    elseif type(amount) ~= "table" then
      log(debug.traceback())
      error("scrap_lookup:add(..., amount) expects a table or number")
    end
    if recipe_name and type(recipe_name) == "string"
    and material and type(material) == "string"
    and type(amount) == "table" then
      if self[recipe_name] then
        if self[recipe_name][material] then
          self[recipe_name][material] = {
            self[recipe_name][material][1] + amount[1],
            self[recipe_name][material][2] + amount[2]
          }
        else
          self[recipe_name][material] = {amount[1], amount[2]}
        end
      else
        self[recipe_name] = {[material] = {amount[1], amount[2]}}
      end
    end
  end,
---Returns a formatted table
---@param self table
---@param recipe_name string
---@return table ``{{name = key, amount = {normal, expensive}}, ...}``
  get = function (self, recipe_name)
    if self[recipe_name] then
      local _t = {}
      for key, value in pairs(self[recipe_name]) do
        _t[#_t+1] = {name = key, amount = {normal = value[1], expensive = value[2]}}
      end
      return _t
    end
  end
}
-- scrap_lookup.test = {
--   ["copper"] = {1,1},
--   ["iron"] = {2,2}
-- }
-- scrap_lookup:add("test", "iron", 3)
-- scrap_lookup:add("new", "steel", 42)
-- scrap_lookup:add("new", "copper", {9,3})
-- -- scrap_lookup:add("new", "copper", "error") -- works
-- log(serpent.block(scrap_lookup:get("test")))
-- log(serpent.block(scrap_lookup:get("error")))
-- log(serpent.block(scrap_lookup))
-- error("scrap_lookup:add()")


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


--loop through all recipes and build the actual lookup table

for recipe_name, _ in pairs(data.raw.recipe) do

  if not ylib.util.is_in_list(recipe_name, _result_recipes) then --exclude recycle result recipes

    local _in = ylib.recipe.get_ingredients(recipe_name) --returns ``{ingredients={}, normal={}, expensive={}}``
    local _out = ylib.recipe.get_results(recipe_name)
    local _re = {}

    if _in.ingredients then
      _re.ingredients =  get_recipe_materials(_in.ingredients)
      data.raw.recipe[recipe_name].results = _out.results
      for _, value in pairs(_re.ingredients) do
        scrap_lookup:add(recipe_name, value[1], value[2])
      end
    end
    if _in.normal then
      _re.normal =  get_recipe_materials(_in.normal)
      data.raw.recipe[recipe_name].normal.results = _out.normal
      for _, value in pairs(_re.normal) do
        scrap_lookup:add(recipe_name, value[1], {value[2], 0})
      end
    end
    if _in.expensive then
      _re.expensive =  get_recipe_materials(_in.expensive)
      data.raw.recipe[recipe_name].expensive.results = _out.expensive
      for _, value in pairs(_re.expensive) do
        scrap_lookup:add(recipe_name, value[1], {0, value[2]})
      end
    end
  end

  -- if ylib.util.check_table(_re) then
  --   log(serpent.block(data.raw.recipe[recipe_name]))
  -- end
end
-- log(serpent.block(data.raw.recipe["tank"]))
-- log(serpent.block(scrap_lookup:get("battery")))
-- log(serpent.block(scrap_lookup:get("tank")))
--#endregion Prepare


-- loop again through all recipes and read all items( which are NOT a recycle result?)
-- look up scrap_lookup and construckt results with added amounts of scrap per material
-- like a vanilla pipe is worth {1,2} iron-scrap
-- an engine-unit 1 steel-plate, 1 iron-gear-wheel {2,4} and 2 pipes (1 steel and {4,6} iron)
-- so a pump (1 steel-plate, 1 engine-unit, 1 pipe) results in {1,1} steel and {5,8} iron
-- since the pump has no difficulty it actually results in 1 steel and 5 iron




