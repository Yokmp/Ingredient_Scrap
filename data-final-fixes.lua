--#region debug
local timing = require("code.lib.timing")
timing.mark("data-final-fixes", "start")
--#endregion

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
--#region debug
timing.mark("data-final-fixes", "remove-scrap-from-recycling-recipes")
--#endregion

--#region debug
if IS_DEBUG then
  local runner = require("tools.test.runner")
  local material_flow = require("code.core.debug.material-flow")
  local technology_flow = require("code.core.debug.technology-flow")
  local ancestry_comparison = require("code.core.ancestry.comparison")
  local recipe_forms = require("code.core.ancestry.recipe-forms")
  timing.mark("data-final-fixes", "load-debug-tools")
  local production_flow_dump = material_flow.build_production_flow()
  timing.mark("data-final-fixes", "build-production-flow", {
    count = table_size(production_flow_dump.recipes or {}),
  })
  local material_flow_dump = material_flow.build(yokmods.ingredient_scrap.data_table)
  timing.mark("data-final-fixes", "build-material-flow", {
    count = #(material_flow_dump.flows or {}),
  })
  local technology_flow_dump = technology_flow.build()
  timing.mark("data-final-fixes", "build-technology-flow", {
    count = #(technology_flow_dump.technology_list or {}),
  })
  yokmods.ingredient_scrap.data_table.debug.passive_runtime =
    yokmods.ingredient_scrap.data_table.debug.passive_runtime or {
      schema = "ingredient-scrap-passive-runtime/v1",
    }
  local ancestry_policy = ISsettings.ancestry_policy or {
    root_policy = "hybrid",
    mixed_limit = 3,
    max_depth = 8,
  }
  yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry =
    ancestry_comparison.build(material_flow_dump, production_flow_dump, ancestry_policy)
  timing.mark("data-final-fixes", "build-passive-ancestry", {
    count = #(yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.comparisons or {}),
  })
  yokmods.ingredient_scrap.data_table.debug.passive_runtime.recipe_forms =
    recipe_forms.build(material_flow_dump, production_flow_dump, yokmods.ingredient_scrap.data_table)
  timing.mark("data-final-fixes", "build-recipe-forms", {
    count = #(yokmods.ingredient_scrap.data_table.debug.passive_runtime.recipe_forms.recipe_results or {}),
  })
  local report = runner.run(production_flow_dump)
  report.passive_runtime = {
    ancestry = {
      schema = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.schema,
      mode = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.mode,
      root_policy = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.root_policy,
      mixed_limit = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.mixed_limit,
      max_depth = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.max_depth,
      component_fallback = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.component_fallback,
      summary = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry.summary,
    },
    recipe_forms = {
      schema = yokmods.ingredient_scrap.data_table.debug.passive_runtime.recipe_forms.schema,
      root_philosophy = yokmods.ingredient_scrap.data_table.debug.passive_runtime.recipe_forms.root_philosophy,
      summary = yokmods.ingredient_scrap.data_table.debug.passive_runtime.recipe_forms.summary,
    },
  }
  report.active_ancestry = yokmods.ingredient_scrap.data_table.debug.active_ancestry and {
    schema = yokmods.ingredient_scrap.data_table.debug.active_ancestry.schema,
    mode = yokmods.ingredient_scrap.data_table.debug.active_ancestry.mode,
    root_policy = yokmods.ingredient_scrap.data_table.debug.active_ancestry.root_policy,
    mixed_limit = yokmods.ingredient_scrap.data_table.debug.active_ancestry.mixed_limit,
    max_depth = yokmods.ingredient_scrap.data_table.debug.active_ancestry.max_depth,
    summary = yokmods.ingredient_scrap.data_table.debug.active_ancestry.summary,
    comparison_summary = yokmods.ingredient_scrap.data_table.debug.active_ancestry.comparison_summary,
  } or nil
  timing.mark("data-final-fixes", "build-test-report")
  local data_table_dump = "return " .. serpent.block(yokmods.ingredient_scrap.data_table, {
    comment = false,
    nocode = true,
  })
  timing.mark("data-final-fixes", "serialize-data-table", {
    count = #data_table_dump,
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
    {
      type = "mod-data",
      name = "ingredient-scrap-technology-flow",
      data_type = "ingredient-scrap-technology-flow/v1",
      data = technology_flow_dump,
    },
    {
      type = "mod-data",
      name = "ingredient-scrap-ancestry-runtime",
      data_type = "ingredient-scrap-passive-runtime-ancestry/v1",
      data = yokmods.ingredient_scrap.data_table.debug.passive_runtime.ancestry,
    },
    {
      type = "mod-data",
      name = "ingredient-scrap-recipe-forms",
      data_type = "ingredient-scrap-recipe-forms/v1",
      data = yokmods.ingredient_scrap.data_table.debug.passive_runtime.recipe_forms,
    },
  })
  timing.mark("data-final-fixes", "extend-debug-mod-data")
end
--#endregion
--#region debug
timing.mark("data-final-fixes", "complete")
--#endregion
