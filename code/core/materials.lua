local resolver = require("code.core.materials.resolver")
local material_overrides = require("code.lib.material-overrides")



--------------------------------
---*MATERIALS*                --
--------------------------------



---Fills data_table.materials.solid and data_table.materials.fluid from resources, items, fluids, and whitelists.
function yokmods.ingredient_scrap.collect_materials()
  local materials = yokmods.ingredient_scrap.data_table.materials
  local solid = yokmods.ingredient_scrap.data_table.materials.solid
  local fluid = yokmods.ingredient_scrap.data_table.materials.fluid
  local seen_solid = {}
  local seen_fluid = {}

  ---Returns the configured material mode, defaulting to auto for unknown materials.
  ---@param scrap_type string
  ---@return string
  local function material_mode(scrap_type)
    return (ISsettings.material_modes and ISsettings.material_modes[scrap_type]) or "auto"
  end

  ---Adds a solid scrap material if it was not already collected.
  ---@param scrap_type string|nil
  ---@param source_name string
  local function add_solid_material(scrap_type, source_name)
    if not scrap_type then return end
    if not material_overrides.is_ignored(material_mode(scrap_type), "solid") and not seen_solid[scrap_type] then
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
    local mode = material_mode(scrap_type)
    local ignored = material_overrides.is_ignored(mode, "fluid")
    local forced = material_overrides.is_forced(mode, "fluid")
    if IS_DEBUG then log("[IS-MAT-FLUID] found: " .. fluid_name .. " -> scrap_type: " .. scrap_type
      .. " ignored: " .. tostring(ignored)
      .. " forced: " .. tostring(forced)
      .. " seen: " .. tostring(seen_fluid[scrap_type] or false)
      .. " has_plate: " .. tostring(data.raw.item[scrap_type .. "-plate"] ~= nil)
      .. " has_ingot: " .. tostring(data.raw.item[scrap_type .. "-ingot"] ~= nil)) end
    if not ignored and not seen_fluid[scrap_type] then
      if forced or data.raw.item[scrap_type .. "-plate"] or data.raw.item[scrap_type .. "-ingot"] then
        seen_fluid[scrap_type] = true
        table.insert(fluid, scrap_type)
        if IS_DEBUG then log("[IS-MAT-FLUID] inserted: " .. scrap_type) end
      end
    end
  end

--------------------------------
---*MINABLE*                  --
--------------------------------

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
---*OVERRIDES*                --
--------------------------------

  for material_name, mode in pairs(ISsettings.material_modes or {}) do
    if material_overrides.is_forced(mode, "solid") then
      add_solid_material(material_name, "material override")
    end
    if ISsettings.fluids and material_overrides.is_forced(mode, "fluid") then
      add_fluid_material(material_name, "material override")
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
