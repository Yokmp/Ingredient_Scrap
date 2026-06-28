if IS_DEBUG then
  local runner = require("test.runner")
  local report = runner.run()
  local data_table_dump = "return " .. serpent.block(yokmods.ingredient_scrap.data_table, {
    comment = false,
    nocode = true,
  })

  data:extend({
    {
      type = "mod-data",
      name = "ingredient-scrap-test-report",
      data_type = "ingredient-scrap-test-report/v1",
      data = report,
    },
    {
      type = "mod-data",
      name = "ingredient-scrap-data-table-dump",
      data_type = "ingredient-scrap-data-table-dump/v1",
      data = {
        filename = "Ingredient_Scrap/data-table.lua",
        contents = data_table_dump,
      },
    },
  })
end
