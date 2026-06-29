require("lib.material-overrides")

local api = yokmods.ingredient_scrap.api

--------------------------------
---*TEST MATERIALS*          --
--------------------------------

api.register.material.both("testium", {
  tint = "#123456",
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ore", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = { "-solution" } },
  },
})

api.register.material.both("solvium", {
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = {}, suffixes = { "-solution" } },
  },
})

api.register.material.both("rare-metal", {
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "-ore", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = { "-solution" } },
  },
})

api.ignore.material("alienite", {
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-plate", "" } },
    fluid = { prefixes = { "molten-" }, suffixes = {} },
  },
})

return api
