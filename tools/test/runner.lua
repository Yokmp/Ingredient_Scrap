local expected = require("tools.test.expected")
local material_resolver = require("code.core.materials.resolver")
require("code.lib.category-overrides")
require("code.compat.vanilla-materials")
require("code.compat.mod-materials")
require("tools.test.material-overrides")
local material_overrides = require("code.lib.material-overrides")

local runner = {}

---Returns true when an array-like table contains the requested value.
local function array_contains(values, value)
  for _, item in ipairs(values or {}) do
    if item == value then return true end
  end
  return false
end

---Normalizes a recipe result to only the fields relevant for test comparisons.
local function result_signature(result)
  if not result then return nil end
  return {
    type = result.type,
    name = result.name,
    amount = result.amount,
    amount_min = result.amount_min,
    amount_max = result.amount_max,
    probability = result.probability,
  }
end

---Extracts and sorts all scrap results from a recipe prototype.
local function scrap_results(recipe)
  local out = {}
  for _, result in ipairs((recipe and recipe.results) or {}) do
    if result.name and result.name:match("%-scrap$") then
      table.insert(out, result_signature(result))
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

---Finds the first result entry with the requested name.
local function find_result(results, name)
  for _, result in ipairs(results or {}) do
    if result.name == name then return result end
  end
  return nil
end

---Finds a passive recipe-chain decision by mode and material.
local function find_recipe_chain_decision(recipe_chain_decisions, mode, material_name)
  local decisions = recipe_chain_decisions and recipe_chain_decisions.by_mode and
    recipe_chain_decisions.by_mode[mode] and recipe_chain_decisions.by_mode[mode].materials or {}
  for _, decision in ipairs(decisions) do
    if decision.material == material_name then return decision end
  end
  return nil
end

---Returns true when the structured log contains an entry matching the main fields.
local function log_contains(logs, level, step, name)
  for _, entry in ipairs(logs or {}) do
    if entry.level == level and entry.step == step and
        entry.details and entry.details.name == name then
      return true
    end
  end
  return false
end

---Returns true when recipe-shape evidence contains an entry with the requested relation.
local function shape_entries_contain(entries, prototype_type, name, relation)
  for _, entry in ipairs(entries or {}) do
    if entry.type == prototype_type and entry.name == name and entry.relation == relation then
      return true
    end
  end
  return false
end

---Returns true when recipe-shape evidence contains any entry with the requested relation.
local function shape_entries_contain_relation(entries, relation)
  for _, entry in ipairs(entries or {}) do
    if entry.relation == relation then return true end
  end
  return false
end

---Returns true when a collected insert has recipe results.
local function insert_has_results(data_table, recipe_name)
  local insert = data_table.inserts.recipes[recipe_name]
  return insert and insert.results and insert.results[1] ~= nil
end

---Returns true when any existing technology unlocks the requested recipe.
local function technology_unlocks_recipe(recipe_name)
  for _, tech in pairs(data.raw.technology or {}) do
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        return true
      end
    end
  end
  return false
end

---Returns the first recycling recipe that received a generated scrap result.
local function recycling_recipe_with_scrap_result()
  for recipe_name, recipe in pairs(data.raw.recipe or {}) do
    if recipe.category == "recycling" and scrap_results(recipe)[1] then
      return recipe_name
    end
  end
  return nil
end

---Returns true when a scrap result uses fixed amount fields only.
local function has_fixed_amount_shape(result)
  return result and result.amount ~= nil and result.amount_min == nil and result.amount_max == nil
end

---Returns true when a scrap result uses range amount fields only.
local function has_range_amount_shape(result)
  return result and result.amount == nil and result.amount_min ~= nil and result.amount_max ~= nil
end

---Returns true when a scrap result matches the current fixed/range setting shape.
local function has_expected_amount_shape(result)
  if ISsettings.fixed_amount then
    return has_fixed_amount_shape(result)
  end
  return has_range_amount_shape(result)
end

---Calculates the expected recycle recipe input amount from collected scrap results.
local function expected_recycle_input_amount(data_table, scrap_name)
  local total_expected = 0
  local count = 0
  for _, insert in pairs(data_table.inserts.recipes or {}) do
    for _, result in ipairs((insert and insert.results) or {}) do
      if result.name == scrap_name then
        local expected
        if ISsettings.fixed_amount then
          expected = (result.amount or 1) * (result.probability or 1)
        else
          local mid = ((result.amount_min or 1) + (result.amount_max or 1)) / 2
          expected = mid * (result.probability or 1)
        end
        total_expected = total_expected + expected
        count = count + 1
      end
    end
  end
  if count == 0 then return ISsettings.needed end
  local avg = total_expected / count
  if avg <= 0 then return ISsettings.needed end
  return math.max(math.floor(ISsettings.needed / avg), 1)
end

---Counts how often a crafting category appears on a machine prototype.
local function category_count(machine, category)
  local count = 0
  for _, crafting_category in ipairs((machine and machine.crafting_categories) or {}) do
    if crafting_category == category then count = count + 1 end
  end
  return count
end

---Returns true when a machine has any crafting category in the allowed set.
local function has_any_category(machine, allowed_categories)
  for _, crafting_category in ipairs((machine and machine.crafting_categories) or {}) do
    if allowed_categories[crafting_category] then return true end
  end
  return false
end

---Returns the names of all machines of a prototype type that can craft the category.
local function machine_names_with_category(prototype_type, category)
  local names = {}
  for name, machine in pairs(data.raw[prototype_type] or {}) do
    if category_count(machine, category) > 0 then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

---Returns true when a localised string contains a raw rich-text item/fluid tag.
local function localised_string_contains_rich_text(value)
  if type(value) == "string" then
    return value:find("%[item=", 1) ~= nil or value:find("%[fluid=", 1) ~= nil
  end
  if type(value) == "table" then
    for _, item in pairs(value) do
      if localised_string_contains_rich_text(item) then return true end
    end
  end
  return false
end

---Returns true when a nested localized string table contains a raw string fragment.
local function localised_string_contains(value, fragment)
  if type(value) == "string" then
    return value:find(fragment, 1, true) ~= nil
  end
  if type(value) == "table" then
    for _, item in pairs(value) do
      if localised_string_contains(item, fragment) then return true end
    end
  end
  return false
end

---Returns true when an icon layer list contains a specific icon path.
local function icon_layers_contain(icons, icon_path)
  for _, layer in ipairs(icons or {}) do
    if layer.icon == icon_path then return true end
  end
  return false
end

---Returns true when all icon layers use Factorio's icon_size field.
local function icon_layers_have_icon_size(icons)
  for _, layer in ipairs(icons or {}) do
    if layer.icon and (not layer.icon_size or layer.size ~= nil) then return false end
  end
  return true
end

---Compares an actual value against the expected subset recursively.
local function same_value(actual, expected_value)
  if type(expected_value) ~= "table" then return actual == expected_value end
  if type(actual) ~= "table" then return false end
  for key, value in pairs(expected_value) do
    if not same_value(actual[key], value) then return false end
  end
  return true
end

---Formats a Lua value for compact failure details.
local function inspect(value)
  return serpent.line(value, { comment = false, nocode = true })
end

---Runs the data-stage assertions and returns the JSON-friendly test report.
function runner.run()
  local report = {
    schema = "ingredient-scrap-test-report/v1",
    mod = "Ingredient_Scrap",
    factorio_version = helpers.game_version,
    profile = yokmods.ingredient_scrap.test_profile or "default",
    status = "pass",
    summary = { total = 0, passed = 0, failed = 0 },
    cases = {},
  }

  ---Adds one assertion result to the report summary and case list.
  local function add_case(id, name, ok, message, details)
    report.summary.total = report.summary.total + 1
    if ok then
      report.summary.passed = report.summary.passed + 1
    else
      report.summary.failed = report.summary.failed + 1
      report.status = "fail"
    end
    table.insert(report.cases, {
      id = id,
      name = name,
      status = ok and "pass" or "fail",
      message = message or (ok and "ok" or "failed"),
      details = details,
    })
  end

  for _, err in ipairs(yokmods.ingredient_scrap.preflight_errors or {}) do
    add_case("preflight." .. err.id, err.name, false, err.message, err.details)
  end

  local exp = expected.build()
  local data_table = yokmods.ingredient_scrap.data_table
  report.logs = data_table.debug and data_table.debug.logs or {}

  add_case("logs.table", "structured log table exists",
    data_table.debug and type(data_table.debug.logs) == "table")
  add_case("logs.function", "structured log function exists",
    type(yokmods.ingredient_scrap.is_log) == "function")
  add_case("settings.fluids-always-on", "fluid handling stays enabled even when the hidden startup setting or test profile disables it",
    ISsettings.fluids == true,
    nil,
    { startup_setting = ISsettings.fluid_setting, effective = ISsettings.fluids })
  add_case("names.scrap-prefix", "scrap item names receive the yis prefix only once",
    yokmods.ingredient_scrap.get_scrap_name("yis-testium") == "yis-testium-scrap" and
      yokmods.ingredient_scrap.get_scrap_name("yis-testium") == "yis-testium-scrap")
  add_case("names.recycle-prefix", "recycle recipe names receive the yis prefix",
    yokmods.ingredient_scrap.get_recycle_recipe_name("yis-testium") == "yis-recycle-testium-scrap" and
      yokmods.ingredient_scrap.get_recycle_recipe_name("yis-testium") == "yis-recycle-testium-scrap")
  local recipe_chain_analysis = data_table.debug and data_table.debug.recipe_chain_analysis
  add_case("analysis.recipe-chain.exists", "passive recipe-chain analysis dump exists",
    recipe_chain_analysis and recipe_chain_analysis.mode == "passive")
  add_case("analysis.recipe-chain.recipe-index", "recipe-chain analysis indexes producers and consumers",
    recipe_chain_analysis and recipe_chain_analysis.recipe_index and
      recipe_chain_analysis.recipe_index.producers.item["yis-testium-plate"] and
      recipe_chain_analysis.recipe_index.consumers.item["yis-testium-plate"])
  add_case("analysis.recipe-chain.name-patterns", "recipe-chain analysis records material infix name patterns",
    recipe_chain_analysis and recipe_chain_analysis.name_patterns and
      recipe_chain_analysis.name_patterns.ngrams["yis-rare-metal"] and
      recipe_chain_analysis.name_patterns.ngrams["yis-rare-metal"].positions.infix > 0,
    nil,
    recipe_chain_analysis and recipe_chain_analysis.name_patterns and
      recipe_chain_analysis.name_patterns.ngrams["yis-rare-metal"])
  add_case("analysis.recipe-chain.current-targets", "recipe-chain analysis records current resolver recycle targets",
    recipe_chain_analysis and recipe_chain_analysis.current and
      recipe_chain_analysis.current.recycle_targets and
      recipe_chain_analysis.current.recycle_targets["yis-testium"] and
      recipe_chain_analysis.current.recycle_targets["yis-testium"][1] and
      recipe_chain_analysis.current.recycle_targets["yis-testium"][1].result_name == "yis-testium-plate")
  add_case("analysis.recipe-chain.target-candidates", "recipe-chain analysis records passive recycle target candidates",
    recipe_chain_analysis and recipe_chain_analysis.target_candidates and
      recipe_chain_analysis.target_candidates["yis-testium"] and
      recipe_chain_analysis.target_candidates["yis-testium"].suggested and
      recipe_chain_analysis.target_candidates["yis-testium"].suggested.result_name == "yis-testium-plate" and
      recipe_chain_analysis.target_candidates["yis-testium"].suggested.recipe_flags and
      recipe_chain_analysis.target_candidates["yis-testium"].suggested.recipe_categories and
      recipe_chain_analysis.target_candidates["yis-testium"].suggested.recipe_shape_evidence and
      recipe_chain_analysis.target_candidates["yis-rare-metal"] and
      recipe_chain_analysis.target_candidates["yis-rare-metal"].suggested,
    nil,
    recipe_chain_analysis and recipe_chain_analysis.target_candidates and {
      yis_testium = recipe_chain_analysis.target_candidates["yis-testium"],
      yis_rare_metal = recipe_chain_analysis.target_candidates["yis-rare-metal"],
    })
  local testium_shape = recipe_chain_analysis and recipe_chain_analysis.target_candidates and
    recipe_chain_analysis.target_candidates["yis-testium"] and
    recipe_chain_analysis.target_candidates["yis-testium"].suggested and
    recipe_chain_analysis.target_candidates["yis-testium"].suggested.recipe_shape_evidence and
    recipe_chain_analysis.target_candidates["yis-testium"].suggested.recipe_shape_evidence[1]
  add_case("analysis.recipe-chain.recipe-shape-evidence", "recipe-chain analysis records normalized recipe shape evidence",
    testium_shape and
      testium_shape.recipe and
      testium_shape.target_result and
      testium_shape.target_result.name == "yis-testium-plate" and
      testium_shape.target_result.relation == "target" and
      shape_entries_contain_relation(testium_shape.ingredients, "material") and
      shape_entries_contain(testium_shape.results, "item", "yis-testium-plate", "target"),
    nil,
    testium_shape)
  add_case("analysis.recipe-chain.target-summary", "recipe-chain analysis summarizes passive recycle target candidates",
    recipe_chain_analysis and recipe_chain_analysis.target_candidate_summary and
      recipe_chain_analysis.target_candidate_summary.materials > 0 and
      recipe_chain_analysis.target_candidate_summary.with_current_target > 0)
  add_case("analysis.recipe-chain.target-modes", "recipe-chain analysis separates solid and fluid target candidates",
    recipe_chain_analysis and recipe_chain_analysis.target_candidates_by_mode and
      recipe_chain_analysis.target_candidates_by_mode.solid and
      recipe_chain_analysis.target_candidates_by_mode.fluid and
      recipe_chain_analysis.target_candidate_summary_by_mode and
      recipe_chain_analysis.target_candidate_summary_by_mode.solid and
      recipe_chain_analysis.target_candidate_summary_by_mode.fluid)
  add_case("analysis.recipe-chain.summary", "recipe-chain analysis exposes compact diagnostic summary",
    recipe_chain_analysis and recipe_chain_analysis.summary and
      recipe_chain_analysis.summary.recipe_index and
      recipe_chain_analysis.summary.recipe_index.recipes > 0 and
      recipe_chain_analysis.summary.materials_only_analysis_top and
      recipe_chain_analysis.summary.materials_only_analysis_top[1] and
      recipe_chain_analysis.summary.filters and
      recipe_chain_analysis.summary.filters.place_result and
      recipe_chain_analysis.summary.filters.place_result.top_patterns[1] and
      recipe_chain_analysis.summary.filters.combined_top_patterns[1] and
      recipe_chain_analysis.summary.target_differences_top_by_mode and
      recipe_chain_analysis.summary.target_differences_top_by_mode.solid)
  add_case("analysis.recipe-chain.recipe-artifact-filter", "recipe-chain analysis records solid recipe artifact filters",
    recipe_chain_analysis and recipe_chain_analysis.recipe_filters and
      recipe_chain_analysis.recipe_filters.solid_artifact and
      recipe_chain_analysis.recipe_filters.solid_artifact.patterns.barrel and
      recipe_chain_analysis.recipe_filters.solid_artifact.patterns.recycling and
      recipe_chain_analysis.recipe_filters.solid_artifact.patterns.recycling.count > 0)
  add_case("analysis.recipe-chain.material-candidates", "recipe-chain analysis records passive material candidates",
    recipe_chain_analysis and recipe_chain_analysis.material_candidates and
      recipe_chain_analysis.material_candidates["yis-rare-metal"] and
      recipe_chain_analysis.material_candidates["yis-rare-metal"].pattern and
      recipe_chain_analysis.material_candidates["yis-rare-metal"].pattern.positions.infix > 0)
  add_case("analysis.recipe-chain.place-result-filter", "recipe-chain analysis excludes place_result items from inferred materials",
    recipe_chain_analysis and recipe_chain_analysis.filters and
      recipe_chain_analysis.filters.place_result and
      recipe_chain_analysis.filters.place_result.patterns["assembling-machine"] and
      recipe_chain_analysis.filters.patterns["assembling-machine"] and
      not recipe_chain_analysis.material_candidates["assembling-machine"])
  add_case("analysis.recipe-chain.filtered-targets", "recipe-chain analysis excludes placeable item results from target candidates",
    recipe_chain_analysis and recipe_chain_analysis.target_candidates and
      recipe_chain_analysis.target_candidates["assembling-machine"] == nil)
  add_case("analysis.recipe-chain.place-as-tile-filter", "recipe-chain analysis records place_as_tile items as passive filters",
    recipe_chain_analysis and recipe_chain_analysis.filters and
      recipe_chain_analysis.filters.place_as_tile and
      recipe_chain_analysis.filters.place_as_tile.summary.items > 0 and
      recipe_chain_analysis.filters.place_as_tile.patterns["refined-concrete"])
  add_case("analysis.recipe-chain.place-as-equipment-filter", "recipe-chain analysis records place_as_equipment_result items as passive filters",
    recipe_chain_analysis and recipe_chain_analysis.filters and
      recipe_chain_analysis.filters.place_as_equipment_result and
      recipe_chain_analysis.filters.place_as_equipment_result.summary.items > 0 and
      recipe_chain_analysis.summary.filters.place_as_equipment_result and
      recipe_chain_analysis.summary.filters.place_as_equipment_result.top_patterns[1])
  add_case("analysis.recipe-chain.comparison", "recipe-chain analysis compares current and passive material candidates",
    recipe_chain_analysis and recipe_chain_analysis.comparison and
      array_contains(recipe_chain_analysis.comparison.materials_shared, "yis-testium") and
      array_contains(recipe_chain_analysis.comparison.materials_shared, "yis-rare-metal"),
    nil,
    recipe_chain_analysis and recipe_chain_analysis.comparison)
  local recipe_chain_decisions = data_table.debug and data_table.debug.recipe_chain_decisions
  add_case("analysis.recipe-chain.decisions", "recipe-chain decider records passive target decisions",
    recipe_chain_decisions and
      recipe_chain_decisions.mode == "passive" and
      recipe_chain_decisions.by_mode and
      recipe_chain_decisions.by_mode.solid and
      recipe_chain_decisions.by_mode.fluid and
      recipe_chain_decisions.staged_data_table and
      recipe_chain_decisions.staged_data_table.prototypes and
      recipe_chain_decisions.staged_data_table.prototypes.recipes and
      recipe_chain_decisions.summary and
      recipe_chain_decisions.summary.solid and
      recipe_chain_decisions.summary.solid.materials > 0 and
      recipe_chain_decisions.summary.solid.keep_current > 0)
  add_case("analysis.recipe-chain.decider-staged-data-table", "recipe-chain decider exposes a data-table-shaped passive staging table",
    recipe_chain_decisions and
      recipe_chain_decisions.staged_data_table and
      recipe_chain_decisions.staged_data_table.materials and
      recipe_chain_decisions.staged_data_table.materials.solid and
      recipe_chain_decisions.staged_data_table.materials.solid_prefixes and
      recipe_chain_decisions.staged_data_table.ingredients and
      recipe_chain_decisions.staged_data_table.ingredients.supplements and
      recipe_chain_decisions.staged_data_table.prototypes and
      recipe_chain_decisions.staged_data_table.prototypes.recipes and
      recipe_chain_decisions.staged_data_table.inserts and
      recipe_chain_decisions.staged_data_table.inserts.recipes and
      recipe_chain_decisions.staged_data_table.debug and
      recipe_chain_decisions.staged_data_table.debug.sources and
      recipe_chain_decisions.staged_data_table.debug.sources.recipes and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-iron-scrap"] and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-iron-scrap"].type == "recipe" and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-acid-barrel-scrap-to-fluid"] == nil and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-iron-scrap"].recipe_chain_decision == nil and
      recipe_chain_decisions.staged_data_table.debug.sources.recipes["yis-recycle-iron-scrap"] and
      recipe_chain_decisions.staged_data_table.debug.sources.recipes["yis-recycle-iron-scrap"].recipe_chain_decision and
      recipe_chain_decisions.staged_data_table.debug.sources.recipes["yis-recycle-iron-scrap"].recipe_chain_decision.confidence and
      recipe_chain_decisions.staged_data_table.debug.sources.recipes["yis-recycle-iron-scrap"].recipe_chain_decision.suggested_reasons,
    nil,
    recipe_chain_decisions and recipe_chain_decisions.staged_data_table and {
      recipe = recipe_chain_decisions.staged_data_table.prototypes and
        recipe_chain_decisions.staged_data_table.prototypes.recipes and
        recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-iron-scrap"],
      source = recipe_chain_decisions.staged_data_table.debug and
        recipe_chain_decisions.staged_data_table.debug.sources and
        recipe_chain_decisions.staged_data_table.debug.sources.recipes and
        recipe_chain_decisions.staged_data_table.debug.sources.recipes["yis-recycle-iron-scrap"],
    })
  local shaped_solid_decision
  for _, decision in ipairs(recipe_chain_decisions and
    recipe_chain_decisions.by_mode and
    recipe_chain_decisions.by_mode.solid and
    recipe_chain_decisions.by_mode.solid.materials or {}) do
    if decision.suggested and decision.suggested.recipe_shape then
      shaped_solid_decision = decision
      break
    end
  end
  add_case("analysis.recipe-chain.decision-shape", "recipe-chain decider carries selected recipe-shape evidence",
    shaped_solid_decision and
      shaped_solid_decision.action and
      shaped_solid_decision.confidence and
      shaped_solid_decision.review_reasons and
      shaped_solid_decision.suggested and
      shaped_solid_decision.suggested.reasons and
      shaped_solid_decision.suggested.recipe_flags and
      shaped_solid_decision.suggested.recipe_shape and
      shaped_solid_decision.suggested.recipe_shape.target_result,
    nil,
    shaped_solid_decision)
  if data.raw.item["kr-steel-beam"] then
    local steel_decision = find_recipe_chain_decision(recipe_chain_decisions, "solid", "steel")
    add_case("analysis.recipe-chain.k2-steel-active-candidate", "K2 steel target difference is strong enough to stage as an active candidate",
      steel_decision and
        steel_decision.action == "review-difference" and
        steel_decision.active_candidate == true and
        steel_decision.confidence == "active-candidate" and
        steel_decision.suggested and
        steel_decision.suggested.result_name == "kr-steel-beam" and
        recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-steel-scrap"] and
        recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-steel-scrap"].results[1].name == "kr-steel-beam",
      nil,
      steel_decision)
  end
  if data.raw.item["kr-enriched-rare-metals"] then
    local rare_metal_decision = find_recipe_chain_decision(recipe_chain_decisions, "solid", "rare-metal")
    add_case("analysis.recipe-chain.k2-rare-metal-manual-review", "weak K2 rare-metal target difference stays out of staged active candidates",
      rare_metal_decision and
        rare_metal_decision.action == "review-difference" and
        rare_metal_decision.active_candidate == false and
        rare_metal_decision.confidence == "manual-review" and
        rare_metal_decision.suggested and
        rare_metal_decision.suggested.result_name == "kr-enriched-rare-metals" and
        recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-rare-metal-scrap"] == nil,
      nil,
      rare_metal_decision)
  end
  local disabledium_decision = find_recipe_chain_decision(recipe_chain_decisions, "solid", "yis-disabledium")
  add_case("analysis.recipe-chain.disabled-source-confidence", "disabled source evidence alone does not lower decider confidence",
    disabledium_decision and
      disabledium_decision.action == "keep-current" and
      disabledium_decision.confidence == "high" and
      disabledium_decision.suggested and
      disabledium_decision.suggested.result_name == "yis-disabledium-plate" and
      disabledium_decision.suggested.recipe_flags and
      disabledium_decision.suggested.recipe_flags.disabled > 0 and
      not array_contains(disabledium_decision.review_reasons, "disabled-source-evidence") and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-disabledium-scrap"] and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-disabledium-scrap"].results[1].name == "yis-disabledium-plate",
    nil,
    disabledium_decision)
  if ISsettings.fluids then
    local solvium_decision = find_recipe_chain_decision(recipe_chain_decisions, "fluid", "yis-solvium")
    add_case("analysis.recipe-chain.api-forced-fluid-target", "recipe-chain API can force a fluid target decision",
      solvium_decision and
        solvium_decision.action == "api-forced-target" and
        solvium_decision.active_candidate == true and
        solvium_decision.api_override and
        solvium_decision.api_override.kind == "forced-target" and
        solvium_decision.suggested and
        solvium_decision.suggested.result_name == "yis-solvium-solution" and
        recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-solvium-scrap-to-fluid"] and
        recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-solvium-scrap-to-fluid"].results[1].name == "yis-solvium-solution",
      nil,
      solvium_decision)
  end
  local quietium_decision = find_recipe_chain_decision(recipe_chain_decisions, "solid", "yis-quietium")
  add_case("analysis.recipe-chain.api-forced-solid-target-without-candidate", "recipe-chain API can force a solid target without automatic analysis evidence",
    quietium_decision and
      quietium_decision.action == "api-forced-target" and
      quietium_decision.active_candidate == true and
      quietium_decision.api_override and
      quietium_decision.api_override.kind == "forced-target" and
      quietium_decision.suggested and
      quietium_decision.suggested.result_name == "yis-quietium-ingot" and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-quietium-scrap"] and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-quietium-scrap"].results[1].name == "yis-quietium-ingot",
    nil,
    quietium_decision)
  local blockium_blocked_decision = find_recipe_chain_decision(recipe_chain_decisions, "solid", "yis-blockium")
  add_case("analysis.recipe-chain.api-blocked-solid-target", "recipe-chain API can block automatic staging for a solid target",
    blockium_blocked_decision and
      blockium_blocked_decision.api_override and
      blockium_blocked_decision.api_override.kind == "blocked-target" and
      array_contains(blockium_blocked_decision.review_reasons, "api-blocked-target") and
      recipe_chain_decisions.staged_data_table.prototypes.recipes["yis-recycle-blockium-scrap"] == nil,
    nil,
    blockium_blocked_decision)
  local api = yokmods.ingredient_scrap.api or {}
  add_case("api.material", "public material API exposes nested register and ignore wrappers",
    api.register and api.register.material and api.ignore and
      type(api.register.material.override) == "function" and
      type(api.register.material.auto) == "function" and
      type(api.register.material.solid) == "function" and
      type(api.register.material.fluid) == "function" and
      type(api.register.material.both) == "function" and
      type(api.register.material.alias) == "function" and
      type(api.ignore.material) == "function" and
      yokmods.ingredient_scrap.register_material_override == nil)
  add_case("api.category", "public category API separates furnace and assembling-machine registration",
    api.register and api.register.category and
      type(api.register.category.furnace) == "function" and
      type(api.register.category.assembling_machine) == "function")
  add_case("api.recipe-chain", "public recipe-chain API exposes target override and block wrappers",
    api.register and api.register.recipe_chain and api.ignore and api.ignore.recipe_chain and
      type(api.register.recipe_chain.target) == "function" and
      type(api.register.recipe_chain.solid_target) == "function" and
      type(api.register.recipe_chain.fluid_target) == "function" and
      type(api.ignore.recipe_chain.target) == "function" and
      type(api.ignore.recipe_chain.solid_target) == "function" and
      type(api.ignore.recipe_chain.fluid_target) == "function")
  add_case("api.generated", "public API exposes generated prototype staging tables",
    api.generated and
      type(api.generated.items) == "function" and
      type(api.generated.recipes) == "function" and
      type(api.generated.fluids) == "function" and
      type(api.generated.technologies) == "function" and
      type(api.generated.techs) == "function" and
      api.generated.items() == data_table.prototypes.items and
      api.generated.recipes() == data_table.prototypes.recipes and
      api.generated.technologies() == data_table.prototypes.technology and
      api.generated.techs() == data_table.prototypes.technology)
  local generated_recipes = api.generated and api.generated.recipes and api.generated.recipes()
  local api_disabled_recipe = generated_recipes and generated_recipes["yis-recycle-testium-scrap"]
  local previous_enabled = api_disabled_recipe and api_disabled_recipe.enabled
  local api_disabled_errors = nil
  if api_disabled_recipe then
    api_disabled_recipe.enabled = false
    api_disabled_errors = yokmods.ingredient_scrap.validate_generated_prototypes()
    api_disabled_recipe.enabled = previous_enabled
  end
  add_case("api.generated.disabled-recipe-warning", "API-disabled generated recipes warn but do not fail validation",
    api_disabled_recipe and
      api_disabled_errors and #api_disabled_errors == 0 and
      log_contains(data_table.debug and data_table.debug.logs, "warn", "validate-generated-prototypes", "yis-recycle-testium-scrap"),
    nil,
    { errors = api_disabled_errors, logs = data_table.debug and data_table.debug.logs })

  add_case("materials.solid.yis-testium", "yis-testium is a solid material",
    array_contains(data_table.materials.solid, "yis-testium"))
  add_case("materials.solid.yis-disabledium", "disabled source fixture is still detected as a solid material",
    array_contains(data_table.materials.solid, "yis-disabledium") == exp.materials.solid["yis-disabledium"])
  add_case("materials.solid.yis-rare-metal", "solid suffix resolver keeps prefixed multi-part material names",
    array_contains(data_table.materials.solid, "yis-rare-metal"))
  add_case("materials.solid.no-rare-prefix", "solid resolver does not collapse yis-rare-metal into rare",
    not array_contains(data_table.materials.solid, "rare"))
  add_case("materials.solid.uranium", "uranium is blacklisted for solid materials",
    not array_contains(data_table.materials.solid, "uranium"))
  add_case("materials.override.uranium-none", "uranium override ignores solid and fluid channels",
    ISsettings.material_modes.uranium == "none" and
      material_overrides.is_ignored(ISsettings.material_modes.uranium, "solid") and
      material_overrides.is_ignored(ISsettings.material_modes.uranium, "fluid"))
  add_case("materials.override.bacteria-none", "bacteria is known but ignored by default",
    ISsettings.material_modes.bacteria == "none" and
      material_overrides.is_ignored(ISsettings.material_modes.bacteria, "solid") and
      material_overrides.is_ignored(ISsettings.material_modes.bacteria, "fluid"),
    nil,
    { mode = ISsettings.material_modes.bacteria, name = material_overrides.localised_setting_name("bacteria") })
  add_case("materials.override.vanilla-auto", "iron, copper, and holmium have material settings without forcing a channel",
    ISsettings.material_modes.iron == "auto" and
      ISsettings.material_modes.copper == "auto" and
      ISsettings.material_modes.holmium == "auto" and
      array_contains(data_table.materials.solid, "iron") and
      array_contains(data_table.materials.solid, "copper"),
    nil,
    {
      iron = ISsettings.material_modes.iron,
      copper = ISsettings.material_modes.copper,
      holmium = ISsettings.material_modes.holmium,
      iron_name = material_overrides.localised_setting_name("iron"),
      copper_name = material_overrides.localised_setting_name("copper"),
      holmium_name = material_overrides.localised_setting_name("holmium"),
    })
  add_case("materials.override.lithium-none", "fluid-only lithium is known but ignored by default",
    ISsettings.material_modes.lithium == "none" and
      material_overrides.is_ignored(ISsettings.material_modes.lithium, "solid") and
      material_overrides.is_ignored(ISsettings.material_modes.lithium, "fluid") and
      not array_contains(data_table.materials.fluid, "lithium"),
    nil,
    { mode = ISsettings.material_modes.lithium, name = material_overrides.localised_setting_name("lithium") })
  add_case("materials.override.ammonia-none", "ammonia is known but ignored by default",
    ISsettings.material_modes.ammonia == "none" and
      material_overrides.is_ignored(ISsettings.material_modes.ammonia, "solid") and
      material_overrides.is_ignored(ISsettings.material_modes.ammonia, "fluid"),
    nil,
    { mode = ISsettings.material_modes.ammonia, name = material_overrides.localised_setting_name("ammonia") })
  add_case("materials.override.steel-solid", "steel override forces solid and ignores fluid",
    ISsettings.material_modes.steel == "solid" and
      material_overrides.is_forced(ISsettings.material_modes.steel, "solid") and
      material_overrides.is_ignored(ISsettings.material_modes.steel, "fluid") and
      array_contains(data_table.materials.solid, "steel"))
  add_case("materials.override.test-api", "debug materials are registered through the material override API",
    material_overrides.default_modes["yis-testium"] == "both" and
      material_overrides.default_modes["yis-solvium"] == "both" and
      material_overrides.default_modes["yis-rare-metal"] == "both" and
      material_overrides.default_modes["yis-alienite"] == "none",
    nil,
    {
      yis_testium = material_overrides.default_modes["yis-testium"],
      yis_solvium = material_overrides.default_modes["yis-solvium"],
      yis_rare_metal = material_overrides.default_modes["yis-rare-metal"],
      yis_alienite = material_overrides.default_modes["yis-alienite"],
    })
  add_case("materials.override.vanilla-tints", "vanilla scrap tints are registered through the material API",
    material_overrides.tints.iron == "#888b8d" and
      material_overrides.tints.copper == "#CB6015" and
      material_overrides.tints.steel == "#888b8d",
    nil,
    {
      iron = material_overrides.tints.iron,
      copper = material_overrides.tints.copper,
      steel = material_overrides.tints.steel,
    })
  add_case("materials.override.resolver-affixes", "resolver affixes come from the material override registry",
    array_contains(data_table.materials.solid_suffixes, "-plate") and
      array_contains(data_table.materials.solid_suffixes, "-ore") and
      array_contains(data_table.materials.fluid_prefixes, "molten-") and
      array_contains(data_table.materials.fluid_suffixes, "-solution") and
      array_contains(data_table.materials.fluid_suffixes, "-brine") and
      not array_contains(data_table.materials.solid_suffixes, "-gear-wheel"),
    nil,
    {
      solid_suffixes = data_table.materials.solid_suffixes,
      fluid_prefixes = data_table.materials.fluid_prefixes,
      fluid_suffixes = data_table.materials.fluid_suffixes,
    })
  add_case("materials.override.icon-steel", "material override icon uses an existing item prototype",
    material_overrides.icon_tag("steel") == "[item=steel-plate]",
    nil,
    { icon = material_overrides.icon_tag("steel") })
  add_case("materials.override.prototype-affixes", "material override prototype affixes build item and fluid candidates",
    array_contains(material_overrides.prototype_candidates("steel", "item"), "steel-plate") and
      array_contains(material_overrides.prototype_candidates("crude", "fluid"), "crude-oil"),
    nil,
    {
      steel = material_overrides.prototype_candidates("steel", "item"),
      crude = material_overrides.prototype_candidates("crude", "fluid"),
    })
  add_case("materials.override.icon-crude", "material override icon uses an existing fluid prototype",
    material_overrides.icon_tag("crude") == "[fluid=crude-oil]",
    nil,
    { icon = material_overrides.icon_tag("crude") })
  add_case("materials.override.localised-name-no-rich-text", "material setting names avoid item/fluid rich-text tags",
    not localised_string_contains_rich_text(material_overrides.localised_setting_name("steel")) and
      not localised_string_contains_rich_text(material_overrides.localised_setting_name("crude")) and
      not localised_string_contains_rich_text(material_overrides.localised_setting_name("bacteria")) and
      material_overrides.localised_setting_name("iron")[2][1] == "mod-setting-name.yis-material-iron" and
      material_overrides.localised_setting_name("copper")[2][1] == "mod-setting-name.yis-material-copper" and
      material_overrides.localised_setting_name("holmium")[2][1] == "mod-setting-name.yis-material-holmium" and
      material_overrides.localised_setting_name("lithium")[2][1] == "mod-setting-name.yis-material-lithium" and
      material_overrides.localised_setting_name("ammonia")[2][1] == "mod-setting-name.yis-material-ammonia" and
      material_overrides.localised_setting_name("steel")[2][1] == "mod-setting-name.yis-material-steel" and
      material_overrides.localised_setting_name("crude")[2][1] == "mod-setting-name.yis-material-crude" and
      material_overrides.localised_setting_name("bacteria")[2][1] == "mod-setting-name.yis-material-bacteria" and
      material_overrides.localised_setting_name("bacteria")[4] == "bacteria",
    nil,
    {
      iron = material_overrides.localised_setting_name("iron"),
      copper = material_overrides.localised_setting_name("copper"),
      holmium = material_overrides.localised_setting_name("holmium"),
      lithium = material_overrides.localised_setting_name("lithium"),
      ammonia = material_overrides.localised_setting_name("ammonia"),
      steel = material_overrides.localised_setting_name("steel"),
      crude = material_overrides.localised_setting_name("crude"),
      bacteria = material_overrides.localised_setting_name("bacteria"),
    })
  add_case("materials.override.source-description", "material setting descriptions include a colored source label",
    localised_string_contains(material_overrides.localised_setting_description("iron"), "[color=") and
      localised_string_contains(material_overrides.localised_setting_description("iron"), "#8DA0AA") and
      localised_string_contains(material_overrides.localised_setting_description("iron"), "Base") and
      localised_string_contains(material_overrides.localised_setting_description("holmium"), "Space Age") and
      localised_string_contains(material_overrides.localised_setting_description("yis-testium"), "Ingredient Scrap Test"),
    nil,
    {
      iron = material_overrides.localised_setting_description("iron"),
      holmium = material_overrides.localised_setting_description("holmium"),
      yis_testium = material_overrides.localised_setting_description("yis-testium"),
    })
  add_case("materials.override.bacteria-locale-icon", "known bacteria uses a locale icon while keeping prototype matching disabled",
    material_overrides.icon_tag("bacteria") == nil and
      material_overrides.localised_setting_name("bacteria")[2][1] == "mod-setting-name.yis-material-bacteria",
    nil,
    { icon = material_overrides.icon_tag("bacteria"), name = material_overrides.localised_setting_name("bacteria") })
  add_case("materials.override.no-localised-setting-icon", "material without a localized setting icon uses the neutral fallback",
    material_overrides.localised_setting_name("yis-testbrass")[2] == "[img=none]",
    nil,
    { icon = material_overrides.icon_tag("yis-testbrass"), name = material_overrides.localised_setting_name("yis-testbrass") })
  add_case("materials.fluid.yis-testium", "yis-testium fluid material matches fluid setting",
    array_contains(data_table.materials.fluid, "yis-testium") == exp.materials.fluid["yis-testium"])
  add_case("materials.fluid.yis-solvium", "fluid suffix material matches fluid setting",
    array_contains(data_table.materials.fluid, "yis-solvium") == exp.materials.fluid["yis-solvium"])
  add_case("materials.fluid.yis-rare-metal", "fluid prefix and suffix resolver keeps prefixed multi-part material names",
    array_contains(data_table.materials.fluid, "yis-rare-metal") ==
      (ISsettings.fluids and not material_overrides.is_ignored(material_overrides.default_modes["yis-rare-metal"], "fluid")))
  add_case("materials.fluid.no-suffix-token", "fluid suffix token is not collected as a material",
    not array_contains(data_table.materials.fluid, "-solution"))
  add_case("materials.fluid.yis-alienite", "yis-alienite fluid is ignored without plate or ingot",
    not array_contains(data_table.materials.fluid, "yis-alienite"))

  add_case("resolver.solid.yis-rare-metal-ore", "solid resolver strips known suffix after prefixed multi-part names",
    material_resolver.resolve_solid("yis-rare-metal-ore", data_table.materials) == "yis-rare-metal")
  add_case("resolver.fluid.yis-rare-metal-solution", "fluid resolver strips known suffix after prefixed multi-part names",
    material_resolver.resolve_fluid("yis-rare-metal-solution", data_table.materials) == "yis-rare-metal")
  add_case("resolver.fluid.molten-yis-rare-metal", "fluid resolver strips known prefix before prefixed multi-part names",
    material_resolver.resolve_fluid("molten-yis-rare-metal", data_table.materials) == "yis-rare-metal")
  add_case("resolver.fluid.molten-yis-rare-metal-ore", "fluid resolver handles combined prefix and suffix",
    material_resolver.resolve_fluid("molten-yis-rare-metal-ore", data_table.materials) == "yis-rare-metal")
  add_case("resolver.fluid.lithium-brine", "fluid resolver handles the Space Age brine suffix",
    material_resolver.resolve_fluid("lithium-brine", data_table.materials) == "lithium")
  add_case("resolver.solid.unknown-composite", "solid resolver avoids blind first-segment fallback",
    material_resolver.resolve_solid("unknown-composite", data_table.materials) == nil)
  if mods and mods["Krastorio2"] then
    add_case("compat.krastorio2.alias-rare-metal", "Krastorio rare metals resolve to rare-metal",
      material_resolver.resolve_solid("kr-rare-metals", data_table.materials) == "rare-metal" and
        material_resolver.resolve_solid("kr-rare-metal-ore", data_table.materials) == "rare-metal" and
        array_contains(data_table.materials.solid, "rare-metal") and
        not array_contains(data_table.materials.solid, "kr-rare-metal"),
      nil,
      { solid = data_table.materials.solid })
    add_case("compat.krastorio2.alias-imersium", "Krastorio imersium prototypes resolve to imersium",
      material_resolver.resolve_solid("kr-imersium-plate", data_table.materials) == "imersium" and
        material_resolver.resolve_solid("kr-imersium-beam", data_table.materials) == "imersium" and
        array_contains(data_table.materials.solid, "imersium") and
        not array_contains(data_table.materials.solid, "kr-imersium"),
      nil,
      { solid = data_table.materials.solid })
    add_case("compat.krastorio2.alias-reinforced-plates", "Krastorio reinforced plates resolve without the kr prefix",
      material_resolver.resolve_solid("kr-black-reinforced-plate", data_table.materials) == "black-reinforced" and
        material_resolver.resolve_solid("kr-white-reinforced-plate", data_table.materials) == "white-reinforced" and
        array_contains(data_table.materials.solid, "black-reinforced") and
        array_contains(data_table.materials.solid, "white-reinforced") and
        not array_contains(data_table.materials.solid, "kr-black-reinforced") and
        not array_contains(data_table.materials.solid, "kr-white-reinforced"),
      nil,
      { solid = data_table.materials.solid })
  end

  local recycle_item_category = "yis-recycle-to-item"
  local recycle_fluid_category = "yis-recycle-to-fluid"
  local furnace_recycle_source_categories = {
    ["smelting"] = true,
    ["recycling"] = true,
  }
  local furnace_fluid_recycle_source_categories = {
    ["metallurgy-or-assembling"] = true,
  }
  local assembling_recycle_source_categories = {
    ["basic-crafting"] = true,
    ["crafting"] = true,
    ["advanced-crafting"] = true,
  }
  local assembling_fluid_recycle_source_categories = {
    ["basic-crafting"] = true,
    ["crafting"] = true,
    ["advanced-crafting"] = true,
    ["crafting-with-fluid-or-metallurgy"] = true,
    ["metallurgy-or-assembling"] = true,
  }
  local eligible_furnace_count = 0
  local patched_furnace_count = 0
  local eligible_fluid_furnace_count = 0
  local patched_fluid_furnace_count = 0
  local duplicate_machine = nil
  for _, furnace in pairs(data.raw.furnace or {}) do
    if has_any_category(furnace, furnace_recycle_source_categories) then
      eligible_furnace_count = eligible_furnace_count + 1
      if category_count(furnace, recycle_item_category) == 1 then
        patched_furnace_count = patched_furnace_count + 1
      end
    end
    if has_any_category(furnace, furnace_fluid_recycle_source_categories) and furnace.fluid_boxes then
      eligible_fluid_furnace_count = eligible_fluid_furnace_count + 1
      if category_count(furnace, recycle_fluid_category) == 1 then
        patched_fluid_furnace_count = patched_fluid_furnace_count + 1
      end
    end
    if category_count(furnace, recycle_item_category) > 1 or
      category_count(furnace, recycle_fluid_category) > 1 then
      duplicate_machine = furnace.name
    end
  end
  add_case("categories.furnace.item", "eligible furnaces can craft item recycle recipes",
    eligible_furnace_count > 0 and patched_furnace_count == eligible_furnace_count,
    nil,
    { eligible = eligible_furnace_count, patched = patched_furnace_count })
  if data.raw.furnace.recycler then
    add_case("categories.furnace.recycler", "quality recycler can craft item recycle recipes",
      category_count(data.raw.furnace.recycler, "recycling") > 0 and
        category_count(data.raw.furnace.recycler, recycle_item_category) == 1,
      nil,
      { categories = data.raw.furnace.recycler.crafting_categories })
  end
  add_case("categories.furnace.fluid", "fluid metallurgy furnaces can craft fluid recycle recipes only",
    eligible_fluid_furnace_count == patched_fluid_furnace_count,
    nil,
    { eligible = eligible_fluid_furnace_count, patched = patched_fluid_furnace_count })
  if data.raw.furnace.foundry then
    add_case("categories.furnace.foundry-fluid-only", "Space Age foundry gets fluid recycling but not item recycling",
      category_count(data.raw.furnace.foundry, "metallurgy-or-assembling") > 0 and
        category_count(data.raw.furnace.foundry, recycle_item_category) == 0 and
        category_count(data.raw.furnace.foundry, recycle_fluid_category) == 1,
      nil,
      { categories = data.raw.furnace.foundry.crafting_categories })
  end
  add_case("categories.furnace.no-duplicates", "furnace recycle categories are not duplicated",
    duplicate_machine == nil, nil, { duplicate = duplicate_machine })

  local eligible_assembler_count = 0
  local patched_assembler_count = 0
  local fluid_assembler_count = 0
  local patched_fluid_assembler_count = 0
  local foundry = data.raw.furnace.foundry or data.raw["assembling-machine"].foundry
  duplicate_machine = nil
  for _, assembling_machine in pairs(data.raw["assembling-machine"] or {}) do
    if has_any_category(assembling_machine, assembling_recycle_source_categories) then
      eligible_assembler_count = eligible_assembler_count + 1
      if category_count(assembling_machine, recycle_item_category) == 1 then
        patched_assembler_count = patched_assembler_count + 1
      end
    end
    if has_any_category(assembling_machine, assembling_fluid_recycle_source_categories) then
      if assembling_machine.fluid_boxes then
        fluid_assembler_count = fluid_assembler_count + 1
        if category_count(assembling_machine, recycle_fluid_category) == 1 then
          patched_fluid_assembler_count = patched_fluid_assembler_count + 1
        end
      end
    end
    if category_count(assembling_machine, recycle_item_category) > 1 or
      category_count(assembling_machine, recycle_fluid_category) > 1 then
      duplicate_machine = assembling_machine.name
    end
  end
  add_case("categories.assembling.item", "eligible assembling machines can craft item recycle recipes",
    eligible_assembler_count > 0 and patched_assembler_count == eligible_assembler_count,
    nil,
    { eligible = eligible_assembler_count, patched = patched_assembler_count })
  add_case("categories.assembling.fluid", "fluid-capable eligible assembling machines can craft fluid recycle recipes",
    fluid_assembler_count > 0 and patched_fluid_assembler_count == fluid_assembler_count,
    nil,
    { eligible = fluid_assembler_count, patched = patched_fluid_assembler_count })
  add_case("categories.assembling.no-duplicates", "assembling machine recycle categories are not duplicated",
    duplicate_machine == nil, nil, { duplicate = duplicate_machine })
  if foundry then
    add_case("categories.foundry.fluid-only", "foundry gets fluid recycling but not item recycling",
      category_count(foundry, "metallurgy-or-assembling") > 0 and
        category_count(foundry, recycle_item_category) == 0 and
        category_count(foundry, recycle_fluid_category) == 1,
      nil,
      { type = data.raw.furnace.foundry and "furnace" or "assembling-machine", categories = foundry.crafting_categories })
  end

  local iron_recycle_recipe = data.raw.recipe["yis-recycle-iron-scrap"]
  local item_recycling_assemblers = machine_names_with_category("assembling-machine", recycle_item_category)
  local item_recycling_furnaces = machine_names_with_category("furnace", recycle_item_category)
  add_case("categories.iron-recycle.recipe", "iron-scrap recycle recipe uses item recycling category",
    iron_recycle_recipe and iron_recycle_recipe.category == recycle_item_category,
    nil,
    { recipe_category = iron_recycle_recipe and iron_recycle_recipe.category, expected = recycle_item_category })
  add_case("categories.iron-recycle.assembling", "at least one assembling machine accepts iron-scrap recycle recipes",
    iron_recycle_recipe and array_contains(item_recycling_assemblers, "assembling-machine-1"),
    nil,
    { recipe_category = iron_recycle_recipe and iron_recycle_recipe.category, machines = item_recycling_assemblers })
  add_case("categories.iron-recycle.furnace", "at least one furnace accepts iron-scrap recycle recipes",
    iron_recycle_recipe and #item_recycling_furnaces > 0,
    nil,
    { recipe_category = iron_recycle_recipe and iron_recycle_recipe.category, machines = item_recycling_furnaces })
  add_case("categories.iron-recycle.result", "iron-scrap recycles to iron-plate",
    iron_recycle_recipe and iron_recycle_recipe.results and
      iron_recycle_recipe.results[1] and iron_recycle_recipe.results[1].name == "iron-plate",
    nil,
    { result = iron_recycle_recipe and iron_recycle_recipe.results and iron_recycle_recipe.results[1] })
  local recycling_scrap_recipe = recycling_recipe_with_scrap_result()
  add_case("raw.patch.no-quality-recycling-scrap", "Quality-style recycling recipes do not receive additional scrap results",
    recycling_scrap_recipe == nil,
    nil,
    { recipe = recycling_scrap_recipe, results = recycling_scrap_recipe and scrap_results(data.raw.recipe[recycling_scrap_recipe]) })
  local quietium_recycle_recipe = data.raw.recipe["yis-recycle-quietium-scrap"]
  local quietium_result = quietium_recycle_recipe and quietium_recycle_recipe.results and quietium_recycle_recipe.results[1]
  local expected_quietium_target = ISsettings.recipe_chain_targets and "yis-quietium-ingot" or "yis-quietium-plate"
  add_case("recipe-chain-targets.api-forced-yis-quietium", "API-forced recipe-chain target follows the recipe-chain target setting",
    quietium_result and quietium_result.name == expected_quietium_target,
    nil,
    {
      enabled = ISsettings.recipe_chain_targets,
      expected = expected_quietium_target,
      actual = quietium_result,
    })
  add_case("recipe-chain-targets.api-forced-yis-quietium.icon", "API-forced recycle recipe uses the active target item icon",
    quietium_recycle_recipe and data.raw.item[expected_quietium_target] and
      icon_layers_contain(quietium_recycle_recipe.icons, data.raw.item[expected_quietium_target].icon),
    nil,
    {
      enabled = ISsettings.recipe_chain_targets,
      expected = expected_quietium_target,
      expected_icon = data.raw.item[expected_quietium_target] and data.raw.item[expected_quietium_target].icon,
      icons = quietium_recycle_recipe and quietium_recycle_recipe.icons,
    })
  if data.raw.item["kr-steel-beam"] then
    local imersium_recycle_recipe = data.raw.recipe["yis-recycle-imersium-scrap"]
    local imersium_result = imersium_recycle_recipe and imersium_recycle_recipe.results and imersium_recycle_recipe.results[1]
    add_case("compat.krastorio2.imersium-recycle-visible", "K2 imersium scrap has a visible item recycle recipe to plate",
      imersium_recycle_recipe and
        imersium_recycle_recipe.hidden ~= true and
        imersium_recycle_recipe.category == recycle_item_category and
        imersium_result and imersium_result.type == "item" and imersium_result.name == "kr-imersium-plate",
      nil,
      {
        hidden = imersium_recycle_recipe and imersium_recycle_recipe.hidden,
        category = imersium_recycle_recipe and imersium_recycle_recipe.category,
        result = imersium_result,
      })

    local steel_recycle_recipe = data.raw.recipe["yis-recycle-steel-scrap"]
    local steel_result = steel_recycle_recipe and steel_recycle_recipe.results and steel_recycle_recipe.results[1]
    local expected_steel_target = ISsettings.recipe_chain_targets and "kr-steel-beam" or "steel-plate"
    add_case("recipe-chain-targets.k2-steel", "K2 steel recycle target follows the recipe-chain target setting",
      steel_result and steel_result.name == expected_steel_target,
      nil,
      {
        enabled = ISsettings.recipe_chain_targets,
        expected = expected_steel_target,
        actual = steel_result,
      })
    add_case("recipe-chain-targets.k2-steel.icon", "K2 steel recycle recipe uses the active target item icon",
      steel_recycle_recipe and data.raw.item[expected_steel_target] and
        icon_layers_contain(steel_recycle_recipe.icons, data.raw.item[expected_steel_target].icon),
      nil,
      {
        enabled = ISsettings.recipe_chain_targets,
        expected = expected_steel_target,
        expected_icon = data.raw.item[expected_steel_target] and data.raw.item[expected_steel_target].icon,
        icons = steel_recycle_recipe and steel_recycle_recipe.icons,
      })

    local rare_metal_recycle_recipe = data.raw.recipe["yis-recycle-rare-metal-scrap"]
    local rare_metal_result = rare_metal_recycle_recipe and rare_metal_recycle_recipe.results and rare_metal_recycle_recipe.results[1]
    add_case("recipe-chain-targets.k2-rare-metal-manual-review", "K2 rare-metal manual review target is not applied automatically",
      rare_metal_result and rare_metal_result.name == "kr-rare-metal-ore",
      nil,
      {
        enabled = ISsettings.recipe_chain_targets,
        expected = "kr-rare-metal-ore",
        actual = rare_metal_result,
      })
  end

  for recipe_name, expected_result in pairs(exp.inserts) do
    local insert = data_table.inserts.recipes[recipe_name]
    local actual = find_result(insert and insert.results, expected_result.name)
    add_case("insert." .. recipe_name, recipe_name .. " has expected scrap insert",
      same_value(result_signature(actual), expected_result),
      nil,
      { expected = expected_result, actual = result_signature(actual) })
  end

  local mixed_results = (data_table.inserts.recipes["yis-test-yis-testium-mixed"] or {}).results or {}
  local mixed_count = 0
  for _, result in ipairs(mixed_results) do
    if result.name == "yis-testium-scrap" then mixed_count = mixed_count + 1 end
  end
  add_case("mixed.single-result", "mixed solid/fluid input accumulates into one result", mixed_count == 1,
    nil, { count = mixed_count, results = mixed_results })

  local insert_shape_mismatch = nil
  local raw_shape_mismatch = nil
  for recipe_name, expected_result in pairs(exp.inserts) do
    local insert = data_table.inserts.recipes[recipe_name]
    local insert_result = find_result(insert and insert.results, expected_result.name)
    local raw_result = find_result(scrap_results(data.raw.recipe[recipe_name]), expected_result.name)
    if not insert_shape_mismatch and not has_expected_amount_shape(insert_result) then
      insert_shape_mismatch = { recipe = recipe_name, result = result_signature(insert_result) }
    end
    if not raw_shape_mismatch and not has_expected_amount_shape(raw_result) then
      raw_shape_mismatch = { recipe = recipe_name, result = result_signature(raw_result) }
    end
  end
  add_case("amount.insert-shape", "insert scrap results use the selected fixed/range amount shape",
    insert_shape_mismatch == nil, nil, insert_shape_mismatch)
  add_case("amount.raw-patch-shape", "patched data.raw scrap results use the selected fixed/range amount shape",
    raw_shape_mismatch == nil, nil, raw_shape_mismatch)

  local small_fixed, small_min, small_max = yokmods.ingredient_scrap.scrap_amount_range(5)
  local large_fixed, large_min, large_max = yokmods.ingredient_scrap.scrap_amount_range(200)
  local linear_large = math.ceil(200 * (ISsettings.probability / 100))
  add_case("amount.small-positive", "small scrap amount remains positive", small_fixed > 0)
  if ISsettings.limit then
    add_case("amount.large-smoothed", "large scrap amount is smoothed below linear scaling when limit is enabled",
      large_fixed < linear_large,
      nil, { large = large_fixed, linear = linear_large })
  else
    add_case("amount.large-linear", "large scrap amount follows linear scaling when limit is disabled",
      large_fixed == math.max(linear_large, 1),
      nil, { large = large_fixed, linear = linear_large })
  end
  if ISsettings.fixed_amount then
    add_case("amount.fixed-shape", "fixed mode uses amount only", small_min == nil and small_max == nil)
  else
    add_case("amount.range-shape", "range mode uses valid min/max", small_min and small_max and small_min <= small_max and small_min > 0)
  end

  local void_insert = data_table.inserts.recipes["yis-test-yis-testium-void"]
  add_case("edge.void", "void recipe creates no scrap insert",
    not (void_insert and void_insert.results))
  local fluid_main_insert = data_table.inserts.recipes["yis-test-yis-testium-fluid-main-product"]
  local fluid_main_result = find_result(fluid_main_insert and fluid_main_insert.results, "yis-testium-scrap")
  if ISsettings.fluids then
    add_case("edge.fluid-main-product", "fluid main product is processed when fluid recipes are enabled",
      same_value(result_signature(fluid_main_result), exp.inserts["yis-test-yis-testium-fluid-main-product"]),
      nil,
      { expected = exp.inserts["yis-test-yis-testium-fluid-main-product"], actual = result_signature(fluid_main_result) })
  else
    add_case("edge.fluid-main-product", "fluid main product is ignored when fluid recipes are disabled",
      not (fluid_main_insert and fluid_main_insert.results))
    add_case("edge.fluid-only-prefix-disabled", "prefix fluid fixture creates no scrap insert when fluid recipes are disabled",
      not insert_has_results(data_table, "yis-test-yis-testium-fluid"))
    add_case("edge.fluid-only-suffix-disabled", "suffix fluid fixture creates no scrap insert when fluid recipes are disabled",
      not insert_has_results(data_table, "yis-test-yis-solvium-solution"))
  end
  local alienite_insert = data_table.inserts.recipes["yis-test-yis-alienite-fluid"]
  add_case("edge.yis-alienite", "unknown fluid creates no scrap insert",
    not (alienite_insert and alienite_insert.results))
  local uranium_insert = data_table.inserts.recipes["yis-test-uranium-blacklist"]
  add_case("edge.uranium", "blacklisted uranium creates no scrap insert",
    not (uranium_insert and uranium_insert.results))

  local item = data.raw.item["yis-testium-scrap"]
  local normalized_item = item and {
    type = item.type,
    name = item.name,
    subgroup = item.subgroup,
    order = item.order,
    hidden = item.hidden or false,
    stack_size = item.stack_size,
    has_icons = item.icons ~= nil or item.icon ~= nil,
    tint = item.icons and item.icons[1] and item.icons[1].tint,
  } or nil
  add_case("raw.item.yis-testium-scrap", "yis-testium-scrap item matches expected normalized object",
    same_value(normalized_item, exp.item), nil, { expected = exp.item, actual = normalized_item })
  add_case("raw.item.yis-testium-scrap.icons", "generated scrap item icon layers use icon_size",
    icon_layers_have_icon_size(item and item.icons), nil, { icons = item and item.icons })

  local hidden_item = data.raw.item["yis-hiddenium-scrap"]
  local normalized_hidden_item = hidden_item and {
    type = hidden_item.type,
    name = hidden_item.name,
    subgroup = hidden_item.subgroup,
    order = hidden_item.order,
    hidden = hidden_item.hidden or false,
    stack_size = hidden_item.stack_size,
    has_icons = hidden_item.icons ~= nil or hidden_item.icon ~= nil,
  } or nil
  add_case("raw.item.yis-hiddenium-scrap", "hidden source creates an existing but hidden scrap item",
    same_value(normalized_hidden_item, exp.hidden_item), nil,
    { expected = exp.hidden_item, actual = normalized_hidden_item })

  local disabled_item = data.raw.item["yis-disabledium-scrap"]
  local normalized_disabled_item = disabled_item and {
    type = disabled_item.type,
    name = disabled_item.name,
    subgroup = disabled_item.subgroup,
    order = disabled_item.order,
    hidden = disabled_item.hidden or false,
    stack_size = disabled_item.stack_size,
    has_icons = disabled_item.icons ~= nil or disabled_item.icon ~= nil,
  } or nil
  add_case("raw.item.yis-disabledium-scrap", "disabled source creates an existing visible scrap item",
    same_value(normalized_disabled_item, exp.disabled_item), nil,
    { expected = exp.disabled_item, actual = normalized_disabled_item })

  if exp.hidden_fluid_item then
    local hidden_fluid_item = data.raw.item["yis-hiddenfluidium-scrap"]
    local normalized_hidden_fluid_item = hidden_fluid_item and {
      type = hidden_fluid_item.type,
      name = hidden_fluid_item.name,
      subgroup = hidden_fluid_item.subgroup,
      order = hidden_fluid_item.order,
      hidden = hidden_fluid_item.hidden or false,
      stack_size = hidden_fluid_item.stack_size,
      has_icons = hidden_fluid_item.icons ~= nil or hidden_fluid_item.icon ~= nil,
    } or nil
    add_case("raw.item.yis-hiddenfluidium-scrap", "hidden fluid source creates an existing but hidden scrap item",
      same_value(normalized_hidden_fluid_item, exp.hidden_fluid_item), nil,
      { expected = exp.hidden_fluid_item, actual = normalized_hidden_fluid_item })
  end

  local iron_item = data.raw.item["yis-iron-scrap"]
  local iron_tint = iron_item and iron_item.icons and iron_item.icons[1] and iron_item.icons[1].tint
  add_case("raw.item.iron-scrap.tint", "iron-scrap item uses the vanilla material API tint",
    same_value(iron_tint, util.color("#888b8d")),
    nil,
    { expected = util.color("#888b8d"), actual = iron_tint })

  local solid_recipe = data.raw.recipe["yis-recycle-testium-scrap"]
  local normalized_solid_recipe = solid_recipe and {
    type = solid_recipe.type,
    name = solid_recipe.name,
    hidden = solid_recipe.hidden or false,
    subgroup = solid_recipe.subgroup,
    category = solid_recipe.category,
    allow_as_intermediate = solid_recipe.allow_as_intermediate,
    hide_from_player_crafting = solid_recipe.hide_from_player_crafting,
    result = solid_recipe.results and solid_recipe.results[1],
  } or nil
  add_case("raw.recipe.recycle-yis-testium-scrap", "solid recycle recipe matches expected normalized object",
    same_value(normalized_solid_recipe, exp.recipes.solid), nil,
    { expected = exp.recipes.solid, actual = normalized_solid_recipe })
  add_case("raw.recipe.recycle-yis-testium-scrap.icons", "generated recycle recipe icon layers use icon_size",
    icon_layers_have_icon_size(solid_recipe and solid_recipe.icons), nil, { icons = solid_recipe and solid_recipe.icons })
  add_case("raw.recipe.recycle-yis-testium-scrap.amount", "solid recycle recipe has patched input amount",
    solid_recipe and solid_recipe.ingredients and solid_recipe.ingredients[1] and
      solid_recipe.ingredients[1].amount == expected_recycle_input_amount(data_table, "yis-testium-scrap"),
    nil,
    {
      expected = expected_recycle_input_amount(data_table, "yis-testium-scrap"),
      ingredients = solid_recipe and solid_recipe.ingredients,
    })

  local hidden_recipe = data.raw.recipe["yis-recycle-hiddenium-scrap"]
  local normalized_hidden_recipe = hidden_recipe and {
    type = hidden_recipe.type,
    name = hidden_recipe.name,
    hidden = hidden_recipe.hidden or false,
    subgroup = hidden_recipe.subgroup,
    category = hidden_recipe.category,
    allow_as_intermediate = hidden_recipe.allow_as_intermediate,
    hide_from_player_crafting = hidden_recipe.hide_from_player_crafting,
    result = hidden_recipe.results and hidden_recipe.results[1],
  } or nil
  add_case("raw.recipe.recycle-yis-hiddenium-scrap", "hidden source creates a hidden recycle recipe without disabling it",
    same_value(normalized_hidden_recipe, exp.recipes.hidden_solid), nil,
    { expected = exp.recipes.hidden_solid, actual = normalized_hidden_recipe })

  local disabled_recipe = data.raw.recipe["yis-recycle-disabledium-scrap"]
  local normalized_disabled_recipe = disabled_recipe and {
    type = disabled_recipe.type,
    name = disabled_recipe.name,
    hidden = disabled_recipe.hidden or false,
    subgroup = disabled_recipe.subgroup,
    category = disabled_recipe.category,
    allow_as_intermediate = disabled_recipe.allow_as_intermediate,
    hide_from_player_crafting = disabled_recipe.hide_from_player_crafting,
    result = disabled_recipe.results and disabled_recipe.results[1],
  } or nil
  add_case("raw.recipe.recycle-yis-disabledium-scrap", "disabled source creates a visible recycle recipe without disabling it",
    same_value(normalized_disabled_recipe, exp.recipes.disabled_solid) and disabled_recipe.enabled ~= false,
    nil,
    { expected = exp.recipes.disabled_solid, actual = normalized_disabled_recipe, enabled = disabled_recipe and disabled_recipe.enabled })

  if exp.recipes.fluid then
    local fluid_recipe = data.raw.recipe["yis-recycle-testium-scrap-to-fluid"]
    local normalized_fluid_recipe = fluid_recipe and {
      type = fluid_recipe.type,
      name = fluid_recipe.name,
      hidden = fluid_recipe.hidden or false,
      subgroup = fluid_recipe.subgroup,
      category = fluid_recipe.category,
      allow_as_intermediate = fluid_recipe.allow_as_intermediate,
      hide_from_player_crafting = fluid_recipe.hide_from_player_crafting,
      result = fluid_recipe.results and fluid_recipe.results[1],
    } or nil
    add_case("raw.recipe.recycle-yis-testium-scrap-to-fluid", "fluid recycle recipe matches expected normalized object",
      same_value(normalized_fluid_recipe, exp.recipes.fluid), nil,
      { expected = exp.recipes.fluid, actual = normalized_fluid_recipe })
    add_case("raw.recipe.recycle-yis-testium-scrap-to-fluid.amount", "fluid recycle recipe has patched input amount",
      fluid_recipe and fluid_recipe.ingredients and fluid_recipe.ingredients[1] and
        fluid_recipe.ingredients[1].amount == expected_recycle_input_amount(data_table, "yis-testium-scrap"),
      nil,
      {
        expected = expected_recycle_input_amount(data_table, "yis-testium-scrap"),
        ingredients = fluid_recipe and fluid_recipe.ingredients,
      })
    add_case("raw.recipe.recycle-yis-testium-scrap-to-fluid.icon", "fluid recycle recipe uses the fluid result icon layer",
      fluid_recipe and solid_recipe and data.raw.fluid["molten-yis-testium"] and
        icon_layers_contain(fluid_recipe.icons, data.raw.fluid["molten-yis-testium"].icon) and
        not icon_layers_contain(solid_recipe.icons, data.raw.fluid["molten-yis-testium"].icon),
      nil,
      {
        fluid_icon = data.raw.fluid["molten-yis-testium"] and data.raw.fluid["molten-yis-testium"].icon,
        solid_icons = solid_recipe and solid_recipe.icons,
        fluid_icons = fluid_recipe and fluid_recipe.icons,
      })

    local solution_recipe = data.raw.recipe["yis-recycle-solvium-scrap-to-fluid"]
    local normalized_solution_recipe = solution_recipe and {
      type = solution_recipe.type,
      name = solution_recipe.name,
      hidden = solution_recipe.hidden or false,
      subgroup = solution_recipe.subgroup,
      category = solution_recipe.category,
      allow_as_intermediate = solution_recipe.allow_as_intermediate,
      hide_from_player_crafting = solution_recipe.hide_from_player_crafting,
      result = solution_recipe.results and solution_recipe.results[1],
    } or nil
    add_case("raw.recipe.recycle-yis-solvium-scrap-to-fluid", "fluid suffix recycle recipe matches expected normalized object",
      same_value(normalized_solution_recipe, exp.recipes.solution_fluid), nil,
      { expected = exp.recipes.solution_fluid, actual = normalized_solution_recipe })
    add_case("raw.recipe.recycle-yis-solvium-scrap-to-fluid.amount", "fluid suffix recycle recipe has patched input amount",
      solution_recipe and solution_recipe.ingredients and solution_recipe.ingredients[1] and
        solution_recipe.ingredients[1].amount == expected_recycle_input_amount(data_table, "yis-solvium-scrap"),
      nil,
      {
        expected = expected_recycle_input_amount(data_table, "yis-solvium-scrap"),
        ingredients = solution_recipe and solution_recipe.ingredients,
      })
    add_case("raw.technology.prefix-fluid-unlock", "prefix fluid recycle recipe is unlocked when fluid recipes are enabled",
      technology_unlocks_recipe("yis-recycle-testium-scrap-to-fluid"))
    add_case("raw.technology.suffix-fluid-unlock", "suffix fluid recycle recipe is unlocked when fluid recipes are enabled",
      technology_unlocks_recipe("yis-recycle-solvium-scrap-to-fluid"))

    local hidden_fluid_recipe = data.raw.recipe["yis-recycle-hiddenfluidium-scrap-to-fluid"]
    local normalized_hidden_fluid_recipe = hidden_fluid_recipe and {
      type = hidden_fluid_recipe.type,
      name = hidden_fluid_recipe.name,
      hidden = hidden_fluid_recipe.hidden or false,
      subgroup = hidden_fluid_recipe.subgroup,
      category = hidden_fluid_recipe.category,
      allow_as_intermediate = hidden_fluid_recipe.allow_as_intermediate,
      hide_from_player_crafting = hidden_fluid_recipe.hide_from_player_crafting,
      result = hidden_fluid_recipe.results and hidden_fluid_recipe.results[1],
    } or nil
    add_case("raw.recipe.recycle-yis-hiddenfluidium-scrap-to-fluid", "hidden fluid source creates a hidden recycle recipe without disabling it",
      same_value(normalized_hidden_fluid_recipe, exp.recipes.hidden_fluid), nil,
      { expected = exp.recipes.hidden_fluid, actual = normalized_hidden_fluid_recipe })
  else
    add_case("raw.recipe.no-prefix-fluid-recycle", "prefix fluid recycle recipe is absent when fluids are disabled",
      data.raw.recipe["yis-recycle-testium-scrap-to-fluid"] == nil)
    add_case("raw.recipe.no-suffix-fluid-recycle", "suffix fluid recycle recipe is absent when fluids are disabled",
      data.raw.recipe["yis-recycle-solvium-scrap-to-fluid"] == nil)
    add_case("raw.recipe.no-hidden-fluid-recycle", "hidden fluid recycle recipe is absent when fluids are disabled",
      data.raw.recipe["yis-recycle-hiddenfluidium-scrap-to-fluid"] == nil)
  end

  for recipe_name, expected_result in pairs(exp.inserts) do
    local actual = scrap_results(data.raw.recipe[recipe_name])
    add_case("raw.patch." .. recipe_name, recipe_name .. " data.raw patch has expected scrap result",
      #actual == 1 and same_value(actual[1], expected_result), nil,
      { expected = expected_result, actual = actual })
  end

  if not ISsettings.fluids then
    add_case("raw.patch.no-prefix-fluid-scrap", "prefix fluid fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-yis-testium-fluid"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-yis-testium-fluid"]) })
    add_case("raw.patch.no-suffix-fluid-scrap", "suffix fluid fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-yis-solvium-solution"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-yis-solvium-solution"]) })
    add_case("raw.patch.no-fluid-main-product-scrap", "fluid main product fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-yis-testium-fluid-main-product"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-yis-testium-fluid-main-product"]) })
    add_case("raw.patch.no-hidden-fluid-scrap", "hidden fluid fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-yis-hiddenfluidium-fluid"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-yis-hiddenfluidium-fluid"]) })
    add_case("raw.technology.no-prefix-fluid-unlock", "prefix fluid recycle recipe is not unlocked when fluid recipes are disabled",
      not technology_unlocks_recipe("yis-recycle-testium-scrap-to-fluid"))
    add_case("raw.technology.no-suffix-fluid-unlock", "suffix fluid recycle recipe is not unlocked when fluid recipes are disabled",
      not technology_unlocks_recipe("yis-recycle-solvium-scrap-to-fluid"))
  end

  local tech = data.raw.technology["yis-recycle-testium-scrap"]
  add_case("raw.technology.visible-during-development", "generated recycle technologies stay visible during development",
    tech and tech.hidden == false,
    nil,
    { expected = false, actual = tech and tech.hidden, shallow_log = ISsettings.shallow_log, hide_tech = ISsettings.hide_tech })
  local normalized_tech = tech and {
    type = tech.type,
    name = tech.name,
    effect = tech.effects and tech.effects[1],
    research_trigger = tech.research_trigger,
  } or nil
  add_case("raw.technology.recycle-yis-testium-scrap", "yis-testium recycle technology matches expected normalized object",
    same_value(normalized_tech, exp.technology), nil,
    { expected = exp.technology, actual = normalized_tech })
  add_case("raw.technology.recycle-yis-testium-scrap.icon-tint", "technology scrap icon layer uses the scrap material tint",
    tech and tech.icons and tech.icons[2] and item and item.icons and item.icons[1] and
      tech.icons[2].icon == "__Ingredient_Scrap__/graphics/icons/scrap-128.png" and
      same_value(tech.icons[2].tint, item.icons[1].tint),
    nil,
    {
      technology_layer = tech and tech.icons and tech.icons[2],
      item_tint = item and item.icons and item.icons[1] and item.icons[1].tint,
    })
  add_case("raw.technology.recycle-yis-testium-scrap.result-icon", "technology icon includes the recycle result item layer",
    tech and data.raw.item["yis-testium-plate"] and
      icon_layers_contain(tech.icons, data.raw.item["yis-testium-plate"].icon),
    nil,
    {
      expected_icon = data.raw.item["yis-testium-plate"] and data.raw.item["yis-testium-plate"].icon,
      icons = tech and tech.icons,
    })
  add_case("raw.technology.no-phantom", "no recipe-specific phantom technology is created",
    data.raw.technology["yis-test-yis-testium-no-tech"] == nil)

  return report
end

return runner


