---@class icon
---@field icon string
---@field icon_size integer
---@field icon_mipmaps integer
---@field scale number
---@field shift vector
---@field tint color

---@class vector
---@field table number

---@class color
---@field r number
---@field g number
---@field b number
---@field a number


---@type icon
local icon_prototype = {
    icon = nil,
    icon_size = nil,
    icon_mipmaps = 0,
    scale = 1,
    shift = {0,0},
    tint = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
  }

-- key = {name, folder, size, mipmaps, scale}
local icons = {

  electric_interface  = {"electric-interface", "icons", 64, 4, 0.5},
  steam_interface     = {"steam-interface", "icons", 64, 4, 0.5},
  missing             = {"missing", "icons", 64, 4, 0.5},

  missingp_tech       = {"missing-tech", "icons", 128, 0, 1},

  ---Returns an icon object, Use ``icons:get(name, ...)``
  ---@param self table icons table
  ---@param name string
  ---@param scale? integer
  ---@param shift? vector
  ---@param tint? color
  ---@return icon
  get = function (self, name, scale, shift, tint)
    local proto = util.copy(icon_prototype)
    name = self[name] and name or "missing"
    proto.icon = "__ylib__/graphics/"..self[name][2].."/"..self[name][1]..".png"
    proto.icon_size = self[name][3]             ---@type integer
    proto.icon_mipmaps = self[name][4]          ---@type integer
    proto.scale = scale or self[name][5]        ---@type number
    proto.shift = shift or icon_prototype.shift ---@type vector
    proto.tint = tint or icon_prototype.tint    ---@type color
    return proto
  end,
}


---Returns the icon as table from an item
---@param item_name string
---@return icon|nil
function ylib.icon.get_icon_from_item(item_name)  --//TODO icons.lua intergation
  local icon
  local _item = data.raw.item[item_name]
  if _item then
    icon = {}
    if _item.icon then
      icon.icon = _item.icon
      icon.icon_size = _item.icon_size
      icon.icon_mipmaps = _item.icon_mipmaps or 0
    -- elseif _item.main_product then --//?search recipes too?
    --   icon =  get_icon_from_item(_item.main_product)
    elseif _item.icons then
      icon = _item.icons[1]
    end
      if loglevel then log("Using icon: "..item_name.." - "..icon.icon) end
  end
  return icon
end


---Returns the icon data of a fluid.
---@param fluid_name string
---@return icon
function ylib.icon.get_fluid_icon(fluid_name)
  ---@type icon
  local icon
  local fluid = data.raw.fluid[fluid_name]
  if fluid then
    icon = {}
    if fluid.icon then
      icon.icon = fluid.icon
      icon.icon_size = fluid.icon_size
      icon.icon_mipmaps = fluid.icon_mipmaps or 0
      icon.shift = icon.shift or {0,0}
      icon.scale = icon.scale or (32/fluid.icon_size)
      icon.tint = icon.tint or {r=1, g=1, b=1, a=1}
    elseif fluid.icons then
      icon = fluid.icons[1]
    end
  end
  return icon
end


--//TODO rework icon layering at some point

---Returns a table containing icon definitions.
---If ``icon_top`` is a string: ``icon_top = get_icon_from_item(icon_top) or get_fluid_icon(icon_top) or icons:get(icon_top)``
---@param icon_top icon|string use icons:get() if possible, can work on strings
---@param icon_bottom? icon defaults to molten_drop (based on icon_top.icon_size)
---@param shift? table default ``{{0,0}, {0,5}}``
function ylib.icon.get_composed_icon(icon_top, icon_bottom, scale, shift) --//*FIXME drop scaling, should consider making custom icons per metal
  scale = scale or 0.5
  shift = shift or 0

  if type(icon_top) == "string" then
    icon_top = ylib.icon.get_icon_from_item(icon_top) or ylib.icon.get_fluid_icon(icon_top) or icons:get(icon_top)
  end

  local function determine_icon_by_type()
    if icon_top.icon_size <= 96 then return icons:get("molten_drop")
    else return icons:get("molten_drop_tech") end
  end

  icon_top.scale = icon_top.scale and icon_top.scale-0.2 or 0.6
  icon_top.scale = icon_top.scale*scale
  icon_top.shift = {0,0-shift}
  icon_bottom = icon_bottom or determine_icon_by_type()
  -- icon_bottom.scale = (icon_bottom.icon_size/icon_top.icon_size)*(scale-0.2)
  icon_bottom.scale = (icon_bottom.icon_size/icon_top.icon_size)*(scale*0.6)
  icon_bottom.shift = {0,0+shift}

  return {icon_top, icon_bottom}
end

