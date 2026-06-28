-- helper functions
local scrap_tints = require("lib.item-tints")

--------------------------------
---*FUNCTIONS*                --
--------------------------------

---Returns a mod-data and JSON friendly copy of a log detail value.
---@param value any
---@param depth integer
---@param seen table
---@return any
local function sanitize_log_value(value, depth, seen)
  local value_type = type(value)
  if value == nil or value_type == "string" or value_type == "number" or value_type == "boolean" then
    return value
  end
  if value_type ~= "table" then
    return tostring(value)
  end
  if depth <= 0 then
    return "<max-depth>"
  end
  if seen[value] then
    return "<cycle>"
  end

  seen[value] = true
  local out = {}
  local count = 0
  for key, item in pairs(value) do
    count = count + 1
    if count > 50 then
      out["..."] = "<truncated>"
      break
    end

    local safe_key = key
    local key_type = type(key)
    if key_type ~= "string" and key_type ~= "number" then
      safe_key = tostring(key)
    end
    out[safe_key] = sanitize_log_value(item, depth - 1, seen)
  end
  seen[value] = nil
  return out
end

---Adds a structured Ingredient Scrap log entry and writes a concise Factorio log message.
---@param source string
---@param level string
---@param step string
---@param description string
---@param details? any
function yokmods.ingredient_scrap.is_log(source, level, step, description, details)
  local data_table = yokmods.ingredient_scrap.data_table
  if data_table then
    data_table.debug = data_table.debug or {}
    data_table.debug.logs = data_table.debug.logs or {}
  end

  local entry = {
    source = tostring(source or "unknown"),
    level = tostring(level or "info"),
    step = tostring(step or "unknown"),
    description = tostring(description or ""),
    details = details ~= nil and sanitize_log_value(details, 4, {}) or nil,
  }

  if data_table and data_table.debug and data_table.debug.logs then
    table.insert(data_table.debug.logs, entry)
  end

  local message = "[IS][" .. entry.level .. "][" .. entry.source .. "][" .. entry.step .. "] " .. entry.description
  if IS_DEBUG and entry.details ~= nil and serpent then
    local ok, rendered = pcall(serpent.line, entry.details, { comment = false, nocode = true })
    if ok and rendered then
      message = message .. " " .. rendered
    end
  end

  if log then
    log(message)
  end
end


---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@return integer base_amount, integer amount_min, integer amount_max
function yokmods.ingredient_scrap.scrap_amount_range(base_amount)
  local probability = ISsettings.probability / 100

  -- Weiche Dämpfung: unter 10 Zutaten fast linear,
  -- darüber zunehmend gedämpft damit Raketensilo nicht absurd wird
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
  else
    local amount_min = math.max(math.floor(dampened * 0.6), 1)
    local amount_max = math.max(math.ceil(dampened * 1.4), amount_min + 1)
    return expected, amount_min, amount_max
  end
end


---Returns the generated recycle recipe name for a scrap material type.
---@param scrap_type string
---@return string
function yokmods.ingredient_scrap.get_recycle_recipe_name(scrap_type)
  return "recycle-" .. scrap_type .. "-scrap"
end
---Returns the generated scrap item name for a scrap material type.
---@param scrap_type string
---@return string
function yokmods.ingredient_scrap.get_scrap_name(scrap_type)
  return scrap_type .. "-scrap"
end


---Determines the correct `default_import_location` for a `scrap_type`.
---First checks whether an ore exists (`<scrap_type>`-ore), then the slab,
---and filters out Gleba if Nauvis resources are present.
---@param scrap_type string
---@return string|nil
function yokmods.ingredient_scrap.get_import_location(scrap_type)
  -- Nauvis-Grundressourcen haben keine import location
  local nauvis_native = { iron = true, copper = true, coal = true, stone = true }
  if nauvis_native[scrap_type] then return nil end

  -- Check if ore (<scrap_type>-ore) -> has the "right" origin
  local ore = data.raw.item[scrap_type .. "-ore"]
  if ore and ore.default_import_location then
    return ore.default_import_location
  end

  -- Fallback: check Plate/Ingot, but exclude planets if
  -- the material also exiistts on Nauvis (via resource check)
  local plate = data.raw.item[scrap_type .. "-plate"]
              or data.raw.item[scrap_type .. "-ingot"]
              or data.raw.item[scrap_type]
  if plate and plate.default_import_location then

    local resource = data.raw.resource[scrap_type .. "-ore"] or data.raw.resource[scrap_type]
    local is_nauvis_resource = resource and (
      resource.autoplace and resource.autoplace.control ~= nil
      -- Nauvis-ressources use autoplace controls, not probability_expression
      and resource.autoplace.probability_expression == nil
    )
    if is_nauvis_resource then return nil end
    return plate.default_import_location
  end

  return nil
end

---Calculates the amount of scrap required for a recycling recipe
---based on the expected value of the scrap results
---that produce this scrap_type.
---@param scrap_type string
---@return integer
function yokmods.ingredient_scrap.get_recycle_needed(scrap_type)
  local probability = ISsettings.probability / 100
  if probability <= 0 then return ISsettings.needed end

  local scrap_name = scrap_type .. "-scrap"
  local total_expected = 0
  local count = 0

  -- Iterate over all inserts that produce this scrap_type
  for _, insert in pairs(yokmods.ingredient_scrap.data_table.inserts.recipes) do
    if insert.results and insert.results[scrap_name] then
      local result = insert.results[scrap_name]
      -- Erwartungswert berechnen je nach fixed_amount oder min/max
      local expected
      if ISsettings.fixed_amount then
        expected = (result.amount or 1) * (result.probability or 1)
      else
        local mid = ((result.amount_min or 1) + (result.amount_max or 1)) / 2
        expected = mid * (result.probability or 1)
      end
      total_expected = total_expected + expected
      count = count + 1
    end
  end

  if count == 0 then return ISsettings.needed end

  -- Average expected value across all prescriptions
  local avg_expected = total_expected / count

  -- Required = rounded up to a reasonable amount
  -- clamp so it never becomes absurdly small or large
  return util.clamp(math.ceil(avg_expected), 1, ISsettings.needed * 2)
end


--------------------------------
---*ICONS*                    --
--------------------------------

---@param scrap_type string
---@param icon_size? string
---@return table
---Returns the icon layers used by recycle recipes for the given scrap type.
function yokmods.ingredient_scrap.get_icon_layers(scrap_type, icon_size)
-- log(serpent.block(scrap_type))
  local source_icons = yokmods.ingredient_scrap.data_table.prototypes.items[scrap_type .. "-scrap"].icons
  local icons = {}
  -- local recycle_icon = (mods["quality"] and "__quality__/graphics/icons/recycling.png") or (icon_path .. "recycle.png")
  local constants = yokmods.ingredient_scrap.data_table.constants

  if not yokmods.ingredient_scrap.data_table.prototypes.items[scrap_type .. "-scrap"] then
    log("no scrap item for: " .. scrap_type)
    return { { icon = "__base__/graphics/icons/signal/signal-deny.png", icon_size = 64 } }
  end

  for _, v in ipairs(source_icons) do
    table.insert(icons, v)
  end

  return icons
end
