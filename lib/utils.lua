-- helper functions
local scrap_tints = require("lib.item-tints")

--------------------------------
---*FUNCTIONS*                --
--------------------------------


---Creates or accumulates the scrap result entry for the specified recipe.
---@param data_table ISdata_table
---@param ingredient ISIngredientPrototype
---@param recipe ISRecipePrototype
---@param scrap_type string
function yokmods.ingredient_scrap.add_recipe_results(data_table, ingredient, recipe, scrap_type)
  local amount, min, max = yokmods.ingredient_scrap.scrap_amount_range(ingredient.amount)
  local scrap_name = scrap_type .. "-scrap"

  if data_table.debug and data_table.debug.sources then
    data_table.debug.sources.inserts[recipe.name] = data_table.debug.sources.inserts[recipe.name] or {}
    table.insert(data_table.debug.sources.inserts[recipe.name], {
      ingredient = ingredient.name,
      ingredient_type = ingredient.type,
      amount = ingredient.amount,
      scrap_type = scrap_type,
    })
  end

  data_table.inserts.recipes[recipe.name].results = data_table.inserts.recipes[recipe.name].results or {}

  -- Check whether this scrap_type already exists in results (accumulate)
  local existing = nil
  for _, result in ipairs(data_table.inserts.recipes[recipe.name].results) do
    if result.name == scrap_name then
      existing = result
      break
    end
  end

  if existing then                            -- adds up amount if scrap_type already exists
    if ISsettings.fixed_amount then
      existing.amount = existing.amount + amount
    else
      existing.amount_min = existing.amount_min + min
      existing.amount_max = existing.amount_max + max
    end
  else                                        -- new entry as array element
    table.insert(data_table.inserts.recipes[recipe.name].results, {
      type        = "item",
      name        = scrap_name,
      amount      = ISsettings.fixed_amount and amount or nil,
      amount_min  = ISsettings.fixed_amount and nil or min,
      amount_max  = ISsettings.fixed_amount and nil or max,
      probability = ISsettings.probability > 0 and (ISsettings.probability / 100) or nil,
    })
  end
end


---Finds, stores, and returns the recipe main product, falling back to the first result.
---@param data_table ISdata_table
---@param recipe ISRecipePrototype
---@return string|nil
function yokmods.ingredient_scrap.get_main_product(data_table, recipe)
  data_table.inserts.recipes[recipe.name] = data_table.inserts.recipes[recipe.name] or {}

  -- Nil-Guard: void recipes or emptty results
  if not recipe.results or not recipe.results[1] then
    data_table.inserts.recipes[recipe.name].main_product = nil
    return nil
  end

  local main_product
  main_product = recipe.main_product or recipe.results[1].name  -- If main_product is not set, use the first result as a fallback.
  data_table.inserts.recipes[recipe.name].main_product = main_product

  return main_product
end

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

  if log and (not ISsettings or ISsettings.shallow_log ~= false) then
    log(message)
  end
end


---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@return integer base_amount, integer|nil amount_min, integer|nil amount_max
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
  -- Nauvis-basseresources dont have an import location
  local nauvis_native = { iron = true, copper = true, coal = true, stone = true }
  if nauvis_native[scrap_type] then return nil end

  -- Check if ore (<scrap_type>-ore) -> has the "right" origin
  local ore = data.raw.item[scrap_type .. "-ore"]
  if ore and ore.default_import_location then
    return ore.default_import_location
  end

  -- Fallback: check Plate/Ingot, but exclude planets if
  -- the material also exists on Nauvis (via resource check)
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

--------------------------------
---*ICONS*                    --
--------------------------------

---@param scrap_type string
---@param tech_icon? boolean
---@param result_type? string
---@param result_name? string
---@return table
---Returns the icon layers used by recycle recipes for the given scrap type.
function yokmods.ingredient_scrap.get_icon_layers(scrap_type, tech_icon, result_type, result_name)
  local constants = yokmods.ingredient_scrap.data_table.constants
  local scrap_item = yokmods.ingredient_scrap.data_table.prototypes.items[scrap_type .. "-scrap"]
  local icons = {}

  if not scrap_item then
    log("No scrap item for: " .. scrap_type .. " default to 'signal-deny.png'")
    return { { icon = "__base__/graphics/icons/signal/signal-deny.png", icon_size = 64 } }
  end

  ---Returns icon layers from an item or fluid prototype.
  ---@param prototype table|nil
  ---@return table[]|nil
  local function prototype_icon_layers(prototype)
    if not prototype then return nil end
    if prototype.icons then return prototype.icons end
    if prototype.icon then
      return {
        {
          icon = prototype.icon,
          icon_size = prototype.icon_size or 64,
          icon_mipmaps = prototype.icon_mipmaps,
        }
      }
    end
    return nil
  end

  local source_icons = scrap_item.icons
  if result_type == "fluid" and result_name and data.raw.fluid[result_name] then
    source_icons = prototype_icon_layers(data.raw.fluid[result_name]) or source_icons
  end

  if tech_icon then
    table.insert(icons, { icon = constants.icon_path .. "recycle-256.png", icon_size = 256, scale = 0.8})
    table.insert(icons, {
      icon = constants.icon_path .. "scrap-128.png",
      icon_size = 128,
      scale = 0.8,
      tint = scrap_item.icons and scrap_item.icons[1] and scrap_item.icons[1].tint,
    })
  else
    if mods["quality"] then
      table.insert(icons, { icon = "__quality__/graphics/icons/recycling.png", icon_size = 64, scale = 0.8})
    else
      table.insert(icons, { icon = constants.icon_path .. "recycle-64.png", icon_size = 64, scale = 0.8})
    end
    for _, v in ipairs(source_icons) do table.insert(icons, v) end
  end

  if not tech_icon then
    if mods["quality"] then
      table.insert(icons, { icon = "__quality__/graphics/icons/recycling-top.png", icon_size = 64, scale = 0.8})
    else
      table.insert(icons, { icon = constants.icon_path .. "recycle-top-64.png", icon_size = 64, scale = 0.8})
    end
  end

  return icons
end
