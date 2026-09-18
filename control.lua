local report_name = "ingredient-scrap-test-report"
local report_path = "Ingredient_Scrap/test-report.json"
local runtime_report_path = "Ingredient_Scrap/runtime-report.json"
local data_table_dump_name = "ingredient-scrap-data-table-dump"
local material_flow_name = "ingredient-scrap-material-flow"
local material_flow_path = "Ingredient_Scrap/material-flow.json"
local production_flow_name = "ingredient-scrap-production-flow"
local production_flow_path = "Ingredient_Scrap/production-flow.json"
local technology_flow_name = "ingredient-scrap-technology-flow"
local technology_flow_path = "Ingredient_Scrap/technology-flow.json"
local ancestry_runtime_name = "ingredient-scrap-ancestry-runtime"
local ancestry_runtime_path = "Ingredient_Scrap/ancestry-runtime.json"
local recipe_forms_name = "ingredient-scrap-recipe-forms"
local recipe_forms_path = "Ingredient_Scrap/recipe-forms.json"
local fish_recycle_recipe_name = "yis-recycle-raw-fish"
local fish_achievement_name = "yis-fish-arent-real"
local fish_achievement_recipe_names = {
  ["raw-fish-recycling"] = true,
  [fish_recycle_recipe_name] = true,
}

--#region debug
---Returns true when runtime debug helpers should be active.
---@return boolean
local function is_debug_runtime_enabled()
  local debug_setting = settings and settings.startup and settings.startup["yis-IS_DEBUG"]
  return debug_setting and debug_setting.value == true
end

---Returns the stack size for an item, falling back to 1 for unknown prototypes.
---@param item_name string
---@return integer
local function item_stack_size(item_name)
  local item = prototypes and prototypes.item and prototypes.item[item_name]
  return item and item.stack_size or 1
end

---Adds an item stack request, merging duplicate item names.
---@param requests table<string, integer>
---@param item_name string
---@param count integer?
local function add_inventory_request(requests, item_name, count)
  if not (prototypes and prototypes.item and prototypes.item[item_name]) then return end
  requests[item_name] = (requests[item_name] or 0) + (count or item_stack_size(item_name))
end

---Adds one stack of every item whose name matches the pattern.
---@param requests table<string, integer>
---@param pattern string
local function add_matching_item_stacks(requests, pattern)
  if not (prototypes and prototypes.item) then return end
  for item_name, _ in pairs(prototypes.item) do
    if item_name:match(pattern) then
      add_inventory_request(requests, item_name)
    end
  end
end

---Adds one stack of every item that places an assembling machine or furnace.
---@param requests table<string, integer>
local function add_machine_item_stacks(requests)
  if not (prototypes and prototypes.item) then return end
  for item_name, item in pairs(prototypes.item) do
    local place_result = item.place_result
    if place_result and (place_result.type == "assembling-machine" or place_result.type == "furnace") then
      add_inventory_request(requests, item_name)
    end
  end
end

---Builds the shared debug inventory kit for manual prototype and achievement testing.
---@return table<string, integer>
local function build_debug_inventory_requests()
  local requests = {}
  add_matching_item_stacks(requests, "^yis%-.+%-scrap$")
  add_matching_item_stacks(requests, "%-ore$")
  add_machine_item_stacks(requests)
  add_inventory_request(requests, "raw-fish", 10)
  add_inventory_request(requests, "coal")
  add_inventory_request(requests, "solar-panel", 20)
  add_inventory_request(requests, "small-electric-pole", 20)
  add_inventory_request(requests, "personal-roboport-mk2-equipment")
  add_inventory_request(requests, "battery-mk2-equipment")
  add_inventory_request(requests, "fission-reactor-equipment")
  add_inventory_request(requests, "power-armor-mk2")
  add_inventory_request(requests, "infinity-chest")
  add_inventory_request(requests, "construction-robot", 50)
  return requests
end

---Inserts the requested debug items into the player's inventory.
---@param player LuaPlayer
---@param requests table<string, integer>
---@return integer inserted_total
local function insert_debug_inventory(player, requests)
  local inserted_total = 0
  local missed = {}

  for item_name, count in pairs(requests) do
    local inserted = player.insert({ name = item_name, count = count })
    inserted_total = inserted_total + inserted
    if inserted < count then
      table.insert(missed, item_name .. " (" .. inserted .. "/" .. count .. ")")
    end
  end

  player.print("[IS-DEBUG] Inserted " .. inserted_total .. " items.")
  if #missed > 0 then
    player.print("[IS-DEBUG] Inventory full or blocked for: " .. table.concat(missed, ", "))
  end
  return inserted_total
end

---Registers the debug inventory command for manual prototype testing.
local function register_debug_inventory_command()
  commands.add_command("is-debug-inventory", "Insert Ingredient Scrap debug stacks for manual testing.", function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if not player then return end

    insert_debug_inventory(player, build_debug_inventory_requests())
  end)
end

register_debug_inventory_command()

script.on_event(defines.events.on_player_created, function(event)
  if not is_debug_runtime_enabled() then return end
  storage.yis_pending_debug_inventory = storage.yis_pending_debug_inventory or {}
  storage.yis_pending_debug_inventory[event.player_index] = 60
end)
--#endregion

---Returns true for Ingredient Scrap recycling recipe categories.
---@param category string?
---@return boolean
local function is_recycle_category(category)
  return category == "yis-recycle-to-item"
    or category == "yis-recycle-to-fluid"
    or category == "yis-recycle-chemical"
    or category == "recycling"
end

---Returns true when a runtime recipe prototype has an Ingredient Scrap recycling category.
---@param recipe LuaRecipe|nil
---@return boolean
local function is_runtime_recycle_recipe(recipe)
  if not recipe or not recipe.valid or not recipe.prototype then return false end
  for _, category in ipairs(recipe.prototype.categories or {}) do
    if is_recycle_category(category) then return true end
  end
  return false
end

---Returns true for Ingredient Scrap generated recycling recipe names.
---@param recipe_name string
---@return boolean
local function is_ingredient_scrap_recycle_recipe(recipe_name)
  return type(recipe_name) == "string" and recipe_name:match("^yis%-recycle%-") ~= nil
end

---Returns true if a researched technology unlocks the recipe for this force.
---@param force LuaForce
---@param recipe_name string
---@return boolean
local function is_recipe_unlocked_by_researched_technology(force, recipe_name)
  for _, technology in pairs(force.technologies or {}) do
    if technology.valid and technology.researched then
      for _, effect in pairs(technology.prototype.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
          return true
        end
      end
    end
  end
  return false
end

---Keeps generated recycling technologies enabled and syncs recipe state in existing saves.
local function sync_recycle_runtime_state()
  if not game or not game.forces then return end

  for _, force in pairs(game.forces) do
    for recipe_name, recipe in pairs(force.recipes or {}) do
      if is_ingredient_scrap_recycle_recipe(recipe_name) and is_runtime_recycle_recipe(recipe) then
        local should_be_enabled = (
          recipe_name == fish_recycle_recipe_name
          or is_recipe_unlocked_by_researched_technology(force, recipe_name)
        )
        if recipe.enabled ~= should_be_enabled then
          log("[IS] Synced recycle recipe state for existing save: " .. recipe_name .. " -> " ..
            tostring(should_be_enabled))
        end
        recipe.enabled = should_be_enabled
      end
    end

    for technology_name, technology in pairs(force.technologies or {}) do
      if technology.valid then
        local enables_recycle_recipe = false
        for _, effect in pairs(technology.prototype.effects or {}) do
          local recipe = effect.type == "unlock-recipe" and force.recipes[effect.recipe]
          if is_runtime_recycle_recipe(recipe) then
            enables_recycle_recipe = true
            break
          end
        end

        if enables_recycle_recipe then
          if not technology.enabled then
            log("[IS] Enabled recycle technology for existing save: " .. technology_name)
          end
          technology.enabled = true
        end
      end
    end
  end
end

---Unlocks the hidden fish achievement once any recycler processes the hidden fish recipe.
local function unlock_fish_recycling_achievement()
  if not (game and game.surfaces and game.players) then return end

  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ name = "recycler" })) do
      if entity.valid and entity.get_recipe then
        local recipe = entity.get_recipe()
        if recipe and recipe.valid and fish_achievement_recipe_names[recipe.name] then
          for _, player in pairs(game.players) do
            if player.valid and player.connected then
              player.unlock_achievement(fish_achievement_name)
            end
          end
          return
        end
      end
    end
  end
end

---Retries the debug start inventory until Freeplay exposes the character inventory.
local function flush_pending_debug_inventory()
  if not is_debug_runtime_enabled() then return end
  local pending = storage.yis_pending_debug_inventory
  if not pending then return end

  for player_index, tries_left in pairs(pending) do
    local player = game.get_player(player_index)
    if not player or not player.valid then
      pending[player_index] = nil
    elseif tries_left <= 0 then
      player.print("[IS-DEBUG] Could not insert debug inventory after waiting for the player inventory.")
      pending[player_index] = nil
    elseif player.character then
      local inserted = insert_debug_inventory(player, build_debug_inventory_requests())
      if inserted > 0 then
        pending[player_index] = nil
      else
        pending[player_index] = tries_left - 1
      end
    else
      pending[player_index] = tries_left - 1
    end
  end
end

local function on_periodic_runtime_tick()
  flush_pending_debug_inventory()
  unlock_fish_recycling_achievement()
end

---Writes debug report and data table dumps from mod-data into script-output.
local function write_debug_files()
  if not prototypes or not prototypes.mod_data then return end

  local report = prototypes.mod_data[report_name]
  if report and report.data then
    helpers.write_file(report_path, helpers.table_to_json(report.data), false)
    log("[IS-TEST] Wrote " .. report_path)

    local force = game and game.forces and game.forces.player
    if force and force.recipes then
      local function recipe_state(recipe_name)
        local recipe = force.recipes[recipe_name]
        return recipe and {
          categories = recipe.prototype and recipe.prototype.categories,
          enabled = recipe.enabled,
          hidden = recipe.prototype and recipe.prototype.hidden,
          valid = recipe.valid,
        } or nil
      end

      local function technology_state(technology_name)
        local technology = force.technologies[technology_name]
        return technology and {
          enabled = technology.enabled,
          researched = technology.researched,
          valid = technology.valid,
          visible_when_disabled = technology.visible_when_disabled,
        } or nil
      end

      helpers.write_file(runtime_report_path, helpers.table_to_json({
        recipes = {
          ["yis-recycle-iron-scrap"] = recipe_state("yis-recycle-iron-scrap"),
          ["yis-recycle-iron-scrap-to-fluid"] = recipe_state("yis-recycle-iron-scrap-to-fluid"),
          ["yis-recycle-testium-scrap"] = recipe_state("yis-recycle-testium-scrap"),
        },
        technologies = {
          ["yis-recycle-iron-scrap"] = technology_state("yis-recycle-iron-scrap"),
          ["yis-recycle-testium-scrap"] = technology_state("yis-recycle-testium-scrap"),
        }
      }), false)
      log("[IS-TEST] Wrote " .. runtime_report_path)
    end
  end

  local dump = prototypes.mod_data[data_table_dump_name]
  if dump and dump.data and dump.data.filename and dump.data.contents then
    helpers.write_file(dump.data.filename, dump.data.contents, false)
    log("[IS-TEST] Wrote " .. dump.data.filename)
  end

  local material_flow = prototypes.mod_data[material_flow_name]
  if material_flow and material_flow.data then
    helpers.write_file(material_flow_path, helpers.table_to_json(material_flow.data), false)
    log("[IS-TEST] Wrote " .. material_flow_path)
  end

  local production_flow = prototypes.mod_data[production_flow_name]
  if production_flow and production_flow.data then
    helpers.write_file(production_flow_path, helpers.table_to_json(production_flow.data), false)
    log("[IS-TEST] Wrote " .. production_flow_path)
  end

  local technology_flow = prototypes.mod_data[technology_flow_name]
  if technology_flow and technology_flow.data then
    helpers.write_file(technology_flow_path, helpers.table_to_json(technology_flow.data), false)
    log("[IS-TEST] Wrote " .. technology_flow_path)
  end

  local ancestry_runtime = prototypes.mod_data[ancestry_runtime_name]
  if ancestry_runtime and ancestry_runtime.data then
    helpers.write_file(ancestry_runtime_path, helpers.table_to_json(ancestry_runtime.data), false)
    log("[IS-TEST] Wrote " .. ancestry_runtime_path)
  end

  local recipe_forms = prototypes.mod_data[recipe_forms_name]
  if recipe_forms and recipe_forms.data then
    helpers.write_file(recipe_forms_path, helpers.table_to_json(recipe_forms.data), false)
    log("[IS-TEST] Wrote " .. recipe_forms_path)
  end
end

script.on_init(function()
  sync_recycle_runtime_state()
  write_debug_files()
end)

script.on_configuration_changed(function()
  sync_recycle_runtime_state()
  write_debug_files()
end)

script.on_event(defines.events.on_tick, function()
  sync_recycle_runtime_state()
  script.on_event(defines.events.on_tick, nil)
end)

script.on_nth_tick(120, on_periodic_runtime_tick)
