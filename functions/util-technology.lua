
----------------------
--    TECHNOLOGY    --
----------------------

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
-- assert(1==2, "technology_has_recipe()")


---returns a list of all technology names if they unlock the given recipe
---@param recipe_name string scrap_type.."-"..item_type
---@return table list
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
-- log(serpent.block(get_technology_by_recipe("missing-plate"), {comment = false}))
-- assert(1==2, "get_technology_by_recipe()")

---@param technology_name string
---@param recipe_name string
---@param recipe_check? boolean Check if the recipe ``recipe_name`` exists before inserting, default false
function technology_add_effect(technology_name, recipe_name, recipe_check)
  local _effect = { recipe = recipe_name, type = "unlock-recipe" }
  recipe_check = recipe_check or false

  if recipe_check and not data.raw.recipe[recipe_name] then
    return
  end

  if data.raw.technology[technology_name] then
    table.insert(data.raw.technology[technology_name].effects, _effect)
  end

end
-- technology_add_effect("steel-processing", "recycle-true-scrap", true)
-- technology_add_effect("steel-processing", "recycle-default-scrap")
-- log(serpent.block(data.raw.technology["steel-processing"]))
-- assert(1==2, "technology_add_effect()")
