local expected = {}

---Builds the expected scrap result for a single normalized ingredient amount.
local function result_for_amount(scrap_name, amount)
  local fixed, min, max = yokmods.ingredient_scrap.scrap_amount_range(amount)
  local result = { type = "item", name = scrap_name }
  if ISsettings.fixed_amount then
    result.amount = fixed
  else
    result.amount_min = min
    result.amount_max = max
  end
  if ISsettings.probability > 0 then
    result.probability = ISsettings.probability / 100
  end
  return result
end

---Adds one expected scrap amount into an accumulated expected result.
local function add_amount(target, amount)
  local part = result_for_amount(target.name, amount)
  if ISsettings.fixed_amount then
    target.amount = (target.amount or 0) + part.amount
  else
    target.amount_min = (target.amount_min or 0) + part.amount_min
    target.amount_max = (target.amount_max or 0) + part.amount_max
  end
  target.probability = part.probability
end

---Combines multiple normalized ingredient amounts into one expected scrap result.
local function combined_result(scrap_name, amounts)
  local result = { type = "item", name = scrap_name }
  for _, amount in ipairs(amounts) do
    add_amount(result, amount)
  end
  return result
end

---Builds the expected normalized objects and inserts for the current test settings profile.
function expected.build()
  local fluids = ISsettings.fluids
  local needed = ISsettings.needed
  local testium_stack = util.clamp(100 * needed, 10, 200)
  local testium_scrap = yokmods.ingredient_scrap.get_scrap_name("yis-testium")
  local hiddenium_scrap = yokmods.ingredient_scrap.get_scrap_name("yis-hiddenium")
  local disabledium_scrap = yokmods.ingredient_scrap.get_scrap_name("yis-disabledium")
  local hiddenfluidium_scrap = yokmods.ingredient_scrap.get_scrap_name("yis-hiddenfluidium")
  local solvium_scrap = yokmods.ingredient_scrap.get_scrap_name("yis-solvium")
  local testium_recycle = yokmods.ingredient_scrap.get_recycle_recipe_name("yis-testium")
  local hiddenium_recycle = yokmods.ingredient_scrap.get_recycle_recipe_name("yis-hiddenium")
  local disabledium_recycle = yokmods.ingredient_scrap.get_recycle_recipe_name("yis-disabledium")
  local hiddenfluidium_recycle = yokmods.ingredient_scrap.get_recycle_recipe_name("yis-hiddenfluidium")
  local solvium_recycle = yokmods.ingredient_scrap.get_recycle_recipe_name("yis-solvium")

  local inserts = {
    ["yis-test-yis-testium-solid"] = combined_result(testium_scrap, { 5 }),
    ["yis-test-yis-testium-mixed"] = combined_result(testium_scrap, fluids and { 6, 4 } or { 6 }),
    ["yis-test-yis-testium-large"] = combined_result(testium_scrap, { 200 }),
    ["yis-test-yis-testium-with-tech"] = combined_result(testium_scrap, { 5 }),
    ["yis-test-yis-testium-no-tech"] = combined_result(testium_scrap, { 3 }),
    ["yis-test-yis-hiddenium-hidden"] = combined_result(hiddenium_scrap, { 4 }),
    ["yis-test-yis-disabledium-disabled"] = combined_result(disabledium_scrap, { 4 }),
  }

  if fluids then
    inserts["yis-test-yis-testium-fluid"] = combined_result(testium_scrap, { 5 })
    inserts["yis-test-yis-testium-fluid-main-product"] = combined_result(testium_scrap, { 5 })
    inserts["yis-test-yis-solvium-solution"] = combined_result(solvium_scrap, { 6 })
    inserts["yis-test-yis-hiddenfluidium-fluid"] = combined_result(hiddenfluidium_scrap, { 7 })
  end

  return {
    materials = {
      solid = { ["yis-testium"] = true, ["yis-disabledium"] = true, uranium = false },
      fluid = { ["yis-testium"] = fluids, ["yis-solvium"] = fluids, ["yis-alienite"] = false },
    },
    inserts = inserts,
    item = {
      type = "item",
      name = testium_scrap,
      subgroup = "raw-material",
      order = "is-[" .. testium_scrap .. "]",
      hidden = false,
      stack_size = testium_stack,
      has_icons = true,
      tint = util.color("#123456"),
    },
    hidden_item = {
      type = "item",
      name = hiddenium_scrap,
      subgroup = "raw-material",
      order = "is-[" .. hiddenium_scrap .. "]",
      hidden = true,
      stack_size = testium_stack,
      has_icons = true,
    },
    disabled_item = {
      type = "item",
      name = disabledium_scrap,
      subgroup = "raw-material",
      order = "is-[" .. disabledium_scrap .. "]",
      hidden = false,
      stack_size = testium_stack,
      has_icons = true,
    },
    hidden_fluid_item = fluids and {
      type = "item",
      name = hiddenfluidium_scrap,
      subgroup = "raw-material",
      order = "is-[" .. hiddenfluidium_scrap .. "]",
      hidden = true,
      stack_size = testium_stack,
      has_icons = true,
    } or nil,
    recipes = {
      solid = {
        type = "recipe",
        name = testium_recycle,
        hidden = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-item",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "item", name = "yis-testium-plate", amount = 1 },
      },
      fluid = fluids and {
        type = "recipe",
        name = testium_recycle .. "-to-fluid",
        hidden = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-fluid",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "fluid", name = "molten-yis-testium", amount = math.max(50 / needed, 10) },
      } or nil,
      solution_fluid = fluids and {
        type = "recipe",
        name = solvium_recycle .. "-to-fluid",
        hidden = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-fluid",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "fluid", name = "yis-solvium-solution", amount = math.max(60 / needed, 10) },
      } or nil,
      hidden_solid = {
        type = "recipe",
        name = hiddenium_recycle,
        hidden = true,
        subgroup = "raw-material",
        category = "yis-recycle-to-item",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "item", name = "yis-hiddenium-plate", amount = 1 },
      },
      disabled_solid = {
        type = "recipe",
        name = disabledium_recycle,
        hidden = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-item",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "item", name = "yis-disabledium-plate", amount = 1 },
      },
      hidden_fluid = fluids and {
        type = "recipe",
        name = hiddenfluidium_recycle .. "-to-fluid",
        hidden = true,
        subgroup = "raw-material",
        category = "yis-recycle-to-fluid",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "fluid", name = "yis-hiddenfluidium-solution", amount = math.max(70 / needed, 10) },
      } or nil,
    },
    technology = {
      type = "technology",
      name = testium_recycle,
      effect = { type = "unlock-recipe", recipe = testium_recycle },
      research_trigger = { type = "craft-item", item = testium_scrap, count = 1 },
    },
  }
end

return expected
