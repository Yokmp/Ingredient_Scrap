


---Fills data_table.materials.solid and data_table.materials.fluid from resources, items, fluids, and whitelists.
function yokmods.ingredient_scrap.collect_materials()
  local materials = yokmods.ingredient_scrap.data_table.materials
  local solid = yokmods.ingredient_scrap.data_table.materials.solid
  local fluid = yokmods.ingredient_scrap.data_table.materials.fluid
  local seen_solid = {}
  local seen_fluid = {}

  ---Adds a fluid scrap material when it has a matching solid item source.
  ---@param scrap_type string
  ---@param fluid_name string
  local function add_fluid_material(scrap_type, fluid_name)
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

  -- ── 1) data.raw.resource ──────────────────────────────────
  for _, resource in pairs(data.raw.resource) do
    if resource.minable then
      if resource.category ~= "basic-fluid" and resource.minable.result then        -- solid
        local prefix = resource.minable.result:match("^(.-)%-") or resource.minable.result
        if not type_blacklist[prefix] and not seen_solid[prefix] then
          seen_solid[prefix] = true
          table.insert(solid, prefix)
          log("[IS-MAT-SOLID] inserted into solid: " .. prefix .. " (total: " .. #solid .. ")")
        end

      elseif ISsettings.fluids and resource.category == "basic-fluid" and resource.minable.results then   -- fluid
        local first = resource.minable.results[1]
        if first and first.name then
          local prefix = first.name:match("^(.-)%-") or first.name
          if not type_blacklist[prefix] and not seen_fluid[prefix] then
            seen_fluid[prefix] = true
            table.insert(fluid, prefix)
            log("[IS-MAT-FLUID] inserted into fluid: " .. prefix .. " (total: " .. #fluid .. ")")
          end
        end
      end
    end
  end

  -- ── 2) Alloys from data.raw.item via suffixes ─────────────
  for name, _ in pairs(data.raw.item) do
    for _, suffix in ipairs(materials.solid_suffixes) do
      if name:sub(-#suffix) == suffix then
        local prefix = name:sub(1, #name - #suffix)
        if IS_DEBUG then log("[IS-MAT] found: " .. name .. " -> prefix: " .. prefix .. " blacklisted: "
        .. tostring(type_blacklist[prefix] or false) .. " seen: " .. tostring(seen_solid[prefix] or false)) end
        if not type_blacklist[prefix] and not seen_solid[prefix] then
          seen_solid[prefix] = true
          table.insert(solid, prefix)
          log("[IS-MAT-SOLID] inserted into solid: " .. prefix .. " (total: " .. #solid .. ")")
        end
        break  -- suffix gefunden, nächstes item
      end
    end
  end

  -- ── 3) Whitelist (Alloys/Materials without -plate/-ingot) ────────────
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

  -- ── 4) Fluid metals via prefixes ─────────────────────────
  if ISsettings.fluids then
    for name, _ in pairs(data.raw.fluid) do
      local matched = false
      for _, prefix in ipairs(materials.fluid_prefixes) do
        if name:sub(1, #prefix) == prefix then
          if IS_DEBUG then log("[IS-MAT] found: " .. name .. " -> prefix: " .. prefix .. " blacklisted: " .. tostring(type_blacklist[prefix] or false) .. " seen: " .. tostring(seen_fluid[prefix] or false)) end
          add_fluid_material(name:sub(#prefix + 1), name)
          matched = true
          break
        end
      end
      if not matched then
        for _, suffix in ipairs(materials.fluid_suffixes) do
          if name:sub(-#suffix) == suffix then
            add_fluid_material(name:sub(1, #name - #suffix), name)
            table.insert(fluid, suffix)
            log("[IS-MAT-FLUID] inserted into fluid: " .. name .. " (total: " .. #fluid .. ")")
            break
          end
        end
      end
    end
  end
end
