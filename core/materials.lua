


---Befüllt data_table.materials.solid und .fluid automatisch
function yokmods.ingredient_scrap.collect_materials()
  local solid = yokmods.ingredient_scrap.data_table.materials.solid
  local fluid = yokmods.ingredient_scrap.data_table.materials.fluid
  local seen  = {}  -- purge the unclean and duplicates


  -- ── 1) data.raw.resource ──────────────────────────────────
  for _, resource in pairs(data.raw.resource) do
    if resource.minable then
      if resource.category ~= "basic-fluid" and resource.minable.result then        -- solid
        local prefix = resource.minable.result:match("^(.-)%-") or resource.minable.result
        if not type_blacklist[prefix] and not seen[prefix] then
          seen[prefix] = true
          table.insert(solid, prefix)
        end

      elseif resource.category == "basic-fluid" and resource.minable.results then   -- fluid
        local first = resource.minable.results[1]
        if first and first.name then
          local prefix = first.name:match("^(.-)%-") or first.name
          if not type_blacklist[prefix] and not seen[prefix] then
            seen[prefix] = true
            table.insert(fluid, prefix)
          end
        end
      end
    end
  end

  -- ── 2) Alloys from data.raw.item (-plate / -ingot) ───────
  for name, _ in pairs(data.raw.item) do
    if name:match("%-plate$") or name:match("%-ingot$") then
      local prefix = name:match("^(.-)%-") or name
      if not type_blacklist[prefix] and not seen[prefix] then
        seen[prefix] = true
        table.insert(solid, prefix)
      end
    end
  end

  -- ── 3) Whitelist (Alloys/Materials without -plate/-ingot) ────────────
  for _, prefix in ipairs(scrap_whitelist_solid) do
    if not type_blacklist[prefix] and not seen[prefix] then
      seen[prefix] = true
      table.insert(solid, prefix)
    end
  end
end