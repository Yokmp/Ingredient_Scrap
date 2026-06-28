-- Synthetic prototypes for the Ingredient Scrap debug test harness.
-- Loaded from data.lua when IS_DEBUG is true.

local icon_base = "__base__/graphics/icons/"
local dummy_icon = icon_base .. "iron-plate.png"

---Builds a minimal item prototype for synthetic test fixtures.
local function dummy_item(name, subgroup, stack_size)
  return {
    type = "item",
    name = name,
    icon = dummy_icon,
    icon_size = 64,
    subgroup = subgroup or "raw-material",
    order = "zz-test-[" .. name .. "]",
    stack_size = stack_size or 100,
  }
end

---Builds a minimal fluid prototype for synthetic test fixtures.
local function dummy_fluid(name)
  return {
    type = "fluid",
    name = name,
    default_temperature = 550,
    max_temperature = 1000,
    heat_capacity = "1kJ",
    base_color = { r = 0.5, g = 0.5, b = 0.5 },
    flow_color = { r = 0.7, g = 0.7, b = 0.7 },
    icon = dummy_icon,
    icon_size = 64,
  }
end

---Builds a minimal recipe prototype for synthetic test fixtures.
local function dummy_recipe(name, ingredients, results, main_product, category)
  return {
    type = "recipe",
    name = name,
    icon = dummy_icon,
    icon_size = 64,
    category = category or "crafting",
    enabled = true,
    energy_required = 1,
    ingredients = ingredients,
    results = results,
    main_product = main_product,
  }
end

---Builds a minimal technology prototype that unlocks a synthetic recipe.
local function dummy_tech(name, recipe_name)
  return {
    type = "technology",
    name = name,
    icon = dummy_icon,
    icon_size = 64,
    effects = {
      { type = "unlock-recipe", recipe = recipe_name },
    },
    unit = {
      count = 10,
      ingredients = { { "automation-science-pack", 1 } },
      time = 10,
    },
  }
end

data:extend({
  dummy_item("testium-plate", "intermediate-product", 100),
  dummy_item("testium-ore", "raw-resource", 100),
  dummy_item("testium-product-solid", "intermediate-product", 100),
  dummy_item("testium-product-fluid", "intermediate-product", 100),
  dummy_item("testium-product-mixed", "intermediate-product", 100),
  dummy_item("testium-product-large", "intermediate-product", 100),
  dummy_item("testium-product-tech", "intermediate-product", 100),
  dummy_item("testium-product-no-tech", "intermediate-product", 100),
  dummy_item("testium-product-void-guard", "intermediate-product", 100),
  dummy_item("testium-product-blacklist-guard", "intermediate-product", 100),
  dummy_item("uranium-plate", "intermediate-product", 100),
})

data:extend({
  dummy_fluid("molten-testium"),
  dummy_fluid("molten-alienite"),
})

data:extend({
  dummy_recipe("yis-test-testium-solid",
    { { type = "item", name = "testium-plate", amount = 5 } },
    { { type = "item", name = "testium-product-solid", amount = 1 } }
  ),

  dummy_recipe("yis-test-testium-fluid",
    { { type = "fluid", name = "molten-testium", amount = 50 } },
    { { type = "item", name = "testium-product-fluid", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-testium-mixed",
    {
      { type = "item", name = "testium-plate", amount = 6 },
      { type = "fluid", name = "molten-testium", amount = 40 },
    },
    { { type = "item", name = "testium-product-mixed", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-testium-large",
    { { type = "item", name = "testium-plate", amount = 200 } },
    { { type = "item", name = "testium-product-large", amount = 1 } }
  ),

  dummy_recipe("yis-test-testium-with-tech",
    { { type = "item", name = "testium-plate", amount = 5 } },
    { { type = "item", name = "testium-product-tech", amount = 1 } }
  ),

  dummy_recipe("yis-test-testium-no-tech",
    { { type = "item", name = "testium-ore", amount = 3 } },
    { { type = "item", name = "testium-product-no-tech", amount = 1 } }
  ),

  {
    type = "recipe",
    name = "yis-test-testium-void",
    icon = dummy_icon,
    icon_size = 64,
    enabled = true,
    energy_required = 1,
    ingredients = { { type = "item", name = "testium-plate", amount = 1 } },
    results = {},
  },

  dummy_recipe("yis-test-testium-fluid-main-product",
    { { type = "item", name = "testium-plate", amount = 5 } },
    { { type = "fluid", name = "steam", amount = 100 } },
    "steam",
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-alienite-fluid",
    { { type = "fluid", name = "molten-alienite", amount = 50 } },
    { { type = "item", name = "testium-product-void-guard", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-uranium-blacklist",
    { { type = "item", name = "uranium-plate", amount = 5 } },
    { { type = "item", name = "testium-product-blacklist-guard", amount = 1 } }
  ),
})

data:extend({
  dummy_tech("yis-test-tech-testium", "yis-test-testium-with-tech"),
})

log("[IS-TEST] Testium synthetic data loaded")
