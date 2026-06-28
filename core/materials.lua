


---Fills data_table.materials.solid and data_table.materials.fluid from resources, items, fluids, and whitelists.
function yokmods.ingredient_scrap.collect_materials()
  local solid = yokmods.ingredient_scrap.data_table.materials.solid
  local fluid = yokmods.ingredient_scrap.data_table.materials.fluid
  local seen_solid = {}
  local seen_fluid = {}


  -- ── 1) data.raw.resource ──────────────────────────────────
  for _, resource in pairs(data.raw.resource) do
    if resource.minable then
      if resource.category ~= "basic-fluid" and resource.minable.result then        -- solid
        local prefix = resource.minable.result:match("^(.-)%-") or resource.minable.result
        if not type_blacklist[prefix] and not seen_solid[prefix] then
          seen_solid[prefix] = true
          table.insert(solid, prefix)
        end

      elseif ISsettings.fluids and resource.category == "basic-fluid" and resource.minable.results then   -- fluid
        local first = resource.minable.results[1]
        if first and first.name then
          local prefix = first.name:match("^(.-)%-") or first.name
          if not type_blacklist[prefix] and not seen_fluid[prefix] then
            seen_fluid[prefix] = true
            table.insert(fluid, prefix)
          end
        end
      end
    end
  end

  -- ── 2) Alloys from data.raw.item via suffixes ─────────────
  for name, _ in pairs(data.raw.item) do
    for _, suffix in ipairs(yokmods.ingredient_scrap.data_table.materials.suffixes) do
      if name:sub(-#suffix) == suffix then
        local prefix = name:sub(1, #name - #suffix)
        if IS_DEBUG then log("[IS-MAT] found: " .. name .. " -> prefix: " .. prefix .. " blacklisted: " .. tostring(type_blacklist[prefix] or false) .. " seen: " .. tostring(seen_solid[prefix] or false)) end
        if not type_blacklist[prefix] and not seen_solid[prefix] then
          seen_solid[prefix] = true
          table.insert(solid, prefix)
          log("[IS-MAT] inserted into solid: " .. prefix .. " (total: " .. #solid .. ")")
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
    end
  end
  for _, prefix in ipairs(scrap_whitelist_fluid) do
    if not type_blacklist[prefix] and not seen_fluid[prefix] then
      seen_fluid[prefix] = true
      table.insert(fluid, prefix)
    end
  end

  -- ── 4) Fluid metals via prefixes ─────────────────────────
  if ISsettings.fluids then
    for name, _ in pairs(data.raw.fluid) do
      for _, prefix in ipairs(yokmods.ingredient_scrap.data_table.materials.prefixes) do
        if name:sub(1, #prefix) == prefix then
          local scrap_type = name:sub(#prefix + 1)
          if IS_DEBUG then log("[IS-MAT-FLUID] found: " .. name .. " -> scrap_type: " .. scrap_type
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
          break
        end
      end
    end
  end
end
