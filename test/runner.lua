local expected = require("test.expected")
local material_resolver = require("core.materials.resolver")
require("lib.category-overrides")
require("compat.vanilla-materials")
require("compat.mod-materials")
require("test.material-overrides")
local material_overrides = require("lib.material-overrides")

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

  add_case("materials.solid.testium", "testium is a solid material",
    array_contains(data_table.materials.solid, "testium"))
  add_case("materials.solid.rare-metal", "solid suffix resolver keeps multi-part material names",
    array_contains(data_table.materials.solid, "rare-metal"))
  add_case("materials.solid.no-rare-prefix", "solid resolver does not collapse rare-metal into rare",
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
    material_overrides.default_modes.testium == "both" and
      material_overrides.default_modes.solvium == "both" and
      material_overrides.default_modes["rare-metal"] == "both" and
      material_overrides.default_modes.alienite == "none",
    nil,
    {
      testium = material_overrides.default_modes.testium,
      solvium = material_overrides.default_modes.solvium,
      rare_metal = material_overrides.default_modes["rare-metal"],
      alienite = material_overrides.default_modes.alienite,
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
      localised_string_contains(material_overrides.localised_setting_description("testium"), "Ingredient Scrap Test"),
    nil,
    {
      iron = material_overrides.localised_setting_description("iron"),
      holmium = material_overrides.localised_setting_description("holmium"),
      testium = material_overrides.localised_setting_description("testium"),
    })
  add_case("materials.override.bacteria-locale-icon", "known bacteria uses a locale icon while keeping prototype matching disabled",
    material_overrides.icon_tag("bacteria") == nil and
      material_overrides.localised_setting_name("bacteria")[2][1] == "mod-setting-name.yis-material-bacteria",
    nil,
    { icon = material_overrides.icon_tag("bacteria"), name = material_overrides.localised_setting_name("bacteria") })
  add_case("materials.override.no-brass-icon", "missing optional material icon stays plain text",
    (data.raw.item["brass-plate"] ~= nil) or (
      material_overrides.icon_tag("brass") == nil and
      material_overrides.localised_setting_name("brass")[2] == "[img=none]"
    ),
    nil,
    { icon = material_overrides.icon_tag("brass"), name = material_overrides.localised_setting_name("brass") })
  add_case("materials.fluid.testium", "testium fluid material matches fluid setting",
    array_contains(data_table.materials.fluid, "testium") == exp.materials.fluid.testium)
  add_case("materials.fluid.solvium", "fluid suffix material matches fluid setting",
    array_contains(data_table.materials.fluid, "solvium") == exp.materials.fluid.solvium)
  add_case("materials.fluid.rare-metal", "fluid prefix and suffix resolver keeps multi-part material names",
    array_contains(data_table.materials.fluid, "rare-metal") == ISsettings.fluids)
  add_case("materials.fluid.no-suffix-token", "fluid suffix token is not collected as a material",
    not array_contains(data_table.materials.fluid, "-solution"))
  add_case("materials.fluid.alienite", "alienite fluid is ignored without plate or ingot",
    not array_contains(data_table.materials.fluid, "alienite"))

  add_case("resolver.solid.rare-metal-ore", "solid resolver strips known suffix after multi-part names",
    material_resolver.resolve_solid("rare-metal-ore", data_table.materials) == "rare-metal")
  add_case("resolver.fluid.rare-metal-solution", "fluid resolver strips known suffix after multi-part names",
    material_resolver.resolve_fluid("rare-metal-solution", data_table.materials) == "rare-metal")
  add_case("resolver.fluid.molten-rare-metal", "fluid resolver strips known prefix before multi-part names",
    material_resolver.resolve_fluid("molten-rare-metal", data_table.materials) == "rare-metal")
  add_case("resolver.fluid.molten-rare-metal-ore", "fluid resolver handles combined prefix and suffix",
    material_resolver.resolve_fluid("molten-rare-metal-ore", data_table.materials) == "rare-metal")
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
    ["metallurgy-or-assembling"] = true,
  }
  local assembling_recycle_source_categories = {
    ["basic-crafting"] = true,
    ["crafting"] = true,
    ["advanced-crafting"] = true,
    ["crafting-with-fluid-or-metallurgy"] = true,
    ["metallurgy-or-assembling"] = true,
  }
  local eligible_furnace_count = 0
  local patched_furnace_count = 0
  local duplicate_machine = nil
  for _, furnace in pairs(data.raw.furnace or {}) do
    if has_any_category(furnace, furnace_recycle_source_categories) then
      eligible_furnace_count = eligible_furnace_count + 1
      if category_count(furnace, recycle_item_category) == 1 then
        patched_furnace_count = patched_furnace_count + 1
      end
    end
    if category_count(furnace, recycle_item_category) > 1 then
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
    tint = item.icons and item.icons[1] and item.icons[1].tint,
  } or nil
  add_case("raw.item.testium-scrap", "testium-scrap item matches expected normalized object",
    same_value(normalized_item, exp.item), nil, { expected = exp.item, actual = normalized_item })

  local iron_item = data.raw.item["iron-scrap"]
  local iron_tint = iron_item and iron_item.icons and iron_item.icons[1] and iron_item.icons[1].tint
  add_case("raw.item.iron-scrap.tint", "iron-scrap item uses the vanilla material API tint",
    same_value(iron_tint, util.color("#888b8d")),
    nil,
    { expected = util.color("#888b8d"), actual = iron_tint })

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
    solid_recipe and solid_recipe.ingredients and solid_recipe.ingredients[1] and
      solid_recipe.ingredients[1].amount == expected_recycle_input_amount(data_table, "testium-scrap"),
    nil,
    {
      expected = expected_recycle_input_amount(data_table, "testium-scrap"),
      ingredients = solid_recipe and solid_recipe.ingredients,
    })

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
      fluid_recipe and fluid_recipe.ingredients and fluid_recipe.ingredients[1] and
        fluid_recipe.ingredients[1].amount == expected_recycle_input_amount(data_table, "testium-scrap"),
      nil,
      {
        expected = expected_recycle_input_amount(data_table, "testium-scrap"),
        ingredients = fluid_recipe and fluid_recipe.ingredients,
      })
    add_case("raw.recipe.recycle-testium-scrap-to-fluid.icon", "fluid recycle recipe uses the fluid result icon layer",
      fluid_recipe and solid_recipe and data.raw.fluid["molten-testium"] and
        icon_layers_contain(fluid_recipe.icons, data.raw.fluid["molten-testium"].icon) and
        not icon_layers_contain(solid_recipe.icons, data.raw.fluid["molten-testium"].icon),
      nil,
      {
        fluid_icon = data.raw.fluid["molten-testium"] and data.raw.fluid["molten-testium"].icon,
        solid_icons = solid_recipe and solid_recipe.icons,
        fluid_icons = fluid_recipe and fluid_recipe.icons,
      })

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
    add_case("raw.recipe.recycle-solvium-scrap-to-fluid.amount", "fluid suffix recycle recipe has patched input amount",
      solution_recipe and solution_recipe.ingredients and solution_recipe.ingredients[1] and
        solution_recipe.ingredients[1].amount == expected_recycle_input_amount(data_table, "solvium-scrap"),
      nil,
      {
        expected = expected_recycle_input_amount(data_table, "solvium-scrap"),
        ingredients = solution_recipe and solution_recipe.ingredients,
      })
    add_case("raw.technology.prefix-fluid-unlock", "prefix fluid recycle recipe is unlocked when fluid recipes are enabled",
      technology_unlocks_recipe("recycle-testium-scrap-to-fluid"))
    add_case("raw.technology.suffix-fluid-unlock", "suffix fluid recycle recipe is unlocked when fluid recipes are enabled",
      technology_unlocks_recipe("recycle-solvium-scrap-to-fluid"))
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
  local expected_hidden = not ISsettings.shallow_log and ISsettings.hide_tech
  add_case("raw.technology.hidden-setting", "technology visibility follows hide-tech unless shallow logging is enabled",
    tech and tech.hidden == expected_hidden,
    nil,
    { expected = expected_hidden, actual = tech and tech.hidden, shallow_log = ISsettings.shallow_log, hide_tech = ISsettings.hide_tech })
  local normalized_tech = tech and {
    type = tech.type,
    name = tech.name,
    effect = tech.effects and tech.effects[1],
    research_trigger = tech.research_trigger,
  } or nil
  add_case("raw.technology.recycle-testium-scrap", "testium recycle technology matches expected normalized object",
    same_value(normalized_tech, exp.technology), nil,
    { expected = exp.technology, actual = normalized_tech })
  add_case("raw.technology.recycle-testium-scrap.icon-tint", "technology scrap icon layer uses the scrap material tint",
    tech and tech.icons and tech.icons[2] and item and item.icons and item.icons[1] and
      tech.icons[2].icon == "__Ingredient_Scrap__/graphics/icons/scrap-128.png" and
      same_value(tech.icons[2].tint, item.icons[1].tint),
    nil,
    {
      technology_layer = tech and tech.icons and tech.icons[2],
      item_tint = item and item.icons and item.icons[1] and item.icons[1].tint,
    })
  add_case("raw.technology.no-phantom", "no recipe-specific phantom technology is created",
    data.raw.technology["yis-test-testium-no-tech"] == nil)

  return report
end

return runner


