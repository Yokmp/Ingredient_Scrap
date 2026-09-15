local recipe_categories = {}

---Returns the recipe category list, accepting both Factorio 2.1 and older debug shapes.
---@param recipe table|nil
---@return string[]
function recipe_categories.list(recipe)
  if not recipe then return {} end
  if type(recipe.categories) == "table" then return recipe.categories end
  if type(recipe.category) == "string" and recipe.category ~= "" then return { recipe.category } end
  return { "crafting" }
end

---Returns the first recipe category.
---@param recipe table|nil
---@return string|nil
function recipe_categories.first(recipe)
  return recipe_categories.list(recipe)[1]
end

---Returns true when the recipe can be crafted in the requested category.
---@param recipe table|nil
---@param category string
---@return boolean
function recipe_categories.has(recipe, category)
  for _, recipe_category in ipairs(recipe_categories.list(recipe)) do
    if recipe_category == category then return true end
  end
  return false
end

---Returns true when any category contains one of the requested search terms.
---@param recipe table|nil
---@param predicate fun(value:string|nil):boolean
---@return boolean
function recipe_categories.any_matches(recipe, predicate)
  for _, category in ipairs(recipe_categories.list(recipe)) do
    if predicate(category) then return true end
  end
  return false
end

return recipe_categories
