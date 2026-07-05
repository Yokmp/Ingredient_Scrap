local expected = require("tools.test.expected")
local material_resolver = require("code.resolver.materials.resolver")
local material_flow = require("code.resolver.debug.material-flow")
local data_table_writer = require("code.data_table.writer")
require("code.override.categories")
local source_overrides = require("code.override.sources")
require("code.compat.vanilla-materials")
require("code.compat.mod-materials")
require("tools.test.material-overrides")
local material_overrides = require("code.override.materials")

local runner = {}

---Returns true when an array-like table contains the requested value.
local function array_contains(values, value)
  for _, item in ipairs(values or {}) do
    if item == value then return true end
  end
  return false
end

---Returns true when any array entry satisfies the predicate.
local function table_contains(values, predicate)
  for _, item in ipairs(values or {}) do
    if predicate(item) then return true end
  end
  return false
end

---Returns true for the tiny Base + Ingredient Scrap profile used for fragile vanilla-only compatibility patches.
local function is_small_vanilla_profile()
  local allowed = {
    base = true,
    Ingredient_Scrap = true,
  }
  for mod_name, _ in pairs(mods or {}) do
    if not allowed[mod_name] then return false end
  end
  return true
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

---Returns the passive production-flow classification for a typed prototype key.
local function production_node_class(production_flow, prototype_type, name)
  local key = prototype_type .. "/" .. name
  local node = production_flow and production_flow.classification and
    production_flow.classification.nodes and production_flow.classification.nodes[key]
  return node and node.class
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

---Returns the first unlock effect for a recipe in the given technology.
local function technology_unlock_effect(tech, recipe_name)
  for _, effect in ipairs((tech and tech.effects) or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
      return effect
    end
  end
  return nil
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
---Runs the Factorio data-stage assertion suite and returns a JSON-ready report.
function runner.run(production_flow_dump)
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
    type(yokmods.ingredient_scrap.api.functions.is_log) == "function")
  add_case("settings.fluids-always-on", "fluid handling stays enabled even when the hidden startup setting or test profile disables it",
    ISsettings.fluids == true,
    nil,
    { startup_setting = ISsettings.fluid_setting, effective = ISsettings.fluids })
  add_case("names.scrap-prefix", "scrap item names receive the yis prefix only once",
    yokmods.ingredient_scrap.api.functions.get_scrap_name("yis-testium") == "yis-testium-scrap" and
      yokmods.ingredient_scrap.api.functions.get_scrap_name("testium") == "yis-testium-scrap")
  add_case("names.recycle-prefix", "recycle recipe and technology names receive the yis prefix only once",
    yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("yis-testium") == "yis-recycle-testium-scrap" and
      yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("testium") == "yis-recycle-testium-scrap")
  add_case("names.no-double-yis-prototypes", "generated scrap items, recycle recipes, and technologies do not double-prefix yis materials",
    data_table.prototypes.items["yis-yis-testium-scrap"] == nil and
      data_table.prototypes.recipes["yis-recycle-yis-testium-scrap"] == nil and
      data_table.prototypes.technology["yis-recycle-yis-testium-scrap"] == nil)
  add_case("architecture.resolver.active-only", "old recipe-chain resolver is not present in active debug output",
    data_table.debug and data_table.debug.recipe_chain_analysis == nil and
      data_table.debug.recipe_chain_decisions == nil)
  add_case("architecture.patch-queue.phase-fifo", "post-resolver patch queue records phase-local FIFO execution order",
    data_table.debug and data_table.debug.patch_queue and
      data_table.debug.patch_queue.mode == "phase-fifo" and
      data_table.debug.patch_queue.phases and
      data_table.debug.patch_queue.phases[1] == "prototype" and
      data_table.debug.patch_queue.phases[2] == "mutate" and
      data_table.debug.patch_queue.phases[3] == "finalize" and
      data_table.debug.patch_queue.history and
      data_table.debug.patch_queue.history[1] and
      data_table.debug.patch_queue.history[1].phase == "mutate" and
      data_table.debug.patch_queue.history[1].type == "internal-handler" and
      data_table.debug.patch_queue.history[1].registration_index == 1 and
      (
        (is_small_vanilla_profile() and
          data_table.debug.patch_queue.history[1].label == "compat-satellite" and
          data_table.debug.patch_queue.history[2] and
          data_table.debug.patch_queue.history[2].label == "compat-fish" and
          data_table.debug.patch_queue.history[2].registration_index == 2) or
        ((not is_small_vanilla_profile()) and
          data_table.debug.patch_queue.history[1].label == "compat-fish")
      ),
    nil,
    data_table.debug and data_table.debug.patch_queue)

  local production_flow = production_flow_dump or material_flow.build_production_flow()
  add_case("analysis.production-flow.classification", "production-flow dump includes passive node classifications",
    production_flow and
      production_flow.schema == "ingredient-scrap-production-flow/v1" and
      production_flow.classification and
      production_flow.classification.summary and
      production_flow.classification.nodes and
      production_flow.classification.by_class and
      production_flow.classification.summary.production and
      production_flow.classification.summary.smelting_process and
      production_flow.classification.summary.chemical,
    nil,
    production_flow and production_flow.classification and production_flow.classification.summary)
  add_case("analysis.production-flow.iron-ore-process", "production-flow classifies iron ore as process evidence when present",
    not data.raw.item["iron-ore"] or
      production_node_class(production_flow, "item", "iron-ore") == "smelting_process",
    nil,
    production_flow and production_flow.classification and
      production_flow.classification.nodes and production_flow.classification.nodes["item/iron-ore"])
  add_case("analysis.production-flow.iron-plate-production", "production-flow classifies iron plate as downstream production material when present",
    not data.raw.item["iron-plate"] or
      production_node_class(production_flow, "item", "iron-plate") == "production",
    nil,
    production_flow and production_flow.classification and
      production_flow.classification.nodes and production_flow.classification.nodes["item/iron-plate"])
  add_case("analysis.production-flow.sulfuric-acid-chemical", "production-flow keeps sulfuric acid in chemical evidence when present",
    not data.raw.fluid["sulfuric-acid"] or
      production_node_class(production_flow, "fluid", "sulfuric-acid") == "chemical",
    nil,
    production_flow and production_flow.classification and
      production_flow.classification.nodes and production_flow.classification.nodes["fluid/sulfuric-acid"])
  local passive_runtime = data_table.debug and data_table.debug.passive_runtime
  local passive_ancestry = passive_runtime and passive_runtime.ancestry
  add_case("analysis.ancestry-runtime.exists", "passive runtime ancestry analysis is available without patching prototypes",
    passive_runtime and
      passive_runtime.schema == "ingredient-scrap-passive-runtime/v1" and
      passive_ancestry and
      passive_ancestry.schema == "ingredient-scrap-passive-runtime-ancestry/v1" and
      passive_ancestry.mode == ISsettings.ancestry_policy.mode and
      passive_ancestry.root_policy == ISsettings.ancestry_policy.root_policy and
      passive_ancestry.mixed_limit == ISsettings.ancestry_policy.mixed_limit and
      passive_ancestry.max_depth == ISsettings.ancestry_policy.max_depth,
    nil,
    passive_ancestry and {
      schema = passive_ancestry.schema,
      mode = passive_ancestry.mode,
      root_policy = passive_ancestry.root_policy,
      mixed_limit = passive_ancestry.mixed_limit,
      max_depth = passive_ancestry.max_depth,
      component_fallback = passive_ancestry.component_fallback,
    })
  add_case("analysis.ancestry-runtime.summary", "passive runtime ancestry summary matches comparison rows",
    passive_ancestry and
      passive_ancestry.summary and
      passive_ancestry.summary.comparisons and
      passive_ancestry.summary.comparisons.same and
      #(passive_ancestry.comparisons or {}) > 0 and
      ((passive_ancestry.summary.comparisons.same or 0) +
        (passive_ancestry.summary.comparisons.different or 0) +
        (passive_ancestry.summary.comparisons.unresolved or 0)) == #(passive_ancestry.comparisons or {}),
    nil,
    passive_ancestry and passive_ancestry.summary)
  add_case("analysis.ancestry-runtime.items", "passive runtime ancestry records resolved item evidence",
    passive_ancestry and
      passive_ancestry.items and
      passive_ancestry.root_aliases and
      passive_ancestry.exact_components and
      passive_ancestry.items["yis-testium-plate"] and
      passive_ancestry.items["yis-testium-plate"].composition and
      passive_ancestry.items["yis-testium-plate"].composition["yis-testium"] and
      (
        passive_ancestry.root_policy ~= "resources" or
        (
          passive_ancestry.root_aliases["yis-testium-plate"] == "yis-testium" and
          passive_ancestry.root_aliases["yis-testium-ore"] == "yis-testium" and
          passive_ancestry.root_aliases["yis-hiddenium-plate"] == "yis-hiddenium" and
          passive_ancestry.root_aliases["yis-quietium-plate"] == "yis-quietium"
        )
      ),
    nil,
    passive_ancestry and {
      item = passive_ancestry.items and passive_ancestry.items["yis-testium-plate"],
      root_aliases = passive_ancestry.root_aliases,
    })
  local active_ancestry = data_table.debug and data_table.debug.active_ancestry
  local resolver_report = data_table.debug and data_table.debug.resolver
  add_case("analysis.resolver.summary", "resolver entrypoint records active ancestry summary",
    resolver_report and
      resolver_report.schema == "ingredient-scrap-resolver/v2" and
      resolver_report.active_only == true and
      resolver_report.baseline == nil and
      resolver_report.active and
      resolver_report.active.schema == "ingredient-scrap-resolver-active/v2" and
      resolver_report.active.skipped == false,
    nil,
    resolver_report)
  if active_ancestry then
    add_case("analysis.active-ancestry.summary", "active ancestry records its applied direct-output summary",
      active_ancestry and
        active_ancestry.schema == "ingredient-scrap-active-ancestry/v1" and
        active_ancestry.mode == ISsettings.ancestry_policy.mode and
        active_ancestry.root_policy == ISsettings.ancestry_policy.root_policy and
        active_ancestry.summary and
        active_ancestry.summary.rewritten_recipes ~= nil and
        active_ancestry.summary.applied_rows ~= nil and
        active_ancestry.summary.skipped_rows ~= nil and
        active_ancestry.summary.mixed_rows ~= nil,
      nil,
      active_ancestry and {
        schema = active_ancestry.schema,
        mode = active_ancestry.mode,
        root_policy = active_ancestry.root_policy,
        summary = active_ancestry.summary,
      })
    local mixed_rounding = active_ancestry and active_ancestry.mixed_rounding
    local floor_rounding = mixed_rounding and mixed_rounding.floor
    local ceil_rounding = mixed_rounding and mixed_rounding.ceil
    local mixed_rows = active_ancestry and active_ancestry.summary and active_ancestry.summary.mixed_rows or 0
    add_case("analysis.active-ancestry.mixed-rounding", "active ancestry exposes floor/ceil mixed-scrap rounding calibration",
      mixed_rounding and
        floor_rounding and
        ceil_rounding and
        floor_rounding.count == ceil_rounding.count and
        floor_rounding.total ~= nil and
        ceil_rounding.total ~= nil and
        floor_rounding.avg ~= nil and
        ceil_rounding.avg ~= nil and
        (
          (mixed_rows == 0 and floor_rounding.count == 0) or
          (mixed_rows > 0 and floor_rounding.count > 0)
        ),
      nil,
      mixed_rounding)
    local mixed_distribution = active_ancestry and active_ancestry.mixed_recycle_distribution
    local top_targets = mixed_distribution and mixed_distribution.top_targets or {}
    local top_target = top_targets[1]
    local sorted_top_targets = true
    for index = 2, #top_targets do
      local previous = top_targets[index - 1]
      local current = top_targets[index]
      if previous.expected_weight < current.expected_weight then
        sorted_top_targets = false
        break
      end
    end
    add_case("analysis.active-ancestry.mixed-recycle-distribution", "mixed scrap recycling uses a weighted 60 percent rank distribution",
      (
        mixed_rows == 0 and mixed_distribution == nil
      ) or (
        mixed_rows > 0 and
        mixed_distribution and
        mixed_distribution.target_count > 0 and
        math.abs((mixed_distribution.total_probability or 0) - 0.60) < 0.000001 and
        top_target and
        math.abs((top_target.probability or 0) - 0.20) < 0.000001 and
        sorted_top_targets
      ),
      nil,
      mixed_distribution)
    local mixed_recycle_recipe = data.raw.recipe["yis-recycle-mixed-scrap"]
    add_case("analysis.active-ancestry.mixed-recycle-recycler-only", "mixed scrap sorting uses the recycler category only",
      (
        mixed_rows == 0 and mixed_recycle_recipe == nil
      ) or (
        mixed_rows > 0 and
        mixed_recycle_recipe and
        mixed_recycle_recipe.category == "recycling" and
        mixed_recycle_recipe.enabled == false and
        mixed_recycle_recipe.hide_from_player_crafting == true
      ),
      nil,
      {
        mixed_rows = mixed_rows,
        recipe_category = mixed_recycle_recipe and mixed_recycle_recipe.category,
        enabled = mixed_recycle_recipe and mixed_recycle_recipe.enabled,
        hide_from_player_crafting = mixed_recycle_recipe and mixed_recycle_recipe.hide_from_player_crafting,
      })
  end
  local recipe_forms = passive_runtime and passive_runtime.recipe_forms
  add_case("analysis.recipe-forms.exists", "passive recipe-form classification is available without patching prototypes",
    recipe_forms and
      recipe_forms.schema == "ingredient-scrap-recipe-forms/v1" and
      recipe_forms.root_philosophy == "recipe-derived-with-edge-case-overrides" and
      recipe_forms.resource_outputs and
      recipe_forms.item_classes and
      recipe_forms.recipe_results and
      recipe_forms.summary,
    nil,
    recipe_forms and {
      schema = recipe_forms.schema,
      root_philosophy = recipe_forms.root_philosophy,
      summary = recipe_forms.summary,
    })
  add_case("analysis.recipe-forms.resource-roots", "recipe-form classification records resource outputs as root evidence",
    recipe_forms and
      recipe_forms.resource_outputs and
      recipe_forms.item_classes and
      recipe_forms.summary and
      recipe_forms.summary.resource_outputs and
      recipe_forms.summary.resource_outputs > 0,
    nil,
    recipe_forms and {
      resource_outputs = recipe_forms.summary and recipe_forms.summary.resource_outputs,
      iron_ore = recipe_forms.resource_outputs and recipe_forms.resource_outputs["iron-ore"],
    })
  add_case("analysis.recipe-forms.first-material-product", "recipe-form classification derives first material products from resource outputs",
    recipe_forms and
      recipe_forms.summary and
      recipe_forms.summary.item_classes and
      recipe_forms.summary.item_classes.first_material_product and
      recipe_forms.summary.item_classes.first_material_product > 0,
    nil,
    recipe_forms and {
      summary = recipe_forms.summary,
      iron_plate = recipe_forms.item_classes and recipe_forms.item_classes["iron-plate"],
    })
  add_case("architecture.recipe-chain.legacy-disabled", "legacy recipe-chain decider is not active",
    data_table.debug and data_table.debug.recipe_chain_decisions == nil)

  local api = yokmods.ingredient_scrap.api or {}
  local api_functions = api.functions or {}
  add_case("api.legacy-globals-removed", "legacy root-level mutation helpers are no longer public",
    yokmods.ingredient_scrap.add_recipe_results == nil and
      yokmods.ingredient_scrap.get_main_product == nil and
      yokmods.ingredient_scrap.is_log == nil and
      yokmods.ingredient_scrap.scrap_amount_range == nil and
      yokmods.ingredient_scrap.get_recycle_recipe_name == nil and
      yokmods.ingredient_scrap.get_scrap_name == nil)
  add_case("api.functions", "public utility helpers live under api.functions",
    type(api_functions.is_log) == "function" and
      type(api_functions.scrap_amount_range) == "function" and
      type(api_functions.get_recycle_recipe_name) == "function" and
      type(api_functions.get_scrap_name) == "function" and
      type(api_functions.get_icon_layers) == "function")
  add_case("api.material", "public material API exposes nested register and ignore wrappers",
    api.register and api.register.material and api.ignore and
      type(api.register.material.override) == "function" and
      type(api.register.material.auto) == "function" and
      type(api.register.material.solid) == "function" and
      type(api.register.material.fluid) == "function" and
      type(api.register.material.both) == "function" and
      type(api.register.material.alias) == "function" and
      type(api.register.material.setting_icon) == "function" and
      type(api.ignore.material) == "function" and
      yokmods.ingredient_scrap.register_material_override == nil)
  add_case("api.category", "public category API separates furnace and assembling-machine registration",
    api.register and api.register.category and
      type(api.register.category.furnace) == "function" and
      type(api.register.category.assembling_machine) == "function")
  add_case("api.recipe-chain", "public recipe-chain API exposes target override and block wrappers",
    api.register and api.register.recipe_chain and api.ignore and api.ignore.recipe_chain and
      type(api.register.recipe_chain.target) == "function" and
      type(api.register.recipe_chain.solid) == "table" and
      type(api.register.recipe_chain.solid.to_item) == "function" and
      type(api.register.recipe_chain.solid.to_fluid) == "function" and
      type(api.register.recipe_chain.fluid) == "table" and
      type(api.register.recipe_chain.fluid.to_item) == "function" and
      type(api.register.recipe_chain.fluid.to_fluid) == "function" and
      type(api.ignore.recipe_chain.target) == "function" and
      type(api.ignore.recipe_chain.solid) == "function" and
      type(api.ignore.recipe_chain.fluid) == "function" and
      api.register.recipe_chain.solid_target == nil and
      api.register.recipe_chain.fluid_target == nil and
      api.ignore.recipe_chain.solid_target == nil and
      api.ignore.recipe_chain.fluid_target == nil)
  add_case("api.source", "public source API exposes recipe and category ignore wrappers",
    api.ignore and api.ignore.source and
      type(api.ignore.source.recipe) == "function" and
      type(api.ignore.source.category) == "function")
  api.ignore.source.category("yis-test-source-filter", {
    ingredient_suffixes = { "-ore" },
    ingredient_exclude_prefixes = { "yis-" },
    reason = "test source filter excludes debug ore fixtures",
  })
  api.ignore.source.category("yis-test-source-filter", {
    ingredient_names = { "specific-plate" },
    reason = "test source filter supports multiple rules per category",
  })
  add_case("api.source.filters", "source filters support multiple rules and ingredient exclusions",
    source_overrides.ignored_source(
      { name = "test-ore-source", category = "yis-test-source-filter" },
      { type = "item", name = "iron-ore" },
      "iron",
      "solid"
    ) and
      not source_overrides.ignored_source(
        { name = "test-debug-ore-source", category = "yis-test-source-filter" },
        { type = "item", name = "yis-testium-ore" },
        "yis-testium",
        "solid"
      ) and
      source_overrides.ignored_source(
        { name = "test-specific-source", category = "yis-test-source-filter" },
        { type = "item", name = "specific-plate" },
        "specific",
        "solid"
      ))
  add_case("api.source.skipped-audit", "source filter skips are auditable without hiding excluded debug ores",
    data_table.debug and data_table.debug.sources and data_table.debug.sources.skipped and
      type(data_table.debug.sources.skipped) == "table" and
      not table_contains(data_table.debug.sources.skipped, function(skip)
        return skip.ingredient == "yis-testium-ore"
      end),
    nil,
    { skipped = data_table.debug and data_table.debug.sources and data_table.debug.sources.skipped })
  add_case("api.queue.typed", "public queue exposes typed phase operations without raw handler access",
    api.queue and
      api.queue.patch == nil and
      api.queue.prototype and
      type(api.queue.prototype.item) == "function" and
      type(api.queue.prototype.recipe) == "function" and
      type(api.queue.prototype.technology) == "function" and
      api.queue.mutate and
      type(api.queue.mutate.recipe_results) == "function" and
      type(api.queue.mutate.machine_category) == "function" and
      type(api.queue.mutate.unlock_recipe) == "function")
  add_case("api.generated", "public API exposes generated prototype read-only snapshots",
    api.generated and
      type(api.generated.items) == "function" and
      type(api.generated.recipes) == "function" and
      type(api.generated.fluids) == "function" and
      type(api.generated.technologies) == "function" and
      type(api.generated.techs) == "function" and
      api.generated.items() ~= data_table.prototypes.items and
      api.generated.recipes() ~= data_table.prototypes.recipes and
      api.generated.technologies() ~= data_table.prototypes.technology and
      api.generated.techs() ~= data_table.prototypes.technology and
      api.generated.items()["yis-testium-scrap"] ~= nil and
      api.generated.recipes()["yis-recycle-testium-scrap"] ~= nil)
  local generated_recipes = api.generated and api.generated.recipes and api.generated.recipes()
  local generated_recipe_snapshot = generated_recipes and generated_recipes["yis-recycle-testium-scrap"]
  if generated_recipe_snapshot then generated_recipe_snapshot.subgroup = "mutated-subgroup" end
  add_case("api.generated.snapshot-isolated", "mutating a generated snapshot does not mutate the internal staged prototype",
    generated_recipe_snapshot and
      data_table.prototypes.recipes["yis-recycle-testium-scrap"] and
      data_table.prototypes.recipes["yis-recycle-testium-scrap"].subgroup ~= "mutated-subgroup",
    nil,
    { snapshot = generated_recipe_snapshot, internal = data_table.prototypes.recipes["yis-recycle-testium-scrap"] })

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
  local has_space_age = mods and mods["space-age"] ~= nil
  if has_space_age then
    add_case("materials.override.bacteria-none", "bacteria is known but ignored by default",
      ISsettings.material_modes.bacteria == "none" and
        material_overrides.is_ignored(ISsettings.material_modes.bacteria, "solid") and
        material_overrides.is_ignored(ISsettings.material_modes.bacteria, "fluid"),
      nil,
      { mode = ISsettings.material_modes.bacteria, name = material_overrides.localised_setting_name("bacteria") })
  end
  add_case("materials.override.vanilla-auto", "iron, copper, and active DLC auto materials have material settings without forcing a channel",
    ISsettings.material_modes.iron == "auto" and
      ISsettings.material_modes.copper == "auto" and
      ((not has_space_age) or ISsettings.material_modes.holmium == "auto") and
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
  add_case("materials.override.copper-cable-alias", "vanilla copper cable resolves to copper material",
    material_resolver.resolve_solid("copper-cable", data_table.materials) == "copper")
  if has_space_age then
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
  end
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
  add_case("materials.override.localised-name-active-icons", "material setting names use active override icons and pure text labels",
    material_overrides.localised_setting_name("iron")[2] == "[item=iron-plate]" and
      material_overrides.localised_setting_name("copper")[2] == "[item=copper-plate]" and
      material_overrides.localised_setting_name("steel")[2] == "[item=steel-plate]" and
      material_overrides.localised_setting_name("crude")[2] == "[fluid=crude-oil]" and
      ((not has_space_age) or material_overrides.localised_setting_name("bacteria")[2] == "[item=iron-bacteria]") and
      material_overrides.localised_setting_name("iron")[4][1] == "mod-setting-name.yis-material-iron" and
      material_overrides.localised_setting_name("copper")[4][1] == "mod-setting-name.yis-material-copper" and
      ((not has_space_age) or material_overrides.localised_setting_name("holmium")[4][1] == "mod-setting-name.yis-material-holmium") and
      ((not has_space_age) or material_overrides.localised_setting_name("lithium")[4][1] == "mod-setting-name.yis-material-lithium") and
      ((not has_space_age) or material_overrides.localised_setting_name("ammonia")[4][1] == "mod-setting-name.yis-material-ammonia") and
      material_overrides.localised_setting_name("steel")[4][1] == "mod-setting-name.yis-material-steel" and
      material_overrides.localised_setting_name("crude")[4][1] == "mod-setting-name.yis-material-crude" and
      ((not has_space_age) or material_overrides.localised_setting_name("bacteria")[4][1] == "mod-setting-name.yis-material-bacteria"),
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
      ((not has_space_age) or localised_string_contains(material_overrides.localised_setting_description("holmium"), "Space Age")) and
      localised_string_contains(material_overrides.localised_setting_description("yis-testium"), "Ingredient Scrap Test"),
    nil,
    {
      iron = material_overrides.localised_setting_description("iron"),
      holmium = material_overrides.localised_setting_description("holmium"),
      yis_testium = material_overrides.localised_setting_description("yis-testium"),
    })
  if has_space_age then
    add_case("materials.override.bacteria-locale-icon", "known bacteria uses a locale icon while keeping prototype matching disabled",
      material_overrides.icon_tag("bacteria") == nil and
        material_overrides.localised_setting_name("bacteria")[2] == "[item=iron-bacteria]",
      nil,
      { icon = material_overrides.icon_tag("bacteria"), name = material_overrides.localised_setting_name("bacteria") })
  end
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
    add_case("compat.krastorio2.setting-icons", "Krastorio material settings use active Krastorio icon aliases",
      material_overrides.setting_icon_tag("glass") == "[item=kr-glass]" and
        material_overrides.setting_icon_tag("rare-metal") == "[item=kr-rare-metal-ore]" and
        material_overrides.setting_icon_tag("imersium") == "[item=kr-imersium-plate]" and
        material_overrides.setting_icon_tag("black-reinforced") == "[item=kr-black-reinforced-plate]",
      nil,
      {
        glass = material_overrides.setting_icon_tag("glass"),
        rare_metal = material_overrides.setting_icon_tag("rare-metal"),
        imersium = material_overrides.setting_icon_tag("imersium"),
        black_reinforced = material_overrides.setting_icon_tag("black-reinforced"),
      })
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
  if data.raw.item["bob-aluminium-plate"] then
    add_case("compat.bobs.setting-icons", "Bob material settings use active Bob icon aliases",
      material_overrides.setting_icon_tag("gold") == "[item=bob-gold-plate]" and
        material_overrides.setting_icon_tag("lead") == "[item=bob-lead-plate]" and
        material_overrides.setting_icon_tag("nickel") == "[item=bob-nickel-plate]" and
        material_overrides.setting_icon_tag("invar") == "[item=bob-invar-alloy]" and
        material_overrides.setting_icon_tag("nitinol") == "[item=bob-nitinol-alloy]" and
        material_overrides.setting_icon_tag("glass") == "[item=bob-glass]",
      nil,
      {
        gold = material_overrides.setting_icon_tag("gold"),
        lead = material_overrides.setting_icon_tag("lead"),
        nickel = material_overrides.setting_icon_tag("nickel"),
        invar = material_overrides.setting_icon_tag("invar"),
        nitinol = material_overrides.setting_icon_tag("nitinol"),
        glass = material_overrides.setting_icon_tag("glass"),
      })
    add_case("compat.bobs.alias-prefixed-materials", "Bob's prefixed material prototypes resolve to stable material names",
      material_resolver.resolve_solid("bob-aluminium-plate", data_table.materials) == "aluminium" and
        material_resolver.resolve_solid("bob-brass-alloy", data_table.materials) == "brass" and
        material_resolver.resolve_solid("bob-bronze-alloy", data_table.materials) == "bronze" and
        material_resolver.resolve_solid("bob-copper-tungsten-alloy", data_table.materials) == "copper-tungsten" and
        material_resolver.resolve_solid("bob-gold-ore", data_table.materials) == "gold" and
        material_resolver.resolve_solid("bob-gold-plate", data_table.materials) == "gold" and
        material_resolver.resolve_solid("bob-gunmetal-alloy", data_table.materials) == "gunmetal" and
        material_resolver.resolve_solid("bob-silicon-plate", data_table.materials) == "silicon" and
        material_resolver.resolve_solid("bob-silicon-wafer", data_table.materials) == "silicon" and
        material_resolver.resolve_solid("bob-titanium-plate", data_table.materials) == "titanium" and
        array_contains(data_table.materials.solid, "aluminium") and
        array_contains(data_table.materials.solid, "brass") and
        array_contains(data_table.materials.solid, "copper-tungsten") and
        array_contains(data_table.materials.solid, "gunmetal") and
        array_contains(data_table.materials.solid, "silicon") and
        not array_contains(data_table.materials.solid, "bob-aluminium") and
        not array_contains(data_table.materials.solid, "bob-brass") and
        not array_contains(data_table.materials.solid, "bob-copper-tungsten") and
        not array_contains(data_table.materials.solid, "bob-gold") and
        not array_contains(data_table.materials.solid, "bob-gunmetal") and
        not array_contains(data_table.materials.solid, "bob-silicon"),
      nil,
      { solid = data_table.materials.solid })
    add_case("compat.bobs.alias-component-families", "Bob's component prototypes resolve to stable component families",
      material_resolver.resolve_solid("bob-brass-gear-wheel", data_table.materials) == "gear" and
        material_resolver.resolve_solid("bob-titanium-bearing", data_table.materials) == "bearing" and
        material_resolver.resolve_solid("bob-brass-bearing-ball", data_table.materials) == "bearing-ball" and
        material_resolver.resolve_solid("bob-tinned-copper-cable", data_table.materials) == "cable" and
        material_resolver.resolve_solid("bob-battery-2", data_table.materials) == "battery" and
        material_resolver.resolve_solid("bob-basic-circuit-board", data_table.materials) == "board" and
        material_resolver.resolve_solid("advanced-circuit", data_table.materials) == "circuit" and
        material_resolver.resolve_solid("bob-brass-pipe", data_table.materials) == "pipe" and
        array_contains(data_table.materials.solid, "gear") and
        array_contains(data_table.materials.solid, "bearing") and
        array_contains(data_table.materials.solid, "bearing-ball") and
        array_contains(data_table.materials.solid, "cable") and
        array_contains(data_table.materials.solid, "battery") and
        array_contains(data_table.materials.solid, "board") and
        array_contains(data_table.materials.solid, "circuit") and
        array_contains(data_table.materials.solid, "pipe"),
      nil,
      { solid = data_table.materials.solid })
    local titanium_bearing_scrap = yokmods.ingredient_scrap.api.functions.get_scrap_name("bob-titanium-bearing")
    local titanium_bearing_recipe = data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("bob-titanium-bearing")]
    local titanium_bearing_result = titanium_bearing_recipe and titanium_bearing_recipe.results and titanium_bearing_recipe.results[1]
    local brass_pipe_scrap = yokmods.ingredient_scrap.api.functions.get_scrap_name("bob-brass-pipe")
    local brass_pipe_recipe = data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("bob-brass-pipe")]
    local brass_pipe_result = brass_pipe_recipe and brass_pipe_recipe.results and brass_pipe_recipe.results[1]
    local processing_unit_scrap = yokmods.ingredient_scrap.api.functions.get_scrap_name("processing-unit")
    local processing_unit_recipe = data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("processing-unit")]
    local processing_unit_result = processing_unit_recipe and processing_unit_recipe.results and processing_unit_recipe.results[1]
    local component_heavy = ISsettings.ancestry_policy.mode == "component-heavy"
    if component_heavy then
      add_case("compat.bobs.component-exact-scrap", "component-heavy mode keeps component scrap and recycle targets exact",
        data.raw.item[titanium_bearing_scrap] and
          titanium_bearing_result and titanium_bearing_result.name == "bob-titanium-bearing" and
          data.raw.item[brass_pipe_scrap] and
          brass_pipe_result and brass_pipe_result.name == "bob-brass-pipe" and
          data.raw.item[processing_unit_scrap] and
          processing_unit_result and processing_unit_result.name == "processing-unit" and
          data.raw.item["yis-bearing-scrap"] == nil and
          data.raw.recipe["yis-recycle-bearing-scrap"] == nil,
        nil,
        {
          titanium_bearing = {
            scrap = titanium_bearing_scrap,
            result = titanium_bearing_result,
          },
          brass_pipe = {
            scrap = brass_pipe_scrap,
            result = brass_pipe_result,
          },
          processing_unit = {
            scrap = processing_unit_scrap,
            result = processing_unit_result,
          },
        })
    else
      local brass_pipe_insert = data_table.inserts.recipes["bob-brass-pipe"]
      local titanium_bearing_insert = data_table.inserts.recipes["bob-titanium-bearing"]
      local brass_recycle = data.raw.recipe["yis-recycle-brass-scrap"]
      local titanium_recycle = data.raw.recipe["yis-recycle-titanium-scrap"]
      local mixed_scrap = yokmods.ingredient_scrap.api.functions.get_scrap_name("yis-mixed")
      local mixed_recycle = data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("yis-mixed")]
      local active_ancestry = data_table.debug and data_table.debug.active_ancestry
      local mixed_pseudo_results = 0
      local normalized_mixed_pseudo_results = 0
      local mixed_floor_amount_matches = 0
      local mixed_floor_range_matches = 0
      for _, insert in pairs(data_table.inserts.recipes or {}) do
        for _, result in ipairs((insert and insert.results) or {}) do
          if result.name and result.name:sub(1, #mixed_scrap + 1) == mixed_scrap .. "_" and
              data_table_writer.final_result_name(result.name) == mixed_scrap then
            mixed_pseudo_results = mixed_pseudo_results + 1
            if result.yis_normalized_after_results == true and
                (result.amount ~= nil or (result.amount_min ~= nil and result.amount_max ~= nil)) then
              normalized_mixed_pseudo_results = normalized_mixed_pseudo_results + 1
            end
            if result.yis_source_amount then
              local floor_variants = yokmods.ingredient_scrap.api.functions.scrap_amount_rounding_variants(result.yis_source_amount).floor
              if result.amount == floor_variants.avg then
                mixed_floor_amount_matches = mixed_floor_amount_matches + 1
              end
              if result.amount_min == floor_variants.min and result.amount_max == floor_variants.max then
                mixed_floor_range_matches = mixed_floor_range_matches + 1
              end
            end
          end
        end
      end
      local raw_mixed_pseudo_results = 0
      for _, recipe in pairs(data.raw.recipe or {}) do
        for _, result in ipairs((recipe and recipe.results) or {}) do
          if result.name and result.name:sub(1, #mixed_scrap + 1) == mixed_scrap .. "_" then
            raw_mixed_pseudo_results = raw_mixed_pseudo_results + 1
          end
        end
      end
      local brass_recycle_result = brass_recycle and brass_recycle.results and brass_recycle.results[1]
      local titanium_recycle_result = titanium_recycle and titanium_recycle.results and titanium_recycle.results[1]
      add_case("compat.bobs.component-ancestry-scrap", "active ancestry collapses simple Bob components and sends broad components to mixed scrap",
        data.raw.item[brass_pipe_scrap] == nil and
          data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("bob-brass-pipe")] == nil and
          data.raw.item[titanium_bearing_scrap] == nil and
          data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("bob-titanium-bearing")] == nil and
          find_result(brass_pipe_insert and brass_pipe_insert.results, "yis-brass-scrap") and
          find_result(titanium_bearing_insert and titanium_bearing_insert.results, "yis-titanium-scrap") and
          brass_recycle_result and brass_recycle_result.name == "bob-brass-alloy" and
          titanium_recycle_result and titanium_recycle_result.name == "bob-titanium-plate" and
          data.raw.item[processing_unit_scrap] == nil and
          data.raw.recipe[yokmods.ingredient_scrap.api.functions.get_recycle_recipe_name("processing-unit")] == nil and
          data.raw.item[mixed_scrap] and
          mixed_recycle and mixed_recycle.results and mixed_recycle.results[1] and
          mixed_pseudo_results > 0 and
          normalized_mixed_pseudo_results == mixed_pseudo_results and
          (
            (ISsettings.fixed_amount and mixed_floor_amount_matches == mixed_pseudo_results) or
            (not ISsettings.fixed_amount and mixed_floor_range_matches == mixed_pseudo_results)
          ) and
          raw_mixed_pseudo_results == 0 and
          active_ancestry and active_ancestry.summary and active_ancestry.summary.mixed_rows > 0,
        nil,
        {
          brass_pipe = {
            exact_scrap = brass_pipe_scrap,
            insert = brass_pipe_insert,
            recycle_result = brass_recycle_result,
          },
          titanium_bearing = {
            exact_scrap = titanium_bearing_scrap,
            insert = titanium_bearing_insert,
            recycle_result = titanium_recycle_result,
          },
          processing_unit = {
            exact_scrap = processing_unit_scrap,
            mixed_scrap = mixed_scrap,
            mixed_recycle = mixed_recycle,
            mixed_pseudo_results = mixed_pseudo_results,
            normalized_mixed_pseudo_results = normalized_mixed_pseudo_results,
            mixed_floor_amount_matches = mixed_floor_amount_matches,
            mixed_floor_range_matches = mixed_floor_range_matches,
            raw_mixed_pseudo_results = raw_mixed_pseudo_results,
            active_summary = active_ancestry and active_ancestry.summary,
          },
        })
    end
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
  local recycler_recipe = data.raw.recipe["yis-recycle-mixed-scrap"]
  add_case("categories.recycler.required-for-mixed-scrap", "mixed scrap has a recycler that accepts the recycling category",
    data.raw.furnace.recycler and
      data.raw.item.recycler and
      data.raw.recipe.recycler and
      category_count(data.raw.furnace.recycler, "recycling") == 1 and
      (not recycler_recipe or recycler_recipe.category == "recycling"),
    nil,
    {
      entity = data.raw.furnace.recycler,
      item = data.raw.item.recycler,
      recipe = data.raw.recipe.recycler,
      mixed_recycle_category = recycler_recipe and recycler_recipe.category,
    })
  if data.raw.furnace.recycler then
    add_case("categories.furnace.recycler", "quality recycler can craft item recycle recipes",
      category_count(data.raw.furnace.recycler, "recycling") > 0 and
        category_count(data.raw.furnace.recycler, recycle_item_category) == 1,
      nil,
      { categories = data.raw.furnace.recycler.crafting_categories })
    if not mods["quality"] then
      add_case("categories.furnace.fallback-recycler", "Ingredient Scrap fallback recycler is available without Quality",
        data.raw.item.recycler and
          data.raw.recipe.recycler and
          data.raw.recipe.recycler.results and
          data.raw.recipe.recycler.results[1] and
          data.raw.recipe.recycler.results[1].name == "recycler",
        nil,
        {
          item = data.raw.item.recycler ~= nil,
          recipe = data.raw.recipe.recycler,
        })
    end
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
  local furnace_width_audit = data_table.debug and data_table.debug.furnace_result_inventory
  local narrow_furnace = nil
  for _, furnace in pairs(data.raw.furnace or {}) do
    for _, crafting_category in ipairs(furnace.crafting_categories or {}) do
      local required_width = furnace_width_audit
        and furnace_width_audit.max_width_by_category
        and furnace_width_audit.max_width_by_category[crafting_category]
        or 0
      if required_width > (furnace.result_inventory_size or 0) then
        narrow_furnace = {
          name = furnace.name,
          category = crafting_category,
          required = required_width,
          actual = furnace.result_inventory_size,
        }
        break
      end
    end
    if narrow_furnace then break end
  end
  add_case("categories.furnace.result-inventory-width", "furnace output slots fit the widest supported item-result recipe",
    furnace_width_audit and narrow_furnace == nil,
    nil,
    {
      narrow = narrow_furnace,
      audit = furnace_width_audit,
    })

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

  local function fast_replaceable_group_summary(group_name, expected_category)
    local total = 0
    local patched = 0
    local machines = {}
    for _, prototype_type in ipairs({ "furnace", "assembling-machine" }) do
      for _, machine in pairs(data.raw[prototype_type] or {}) do
        if machine.fast_replaceable_group == group_name then
          total = total + 1
          if category_count(machine, expected_category) == 1 then
            patched = patched + 1
          end
          table.insert(machines, {
            name = machine.name,
            type = prototype_type,
            categories = machine.crafting_categories,
          })
        end
      end
    end
    return {
      total = total,
      patched = patched,
      machines = machines,
    }
  end

  local angels_casting = fast_replaceable_group_summary("angels-casting-machine", recycle_item_category)
  if angels_casting.total > 0 then
    add_case("categories.angels.casting-solid", "Angel's casting machines accept solid recycle recipes",
      angels_casting.patched == angels_casting.total,
      nil,
      angels_casting)
  end
  local angels_induction = fast_replaceable_group_summary("angels-induction-furnace", recycle_fluid_category)
  if angels_induction.total > 0 then
    add_case("categories.angels.induction-fluid", "Angel's induction furnaces accept fluid recycle recipes",
      angels_induction.patched == angels_induction.total,
      nil,
      angels_induction)
  end

  local function partially_patched_fast_replaceable_groups(prototype_type, recycle_category, fluid_only)
    local groups = {}
    local partial = {}

    for _, machine in pairs(data.raw[prototype_type] or {}) do
      local group = machine.fast_replaceable_group
      if group then
        local info = groups[group] or { total = 0, eligible = 0, patched = 0, machines = {} }
        local eligible = not fluid_only or machine.fluid_boxes ~= nil
        info.total = info.total + 1
        if eligible then
          info.eligible = info.eligible + 1
          if category_count(machine, recycle_category) == 1 then
            info.patched = info.patched + 1
          end
        end
        table.insert(info.machines, {
          name = machine.name,
          eligible = eligible,
          categories = machine.crafting_categories,
        })
        groups[group] = info
      end
    end

    for group, info in pairs(groups) do
      if info.patched > 0 and info.patched < info.eligible then
        partial[group] = info
      end
    end

    return partial
  end

  local partial_item_furnaces = partially_patched_fast_replaceable_groups("furnace", recycle_item_category, false)
  local partial_item_assemblers = partially_patched_fast_replaceable_groups("assembling-machine", recycle_item_category, false)
  local partial_fluid_furnaces = partially_patched_fast_replaceable_groups("furnace", recycle_fluid_category, true)
  local partial_fluid_assemblers = partially_patched_fast_replaceable_groups("assembling-machine", recycle_fluid_category, true)
  add_case("categories.fast-replaceable.item-consistent", "fast-replaceable machine tiers are consistently patched for item recycling",
    table_size(partial_item_furnaces) == 0 and table_size(partial_item_assemblers) == 0,
    nil,
    { furnaces = partial_item_furnaces, assembling_machines = partial_item_assemblers })
  add_case("categories.fast-replaceable.fluid-consistent", "fast-replaceable fluid-capable machine tiers are consistently patched for fluid recycling",
    table_size(partial_fluid_furnaces) == 0 and table_size(partial_fluid_assemblers) == 0,
    nil,
    { furnaces = partial_fluid_furnaces, assembling_machines = partial_fluid_assemblers })

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
  local active_lookup_direct = ISsettings.ancestry_policy
    and ISsettings.ancestry_policy.mode ~= "component-heavy"
    and ISsettings.ancestry_policy.root_policy ~= "resources"
  local item_like_recipe_cases = {
    { id = "ammo", recipe = "firearm-magazine", prototype_type = "ammo" },
    { id = "capsule", recipe = "grenade", prototype_type = "capsule" },
    { id = "gun", recipe = "submachine-gun", prototype_type = "gun" },
    { id = "armor", recipe = "light-armor", prototype_type = "armor" },
    { id = "equipment", recipe = "personal-laser-defense-equipment", prototype_type = "item" },
  }
  for _, case in ipairs(item_like_recipe_cases) do
    if active_lookup_direct and data.raw.recipe[case.recipe] then
      add_case("raw.patch.item-like-main-product." .. case.id, "item-like main product recipe creates scrap: " .. case.recipe,
        insert_has_results(data_table, case.recipe),
        nil,
        {
          prototype_type = case.prototype_type,
          recipe = data.raw.recipe[case.recipe],
          insert = data_table.inserts.recipes[case.recipe],
      })
    end
  end
  if active_lookup_direct and data.raw.recipe["electronic-circuit"] then
    add_case("raw.patch.electronic-circuit.copper-cable", "electronic circuits create copper scrap from copper cable",
      find_result((data_table.inserts.recipes["electronic-circuit"] or {}).results, "yis-copper-scrap") ~= nil,
      nil,
      { insert = data_table.inserts.recipes["electronic-circuit"] })
  end
  if active_lookup_direct and data.raw.recipe["radar"] then
    local radar_results = (data_table.inserts.recipes["radar"] or {}).results
    add_case("raw.patch.radar.lookup-components", "radar uses lookup-resolved circuit and gear materials",
      find_result(radar_results, "yis-iron-scrap") ~= nil and
        find_result(radar_results, "yis-copper-scrap") ~= nil,
      nil,
      { insert = data_table.inserts.recipes["radar"] })
  end
  if active_lookup_direct and data.raw.recipe["low-density-structure"] then
    local lds_results = (data_table.inserts.recipes["low-density-structure"] or {}).results
    add_case("raw.patch.low-density-structure.lookup-components", "low-density structure resolves steel, copper, and plastic",
      find_result(lds_results, "yis-steel-scrap") ~= nil and
        find_result(lds_results, "yis-copper-scrap") ~= nil and
        find_result(lds_results, "yis-plastic-scrap") ~= nil,
      nil,
      { insert = data_table.inserts.recipes["low-density-structure"] })
  end
  local recycling_scrap_recipe = recycling_recipe_with_scrap_result()
  add_case("raw.patch.no-quality-recycling-scrap", "Quality-style recycling recipes do not receive additional scrap results",
    recycling_scrap_recipe == nil,
    nil,
    { recipe = recycling_scrap_recipe, results = recycling_scrap_recipe and scrap_results(data.raw.recipe[recycling_scrap_recipe]) })
  local quietium_recycle_recipe = data.raw.recipe["yis-recycle-quietium-scrap"]
  local quietium_result = quietium_recycle_recipe and quietium_recycle_recipe.results and quietium_recycle_recipe.results[1]
  local expected_quietium_target = "yis-quietium-plate"
  add_case("recipe-chain-targets.legacy-disabled-yis-quietium", "legacy recipe-chain target setting does not override ancestry targets",
    quietium_result and quietium_result.name == expected_quietium_target,
    nil,
    {
      enabled = ISsettings.recipe_chain_targets,
      expected = expected_quietium_target,
      actual = quietium_result,
    })
  add_case("recipe-chain-targets.legacy-disabled-yis-quietium.icon", "legacy-disabled recycle recipe uses the ancestry target item icon",
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
    local expected_steel_target = "steel-plate"
    add_case("recipe-chain-targets.k2-steel", "legacy recipe-chain target setting does not override K2 steel ancestry target",
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
    add_case("recipe-chain-targets.k2-rare-metal-api-forced", "K2 rare-metal target uses processed rare metals",
      rare_metal_result and rare_metal_result.name == "kr-rare-metals",
      nil,
      {
        enabled = ISsettings.recipe_chain_targets,
        expected = "kr-rare-metals",
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

  local small_fixed, small_min, small_max = yokmods.ingredient_scrap.api.functions.scrap_amount_range(5)
  local large_fixed, large_min, large_max = yokmods.ingredient_scrap.api.functions.scrap_amount_range(200)
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
    enabled = solid_recipe.enabled,
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
    enabled = hidden_recipe.enabled,
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
    enabled = disabled_recipe.enabled,
    subgroup = disabled_recipe.subgroup,
    category = disabled_recipe.category,
    allow_as_intermediate = disabled_recipe.allow_as_intermediate,
    hide_from_player_crafting = disabled_recipe.hide_from_player_crafting,
    result = disabled_recipe.results and disabled_recipe.results[1],
  } or nil
  add_case("raw.recipe.recycle-yis-disabledium-scrap", "disabled source creates a visible but technology-locked recycle recipe",
    same_value(normalized_disabled_recipe, exp.recipes.disabled_solid) and disabled_recipe.enabled == false,
    nil,
    { expected = exp.recipes.disabled_solid, actual = normalized_disabled_recipe, enabled = disabled_recipe and disabled_recipe.enabled })

  if exp.recipes.fluid then
    local fluid_recipe = data.raw.recipe["yis-recycle-testium-scrap-to-fluid"]
    local normalized_fluid_recipe = fluid_recipe and {
      type = fluid_recipe.type,
      name = fluid_recipe.name,
      hidden = fluid_recipe.hidden or false,
      enabled = fluid_recipe.enabled,
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
      enabled = solution_recipe.enabled,
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
      enabled = hidden_fluid_recipe.enabled,
      subgroup = hidden_fluid_recipe.subgroup,
      category = hidden_fluid_recipe.category,
      allow_as_intermediate = hidden_fluid_recipe.allow_as_intermediate,
      hide_from_player_crafting = hidden_fluid_recipe.hide_from_player_crafting,
      result = hidden_fluid_recipe.results and hidden_fluid_recipe.results[1],
    } or nil
    add_case("raw.recipe.recycle-yis-hiddenfluidium-scrap-to-fluid", "hidden fluid source creates a hidden technology-locked recycle recipe",
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

  if is_small_vanilla_profile() and data.raw.recipe["satellite"] then
    local satellite_ingredient_count = 0
    for _, ingredient in ipairs(data.raw.recipe["satellite"].ingredients or {}) do
      if ingredient.name then satellite_ingredient_count = satellite_ingredient_count + 1 end
    end
    local satellite_expected = {
      type = "item",
      name = "yis-mixed-scrap",
      amount = ISsettings.fixed_amount and satellite_ingredient_count or nil,
      amount_min = ISsettings.fixed_amount and nil or satellite_ingredient_count,
      amount_max = ISsettings.fixed_amount and nil or satellite_ingredient_count,
      probability = ISsettings.probability > 0 and (ISsettings.probability / 100) or nil,
    }
    local satellite_actual = scrap_results(data.raw.recipe["satellite"])
    add_case("compat.satellite.mixed-scrap", "Base-only satellite recipe creates one mixed scrap result",
      #satellite_actual == 1 and same_value(satellite_actual[1], satellite_expected) and
        data.raw.item["yis-mixed-scrap"] and data.raw.recipe["yis-recycle-mixed-scrap"],
      nil,
      {
        expected = satellite_expected,
        actual = satellite_actual,
        ingredient_count = satellite_ingredient_count,
        recycle_recipe = data.raw.recipe["yis-recycle-mixed-scrap"],
      })
  end

  if data.raw.item["raw-fish"] or (data.raw.capsule and data.raw.capsule["raw-fish"]) then
    local fish_recipe = data.raw.recipe["yis-recycle-raw-fish"]
    local fish_tech = data.raw.technology["yis-recycle-raw-fish"]
    add_case("compat.fish.mixed-scrap", "raw fish can be recycled into mixed scrap",
      fish_recipe and
        fish_recipe.enabled == false and
        fish_recipe.hide_from_player_crafting == true and
        fish_recipe.category == "yis-recycle-to-item" and
        fish_recipe.ingredients and fish_recipe.ingredients[1] and
        fish_recipe.ingredients[1].name == "raw-fish" and
        fish_recipe.ingredients[1].amount == 1 and
        fish_recipe.results and fish_recipe.results[1] and
        fish_recipe.results[1].name == "yis-mixed-scrap" and
        fish_recipe.results[1].amount == 1 and
        data.raw.item["yis-mixed-scrap"] and data.raw.recipe["yis-recycle-mixed-scrap"],
      nil,
      { recipe = fish_recipe })
    local expected_fish_technology_hidden = ISsettings.hide_tech == true and ISsettings.shallow_log == false
    add_case("compat.fish.recycler-trigger-tech", "raw fish recycling unlocks after building a recycler",
      fish_tech and
        fish_tech.enabled == true and
        fish_tech.hidden == expected_fish_technology_hidden and
        fish_tech.research_trigger and
        fish_tech.research_trigger.type == "build-entity" and
        fish_tech.research_trigger.entity == "recycler" and
        technology_unlocks_recipe("yis-recycle-raw-fish"),
      nil,
      {
        technology = fish_tech,
        expected_hidden = expected_fish_technology_hidden,
      })
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
  local expected_technology_hidden = ISsettings.hide_tech == true and ISsettings.shallow_log == false
  add_case("raw.technology.hide-tech-setting", "generated recycle technologies follow yis-hide-tech unless shallow logging is enabled",
    tech and tech.hidden == expected_technology_hidden,
    nil,
    { expected = expected_technology_hidden, actual = tech and tech.hidden, shallow_log = ISsettings.shallow_log, hide_tech = ISsettings.hide_tech })
  local normalized_tech = tech and {
    type = tech.type,
    name = tech.name,
    enabled = tech.enabled,
    effect = technology_unlock_effect(tech, "yis-recycle-testium-scrap"),
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


