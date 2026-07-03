local graph = require("code.core.ancestry.graph")

local resolver = {}

---Returns a sorted copy of a material composition.
---@param composition table<string, number>
---@return table<string, number>
local function rounded_composition(composition)
  local out = {}
  for material, amount in pairs(composition or {}) do
    if amount > 0 then
      out[material] = math.floor((amount * 1000000) + 0.5) / 1000000
    end
  end
  return out
end

---Returns a JSON-friendly copy of a resolve result.
---@param result table
---@return table
local function result_as_json(result)
  return {
    status = result.status,
    composition = rounded_composition(result.composition),
    recipe = result.recipe,
    reasons = result.reasons or {},
    ingredients = result.ingredients or {},
  }
end

---Creates a new passive ancestry resolver.
---@param root_aliases table<string, string>
---@param producers table<string, table[]>
---@param max_depth integer
---@return table
function resolver.new(root_aliases, producers, max_depth)
  local instance = {
    root_aliases = root_aliases or {},
    producers = producers or {},
    max_depth = max_depth or 8,
    cache = {},
  }

  ---Resolves an item name to material ancestry composition.
  ---@param item_name string
  ---@param depth? integer
  ---@param stack? string[]
  ---@return table
  function instance:resolve(item_name, depth, stack)
    depth = depth or 0
    stack = stack or {}

    if self.root_aliases[item_name] then
      local result = {
        status = "root",
        composition = { [self.root_aliases[item_name]] = 1 },
        reasons = { "root-alias" },
      }
      self.cache[item_name] = result
      return result
    end

    if self.cache[item_name] then return self.cache[item_name] end

    for _, name in ipairs(stack) do
      if name == item_name then
        return {
          status = "cycle",
          composition = {},
          reasons = { "cycle" },
          ingredients = { { name = item_name } },
        }
      end
    end

    if depth >= self.max_depth then
      return {
        status = "depth-limit",
        composition = {},
        reasons = { "depth-limit" },
      }
    end

    local recipes = self.producers[item_name] or {}
    if not recipes[1] then
      local result = {
        status = "unresolved",
        composition = {},
        reasons = { "no-producer" },
      }
      self.cache[item_name] = result
      return result
    end

    local recipe = recipes[1]
    local result_amount = graph.recipe_result_amount(recipe, item_name)
    local composition = {}
    local ingredient_details = {}
    local reasons = {}
    local seen_reasons = {}
    local next_stack = {}
    for _, name in ipairs(stack) do table.insert(next_stack, name) end
    table.insert(next_stack, item_name)

    local function add_reason(reason)
      if seen_reasons[reason] then return end
      seen_reasons[reason] = true
      table.insert(reasons, reason)
    end

    for _, ingredient in ipairs(recipe.ingredients or {}) do
      local ingredient_type = ingredient.type or "item"
      local ingredient_name = ingredient.name
      if ingredient_name then
        local amount = graph.amount_of(ingredient)
        if ingredient_type ~= "item" then
          add_reason("deferred-" .. ingredient_type .. ":" .. ingredient_name)
          table.insert(ingredient_details, {
            type = ingredient_type,
            name = ingredient_name,
            amount = amount,
            status = "deferred",
          })
        else
          local factor = amount / result_amount
          local resolved = self:resolve(ingredient_name, depth + 1, next_stack)
          table.insert(ingredient_details, {
            type = "item",
            name = ingredient_name,
            amount = amount,
            factor = math.floor((factor * 1000000) + 0.5) / 1000000,
            status = resolved.status,
            composition = rounded_composition(resolved.composition),
          })
          for material, material_amount in pairs(resolved.composition or {}) do
            composition[material] = (composition[material] or 0) + (material_amount * factor)
          end
          if not next(resolved.composition or {}) then
            add_reason(resolved.status .. ":" .. ingredient_name)
          end
        end
      end
    end

    table.sort(reasons)
    local status = "unresolved"
    if next(composition) then
      status = #reasons > 0 and "composed" or "resolved"
    elseif #reasons == 0 then
      add_reason("empty-composition")
    end

    local result = {
      status = status,
      composition = composition,
      recipe = recipe.name,
      reasons = reasons,
      ingredients = ingredient_details,
    }
    self.cache[item_name] = result
    return result
  end

  ---Returns all cached resolve results as a JSON-friendly table.
  ---@return table<string, table>
  function instance:items()
    local items = {}
    for item_name, result in pairs(self.cache) do
      items[item_name] = result_as_json(result)
    end
    return items
  end

  return instance
end

resolver.rounded_composition = rounded_composition

return resolver
