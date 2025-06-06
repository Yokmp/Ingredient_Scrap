local _material_types = { "iron", "copper", "steel", "aluminum", "erronium" }
local _result_types = { "plate" }
local _result_recipes = {} --these recipes will not generate scrap
local _unresolved = {}     --{["recipe-name"] = true}

local scrap_probability = settings.startup["yis-probability"].value / 100


--#region Prepare
scrap_lookup = {
  ---Adds or updates an entry to this table
  ---@param self table
  ---@param recipe_name string
  ---@param material string
  ---@param amount number|table saves as table for difficulty ``{normal, expensive}``
  add = function(self, recipe_name, material, amount)
    if amount and type(amount) == "number" then
      amount = { amount, amount }
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
          self[recipe_name][material] = { amount[1], amount[2] }
        end
      else
        self[recipe_name] = { [material] = { amount[1], amount[2] } }
      end
    end
  end,
  -- ---Returns a formatted table
  -- ---@param self table
  -- ---@param recipe_name string
  -- ---@return table ``{{name = material_name, amount = {normal, expensive}}, ...}``
  --   get = function (self, recipe_name)
  --     if self[recipe_name] then
  --       local _t = {}
  --       for key, value in pairs(self[recipe_name]) do
  --         _t[#_t+1] = {name = key, amount = {normal = value[1], expensive = value[2]}}
  --       end
  --       return _t
  --     end
  --   end
}
-- scrap_lookup["test-recipe"] = {
--   ["copper"] = {1,1},
--   ["iron"] = {2,2}
-- }
-- scrap_lookup:add("test-recipe", "iron", 3)
-- scrap_lookup:add("new_recipe", "steel", 42)
-- scrap_lookup:add("new_recipe", "copper", {9,3})
-- -- scrap_lookup:add("new", "copper", "error") -- works
-- log(serpent.block(scrap_lookup:get("test-recipe")))
-- -- log(serpent.block(scrap_lookup:get("error"))) --works
-- log(serpent.block(scrap_lookup))
-- error("scrap_lookup:add()")


-- Remove unused materials from _material_types and add the recipe name to _result_recipes
local _t1, _t2 = {}, {}
for _, m_type in ipairs(_material_types) do
  for _, r_type in ipairs(_result_types) do
    if data.raw.item[m_type .. "-" .. r_type] then
      _result_recipes[#_result_recipes + 1] = m_type .. "-" .. r_type
      _t1[m_type] = m_type
    end
  end
end
for _, _type in pairs(_t1) do
  _t2[#_t2 + 1] = _type
end
_material_types = _t2
-- log(serpent.block(_material_types)) --{"iron", "copper", ...}
-- log(serpent.block(_result_recipes)) --{"iron-plate", "copper-plate" ...}
-- error("Remove unused materials")


---Returns a list of materials based on the recipes ingredients
---@param ingredients table
---@return table ``["iron-plate"] = {["iron-scrap"] = { 1,1 }},``
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
        materials[m_type] = { type="item", m_type .. "-scrap", value.amount + amount_old }
      end
    end
  end
  return materials
end
-- ingredients = {{ "iron-gear-wheel", 10 }, { "copper-plate", 10 }, { "iron-plate", 16 }, { "lead-plate", 4 }}
-- log(serpent.block(get_recipe_materials(ingredients))) -- copper 10, iron 26, (lead 0 - no lead in _material_types)
-- error("get_recipe_materials()")


-- loop through _result_recipes and build a basic lookup table
for _, recipe_name in pairs(_result_recipes) do
  local _in = ylib.recipe.get_ingredients(recipe_name)   --returns ``{ingredients={}, normal={}, expensive={}}``
  local _re = {}

  if _in.ingredients then
    _re.ingredients = get_recipe_materials(_in.ingredients)
    for _, value in pairs(_re.ingredients) do
      scrap_lookup:add(recipe_name, value[1], value[2])
    end
  end

  if not ylib.util.check_table(_re) then
    log(debug.traceback("An empty result was generated for: " ..
    recipe_name .. ".\nThis means that some mod probably added an invalid recipe at some point."))
  end
end
log(serpent.block(scrap_lookup))
error("Fill scrap_lookup")


-- get all unresolved recipes but exclude recycle results recipes
for recipe_name, _ in pairs(data.raw.recipe) do
  if not ylib.util.is_in_list(recipe_name, _result_recipes) then
    _unresolved[recipe_name] = recipe_name
  end
end
-- log(serpent.block(_unresolved))
-- error("EOP")
--#endregion Prepare


-- loop again through all recipes and read all items( which are NOT a recycle result?)
-- look up scrap_lookup and construckt results with added amounts of scrap per material
-- like a vanilla pipe is worth {1,2} iron-scrap
-- an engine-unit 1 steel-plate, 1 iron-gear-wheel {2,4} and 2 pipes (1 steel and {4,6} iron)
-- so a pump (1 steel-plate, 1 engine-unit, 1 pipe) results in {1,1} steel and {5,8} iron
-- since the pump has no difficulty it actually results in 1 steel and 5 iron


-- TESTING BELOW


-- log(serpent.block(scrap_lookup))
-- log(serpent.block(_result_recipes))

function prepare(recipe_name)
  local _in = ylib.recipe.get_ingredients(_result_recipes[recipe_name]) --returns ``{ingredients={}, normal={}, expensive={}}``

  if _in then
    if _in.normal then
      for _, _ingr in ipairs(_in.ingredients) do
        if scrap_lookup[_ingr.name] then
          -- scrap_lookup:add(recipe_name, , {value[2], 0})
        end
      end
    end
  end
end

-- prepare("pipe")

log(serpent.block(scrap_lookup))


-- for recipe_name, _ in pairs(data.raw.recipe) do
--   prepare(recipe_name)
-- end

error("EOT")
