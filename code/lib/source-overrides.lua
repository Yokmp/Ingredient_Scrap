yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}

local overrides = {}

overrides.blocked_recipes = {}
overrides.blocked_categories = {}

---Copies a list-like table.
---@param values string[]|nil
---@return string[]
local function copy_list(values)
  local out = {}
  for _, value in ipairs(values or {}) do
    table.insert(out, value)
  end
  return out
end

---Returns true when a value is present in a list-like table.
---@param values string[]|nil
---@param value string|nil
---@return boolean
local function contains(values, value)
  if not value then return false end
  for _, candidate in ipairs(values or {}) do
    if candidate == value then return true end
  end
  return false
end

---Normalizes a source ignore rule definition.
---@param options table|nil
---@return table
local function normalize_rule(options)
  options = options or {}
  return {
    reason = options.reason or "api-source-ignore",
    material = options.material,
    mode = options.mode,
    ingredient_names = copy_list(options.ingredient_names),
    ingredient_prefixes = copy_list(options.ingredient_prefixes),
    ingredient_suffixes = copy_list(options.ingredient_suffixes),
    ingredient_exclude_names = copy_list(options.ingredient_exclude_names),
    ingredient_exclude_prefixes = copy_list(options.ingredient_exclude_prefixes),
    ingredient_exclude_suffixes = copy_list(options.ingredient_exclude_suffixes),
  }
end

---Adds a normalized rule to a rule list.
---@param rules table
---@param key string
---@param options table|nil
local function add_rule(rules, key, options)
  rules[key] = rules[key] or {}
  table.insert(rules[key], normalize_rule(options))
end

---Registers a recipe name that should not receive Ingredient Scrap results.
---See API examples: https://github.com/Yokmp/Ingredient_Scrap
---@param recipe_name string
---@param options table|nil
function overrides.ignore_recipe(recipe_name, options)
  if type(recipe_name) ~= "string" or recipe_name == "" then
    error("Ingredient Scrap source recipe ignore requires a non-empty recipe name")
  end
  add_rule(overrides.blocked_recipes, recipe_name, options)
end

---Registers a recipe category that should not receive Ingredient Scrap results.
---See API examples: https://github.com/Yokmp/Ingredient_Scrap
---@param category string
---@param options table|nil
function overrides.ignore_category(category, options)
  if type(category) ~= "string" or category == "" then
    error("Ingredient Scrap source category ignore requires a non-empty category")
  end
  add_rule(overrides.blocked_categories, category, options)
end

---Returns true when the ingredient is explicitly excluded from the rule.
---@param rule table
---@param ingredient table
---@return boolean
local function excludes_ingredient(rule, ingredient)
  local name = ingredient and ingredient.name
  if not name then return false end

  if contains(rule.ingredient_exclude_names, name) then return true end
  for _, prefix in ipairs(rule.ingredient_exclude_prefixes or {}) do
    if prefix ~= "" and name:sub(1, #prefix) == prefix then return true end
  end
  for _, suffix in ipairs(rule.ingredient_exclude_suffixes or {}) do
    if suffix ~= "" and name:sub(-#suffix) == suffix then return true end
  end

  return false
end

---Returns true when the ingredient name matches the optional rule filters.
---@param rule table
---@param ingredient table
---@return boolean
local function matches_ingredient(rule, ingredient)
  if excludes_ingredient(rule, ingredient) then return false end

  local name = ingredient and ingredient.name
  if not name then return false end

  local has_filter = false
  if #(rule.ingredient_names or {}) > 0 then
    has_filter = true
    if contains(rule.ingredient_names, name) then return true end
  end
  for _, prefix in ipairs(rule.ingredient_prefixes or {}) do
    if prefix ~= "" then
      has_filter = true
      if name:sub(1, #prefix) == prefix then return true end
    end
  end
  for _, suffix in ipairs(rule.ingredient_suffixes or {}) do
    if suffix ~= "" then
      has_filter = true
      if name:sub(-#suffix) == suffix then return true end
    end
  end

  return not has_filter
end

---Returns true when a source ignore rule applies to a matched recipe ingredient.
---@param rule table|nil
---@param ingredient table
---@param scrap_type string
---@param mode "solid"|"fluid"
---@return boolean
local function rule_applies(rule, ingredient, scrap_type, mode)
  if not rule then return false end
  if rule.material and rule.material ~= scrap_type then return false end
  if rule.mode and rule.mode ~= mode then return false end
  return matches_ingredient(rule, ingredient)
end

---Returns the source ignore rule that applies to this recipe ingredient, if any.
---@param recipe table
---@param ingredient table
---@param scrap_type string
---@param mode "solid"|"fluid"
---@return table|nil
function overrides.ignored_source(recipe, ingredient, scrap_type, mode)
  if not recipe then return nil end
  for _, recipe_rule in ipairs(overrides.blocked_recipes[recipe.name] or {}) do
    if rule_applies(recipe_rule, ingredient, scrap_type, mode) then
      return recipe_rule
    end
  end

  for _, category_rule in ipairs(overrides.blocked_categories[recipe.category] or {}) do
    if rule_applies(category_rule, ingredient, scrap_type, mode) then
      return category_rule
    end
  end

  return nil
end

---Publishes the public source ignore API.
local function publish_source_api()
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.ignore = api.ignore or {}
  api.ignore.source = api.ignore.source or {}

  api.ignore.source.recipe = overrides.ignore_recipe
  api.ignore.source.category = overrides.ignore_category
end

publish_source_api()

return overrides
