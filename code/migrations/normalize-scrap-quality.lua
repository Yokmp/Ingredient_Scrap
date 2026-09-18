local migration = {}

function migration.run()
  local scraps = {}
  for name in pairs(prototypes.item) do
    if name:match("^yis%-.+%-scrap$") then scraps[name] = true end
  end
  local changed, stacks = 0, 0

  local function normalize(stack)
    if not (stack and stack.valid and stack.valid_for_read
        and scraps[stack.name] and stack.quality.name ~= "normal") then return end
    local replacement = { name = stack.name, count = stack.count, quality = "normal" }
    -- Fail the load rather than silently delete or partially convert a stack.
    assert(stack.set_stack(replacement), "[IS migration] Cannot normalize " .. replacement.name)
    assert(stack.valid_for_read and stack.name == replacement.name
      and stack.count == replacement.count and stack.quality.name == "normal",
      "[IS migration] Scrap stack was not preserved")
    changed = changed + replacement.count
    stacks = stacks + 1
  end

  local function inventory(inv)
    if not (inv and inv.valid) then return end
    local supports_filters = inv.supports_filters()
    for slot = 1, #inv do
      if supports_filters then
        local filter = inv.get_filter(slot)
        if filter and scraps[filter.name] and filter.quality and filter.quality ~= "normal" then
          filter.quality = "normal"
          filter.comparator = "="
          assert(inv.set_filter(slot, filter), "[IS migration] Cannot normalize scrap inventory filter")
        end
      end
      normalize(inv[slot])
    end
  end

  local function inventories(owner)
    for index = 1, owner.get_max_inventory_index() do inventory(owner.get_inventory(index)) end
  end

  for _, player in pairs(game.players) do
    inventories(player)
    normalize(player.cursor_stack)
  end
  for _, inventories_by_mod in pairs(game.get_script_inventories()) do
    for _, inv in pairs(inventories_by_mod) do inventory(inv) end
  end
  local belt_types = {
    ["transport-belt"] = true, ["underground-belt"] = true,
    splitter = true, loader = true, ["loader-1x1"] = true,
    ["linked-belt"] = true,
  }
  for _, surface in pairs(game.surfaces) do
    -- Visit generated chunks only; do not force generation or hold the whole map.
    for chunk in surface.get_chunks() do
      local area = {{chunk.x * 32, chunk.y * 32}, {chunk.x * 32 + 32, chunk.y * 32 + 32}}
      for _, entity in pairs(surface.find_entities(area)) do
        inventories(entity)
        if entity.type == "inserter" then normalize(entity.held_stack) end
        if entity.type == "item-entity" then normalize(entity.stack) end
        if belt_types[entity.type] then
          for index = 1, entity.get_max_transport_line_index() do
            local line = entity.get_transport_line(index)
            if line.valid then
              for slot = 1, #line do normalize(line[slot]) end
            end
          end
        end
      end
    end
  end
  log("[IS migration] Normalized " .. changed .. " scrap items in " .. stacks .. " stacks.")
  return { items = changed, stacks = stacks }
end

return migration
