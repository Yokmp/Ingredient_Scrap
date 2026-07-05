local roots = {}

local material_resolver = require("code.resolver.materials.resolver")

---Returns true when a recycle recipe returns the exact source material.
---@param flow table
---@param material string
---@return boolean
local function has_exact_recycle_target(flow, material)
  for _, recycle in ipairs(flow.recycle_recipes or {}) do
    local result_name = recycle.result and recycle.result.name
    if result_name == material then return true end
  end
  return false
end

---Returns material names that are currently exact component scrap families.
---@param material_flow table
---@return table<string, boolean>
function roots.exact_component_materials(material_flow)
  local exact = {}
  for _, flow in ipairs((material_flow and material_flow.flows) or {}) do
    local material = flow.material
    local input_name = flow.input and flow.input.name
    if material and input_name and material == input_name and has_exact_recycle_target(flow, material) then
      exact[material] = true
    end
  end
  return exact
end

---Builds resource-result root aliases from material-flow resource evidence.
---@param material_flow table
---@return table<string, string>
function roots.resource_root_aliases(material_flow)
  local aliases = {}
  for material, resources in pairs((material_flow and material_flow.resources_by_material) or {}) do
    for _, resource in ipairs(resources or {}) do
      local result = resource.result or {}
      if (result.type or "item") == "item" and result.name then
        aliases[result.name] = material
      end
    end
  end
  return aliases
end

---Builds direct solid material aliases from enabled materials and registered prototype aliases.
---@param materials ISdata_table_materials|nil
---@param exact_components table<string, boolean>|nil
---@param include_exact_components boolean|nil
---@return table<string, string>
function roots.material_root_aliases(materials, exact_components, include_exact_components)
  local aliases = {}
  if not materials then return aliases end
  local exact_scrap = materials.solid_exact_scrap or {}

  for item_name, material in pairs(materials.solid_aliases or {}) do
    if (include_exact_components or not ((exact_components and exact_components[material]) or exact_scrap[material]))
        and data.raw.item and data.raw.item[item_name] then
      aliases[item_name] = material
    end
  end

  local suffixes = materials.solid_suffixes or {}
  local prefixes = materials.solid_prefixes or {}
  for _, material in ipairs(materials.solid or {}) do
    local candidates = {
      material .. "-plate",
      material .. "-alloy",
      material .. "-ingot",
      material .. "-bar",
      material .. "-ore",
      material,
    }
    for _, prefix in ipairs(prefixes) do
      table.insert(candidates, prefix .. material)
    end
    for _, suffix in ipairs(suffixes) do
      table.insert(candidates, material .. suffix)
    end

    for _, item_name in ipairs(candidates) do
      if data.raw.item and data.raw.item[item_name]
          and material_resolver.resolve_solid(item_name, materials, true) == material then
        aliases[item_name] = material
      end
    end
  end

  return aliases
end

---Builds stable material root aliases while allowing exact components to resolve deeper.
---@param material_flow table
---@param exact_components table<string, boolean>
---@param include_exact_components boolean|nil
---@return table<string, string>
function roots.stable_material_root_aliases(material_flow, exact_components, include_exact_components)
  local aliases = roots.resource_root_aliases(material_flow)

  for _, flow in ipairs((material_flow and material_flow.flows) or {}) do
    local material = flow.material
    local input_name = flow.input and flow.input.name
    if material and input_name and (include_exact_components or not exact_components[material]) then
      aliases[input_name] = material
    end
  end

  return aliases
end

---Builds root aliases for the requested passive ancestry policy.
---@param material_flow table
---@param policy string
---@param materials ISdata_table_materials|nil
---@return table<string, string>, table<string, boolean>
function roots.build(material_flow, policy, materials)
  local exact_components = roots.exact_component_materials(material_flow)
  if policy == "resources" then
    return roots.resource_root_aliases(material_flow), exact_components
  end
  local aliases = roots.stable_material_root_aliases(material_flow, exact_components, policy == "stable")
  for item_name, material in pairs(roots.material_root_aliases(materials, exact_components, policy == "stable") or {}) do
    aliases[item_name] = aliases[item_name] or material
  end
  return aliases, exact_components
end

return roots
