require("code.lib.material-overrides")

local api = yokmods.ingredient_scrap.api
local test_source = { name = "Ingredient Scrap Test", color = "#66CCFF" }

--------------------------------
---*TEST MATERIALS*          --
--------------------------------

api.register.material.both("yis-testium", {
  tint = "#123456",
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ore", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = { "-solution" } },
  },
})

api.register.material.both("yis-solvium", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = {}, suffixes = { "-solution" } },
  },
})

api.register.material.solid("yis-quietium", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ingot" } },
    fluid = { prefixes = {}, suffixes = {} },
  },
})

api.register.material.solid("yis-testbrass", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = {}, suffixes = {} },
  },
})

api.register.material.both("yis-rare-metal", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ore", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = { "-solution" } },
  },
})

api.register.recipe_chain.fluid_target("yis-solvium", "yis-solvium-solution", {
  source = test_source,
  reason = "synthetic forced recipe-chain fluid target",
})

api.register.recipe_chain.solid_target("yis-quietium", "yis-quietium-ingot", {
  source = test_source,
  reason = "synthetic forced recipe-chain solid target without analysis candidate",
})

api.ignore.recipe_chain.solid_target("yis-blockium", "synthetic blocked recipe-chain solid target")

api.ignore.material("yis-alienite", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = {} },
  },
})

return api
