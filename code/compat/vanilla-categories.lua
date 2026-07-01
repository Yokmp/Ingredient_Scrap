require("code.lib.category-overrides")

local api = yokmods.ingredient_scrap.api

--------------------------------
---*FURNACES*                --
--------------------------------

api.register.category.furnace({
  source_categories = {
    "smelting",
    "recycling",
  },
  add_item_recycling = true,
})

api.register.category.furnace({
  source_categories = {
    "metallurgy-or-assembling",
  },
  add_item_recycling = false,
  add_fluid_recycling_if_fluid_boxes = true,
})

--------------------------------
---*ASSEMBLING MACHINES*     --
--------------------------------

api.register.category.assembling_machine({
  source_categories = {
    "basic-crafting",
    "crafting",
    "advanced-crafting",
  },
  add_item_recycling = true,
  add_fluid_recycling_if_fluid_boxes = true,
})

api.register.category.assembling_machine({
  source_categories = {
    "crafting-with-fluid-or-metallurgy",
    "metallurgy-or-assembling",
  },
  add_item_recycling = false,
  add_fluid_recycling_if_fluid_boxes = true,
})

return api
