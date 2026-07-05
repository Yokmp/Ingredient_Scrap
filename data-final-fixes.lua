--#region debug
local timing = require("code.functions.timing")
timing.mark("data-final-fixes", "start")
--#endregion

local context = yokmods and yokmods.ingredient_scrap and yokmods.ingredient_scrap.internal

---Returns true for the tiny Base + Ingredient Scrap profile used for fragile vanilla-only compatibility patches.
local function is_small_vanilla_profile()
  local allowed = {
    base = true,
    Ingredient_Scrap = true,
  }
  for mod_name, _ in pairs(mods or {}) do
    if not allowed[mod_name] then return false end
  end
  return true
end

---Queues built-in post-resolver compatibility patches.
local function enqueue_builtin_compat()
  if is_small_vanilla_profile() then
    context:enqueue_internal("mutate", "compat-satellite", function(api)
      require("code.compat.satellite").apply(api:data_table())
    end, {
      source = "code.compat.satellite",
      requires = { recipe = "satellite", item = "satellite" },
    })
  end
  context:enqueue_internal("mutate", "compat-fish", function(api)
    require("code.compat.fish").apply(api:data_table())
  end, { source = "code.compat.fish" })
end

---Validates generated prototypes and applies the final data.raw patch when safe.
local function validate_and_patch()
  yokmods.ingredient_scrap.preflight_errors = context:validate_generated_prototypes()
  --#region debug
  timing.mark("data-final-fixes", "validate-generated-prototypes", {
    count = #yokmods.ingredient_scrap.preflight_errors,
  })
  --#endregion

  if #yokmods.ingredient_scrap.preflight_errors > 0 then
    if IS_DEBUG then
      log("[IS-TEST] Preflight failed; skipping data:extend patch so the JSON report can be written.")
    else
      error("Ingredient Scrap generated invalid prototypes: " .. serpent.line(yokmods.ingredient_scrap.preflight_errors))
    end
    return
  end

  context:patch()
  --#region debug
  timing.mark("data-final-fixes", "patch-data-raw", {
    count = context:generated_prototype_count(),
  })
  --#endregion
end

---Runs Ingredient Scrap's final-stage resolver and patcher pipeline.
local function run_active_pipeline()
  local materials = context:collect_materials()
  --#region debug
  timing.mark("data-final-fixes", "collect-materials", {
    count = #materials.solid + #materials.fluid,
  })
  --#endregion

  local active_ancestry_report = context:apply_ancestry(ISsettings.ancestry_policy)
  --#region debug
  timing.mark("data-final-fixes", "active-ancestry", {
    count = (active_ancestry_report.summary or {}).applied_rows or 0,
  })
  --#endregion

  enqueue_builtin_compat()
  context:drain_queue()
  --#region debug
  timing.mark("data-final-fixes", "compat-special-recipes")
  --#endregion

  context:patch_recycle_amounts()
  --#region debug
  timing.mark("data-final-fixes", "patch-recycle-amounts", {
    count = table_size(context:generated_recipes()),
  })
  --#endregion

  validate_and_patch()
end

if not context then
  error("Ingredient Scrap internal API context was not initialized before final-fixes.")
end

require("code.compat.recycler.ensure").recycler()

run_active_pipeline()

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
  local material_flow = require("code.resolver.debug.material-flow")
  local technology_flow = require("code.resolver.debug.technology-flow")
  local ancestry_comparison = require("code.resolver.ancestry.comparison")
  local recipe_forms = require("code.resolver.ancestry.recipe-forms")
  local data_table = context and context:debug_data_table()
    or (yokmods.ingredient_scrap and yokmods.ingredient_scrap.data_table)
  timing.mark("data-final-fixes", "load-debug-tools")
  local production_flow_dump = material_flow.build_production_flow()
  timing.mark("data-final-fixes", "build-production-flow", {
    count = table_size(production_flow_dump.recipes or {}),
  })
  local material_flow_dump = material_flow.build(data_table)
  timing.mark("data-final-fixes", "build-material-flow", {
    count = #(material_flow_dump.flows or {}),
  })
  local technology_flow_dump = technology_flow.build()
  timing.mark("data-final-fixes", "build-technology-flow", {
    count = #(technology_flow_dump.technology_list or {}),
  })
  data_table.debug.passive_runtime =
    data_table.debug.passive_runtime or {
      schema = "ingredient-scrap-passive-runtime/v1",
    }
  local ancestry_policy = ISsettings.ancestry_policy or {
    root_policy = "hybrid",
    mixed_limit = 3,
    max_depth = 8,
  }
  local ancestry_options = {}
  for key, value in pairs(ancestry_policy) do ancestry_options[key] = value end
  ancestry_options.materials = data_table.materials
  local ancestry_runtime_dump = ancestry_comparison.build(material_flow_dump, production_flow_dump, ancestry_options)
  ancestry_runtime_dump.debug_source = "data-final-fixes-post-active"
  data_table.debug.passive_runtime.ancestry = ancestry_runtime_dump
  timing.mark("data-final-fixes", "build-passive-ancestry", {
    count = #(ancestry_runtime_dump.comparisons or {}),
    source = ancestry_runtime_dump.debug_source,
  })
  data_table.debug.passive_runtime.recipe_forms =
    recipe_forms.build(material_flow_dump, production_flow_dump, data_table)
  timing.mark("data-final-fixes", "build-recipe-forms", {
    count = #(data_table.debug.passive_runtime.recipe_forms.recipe_results or {}),
  })
  local report = runner.run(production_flow_dump)
  report.passive_runtime = {
    ancestry = {
      schema = data_table.debug.passive_runtime.ancestry.schema,
      mode = data_table.debug.passive_runtime.ancestry.mode,
      root_policy = data_table.debug.passive_runtime.ancestry.root_policy,
      mixed_limit = data_table.debug.passive_runtime.ancestry.mixed_limit,
      max_depth = data_table.debug.passive_runtime.ancestry.max_depth,
      component_fallback = data_table.debug.passive_runtime.ancestry.component_fallback,
      summary = data_table.debug.passive_runtime.ancestry.summary,
    },
    recipe_forms = {
      schema = data_table.debug.passive_runtime.recipe_forms.schema,
      root_philosophy = data_table.debug.passive_runtime.recipe_forms.root_philosophy,
      summary = data_table.debug.passive_runtime.recipe_forms.summary,
    },
  }
  report.active_ancestry = data_table.debug.active_ancestry and {
    schema = data_table.debug.active_ancestry.schema,
    mode = data_table.debug.active_ancestry.mode,
    root_policy = data_table.debug.active_ancestry.root_policy,
    mixed_limit = data_table.debug.active_ancestry.mixed_limit,
    max_depth = data_table.debug.active_ancestry.max_depth,
    summary = data_table.debug.active_ancestry.summary,
    mixed_rounding = data_table.debug.active_ancestry.mixed_rounding,
    mixed_recycle_distribution = data_table.debug.active_ancestry.mixed_recycle_distribution,
    comparison_summary = data_table.debug.active_ancestry.comparison_summary,
    lookup = data_table.debug.active_ancestry.lookup and {
      schema = data_table.debug.active_ancestry.lookup.schema,
      summary = data_table.debug.active_ancestry.lookup.summary,
    } or nil,
  } or nil
  timing.mark("data-final-fixes", "build-test-report")
  local data_table_dump = "return " .. serpent.block(data_table, {
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
      data = data_table.debug.passive_runtime.ancestry,
    },
    {
      type = "mod-data",
      name = "ingredient-scrap-recipe-forms",
      data_type = "ingredient-scrap-recipe-forms/v1",
      data = data_table.debug.passive_runtime.recipe_forms,
    },
  })
  timing.mark("data-final-fixes", "extend-debug-mod-data")
end
--#endregion
--#region debug
timing.mark("data-final-fixes", "complete")
--#endregion
