local expected = require("test.expected")

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

  add_case("materials.solid.testium", "testium is a solid material",
    array_contains(data_table.materials.solid, "testium"))
  add_case("materials.solid.uranium", "uranium is blacklisted for solid materials",
    not array_contains(data_table.materials.solid, "uranium"))
  add_case("materials.fluid.testium", "testium fluid material matches fluid setting",
    array_contains(data_table.materials.fluid, "testium") == exp.materials.fluid.testium)
  add_case("materials.fluid.solvium", "fluid suffix material matches fluid setting",
    array_contains(data_table.materials.fluid, "solvium") == exp.materials.fluid.solvium)
  add_case("materials.fluid.alienite", "alienite fluid is ignored without plate or ingot",
    not array_contains(data_table.materials.fluid, "alienite"))

  local recycle_item_category = "yis-recycle-to-item"
  local recycle_fluid_category = "yis-recycle-to-fluid"
  local assembling_recycle_source_categories = {
    ["basic-crafting"] = true,
    ["crafting"] = true,
    ["advanced-crafting"] = true,
    ["metallurgy"] = true,
    ["crafting-with-fluid-or-metallurgy"] = true,
    ["metallurgy-or-assembling"] = true,
  }
  local smelting_furnace_count = 0
  local patched_smelting_furnace_count = 0
  local duplicate_machine = nil
  for _, furnace in pairs(data.raw.furnace or {}) do
    if category_count(furnace, "smelting") > 0 then
      smelting_furnace_count = smelting_furnace_count + 1
      if category_count(furnace, recycle_item_category) == 1 then
        patched_smelting_furnace_count = patched_smelting_furnace_count + 1
      end
    end
    if category_count(furnace, recycle_item_category) > 1 then
      duplicate_machine = furnace.name
    end
  end
  add_case("categories.furnace.smelting", "smelting furnaces can craft item recycle recipes",
    smelting_furnace_count > 0 and patched_smelting_furnace_count == smelting_furnace_count,
    nil,
    { smelting = smelting_furnace_count, patched = patched_smelting_furnace_count })
  add_case("categories.furnace.no-duplicates", "furnace recycle categories are not duplicated",
    duplicate_machine == nil, nil, { duplicate = duplicate_machine })

  local eligible_assembler_count = 0
  local patched_assembler_count = 0
  local fluid_assembler_count = 0
  local patched_fluid_assembler_count = 0
  duplicate_machine = nil
  for _, assembling_machine in pairs(data.raw["assembling-machine"] or {}) do
    if has_any_category(assembling_machine, assembling_recycle_source_categories) then
      eligible_assembler_count = eligible_assembler_count + 1
      if category_count(assembling_machine, recycle_item_category) == 1 then
        patched_assembler_count = patched_assembler_count + 1
      end
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

  local iron_recycle_recipe = data.raw.recipe["recycle-iron-scrap"]
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

  for recipe_name, expected_result in pairs(exp.inserts) do
    local insert = data_table.inserts.recipes[recipe_name]
    local actual = find_result(insert and insert.results, expected_result.name)
    add_case("insert." .. recipe_name, recipe_name .. " has expected scrap insert",
      same_value(result_signature(actual), expected_result),
      nil,
      { expected = expected_result, actual = result_signature(actual) })
  end

  local mixed_results = (data_table.inserts.recipes["yis-test-testium-mixed"] or {}).results or {}
  local mixed_count = 0
  for _, result in ipairs(mixed_results) do
    if result.name == "testium-scrap" then mixed_count = mixed_count + 1 end
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
      large_fixed < linear_large or ISsettings.probability == 0,
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

  local void_insert = data_table.inserts.recipes["yis-test-testium-void"]
  add_case("edge.void", "void recipe creates no scrap insert",
    not (void_insert and void_insert.results))
  local fluid_main_insert = data_table.inserts.recipes["yis-test-testium-fluid-main-product"]
  local fluid_main_result = find_result(fluid_main_insert and fluid_main_insert.results, "testium-scrap")
  if ISsettings.fluids then
    add_case("edge.fluid-main-product", "fluid main product is processed when fluid recipes are enabled",
      same_value(result_signature(fluid_main_result), exp.inserts["yis-test-testium-fluid-main-product"]),
      nil,
      { expected = exp.inserts["yis-test-testium-fluid-main-product"], actual = result_signature(fluid_main_result) })
  else
    add_case("edge.fluid-main-product", "fluid main product is ignored when fluid recipes are disabled",
      not (fluid_main_insert and fluid_main_insert.results))
    add_case("edge.fluid-only-prefix-disabled", "prefix fluid fixture creates no scrap insert when fluid recipes are disabled",
      not insert_has_results(data_table, "yis-test-testium-fluid"))
    add_case("edge.fluid-only-suffix-disabled", "suffix fluid fixture creates no scrap insert when fluid recipes are disabled",
      not insert_has_results(data_table, "yis-test-solvium-solution"))
  end
  local alienite_insert = data_table.inserts.recipes["yis-test-alienite-fluid"]
  add_case("edge.alienite", "unknown fluid creates no scrap insert",
    not (alienite_insert and alienite_insert.results))
  local uranium_insert = data_table.inserts.recipes["yis-test-uranium-blacklist"]
  add_case("edge.uranium", "blacklisted uranium creates no scrap insert",
    not (uranium_insert and uranium_insert.results))

  local item = data.raw.item["testium-scrap"]
  local normalized_item = item and {
    type = item.type,
    name = item.name,
    subgroup = item.subgroup,
    order = item.order,
    stack_size = item.stack_size,
    has_icons = item.icons ~= nil or item.icon ~= nil,
  } or nil
  add_case("raw.item.testium-scrap", "testium-scrap item matches expected normalized object",
    same_value(normalized_item, exp.item), nil, { expected = exp.item, actual = normalized_item })

  local solid_recipe = data.raw.recipe["recycle-testium-scrap"]
  local normalized_solid_recipe = solid_recipe and {
    type = solid_recipe.type,
    name = solid_recipe.name,
    enabled = solid_recipe.enabled,
    subgroup = solid_recipe.subgroup,
    category = solid_recipe.category,
    allow_as_intermediate = solid_recipe.allow_as_intermediate,
    hide_from_player_crafting = solid_recipe.hide_from_player_crafting,
    result = solid_recipe.results and solid_recipe.results[1],
  } or nil
  add_case("raw.recipe.recycle-testium-scrap", "solid recycle recipe matches expected normalized object",
    same_value(normalized_solid_recipe, exp.recipes.solid), nil,
    { expected = exp.recipes.solid, actual = normalized_solid_recipe })
  add_case("raw.recipe.recycle-testium-scrap.amount", "solid recycle recipe has patched input amount",
    solid_recipe and solid_recipe.ingredients and solid_recipe.ingredients[1] and solid_recipe.ingredients[1].amount > 0,
    nil, { ingredients = solid_recipe and solid_recipe.ingredients })

  if exp.recipes.fluid then
    local fluid_recipe = data.raw.recipe["recycle-testium-scrap-to-fluid"]
    local normalized_fluid_recipe = fluid_recipe and {
      type = fluid_recipe.type,
      name = fluid_recipe.name,
      enabled = fluid_recipe.enabled,
      subgroup = fluid_recipe.subgroup,
      category = fluid_recipe.category,
      allow_as_intermediate = fluid_recipe.allow_as_intermediate,
      hide_from_player_crafting = fluid_recipe.hide_from_player_crafting,
      result = fluid_recipe.results and fluid_recipe.results[1],
    } or nil
    add_case("raw.recipe.recycle-testium-scrap-to-fluid", "fluid recycle recipe matches expected normalized object",
      same_value(normalized_fluid_recipe, exp.recipes.fluid), nil,
      { expected = exp.recipes.fluid, actual = normalized_fluid_recipe })
    add_case("raw.recipe.recycle-testium-scrap-to-fluid.amount", "fluid recycle recipe has patched input amount",
      fluid_recipe and fluid_recipe.ingredients and fluid_recipe.ingredients[1] and fluid_recipe.ingredients[1].amount > 0,
      nil, { ingredients = fluid_recipe and fluid_recipe.ingredients })

    local solution_recipe = data.raw.recipe["recycle-solvium-scrap-to-fluid"]
    local normalized_solution_recipe = solution_recipe and {
      type = solution_recipe.type,
      name = solution_recipe.name,
      enabled = solution_recipe.enabled,
      subgroup = solution_recipe.subgroup,
      category = solution_recipe.category,
      allow_as_intermediate = solution_recipe.allow_as_intermediate,
      hide_from_player_crafting = solution_recipe.hide_from_player_crafting,
      result = solution_recipe.results and solution_recipe.results[1],
    } or nil
    add_case("raw.recipe.recycle-solvium-scrap-to-fluid", "fluid suffix recycle recipe matches expected normalized object",
      same_value(normalized_solution_recipe, exp.recipes.solution_fluid), nil,
      { expected = exp.recipes.solution_fluid, actual = normalized_solution_recipe })
  else
    add_case("raw.recipe.no-prefix-fluid-recycle", "prefix fluid recycle recipe is absent when fluids are disabled",
      data.raw.recipe["recycle-testium-scrap-to-fluid"] == nil)
    add_case("raw.recipe.no-suffix-fluid-recycle", "suffix fluid recycle recipe is absent when fluids are disabled",
      data.raw.recipe["recycle-solvium-scrap-to-fluid"] == nil)
  end

  for recipe_name, expected_result in pairs(exp.inserts) do
    local actual = scrap_results(data.raw.recipe[recipe_name])
    add_case("raw.patch." .. recipe_name, recipe_name .. " data.raw patch has expected scrap result",
      #actual == 1 and same_value(actual[1], expected_result), nil,
      { expected = expected_result, actual = actual })
  end

  if not ISsettings.fluids then
    add_case("raw.patch.no-prefix-fluid-scrap", "prefix fluid fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-testium-fluid"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-testium-fluid"]) })
    add_case("raw.patch.no-suffix-fluid-scrap", "suffix fluid fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-solvium-solution"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-solvium-solution"]) })
    add_case("raw.patch.no-fluid-main-product-scrap", "fluid main product fixture has no data.raw scrap result when fluid recipes are disabled",
      #scrap_results(data.raw.recipe["yis-test-testium-fluid-main-product"]) == 0,
      nil, { actual = scrap_results(data.raw.recipe["yis-test-testium-fluid-main-product"]) })
    add_case("raw.technology.no-prefix-fluid-unlock", "prefix fluid recycle recipe is not unlocked when fluid recipes are disabled",
      not technology_unlocks_recipe("recycle-testium-scrap-to-fluid"))
    add_case("raw.technology.no-suffix-fluid-unlock", "suffix fluid recycle recipe is not unlocked when fluid recipes are disabled",
      not technology_unlocks_recipe("recycle-solvium-scrap-to-fluid"))
  end

  local tech = data.raw.technology["recycle-testium-scrap"]
  local normalized_tech = tech and {
    type = tech.type,
    name = tech.name,
    effect = tech.effects and tech.effects[1],
    research_trigger = tech.research_trigger,
  } or nil
  add_case("raw.technology.recycle-testium-scrap", "testium recycle technology matches expected normalized object",
    same_value(normalized_tech, exp.technology), nil,
    { expected = exp.technology, actual = normalized_tech })
  add_case("raw.technology.no-phantom", "no recipe-specific phantom technology is created",
    data.raw.technology["yis-test-testium-no-tech"] == nil)

  return report
end

return runner


