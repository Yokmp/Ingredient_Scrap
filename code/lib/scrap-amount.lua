local scrap_amount = {}

---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@return integer base_amount, integer|nil amount_min, integer|nil amount_max
function scrap_amount.range(base_amount)
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

  local expected = math.max(math.ceil(dampened), 1)

  if ISsettings.fixed_amount then
    return expected, nil, nil
  end

  local amount_min = math.max(math.floor(dampened * 0.6), 1)
  local amount_max = math.max(math.ceil(dampened * 1.4), amount_min + 1)
  return expected, amount_min, amount_max
end

return scrap_amount
