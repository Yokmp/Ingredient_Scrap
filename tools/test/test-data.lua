-- Synthetic prototypes for the Ingredient Scrap debug test harness.
-- Loaded from data.lua when IS_DEBUG is true.

local icon_base = "__base__/graphics/icons/"
local dummy_icon = icon_base .. "iron-plate.png"
local dummy_fluid_icon = icon_base .. "fluid/water.png"

---Builds a minimal item prototype for synthetic test fixtures.
local function dummy_item(name, subgroup, stack_size, icon)
  return {
    type = "item",
    name = name,
    icon = icon or dummy_icon,
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
    icon = dummy_fluid_icon,
    icon_size = 64,
  }
end

---Builds a synthetic solid resource from the base iron ore prototype.
local function dummy_solid_resource(name, result_name)
  local resource = table.deepcopy(data.raw.resource["iron-ore"])
  resource.name = name
  resource.order = "zz-test-[" .. name .. "]"
  resource.minable = {
    mining_time = 1,
    results = { { type = "item", name = result_name, amount = 1 } },
  }
  return resource
end

---Builds a synthetic fluid resource from the base crude oil prototype.
local function dummy_fluid_resource(name, result_name)
  local resource = table.deepcopy(data.raw.resource["crude-oil"])
  resource.name = name
  resource.order = "zz-test-[" .. name .. "]"
  resource.category = "basic-fluid"
  resource.minable = {
    mining_time = 1,
    results = { { type = "fluid", name = result_name, amount = 10 } },
  }
  return resource
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
  dummy_item("yis-testium-plate", "intermediate-product", 100),
  dummy_item("yis-testium-ore", "raw-resource", 100),
  dummy_item("yis-testium-product-solid", "intermediate-product", 100),
  dummy_item("yis-testium-product-fluid", "intermediate-product", 100),
  dummy_item("yis-testium-product-mixed", "intermediate-product", 100),
  dummy_item("yis-testium-product-large", "intermediate-product", 100),
  dummy_item("yis-testium-product-tech", "intermediate-product", 100),
  dummy_item("yis-testium-product-no-tech", "intermediate-product", 100),
  dummy_item("yis-testium-product-void-guard", "intermediate-product", 100),
  dummy_item("yis-testium-product-blacklist-guard", "intermediate-product", 100),
  dummy_item("yis-hiddenium-plate", "intermediate-product", 100),
  dummy_item("yis-hiddenium-ore", "raw-resource", 100),
  dummy_item("yis-hiddenium-product", "intermediate-product", 100),
  dummy_item("yis-disabledium-plate", "intermediate-product", 100),
  dummy_item("yis-disabledium-ore", "raw-resource", 100),
  dummy_item("yis-disabledium-product", "intermediate-product", 100),
  dummy_item("yis-blockium-plate", "intermediate-product", 100),
  dummy_item("yis-blockium-ore", "raw-resource", 100),
  dummy_item("yis-blockium-product", "intermediate-product", 100),
  dummy_item("yis-quietium-plate", "intermediate-product", 100, icon_base .. "copper-plate.png"),
  dummy_item("yis-quietium-ingot", "intermediate-product", 100, icon_base .. "steel-plate.png"),
  dummy_item("yis-neutral-product", "intermediate-product", 100),
  dummy_item("yis-hiddenfluidium-plate", "intermediate-product", 100),
  dummy_item("yis-hiddenfluidium-product", "intermediate-product", 100),
  dummy_item("yis-solvium-plate", "intermediate-product", 100),
  dummy_item("yis-solvium-product-fluid", "intermediate-product", 100),
  dummy_item("yis-rare-metal-plate", "intermediate-product", 100),
  dummy_item("yis-rare-metal-ore", "raw-resource", 100),
})

data:extend({
  dummy_fluid("molten-yis-testium"),
  dummy_fluid("yis-solvium-solution"),
  dummy_fluid("yis-rare-metal-solution"),
  dummy_fluid("molten-yis-rare-metal"),
  dummy_fluid("molten-yis-rare-metal-ore"),
  dummy_fluid("molten-yis-alienite"),
  dummy_fluid("yis-hiddenfluidium-solution"),
})

data:extend({
  dummy_solid_resource("yis-test-rare-metal-resource", "yis-rare-metal-ore"),
  dummy_solid_resource("yis-test-yis-hiddenium-resource", "yis-hiddenium-ore"),
  dummy_solid_resource("yis-test-yis-disabledium-resource", "yis-disabledium-ore"),
  dummy_solid_resource("yis-test-yis-blockium-resource", "yis-blockium-ore"),
  dummy_fluid_resource("yis-test-yis-rare-metal-solution-resource", "yis-rare-metal-solution"),
  dummy_fluid_resource("yis-test-yis-hiddenfluidium-resource", "yis-hiddenfluidium-solution"),
})

data.raw.item["yis-hiddenium-plate"].hidden = true
data.raw.item["yis-hiddenium-ore"].hidden = true
data.raw.item["yis-hiddenium-product"].hidden = true
data.raw.fluid["yis-hiddenfluidium-solution"].hidden = true

data:extend({
  dummy_recipe("yis-test-yis-testium-solid",
    { { type = "item", name = "yis-testium-plate", amount = 5 } },
    { { type = "item", name = "yis-testium-product-solid", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-testium-fluid",
    { { type = "fluid", name = "molten-yis-testium", amount = 50 } },
    { { type = "item", name = "yis-testium-product-fluid", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-yis-testium-mixed",
    {
      { type = "item", name = "yis-testium-plate", amount = 6 },
      { type = "fluid", name = "molten-yis-testium", amount = 40 },
    },
    { { type = "item", name = "yis-testium-product-mixed", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-yis-testium-large",
    { { type = "item", name = "yis-testium-plate", amount = 200 } },
    { { type = "item", name = "yis-testium-product-large", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-testium-with-tech",
    { { type = "item", name = "yis-testium-plate", amount = 5 } },
    { { type = "item", name = "yis-testium-product-tech", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-testium-no-tech",
    { { type = "item", name = "yis-testium-ore", amount = 3 } },
    { { type = "item", name = "yis-testium-product-no-tech", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-hiddenium-hidden",
    { { type = "item", name = "yis-hiddenium-plate", amount = 4 } },
    { { type = "item", name = "yis-hiddenium-product", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-disabledium-disabled",
    { { type = "item", name = "yis-disabledium-ore", amount = 4 } },
    { { type = "item", name = "yis-disabledium-plate", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-blockium-disabled",
    { { type = "item", name = "yis-blockium-ore", amount = 4 } },
    { { type = "item", name = "yis-blockium-plate", amount = 1 } }
  ),

  dummy_recipe("yis-test-yis-quietium-neutral",
    { { type = "item", name = "yis-quietium-plate", amount = 4 } },
    { { type = "item", name = "yis-neutral-product", amount = 1 } }
  ),

  {
    type = "recipe",
    name = "yis-test-yis-testium-void",
    icon = dummy_icon,
    icon_size = 64,
    enabled = true,
    energy_required = 1,
    ingredients = { { type = "item", name = "yis-testium-plate", amount = 1 } },
    results = {},
  },

  dummy_recipe("yis-test-yis-testium-fluid-main-product",
    { { type = "item", name = "yis-testium-plate", amount = 5 } },
    { { type = "fluid", name = "steam", amount = 100 } },
    "steam",
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-yis-alienite-fluid",
    { { type = "fluid", name = "molten-yis-alienite", amount = 50 } },
    { { type = "item", name = "yis-testium-product-void-guard", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-yis-solvium-solution",
    { { type = "fluid", name = "yis-solvium-solution", amount = 60 } },
    { { type = "item", name = "yis-solvium-product-fluid", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-yis-hiddenfluidium-fluid",
    { { type = "fluid", name = "yis-hiddenfluidium-solution", amount = 70 } },
    { { type = "item", name = "yis-hiddenfluidium-product", amount = 1 } },
    nil,
    "crafting-with-fluid"
  ),

  dummy_recipe("yis-test-uranium-blacklist",
    { { type = "item", name = "uranium-ore", amount = 5 } },
    { { type = "item", name = "yis-testium-product-blacklist-guard", amount = 1 } }
  ),
})

data.raw.recipe["yis-test-yis-hiddenium-hidden"].enabled = false
data.raw.recipe["yis-test-yis-hiddenium-hidden"].hidden = true
data.raw.recipe["yis-test-yis-disabledium-disabled"].enabled = false
data.raw.recipe["yis-test-yis-blockium-disabled"].enabled = false

data:extend({
  dummy_tech("yis-test-tech-yis-testium", "yis-test-yis-testium-with-tech"),
})

log("[IS-TEST] Testium synthetic data loaded")
