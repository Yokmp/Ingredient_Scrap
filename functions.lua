local mod_name = "__Ingredient_Scrap__"

local yutil = { table = {} }

function util.table.extend(t1, t2)
  if type(t1) == "table" and type(t2) == "table" then
    for i = 1, #t2 do t1[#t1 + 1] = t2[i] end
    return t1
  end
end

---adds name and amount keys to ingredients and returns a new table
---@param _table table ``{string, number?}``
---@return table ``{ name = "name", amount = n }``
function util.add_pairs(_table)
  local _t = _table
  if type(_t) == "table" and _t[1] then --they can be empty and would be "valid" until ...
    if _t.name then return _t end       --ignore if it has pairs already
    if type(_t[1]) ~= "string" then error(" First index must be of type 'string'") end
    if type(_t[2]) ~= "number" then --[[log(" Warning: add_pairs("..type(_t[1])..", "..type(_t[2])..") - implicitly set value - amount = 1");]] _t[2] = 1 end
    return { name = _t[1], amount = _t[2] or 1 }
  elseif type(_t) == "string" then
    log(" Warning: add_pairs(" .. type(_t[1]) .. ", " .. type(_t[2]) .. ") - implicitly set value - amount = 1")
    return { name = _t, amount = 1 }
  end
  return _t
end

---Sets the items icon, sets icons to nil.
---@param item_name string
---@param new_icon string
function util.set_item_icon(item_name, new_icon)
  if data.raw.item[item_name] then
    data.raw.item[item_name].icons = {
      icon = new_icon,
      icon_size = 64,
      scale = 0.5,
      shift = { 0, 0 }
    }
  end
end

---Sets the recipes icon, sets icons to nil.
---@param recipe_name string
---@param new_icon string
function util.set_recipe_icon(recipe_name, new_icon)
  if data.raw.recipe[recipe_name] then
    data.raw.recipe[recipe_name].icons = {
      icon = new_icon,
      icon_size = 64,
      scale = 0.5,
      shift = { 0, 0 }
    }
  end
end

----------------
--    ICONS   --
----------------



---returns an icon in the form of ``path/color-scrap-index.png``
---@param color string
---@param index number
---@return string
function util.get_icon_bycolor(color, index)
  local icon_path = mod_name .. "/graphics/icons/"
  local icon      = nil
  local missing   = mod_name .. "/graphics/icons/missing-icon.png"
  local recycle   = mod_name .. "/graphics/icons/recycle.png"
  local icons     = {
    blue   = "blue",
    brown  = "brown",
    dgrey  = "darkgrey",
    grey   = "grey",
    orange = "orange",
    purple = "purple",
    red    = "red",
    teal   = "teal",
    green  = "green",
    yellow = "yellow",
  }

  if type(color) == "string" and icons[color] then
    if type(index) == "number" then
      local ii = tostring(util.clamp(index, 1, 3))
      icon = icon_path .. icons[color] .. "-scrap-" .. ii .. ".png"
    else
      icon = icon_path .. icons[color] .. "-scrap-" .. tostring(math.random(3)) .. ".png"
    end
  elseif color == "recycle" then
    icon = recycle
  end

  return icon or missing
end

util.scrap_icons = {
  recycle             = util.get_icon_bycolor("recycle", 1),
  adamantite          = util.get_icon_bycolor("purple", 1),
  aluminum            = util.get_icon_bycolor("grey", 1),
  aluminium           = util.get_icon_bycolor("grey", 1),
  antitate            = util.get_icon_bycolor("red", 1),
  brass               = util.get_icon_bycolor("yellow", 1),
  bronze              = util.get_icon_bycolor("yellow", 2),
  chromium            = util.get_icon_bycolor("grey", 1),
  cobalt              = util.get_icon_bycolor("blue", 2),
  copper              = util.get_icon_bycolor("orange", 1),
  ["cobalt-steel"]    = util.get_icon_bycolor("blue", 1),
  ["copper-tungsten"] = util.get_icon_bycolor("red", 2),
  elionagate          = util.get_icon_bycolor("teal", 1),
  -- glass            = util.get_icon_bycolor("purple", 1),
  gold                = util.get_icon_bycolor("yellow", 2),
  gunmetal            = util.get_icon_bycolor("yellow", 2),
  imersium            = util.get_icon_bycolor("purple", 1),
  invar               = util.get_icon_bycolor("grey", 3),
  iron                = util.get_icon_bycolor("grey", 1),
  lead                = util.get_icon_bycolor("brown", 3),
  lithium             = util.get_icon_bycolor("dgrey", 1),
  manganic            = util.get_icon_bycolor("orange", 3),
  ["meta-garnierite"] = util.get_icon_bycolor("yellow", 1),
  nickel              = util.get_icon_bycolor("grey", 2),
  nitinol             = util.get_icon_bycolor("grey", 2),
  ["nova-leucoxene"]  = util.get_icon_bycolor("dgrey", 1),
  orichalcite         = util.get_icon_bycolor("orange", 1),
  osmium              = util.get_icon_bycolor("purple", 3),
  phosphic            = util.get_icon_bycolor("teal", 3),
  phosphorite         = util.get_icon_bycolor("grey", 1),
  plumbic             = util.get_icon_bycolor("purple", 3),
  ["pro-galena"]      = util.get_icon_bycolor("dgrey", 1),
  sanguinate          = util.get_icon_bycolor("red", 1),
  silicon             = util.get_icon_bycolor("brown", 1),
  silver              = util.get_icon_bycolor("grey", 1),
  stannic             = util.get_icon_bycolor("green", 3),
  steel               = util.get_icon_bycolor("grey", 2),
  tellurium           = util.get_icon_bycolor("purple", 1),
  tin                 = util.get_icon_bycolor("grey", 2),
  titanic             = util.get_icon_bycolor("grey", 3),
  titanium            = util.get_icon_bycolor("dgrey", 2),
  tungsten            = util.get_icon_bycolor("dgrey", 1),
  zinc                = util.get_icon_bycolor("grey", 2),
}


---@return string - icon path
function util.get_item_icon(scrap_type)
  local icons = util.scrap_icons
  return icons[scrap_type] or icons.missing
end

---returns the recycle recipe icons table
---@param scrap_type string
---@param result_name string
---@return table
function util.get_recycle_icons(scrap_type, result_name)
  local icon_item, icon_size, scale_factor

  if data.raw.item[result_name] then
    if data.raw.item[result_name].icon then
      icon_item = data.raw.item[result_name].icon
      icon_size = data.raw.item[result_name].icon_size
    elseif data.raw.item[result_name].icons then
      icon_item = data.raw.item[result_name].icons[1].icon
      icon_size = data.raw.item[result_name].icons[1].icon_size
      icon_scale = data.raw.item[result_name].icons[1].scale
    elseif data.raw.item[scrap_type].icon then
      icon_item = data.raw.item[scrap_type].icon
      icon_size = data.raw.item[scrap_type].icon_size
    end
  end
  scale_factor = (64 / icon_size) or 1
  return {
    {
      icon = util.get_item_icon(scrap_type),
      icon_size = 64,
      scale = 0.5,
      shift = util.by_pixel(0, 0)
    },
    {
      icon = icon_item or util.get_item_icon("missing"),
      icon_size = icon_size or 64,
      scale = 0.25 * scale_factor,
      shift = { -8, -8 }
    },
    {
      icon = util.get_item_icon("recycle"),
      icon_size = 64,
      scale = 0.5,
      shift = util.by_pixel(0, 0),
      tint = { r = 0.8, g = 1.0, b = 0.8, a = 1.0 }
    },
  }
end

return yutil
