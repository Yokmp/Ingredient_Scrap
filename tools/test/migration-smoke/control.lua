local migration = require("__Ingredient_Scrap__/code/migrations/normalize-scrap-quality")

script.on_init(function()
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({0, 0}, 1)
  surface.force_generate_chunk_requests()
  local scrap = "yis-iron-scrap"
  assert(prototypes.item[scrap])
  local function entity(name, x)
    return assert(surface.create_entity{name = name, position = {x, 0}, force = "player"})
  end
  local chest = entity("steel-chest", 0).get_inventory(defines.inventory.chest)
  chest[1].set_stack{name = scrap, count = 17, quality = "legendary"}
  chest[2].set_stack{name = "iron-plate", count = 9, quality = "legendary"}
  local inserter = entity("inserter", 2)
  assert(inserter.held_stack.set_stack{name = scrap, count = 1, quality = "rare"})
  local ground = assert(surface.create_entity{name = "item-on-ground", position = {4, 0},
    stack = {name = scrap, count = 7, quality = "epic"}})
  local belt = entity("transport-belt", 6).get_transport_line(1)
  assert(belt.insert_at(.5, {name = scrap, count = 1, quality = "legendary"}))
  local assembler = entity("assembling-machine-3", 10)
  assembler.set_recipe("iron-gear-wheel", "uncommon")
  local machine = assembler.get_inventory(defines.inventory.crafter_output)
  assert(machine[2].set_stack{name = scrap, count = 11, quality = "uncommon"})
  local isolated = game.create_inventory(2)
  isolated[1].set_stack{name = scrap, count = 13, quality = "legendary"}
  local character = entity("character", 15)
  local player_inventory = character.get_main_inventory()
  player_inventory.clear()
  assert(player_inventory.set_filter(1, {name = scrap, quality = "legendary", comparator = "="}))
  assert(player_inventory[1].set_stack{name = scrap, count = 5, quality = "legendary"})
  local belt_position = belt.get_detailed_contents()[1].position
  local transport_checks = {}
  local function seed_lines(owner)
    for index = 1, owner.get_max_transport_line_index() do
      local line = owner.get_transport_line(index)
      local duplicate = false
      for _, check in ipairs(transport_checks) do
        if line.valid and line.line_equals(check.line) then duplicate = true end
      end
      if line.valid and line.line_length > 0 and not duplicate then
        local position = math.min(.125, line.line_length / 2)
        assert(line.insert_at(position, {name = scrap, count = 1, quality = "rare"}),
          owner.name .. " line " .. index .. " seed failed")
        local contents = line.get_detailed_contents()
        assert(#contents == 1)
        transport_checks[#transport_checks + 1] = {
          line = line, position = contents[1].position, label = owner.name .. ":" .. index,
        }
      end
    end
  end
  for tier, prefix in ipairs({"", "fast-", "express-", "turbo-"}) do
    local x = tier * 12
    seed_lines(assert(surface.create_entity{name = prefix .. "splitter", position = {x, 12},
      direction = defines.direction.east, force = "player"}))
    local input = assert(surface.create_entity{name = prefix .. "underground-belt", position = {x, 20},
      direction = defines.direction.east, type = "input", force = "player"})
    local output = assert(surface.create_entity{name = prefix .. "underground-belt", position = {x + 4, 20},
      direction = defines.direction.east, type = "output", force = "player"})
    seed_lines(input)
    seed_lines(output)
  end
  local other = game.create_surface("is-migration-second-surface", {width = 64, height = 64})
  other.request_to_generate_chunks({0, 0}, 1)
  other.force_generate_chunk_requests()
  local other_inventory = assert(other.create_entity{name = "steel-chest", position = {0, 0},
    force = "player"}).get_inventory(defines.inventory.chest)
  assert(other_inventory[1].set_stack{name = scrap, count = 23, quality = "epic"})
  assert(other_inventory[2].set_stack{name = "yis-mixed-scrap", count = 19, quality = "rare"})
  local result = migration.run()
  for label, stack in pairs({chest = chest[1], hand = inserter.held_stack, ground = ground.stack,
      belt = belt[1], machine = machine[2], isolated = isolated[1]}) do
    log(label .. ": " .. (stack.valid_for_read and (stack.name .. " " .. stack.count .. " " .. stack.quality.name) or "empty"))
  end
  assert(result.items == 97 + #transport_checks, "Wrong migrated count: " .. result.items)
  for _, check in ipairs(transport_checks) do
    local contents = check.line.get_detailed_contents()
    assert(#contents == 1 and contents[1].stack.count == 1
      and contents[1].stack.quality.name == "normal" and contents[1].position == check.position,
      "Transport migration failed: " .. check.label)
    log("IS-MIGRATION-TRANSPORT PASS " .. check.label)
  end
  assert(other_inventory[1].count == 23 and other_inventory[1].quality.name == "normal")
  assert(other_inventory[2].count == 19 and other_inventory[2].quality.name == "normal")
  log("IS-MIGRATION-SURFACE PASS")
  for _, stack in pairs({chest[1], inserter.held_stack, ground.stack, belt[1], machine[2], isolated[1]}) do
    assert(stack.valid_for_read and stack.quality.name == "normal")
  end
  assert(chest[2].quality.name == "legendary" and chest[2].count == 9)
  assert(player_inventory[1].count == 5 and player_inventory[1].quality.name == "normal")
  assert(player_inventory.get_filter(1).quality == "normal")
  assert(belt.get_detailed_contents()[1].position == belt_position)
  assert(migration.run().items == 0, "Migration is not idempotent")
  isolated.destroy()
  log("IS-MIGRATION-SMOKE PASS")
  -- Leave legacy stock for the separate load-time migration test.
  assert(chest[1].set_stack{name = scrap, count = 17, quality = "legendary"})
  storage.migration_test_chest = chest
  storage.migration_test_lines = transport_checks
  storage.migration_test_other_inventory = other_inventory
  for _, check in ipairs(transport_checks) do
    assert(check.line[1].set_stack{name = scrap, count = 1, quality = "rare"})
  end
  assert(other_inventory[1].set_stack{name = scrap, count = 23, quality = "epic"})
  assert(other_inventory[2].set_stack{name = "yis-mixed-scrap", count = 19, quality = "rare"})
end)
