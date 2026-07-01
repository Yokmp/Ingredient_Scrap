local report_name = "ingredient-scrap-test-report"
local report_path = "Ingredient_Scrap/test-report.json"
local runtime_report_path = "Ingredient_Scrap/runtime-report.json"
local data_table_dump_name = "ingredient-scrap-data-table-dump"
local material_flow_name = "ingredient-scrap-material-flow"
local material_flow_path = "Ingredient_Scrap/material-flow.json"
local production_flow_name = "ingredient-scrap-production-flow"
local production_flow_path = "Ingredient_Scrap/production-flow.json"

---Returns true for Ingredient Scrap recycling recipe categories.
---@param category string?
---@return boolean
local function is_recycle_category(category)
  return category == "yis-recycle-to-item" or category == "yis-recycle-to-fluid"
end

---Keeps generated recycling recipes and technologies usable in existing saves after prototype changes.
local function sync_recycle_runtime_state()
  if not game or not game.forces then return end

  for _, force in pairs(game.forces) do
    for recipe_name, recipe in pairs(force.recipes or {}) do
      if recipe.valid and is_recycle_category(recipe.category) and not recipe.hidden then
        if not recipe.enabled then
          log("[IS] Enabled recycle recipe for existing save: " .. recipe_name)
        end
        recipe.enabled = true
      end
    end

    for technology_name, technology in pairs(force.technologies or {}) do
      if technology.valid then
        local enables_recycle_recipe = false
        for _, effect in pairs(technology.prototype.effects or {}) do
          local recipe = effect.type == "unlock-recipe" and force.recipes[effect.recipe]
          if recipe and recipe.valid and is_recycle_category(recipe.category) then
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
          category = recipe.category,
          enabled = recipe.enabled,
          hidden = recipe.hidden,
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
