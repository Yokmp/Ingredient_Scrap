local data_table_reader = require("code.data_table.reader")
local is_log = require("code.functions.is-log")
local naming = require("code.functions.naming")

local icon_layers = {}

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

---Returns a copied icon layer with Factorio's icon_size field populated.
---@param icon_layer table
---@return table
local function normalize_icon_layer(icon_layer)
  local copy = {}
  for key, value in pairs(icon_layer) do
    copy[key] = value
  end
  copy.icon_size = copy.icon_size or copy.size or 64
  copy.size = nil
  return copy
end

---Returns the icon layers used by recycle recipes for the given scrap type.
---@param data_table ISdata_table
---@param scrap_type string
---@param tech_icon? boolean
---@param result_type? string
---@param result_name? string
---@return table
function icon_layers.get(data_table, scrap_type, tech_icon, result_type, result_name)
  local constants = data_table_reader.constants(data_table)
  local scrap_item = data_table_reader.generated_item(
    data_table,
    naming.get_scrap_name(scrap_type)
  )
  local icons = {}

  if not scrap_item then
    is_log.write(
      "icons",
      "warn",
      "missing-scrap-item",
      "Missing generated scrap item; using the deny signal as fallback icon.",
      { scrap_type = scrap_type }
    )
    return { { icon = "__base__/graphics/icons/signal/signal-deny.png", icon_size = 64 } }
  end

  local source_icons = scrap_item.icons
  if result_type == "item" and result_name and data.raw.item[result_name] then
    source_icons = prototype_icon_layers(data.raw.item[result_name]) or source_icons
  elseif result_type == "fluid" and result_name and data.raw.fluid[result_name] then
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
    for _, v in ipairs(source_icons) do
      local layer = normalize_icon_layer(v)
      layer.scale = layer.scale or 0.85
      layer.shift = layer.shift or { 0, 0 }
      table.insert(icons, layer)
    end
  else
    if mods["quality"] then
      table.insert(icons, { icon = "__quality__/graphics/icons/recycling.png", icon_size = 64, scale = 0.8})
    else
      table.insert(icons, { icon = constants.icon_path .. "recycle-64.png", icon_size = 64, scale = 0.8})
    end
    for _, v in ipairs(source_icons) do table.insert(icons, normalize_icon_layer(v)) end
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

return icon_layers
