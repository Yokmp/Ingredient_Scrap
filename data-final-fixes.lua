local _material_types = {"iron", "copper", "steel"}
local _result_types = {"plate", "cable"}

-- local yutil = require("functions.functions")
-- local mod = require("mods")
-- local patch = mod[3]

-- local scrap_types = yutil.table.extend(mod[1], _material_types)
-- local item_types = yutil.table.extend(mod[2], _item_types)


---holds the return table template
return_template = {
    name = "_return_template_",
    recipe = {    -- determine and cache                                     get -> modify -> replace
      none      = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil,},
      normal    = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil, },
      expensive = { ingredients = {}, ingredient_types = {},   results = {}, enabled = true, main_product = nil, },

    },

    new = function(self, recipe_name)
      if recipe_name and type(recipe_name) == "string" then
        local _t = util.table.deepcopy(return_template)
        _t.name = recipe_name
        return _t
      end
    end
  }


---Removes all material_types which don't have a result when combined with item_types
---@param material_types table
---@param result_types table
---@return table material_types
function get_materials(material_types, result_types)
  local _t1, _t2 = {}, {}
  info("Filtering scrap types")
  for _, m_type in ipairs(material_types) do
    for _, i_type in ipairs(result_types) do
      if data.raw.item[m_type.."-"..i_type] then

        if not _t1[m_type] then

          _t1[m_type] = m_type.."-"..i_type

        elseif data.raw.item[m_type.."-"..i_type].subgroup
           and data.raw.item[m_type.."-"..i_type].subgroup == "raw-material" then

          _t1[m_type] = m_type.."-"..i_type
        end

      end
    end
  end
  return _t1
end
-- log(serpent.block(get_materials(_material_types, _result_types)))
-- error("get_materials()")


---Returns a table containing all 
---@param scrap_type table
---@param result_types table
---@return table - eg.: ``{ scrap = "iron-scrap", item = "iron-plate", amount = 0 }``
function get_scrap_types(scrap_type, result_types)
  for _, i_type in ipairs(result_types) do
    local _name = scrap_type.."-"..i_type
    if data.raw.item[_name] then
      return { scrap = scrap_type.."-scrap", item = _name, amount = 0 }
    end
  end

  return false
end
-- log(serpent.block(get_scrap_types("iron", _result_types)))
-- error("get_scrap_types()")






