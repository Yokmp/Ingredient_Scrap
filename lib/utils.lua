-- helper functions
local scrap_tints = require("lib.item-tints")

--------------------------------
---*FUNCTIONS*                --
--------------------------------


---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@return integer base_amount
function yokmods.ingredient_scrap.scrap_amount_range(base_amount)
  local probability = ISsettings.probability / 100

  -- Weiche Dämpfung: unter 10 Zutaten fast linear,
  -- darüber zunehmend gedämpft damit Raketensilo nicht absurd wird
  local threshold = 10
  local dampened
  if base_amount <= threshold then
    dampened = base_amount * probability
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


---returns the scrap name
---@param scrap_type string
---@return string
function yokmods.ingredient_scrap.get_recycle_recipe_name(scrap_type)
  return "recycle-" .. scrap_type .. "-scrap"
end
---returns the scrap name
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
