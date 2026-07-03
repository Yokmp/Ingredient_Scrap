local naming = {}

---Adds the mod-owned prototype prefix only when it is not already present.
---@param name string
---@return string
function naming.with_yis_prefix(name)
  if name:match("^yis%-") then return name end
  return "yis-" .. name
end

---Removes the mod-owned prefix from a material token before composing names.
---@param scrap_type string
---@return string
function naming.without_yis_prefix(scrap_type)
  return scrap_type:gsub("^yis%-", "")
end

---Returns the generated recycle recipe name for a scrap material type.
---@param scrap_type string
---@return string
function naming.get_recycle_recipe_name(scrap_type)
  return naming.with_yis_prefix("recycle-" .. naming.without_yis_prefix(scrap_type) .. "-scrap")
end

---Returns the generated scrap item name for a scrap material type.
---@param scrap_type string
---@return string
function naming.get_scrap_name(scrap_type)
  return naming.with_yis_prefix(naming.without_yis_prefix(scrap_type) .. "-scrap")
end

---Determines the correct `default_import_location` for a `scrap_type`.
---First checks whether an ore exists (`<scrap_type>`-ore), then plate/ingot,
---and filters out Gleba if Nauvis resources are present.
---@param scrap_type string
---@return string|nil
function naming.get_import_location(scrap_type)
  -- Nauvis base resources do not need an import location.
  local nauvis_native = { iron = true, copper = true, coal = true, stone = true }
  if nauvis_native[scrap_type] then return nil end

  local ore = data.raw.item[scrap_type .. "-ore"]
  if ore and ore.default_import_location then
    return ore.default_import_location
  end

  -- Fallback: check plate/ingot, but exclude planets if the material also
  -- exists on Nauvis via a resource prototype.
  local plate = data.raw.item[scrap_type .. "-plate"]
              or data.raw.item[scrap_type .. "-ingot"]
              or data.raw.item[scrap_type]
  if plate and plate.default_import_location then
    local resource = data.raw.resource[scrap_type .. "-ore"] or data.raw.resource[scrap_type]
    local is_nauvis_resource = resource and (
      resource.autoplace and resource.autoplace.control ~= nil
      -- Nauvis resources use autoplace controls, not probability_expression.
      and resource.autoplace.probability_expression == nil
    )
    if is_nauvis_resource then return nil end
    return plate.default_import_location
  end

  return nil
end

return naming
