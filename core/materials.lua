local resolver = require("core.materials.resolver")

---Fills data_table.materials.solid and data_table.materials.fluid from resources, items, fluids, and whitelists.
function yokmods.ingredient_scrap.collect_materials()
  local materials = yokmods.ingredient_scrap.data_table.materials
  local solid = yokmods.ingredient_scrap.data_table.materials.solid
  local fluid = yokmods.ingredient_scrap.data_table.materials.fluid
  local seen_solid = {}
  local seen_fluid = {}

  ---Adds a solid scrap material if it was not already collected.
  ---@param scrap_type string|nil
  ---@param source_name string
  local function add_solid_material(scrap_type, source_name)
    if not scrap_type then return end
    if not type_blacklist[scrap_type] and not seen_solid[scrap_type] then
      seen_solid[scrap_type] = true
      table.insert(solid, scrap_type)
      log("[IS-MAT-SOLID] inserted into solid: " .. scrap_type .. " from " .. source_name .. " (total: " .. #solid .. ")")
    end
  end

  ---Adds a fluid scrap material when it has a matching solid item source.
  ---@param scrap_type string|nil
  ---@param fluid_name string
  local function add_fluid_material(scrap_type, fluid_name)
    if not scrap_type then return end
    if IS_DEBUG then log("[IS-MAT-FLUID] found: " .. fluid_name .. " -> scrap_type: " .. scrap_type
      .. " blacklisted: " .. tostring(type_blacklist[scrap_type] or false)
      .. " seen: " .. tostring(seen_fluid[scrap_type] or false)
      .. " has_plate: " .. tostring(data.raw.item[scrap_type .. "-plate"] ~= nil)
      .. " has_ingot: " .. tostring(data.raw.item[scrap_type .. "-ingot"] ~= nil)) end
    if not type_blacklist[scrap_type] and not seen_fluid[scrap_type] then
      if data.raw.item[scrap_type .. "-plate"] or data.raw.item[scrap_type .. "-ingot"] then
        seen_fluid[scrap_type] = true
        table.insert(fluid, scrap_type)
        if IS_DEBUG then log("[IS-MAT-FLUID] inserted: " .. scrap_type) end
      end
    end
  end

  ---Returns minable result names matching the requested result type.
  ---@param minable table
  ---@param result_type string
  ---@return string[]
  local function minable_result_names(minable, result_type)
    local names = {}
    if minable.result and result_type == "item" then
      table.insert(names, minable.result)
    end
    for _, result in ipairs(minable.results or {}) do
      if result.name and (result.type == result_type or (result.type == nil and result_type == "item")) then
        table.insert(names, result.name)
      end
    end
    return names
  end

--------------------------------
---*data.raw.resource*        --
--------------------------------

  for _, resource in pairs(data.raw.resource) do
    if resource.minable then
      if resource.category ~= "basic-fluid" then
        for _, result_name in ipairs(minable_result_names(resource.minable, "item")) do
          add_solid_material(resolver.resolve_solid(result_name, materials, true), result_name)
        end

      elseif ISsettings.fluids and resource.category == "basic-fluid" and resource.minable.results then   -- fluid
        for _, result_name in ipairs(minable_result_names(resource.minable, "fluid")) do
          add_fluid_material(resolver.resolve_fluid(result_name, materials), result_name)
        end
      end
    end
  end

--------------------------------
---*SOLID: ALLOY BY SUFFIX*   --
--------------------------------

  for name, _ in pairs(data.raw.item) do
    add_solid_material(resolver.resolve_solid(name, materials), name)
  end

--------------------------------
---*WHIELIST*                 --
--------------------------------

  for _, prefix in ipairs(scrap_whitelist_solid) do
    if not type_blacklist[prefix] and not seen_solid[prefix] then
      seen_solid[prefix] = true
      table.insert(solid, prefix)
      log("[IS-MAT-SOLID] inserted into solid: " .. prefix .. " (total: " .. #solid .. ")")
    end
  end
  for _, prefix in ipairs(scrap_whitelist_fluid) do
    if not type_blacklist[prefix] and not seen_fluid[prefix] then
      seen_fluid[prefix] = true
      table.insert(fluid, prefix)
      log("[IS-MAT-FLUID] inserted into fluid: " .. prefix .. " (total: " .. #fluid .. ")")
    end
  end

--------------------------------
---*FLUID: TYPES BY PREFIX*   --
--------------------------------

  if ISsettings.fluids then
    for name, _ in pairs(data.raw.fluid) do
      add_fluid_material(resolver.resolve_fluid(name, materials), name)
    end
  end
end
