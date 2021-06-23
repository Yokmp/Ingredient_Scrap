
local mod_name = "__Ingredient_Scrap__"


function table.extend(t1, t2)
  for i = 1, #t2 do t1[#t1+1] = t2[i] end return t1
end


---adds name and amount keys to ingredients and returns a new table
---@param table table ``{string, number?}``
---@return table ``{ name = "name", amount = n }``
function add_pairs(table)
  if table and table.name then return table end --they can be empty and would be "valid"
  local _t = table

  _t.type   = "item"
  _t.name   = _t[1]      ;  _t[1] = nil
  _t.amount = _t[2] or 1 ;  _t[2] = nil

  return _t
end
-- log(serpent.block( add_pairs({ "iron-gear-wheel", 10 }) ))
-- log(serpent.block( add_pairs({ "copper-plate", 10 }) ))
-- log(serpent.block( add_pairs({ name="iron-plate", amount=20 }) ))
-- log(serpent.block( add_pairs({ name = "uranium-235", probability = 0.007, amount = 1 }) ))
-- assert(1==2, "add_pairs()")


-- constants = constants or {}
-- constants.difficulty = {
--   ["none"] = 1,
--   ["result"] = 1,
--   ["results"] = 2,
--   ["ingredients"] = 2,
--   ["normal"] = 3,
--   ["expensive"] = 4,
-- }

---comment
---@return string
function get_icon(name)
  local icon_path = mod_name.. "/graphics/icons/"
  local icon = icon_path..name.."-scrap.png"
  local icons = {
    missing   = icon_path.."missing-icon.png",
    recycle   = icon_path.."recycle.png",
    iron      = icon,
    copper    = icon,
    steel     = icon,
    imersium      = get_icon_bycolor("purple", 1),
    lead          = get_icon_bycolor("brown", 3),
    titanium      = get_icon_bycolor("dgrey", 2),
    zinc          = get_icon_bycolor("grey", 3),
    nickel        = get_icon_bycolor("grey", 2),
    aluminium     = get_icon_bycolor("grey", 1),
    tungsten      = get_icon_bycolor("grey", 2),
    tin           = get_icon_bycolor("grey", 2),
    silver        = get_icon_bycolor("grey", 1),
    gold          = get_icon_bycolor("yellow", 2),
    brass         = get_icon_bycolor("yellow", 1),
    bronze        = get_icon_bycolor("orange", 1),
    nitinol       = get_icon_bycolor("grey", 2),
    invar         = get_icon_bycolor("grey", 3),
    cobalt        = get_icon_bycolor("blue", 2),
    -- glass      = get_icon_bycolor("purple", 1),
    -- silicon    = get_icon_bycolor("purple", 1),
    gunmetal      = get_icon_bycolor("yellow", 1),
    ["cobalt-steel"]  = get_icon_bycolor("blue", 2),
    ["copper-tungsten"]  = get_icon_bycolor("red", 2),
  }
  return icons[name] or icons.missing
end

function get_scrap_icons(item, result)
  local icon_item, icon_size, icon_mipmaps
  if data.raw.item[result] then
    if data.raw.item[result].icon then
      icon_item = data.raw.item[result].icon
      icon_size = data.raw.item[result].icon_size
      icon_mipmaps = data.raw.item[result].icon_mipmaps
    elseif data.raw.item[item].icon then
      icon_item = data.raw.item[item].icon
      icon_size = data.raw.item[item].icon_size
      icon_mipmaps = data.raw.item[item].icon_mipmaps
    end
  end
  return {
    {
      icon = get_icon(item),
      icon_size = 64, icon_mipmaps = 4,
      scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    },
    {
      icon = icon_item or get_icon("missing"),
      icon_size = icon_size or 64, icon_mipmaps = icon_mipmaps or 4,
      scale = 0.25, shift = util.by_pixel(0, 0), tint = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    },
    {
      icon = get_icon("recycle"),
      icon_size = 64, icon_mipmaps = 4,
      scale = 0.5, shift = util.by_pixel(0, 0), tint = { r = 0.8, g = 1.0, b = 0.8, a = 1.0 }
    },
  }
end

function table.extend(t1, t2)
  for i = 1, #t2 do t1[#t1+1] = t2[i] end return t1
end

---returns an icon in the form of ``path/color-scrap-index.png``
---@param color string
---@param index number
---@return string
function get_icon_bycolor(color, index)
  local mod_name = "__Ingredient_Scrap__"
  local icon_path = mod_name.. "/graphics/icons/color/"
  local icon  	  = nil
  local missing   = mod_name.. "/graphics/icons/missing-icon.png"
  local recycle   = mod_name.. "/graphics/icons/recycle.png"
  local icons = {
    blue    = {"blue"},
    brown   = {"brown"},
    dgrey   = {"dgrey"},
    grey    = {"grey"},
    orange  = {"orange"},
    purple  = {"purple"},
    red     = {"red"},
    teal    = {"teal"},
    yellow  = {"yellow"},
  }

  if icons.color then
    if index and type(index) =="number" then
      icon = icon_path..icons.color.."-scrap-"..tostring(util.clamp(index, 1, 3))..".png"
    else
      icon = icon_path..icons.color.."-scrap-"..tostring(math.random(3))..".png"
    end
  elseif color == "recycle" then
    icon = recycle
  end


  return icon or missing
end

