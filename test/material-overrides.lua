require("lib.material-overrides")

local api = yokmods.ingredient_scrap.api
local test_source = { name = "Ingredient Scrap Test", color = "#66CCFF" }

--------------------------------
---*TEST MATERIALS*          --
--------------------------------

api.register.material.both("testium", {
  tint = "#123456",
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ore", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = { "-solution" } },
  },
})

api.register.material.both("solvium", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = {}, suffixes = { "-solution" } },
  },
})

api.register.material.both("rare-metal", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ore", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = { "-solution" } },
  },
})

api.ignore.material("alienite", {
  source = test_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = {} },
  },
})

return api
