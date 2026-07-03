local resolver = require("code.core.ancestry.resolver")
local mixed = require("code.core.ancestry.mixed")

local effective = {}

---Counts keys in a composition table.
---@param values table|nil
---@return integer
local function table_size(values)
  local count = 0
  for _, _ in pairs(values or {}) do count = count + 1 end
  return count
end

---Returns true when the composition already contains the mixed fallback material.
---@param values table<string, number>|nil
---@return boolean
local function contains_mixed(values)
  return values and values[mixed.material] ~= nil
end

---Returns the positive sum of all composition weights.
---@param values table<string, number>|nil
---@return number
local function sum_positive(values)
  local sum = 0
  for _, amount in pairs(values or {}) do
    if amount > 0 then sum = sum + amount end
  end
  return sum
end

---Returns the passive effective output after mixed-scrap fallback rules.
---@param ancestry table<string, number>
---@param limit integer|nil
---@return table
function effective.output(ancestry, limit)
  local width = table_size(ancestry)
  if width == 0 then
    return {
      kind = "mixed",
      reason = "unresolved",
      materials = { [mixed.material] = 1 },
    }
  end
  if contains_mixed(ancestry) then
    return {
      kind = "direct",
      reason = "contains-mixed",
      limit = limit,
      width = width,
      materials = resolver.rounded_composition(ancestry),
    }
  end
  if limit and width > limit then
    return {
      kind = "mixed",
      reason = "width-limit",
      limit = limit,
      width = width,
      materials = { [mixed.material] = math.max(sum_positive(ancestry), 1) },
    }
  end
  return {
    kind = "direct",
    reason = "within-limit",
    limit = limit,
    width = width,
    materials = resolver.rounded_composition(ancestry),
  }
end

return effective
