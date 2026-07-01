---Removes generated scrap byproducts from Quality-style recycling recipes.
---Quality can build recycling recipes after Ingredient Scrap patched the source
---recipe, which would otherwise copy scrap byproducts into the recycling recipe.
local function remove_scrap_from_recycling_recipes()
  for recipe_name, recipe in pairs(data.raw.recipe or {}) do
    if recipe.results and (recipe.category == "recycling" or recipe_name:match("%-recycling$") ~= nil) then
      local filtered_results = {}
      local removed = false
      for _, result in ipairs(recipe.results) do
        if result.name and result.name:match("^yis%-.*%-scrap$") then
          removed = true
        else
          table.insert(filtered_results, result)
        end
      end
      if removed then
        recipe.results = filtered_results
      end
    end
  end
end

remove_scrap_from_recycling_recipes()

if IS_DEBUG then
  local runner = require("tools.test.runner")
  local material_flow = require("code.core.debug.material-flow")
  local report = runner.run()
  local material_flow_dump = material_flow.build(yokmods.ingredient_scrap.data_table)
  local production_flow_dump = material_flow.build_production_flow()
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
    {
      type = "mod-data",
      name = "ingredient-scrap-material-flow",
      data_type = "ingredient-scrap-material-flow/v1",
      data = material_flow_dump,
    },
    {
      type = "mod-data",
      name = "ingredient-scrap-production-flow",
      data_type = "ingredient-scrap-production-flow/v1",
      data = production_flow_dump,
    },
  })
end
