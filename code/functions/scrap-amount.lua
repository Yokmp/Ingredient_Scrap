local scrap_amount = {}

---Returns the dampened expected scrap amount before integer rounding.
---@param base_amount number
---@return number
local function dampened_amount(base_amount)
  local probability = ISsettings.probability / 100

  -- Small inputs stay close to linear scaling; large inputs are dampened so
  -- high-cost recipes do not produce absurd scrap amounts.
  local threshold = 10
  local linear = base_amount * probability
  local dampened
  if not ISsettings.limit then
    dampened = linear
  elseif base_amount <= threshold then
    dampened = linear
  else
    dampened = (threshold * probability)
             + math.sqrt(base_amount - threshold) * probability
  end

  return dampened
end

---Rounds a positive amount while keeping non-zero contributions visible.
---@param value number
---@param rounder fun(value: number): integer
---@return integer
local function rounded_at_least_one(value, rounder)
  return math.max(rounder(value), 1)
end

---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount number
---@return integer base_amount, integer|nil amount_min, integer|nil amount_max
function scrap_amount.range(base_amount)
  local dampened = dampened_amount(base_amount)
  local expected = math.max(math.ceil(dampened), 1)

  if ISsettings.fixed_amount then
    return expected, nil, nil
  end

  local amount_min = math.max(math.floor(dampened * 0.6), 1)
  local amount_max = math.max(math.ceil(dampened * 1.4), amount_min + 1)
  return expected, amount_min, amount_max
end

---Returns debug-only floor/ceil variants for mixed-scrap rounding calibration.
---@param base_amount number
---@return table
function scrap_amount.rounding_variants(base_amount)
  local dampened = dampened_amount(base_amount)

  local floor_min = rounded_at_least_one(dampened * 0.6, math.floor)
  local floor_avg = rounded_at_least_one(dampened, math.floor)
  local floor_max = math.max(rounded_at_least_one(dampened * 1.4, math.floor), floor_min)

  local ceil_min = rounded_at_least_one(dampened * 0.6, math.ceil)
  local ceil_avg = rounded_at_least_one(dampened, math.ceil)
  local ceil_max = math.max(rounded_at_least_one(dampened * 1.4, math.ceil), ceil_min)

  return {
    source_amount = base_amount,
    dampened = dampened,
    floor = {
      min = floor_min,
      avg = floor_avg,
      max = floor_max,
    },
    ceil = {
      min = ceil_min,
      avg = ceil_avg,
      max = ceil_max,
    },
  }
end

---Returns the active conservative mixed-scrap amount using floor rounding.
---@param base_amount number
---@return integer amount, integer amount_min, integer amount_max
function scrap_amount.mixed_floor_range(base_amount)
  local variants = scrap_amount.rounding_variants(base_amount)
  return variants.floor.avg, variants.floor.min, variants.floor.max
end

return scrap_amount
