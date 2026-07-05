local graph = require("code.resolver.ancestry.graph")
local roots = require("code.resolver.ancestry.roots")
local resolver = require("code.resolver.ancestry.resolver")

local lookup = {}

---Returns a sorted list of map keys.
---@param values table|nil
---@return string[]
local function sorted_keys(values)
  local keys = {}
  for key, _ in pairs(values or {}) do table.insert(keys, key) end
  table.sort(keys)
  return keys
end

---Returns a shallow copy of currently resolved lookup entries for stable round semantics.
---@param entries table<string, table>
---@return table<string, table>
local function resolved_snapshot(entries)
  local snapshot = {}
  for name, entry in pairs(entries or {}) do
    if entry.resolved then snapshot[name] = entry end
  end
  return snapshot
end

---Adds material amounts from a composition into a target composition.
---@param target table<string, number>
---@param composition table<string, number>|nil
---@param factor number
local function add_composition(target, composition, factor)
  for material, amount in pairs(composition or {}) do
    if amount > 0 then
      target[material] = (target[material] or 0) + (amount * factor)
    end
  end
end

---Returns true when the selected producer graph contains a cycle for this item.
---@param item_name string
---@param producers table<string, table[]>
---@param stack table<string, boolean>|nil
---@return boolean
local function has_cycle(item_name, producers, stack)
  stack = stack or {}
  if stack[item_name] then return true end
  local recipe = producers[item_name] and producers[item_name][1]
  if not recipe then return false end
  stack[item_name] = true
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    if (ingredient.type or "item") == "item" and ingredient.name then
      if has_cycle(ingredient.name, producers, stack) then
        stack[item_name] = nil
        return true
      end
    end
  end
  stack[item_name] = nil
  return false
end

---Builds one unresolved ingredient entry.
---@param ingredient table
---@param factor number
---@param reason string
---@return table
local function unresolved_ingredient(ingredient, factor, reason)
  return {
    type = ingredient.type or "item",
    name = ingredient.name,
    amount = ingredient.amount,
    factor = factor,
    reason = reason,
  }
end

---Attempts to resolve one item from a producer recipe using a resolved-entry snapshot.
---@param item_name string
---@param recipe table
---@param resolved table<string, table>
---@return table
local function resolve_from_recipe(item_name, recipe, resolved)
  local result_amount = graph.recipe_result_amount(recipe, item_name)
  local scrap = {}
  local unresolved = {}
  local reasons = {}

  local function add_reason(reason)
    for _, existing in ipairs(reasons) do
      if existing == reason then return end
    end
    table.insert(reasons, reason)
  end

  for _, ingredient in ipairs(recipe.ingredients or {}) do
    local ingredient_type = ingredient.type or "item"
    local ingredient_name = ingredient.name
    if ingredient_name then
      local factor = graph.amount_of(ingredient) / result_amount
      if ingredient_type ~= "item" then
        add_reason("deferred-" .. ingredient_type .. ":" .. ingredient_name)
        table.insert(unresolved, unresolved_ingredient(ingredient, factor, "deferred-" .. ingredient_type))
      elseif resolved[ingredient_name] then
        add_composition(scrap, resolved[ingredient_name].scrap, factor)
      else
        add_reason("missing-lookup:" .. ingredient_name)
        table.insert(unresolved, unresolved_ingredient(ingredient, factor, "missing-lookup"))
      end
    end
  end

  table.sort(reasons)
  return {
    name = item_name,
    source_recipe = recipe.name,
    resolved = not unresolved[1],
    scrap = resolver.rounded_composition(scrap),
    unresolved = unresolved,
    reasons = reasons,
  }
end

---Returns a compact summary for the iterative lookup report.
---@param entries table<string, table>
---@param rounds integer
---@return table
local function summarize(entries, rounds)
  local summary = {
    rounds = rounds,
    resolved_count = 0,
    unresolved_count = 0,
    partial_count = 0,
    mixed_from_unresolved_count = 0,
    loop_count = 0,
    unresolved_examples = {},
    loop_examples = {},
  }

  for _, name in ipairs(sorted_keys(entries)) do
    local entry = entries[name]
    if entry.resolved then
      summary.resolved_count = summary.resolved_count + 1
    else
      summary.unresolved_count = summary.unresolved_count + 1
      if next(entry.scrap or {}) then summary.partial_count = summary.partial_count + 1 end
      if entry.unresolved and entry.unresolved[1] then summary.mixed_from_unresolved_count = summary.mixed_from_unresolved_count + 1 end
      if #(summary.unresolved_examples) < 10 then
        table.insert(summary.unresolved_examples, {
          name = name,
          source_recipe = entry.source_recipe,
          reasons = entry.reasons,
          unresolved = entry.unresolved,
        })
      end
    end
    if entry.loop then
      summary.loop_count = summary.loop_count + 1
      if #(summary.loop_examples) < 10 then
        table.insert(summary.loop_examples, {
          name = name,
          source_recipe = entry.source_recipe,
          reasons = entry.reasons,
        })
      end
    end
  end

  return summary
end

---Builds an iterative item-to-scrap lookup table from production recipes.
---@param material_flow table
---@param production_flow table
---@param options table|nil
---@return table
function lookup.build(material_flow, production_flow, options)
  options = options or {}
  local root_policy = options.root_policy or "hybrid"
  local max_rounds = options.max_depth or 8
  local root_aliases = roots.build(material_flow, root_policy, options.materials)
  local producers = graph.build_producers(production_flow)
  local entries = {}

  for item_name, material in pairs(root_aliases or {}) do
    entries[item_name] = {
      name = item_name,
      resolved = true,
      root = true,
      scrap = { [material] = 1 },
      unresolved = {},
      reasons = { "root-alias" },
    }
  end

  for item_name, recipes in pairs(producers or {}) do
    if not entries[item_name] and recipes[1] then
      entries[item_name] = {
        name = item_name,
        resolved = false,
        source_recipe = recipes[1].name,
        scrap = {},
        unresolved = {},
        reasons = { "pending" },
      }
    end
  end

  local rounds = 0
  for round = 1, max_rounds do
    local changed = false
    local snapshot = resolved_snapshot(entries)
    for _, item_name in ipairs(sorted_keys(producers)) do
      local entry = entries[item_name]
      local recipe = producers[item_name] and producers[item_name][1]
      if entry and recipe and not entry.resolved then
        local next_entry = resolve_from_recipe(item_name, recipe, snapshot)
        if next_entry.resolved or next(next_entry.scrap or {}) or #(next_entry.unresolved or {}) > 0 then
          entries[item_name] = next_entry
        end
        if next_entry.resolved then changed = true end
      end
    end
    rounds = round
    if not changed then break end
  end

  for item_name, entry in pairs(entries) do
    if not entry.resolved and has_cycle(item_name, producers) then
      entry.loop = true
      entry.reasons = entry.reasons or {}
      table.insert(entry.reasons, "loop")
    end
  end

  return {
    schema = "ingredient-scrap-iterative-lookup/v1",
    mode = options.mode,
    root_policy = root_policy,
    max_rounds = max_rounds,
    rounds = rounds,
    entries = entries,
    summary = summarize(entries, rounds),
  }
end

return lookup
