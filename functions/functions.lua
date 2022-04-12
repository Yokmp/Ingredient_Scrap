
local mod_name = "__Ingredient_Scrap__"

local yutil = { table={} }

function yutil.table.extend(t1, t2)
  if type(t1) == "table" and type(t2) == "table" then
    for i = 1, #t2 do t1[#t1+1] = t2[i] end return t1 end
end


function yutil.set_item_icon(item_name, new_icon)
  if data.raw.item[item_name] then
    data.raw.item[item_name].icon = new_icon
    data.raw.item[item_name].icon_size = 64
    data.raw.item[item_name].icon_mipmaps = 4
    data.raw.item[item_name].icons = nil
  end
end
function yutil.set_recipe_icon(recipe_name, new_icon)
  if data.raw.recipe[recipe_name] then
    data.raw.recipe[recipe_name].icon = new_icon
    data.raw.recipe[recipe_name].icon_size = 64
    data.raw.recipe[recipe_name].icon_mipmaps = 4
    data.raw.recipe[recipe_name].icons = nil
  end
end



----------------
--    ICONS   --
----------------



---returns an icon in the form of ``path/color-scrap-index.png``
---@param color string
---@param index number
---@return string
function yutil.get_icon_bycolor(color, index)
  local icon_path = mod_name.. "/graphics/icons/"
  local icon  	  = nil
  local missing   = mod_name.. "/graphics/icons/missing-icon.png"
  local recycle   = mod_name.. "/graphics/icons/recycle.png"
  local icons = {
    blue    = "blue",
    brown   = "brown",
    dgrey   = "darkgrey",
    grey    = "grey",
    orange  = "orange",
    purple  = "purple",
    red     = "red",
    teal    = "teal",
    green   = "green",
    yellow  = "yellow",
  }

  if type(color) == "string" and icons[color] then
    if type(index) =="number" then
      index = tostring(util.clamp(index, 1, 3))
      icon = icon_path..icons[color].."-scrap-"..index..".png"
    else
      icon = icon_path..icons[color].."-scrap-"..tostring(math.random(3))..".png"
    end
  elseif color == "recycle" then
    icon = recycle
  end

  return icon or missing
end


yutil.scrap_icons = {
  recycle             = yutil.get_icon_bycolor("recycle"),
  adamantite          = yutil.get_icon_bycolor("purple", 1),
  aluminum            = yutil.get_icon_bycolor("grey", 1),
  aluminium           = yutil.get_icon_bycolor("grey", 1),
  antitate            = yutil.get_icon_bycolor("red", 1),
  brass               = yutil.get_icon_bycolor("yellow", 1),
  bronze              = yutil.get_icon_bycolor("yellow", 2),
  chromium            = yutil.get_icon_bycolor("grey", 1),
  cobalt              = yutil.get_icon_bycolor("blue", 2),
  copper              = yutil.get_icon_bycolor("orange", 1),
  ["cobalt-steel"]    = yutil.get_icon_bycolor("blue", 1),
  ["copper-tungsten"] = yutil.get_icon_bycolor("red", 2),
  elionagate          = yutil.get_icon_bycolor("teal", 1),
  -- glass            = yutil.get_icon_bycolor("purple", 1),
  gold                = yutil.get_icon_bycolor("yellow", 2),
  gunmetal            = yutil.get_icon_bycolor("yellow", 2),
  imersium            = yutil.get_icon_bycolor("purple", 1),
  invar               = yutil.get_icon_bycolor("grey", 3),
  iron                = yutil.get_icon_bycolor("grey", 1),
  lead                = yutil.get_icon_bycolor("brown", 3),
  lithium             = yutil.get_icon_bycolor("dgrey", 1),
  manganic            = yutil.get_icon_bycolor("orange", 3),
  ["meta-garnierite"] = yutil.get_icon_bycolor("yellow", 1),
  nickel              = yutil.get_icon_bycolor("grey", 2),
  nitinol             = yutil.get_icon_bycolor("grey", 2),
  ["nova-leucoxene"]  = yutil.get_icon_bycolor("dgrey", 1),
  orichalcite         = yutil.get_icon_bycolor("orange", 1),
  osmium              = yutil.get_icon_bycolor("purple", 3),
  phosphic            = yutil.get_icon_bycolor("teal", 3),
  phosphorite         = yutil.get_icon_bycolor("grey", 1),
  plumbic             = yutil.get_icon_bycolor("purple", 3),
  ["pro-galena"]      = yutil.get_icon_bycolor("dgrey", 1),
  sanguinate          = yutil.get_icon_bycolor("red", 1),
  silicon             = yutil.get_icon_bycolor("brown", 1),
  silver              = yutil.get_icon_bycolor("grey", 1),
  stannic             = yutil.get_icon_bycolor("green", 3),
  steel               = yutil.get_icon_bycolor("grey", 2),
  tellurium           = yutil.get_icon_bycolor("purple", 1),
  tin                 = yutil.get_icon_bycolor("grey", 2),
  titanic             = yutil.get_icon_bycolor("grey", 3),
  titanium            = yutil.get_icon_bycolor("dgrey", 2),
  tungsten            = yutil.get_icon_bycolor("dgrey", 1),
  zinc                = yutil.get_icon_bycolor("grey", 2),
}


---@return string
function yutil.get_item_icon(scrap_type)
  local icons = yutil.scrap_icons
  return icons[scrap_type] or icons.missing
end


---returns the recycle recipe icons layers
function yutil.get_recycle_icons(scrap_type, result_name)
  local icon_item, icon_size, icon_mipmaps, scale_factor

  if data.raw.item[result_name] then
    if data.raw.item[result_name].icon then
      icon_item = data.raw.item[result_name].icon
      icon_size = data.raw.item[result_name].icon_size
      icon_mipmaps = data.raw.item[result_name].icon_mipmaps
    elseif data.raw.item[scrap_type].icon then
      icon_item = data.raw.item[scrap_type].icon
      icon_size = data.raw.item[scrap_type].icon_size
      icon_mipmaps = data.raw.item[scrap_type].icon_mipmaps
    end
  end
  scale_factor = (64/icon_size) or 1
  return {
    {
      icon = yutil.get_item_icon(scrap_type),
      icon_size = 64, icon_mipmaps = 4,
      scale = 0.5, shift = util.by_pixel(0, 0)
    },
    {
      icon = icon_item or yutil.get_item_icon("missing"),
      icon_size = icon_size or 64, icon_mipmaps = icon_mipmaps or 4,
      scale = 0.25*scale_factor, shift = {-8,-8}
    },
    {
      icon = yutil.get_item_icon("recycle"),
      icon_size = 64, icon_mipmaps = 4,
      scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 0.8, g = 1.0, b = 0.8, a = 1.0 }
    },
  }
end


return yutil
