
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

