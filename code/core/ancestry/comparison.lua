local graph = require("code.core.ancestry.graph")
local roots = require("code.core.ancestry.roots")
local resolver_factory = require("code.core.ancestry.resolver")
local effective = require("code.core.ancestry.effective-output")

local comparison = {}

---Returns a sorted list of keys from a map-like table.
---@param values table
---@return string[]
local function sorted_keys(values)
  local keys = {}
  for key, _ in pairs(values or {}) do table.insert(keys, key) end
  table.sort(keys)
  return keys
end

---Counts values by key returned from a getter function.
---@param values table[]
---@param getter function
---@return table<string, integer>
local function count_by(values, getter)
  local counts = {}
  for _, value in ipairs(values or {}) do
    local key = getter(value) or "unknown"
    counts[key] = (counts[key] or 0) + 1
  end
  return counts
end

---Returns true when both maps contain the same keys.
---@param a table
---@param b table
---@return boolean
local function same_keys(a, b)
  for key, _ in pairs(a or {}) do
    if b[key] == nil then return false end
  end
  for key, _ in pairs(b or {}) do
    if a[key] == nil then return false end
  end
  return true
end

---Builds passive comparison rows between current and ancestry-derived output.
---@param material_flow table
---@param resolver table
---@param mixed_limit integer
---@return table[]
local function build_comparisons(material_flow, resolver, mixed_limit)
  local rows = {}
  for _, flow in ipairs((material_flow and material_flow.flows) or {}) do
    local input = flow.input or {}
    local input_name = input.name
    if input_name then
      local resolved = resolver:resolve(input_name)
      local current = flow.material and { [flow.material] = 1 } or {}
      local ancestry = resolved.composition or {}
      local status
      if not next(ancestry) then
        status = "unresolved"
      elseif same_keys(current, ancestry) then
        status = "same"
      else
        status = "different"
      end

      table.insert(rows, {
        status = status,
        recipe = flow.source_recipe and flow.source_recipe.name,
        ingredient = input_name,
        ingredient_type = input.type or "item",
        ingredient_amount = input.amount,
        current = resolver_factory.rounded_composition(current),
        ancestry = resolver_factory.rounded_composition(ancestry),
        effective_output = effective.output(ancestry, mixed_limit),
        resolve_status = resolved.status,
        resolve_recipe = resolved.recipe,
        reasons = resolved.reasons or {},
      })
    end
  end

  table.sort(rows, function(a, b)
    if a.status ~= b.status then return a.status < b.status end
    if a.ingredient ~= b.ingredient then return (a.ingredient or "") < (b.ingredient or "") end
    return (a.recipe or "") < (b.recipe or "")
  end)
  return rows
end

---Builds a compact passive ancestry summary.
---@param comparisons table[]
---@param resolver table
---@return table
local function summarize(comparisons, resolver)
  local widths = {}
  local max_width = 0
  for _, row in ipairs(comparisons or {}) do
    local width = #sorted_keys(row.ancestry or {})
    if width > 0 then
      local key = tostring(width)
      widths[key] = (widths[key] or 0) + 1
      max_width = math.max(max_width, width)
    end
  end

  local resolved_items = {}
  for _, result in pairs(resolver.cache or {}) do
    resolved_items[result.status] = (resolved_items[result.status] or 0) + 1
  end

  return {
    comparisons = count_by(comparisons, function(row) return row.status end),
    effective_outputs = count_by(comparisons, function(row) return row.effective_output and row.effective_output.kind end),
    effective_reasons = count_by(comparisons, function(row) return row.effective_output and row.effective_output.reason end),
    resolved_items = resolved_items,
    ancestry_widths = widths,
    max_ancestry_width = max_width,
  }
end

---Builds passive runtime ancestry output from existing debug flow tables.
---@param material_flow table
---@param production_flow table
---@param options? table
---@return table
function comparison.build(material_flow, production_flow, options)
  options = options or {}
  local mode = options.mode or "balanced"
  local root_policy = options.root_policy or "hybrid"
  local mixed_limit = options.mixed_limit or 3
  local max_depth = options.max_depth or 8
  local root_aliases, exact_components = roots.build(material_flow, root_policy)
  local producers = graph.build_producers(production_flow)
  local ancestry_resolver = resolver_factory.new(root_aliases, producers, max_depth)
  local comparisons = build_comparisons(material_flow, ancestry_resolver, mixed_limit)

  return {
    schema = "ingredient-scrap-passive-runtime-ancestry/v1",
    profile = yokmods.ingredient_scrap.test_profile,
    active_mods = material_flow and material_flow.active_mods or {},
    mode = mode,
    root_policy = root_policy,
    mixed_limit = mixed_limit,
    max_depth = max_depth,
    component_fallback = options.component_fallback,
    root_aliases = root_aliases,
    exact_components = exact_components,
    summary = summarize(comparisons, ancestry_resolver),
    items = ancestry_resolver:items(),
    comparisons = comparisons,
  }
end

return comparison
