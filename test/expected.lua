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

  local inserts = {
    ["yis-test-testium-solid"] = combined_result("testium-scrap", { 5 }),
    ["yis-test-testium-mixed"] = combined_result("testium-scrap", fluids and { 6, 4 } or { 6 }),
    ["yis-test-testium-large"] = combined_result("testium-scrap", { 200 }),
    ["yis-test-testium-with-tech"] = combined_result("testium-scrap", { 5 }),
    ["yis-test-testium-no-tech"] = combined_result("testium-scrap", { 3 }),
  }

  if fluids then
    inserts["yis-test-testium-fluid"] = combined_result("testium-scrap", { 5 })
    inserts["yis-test-testium-fluid-main-product"] = combined_result("testium-scrap", { 5 })
    inserts["yis-test-solvium-solution"] = combined_result("solvium-scrap", { 6 })
  end

  return {
    materials = {
      solid = { testium = true, uranium = false },
      fluid = { testium = fluids, solvium = fluids, alienite = false },
    },
    inserts = inserts,
    item = {
      type = "item",
      name = "testium-scrap",
      subgroup = "raw-material",
      order = "is-[testium-scrap]",
      stack_size = testium_stack,
      has_icons = true,
    },
    recipes = {
      solid = {
        type = "recipe",
        name = "recycle-testium-scrap",
        enabled = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-item",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "item", name = "testium-plate", amount = 1 },
      },
      fluid = fluids and {
        type = "recipe",
        name = "recycle-testium-scrap-to-fluid",
        enabled = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-fluid",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "fluid", name = "molten-testium", amount = math.max(50 / needed, 10) },
      } or nil,
      solution_fluid = fluids and {
        type = "recipe",
        name = "recycle-solvium-scrap-to-fluid",
        enabled = false,
        subgroup = "raw-material",
        category = "yis-recycle-to-fluid",
        allow_as_intermediate = false,
        hide_from_player_crafting = false,
        result = { type = "fluid", name = "solvium-solution", amount = math.max(60 / needed, 10) },
      } or nil,
    },
    technology = {
      type = "technology",
      name = "recycle-testium-scrap",
      effect = { type = "unlock-recipe", recipe = "recycle-testium-scrap" },
      research_trigger = { type = "craft-item", item = "testium-scrap", count = 1 },
    },
  }
end

return expected


