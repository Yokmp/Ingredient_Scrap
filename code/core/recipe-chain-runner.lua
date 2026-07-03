local data_table_writer = require("code.core.data-table.writer")
local icon_layers = require("code.lib.icon-layers")
local is_log = require("code.lib.is-log")

local recipe_chain_runner = {}

---Returns true when passive recipe-chain analysis should be built in this run.
---@return boolean
local function should_build_analysis()
  local enabled = ISsettings.recipe_chain_targets
  --#region debug
  enabled = enabled or IS_DEBUG
  --#endregion
  return enabled
end

---Applies high-confidence passive recipe-chain target decisions to generated recycle recipes.
---@param data_table ISdata_table
---@param decisions table|nil
local function apply_recipe_chain_targets(data_table, decisions)
  if not ISsettings.recipe_chain_targets or not decisions then return end

  local staged_recipes = decisions.staged_data_table
    and decisions.staged_data_table.prototypes
    and decisions.staged_data_table.prototypes.recipes or {}
  local staged_sources = decisions.staged_data_table
    and decisions.staged_data_table.debug
    and decisions.staged_data_table.debug.sources
    and decisions.staged_data_table.debug.sources.recipes or {}

  for recipe_name, staged_source in pairs(staged_sources) do
    local decision = staged_source.recipe_chain_decision
    local recipe = data_table_writer.generated_recipe(data_table, recipe_name)
    local staged_recipe = staged_recipes[recipe_name]
    local staged_result = staged_recipe and staged_recipe.results and staged_recipe.results[1]
    if decision and decision.active_candidate == true and recipe and staged_result then
      recipe.results = {
        {
          type = staged_result.type,
          name = staged_result.name,
          amount = staged_result.amount,
        },
      }
      recipe.icons = icon_layers.get(
        data_table,
        decision.material,
        false,
        staged_result.type,
        staged_result.name
      )

      data_table_writer.merge_recipe_source(data_table, recipe_name, {
        result_type = staged_result.type,
        result_name = staged_result.name,
        recipe_chain_decision = decision,
      })

      is_log.write(
        "recipe-chain",
        "warn",
        "apply-active-target",
        "Applied high-confidence recipe-chain recycle target.",
        {
          recipe = recipe_name,
          material = decision.material,
          result_type = staged_result.type,
          result_name = staged_result.name,
          current = decision.current,
          score = decision.suggested_score,
        }
      )
    end
  end
end

---Builds passive recipe-chain debug data and applies enabled active target decisions.
---@param data_table ISdata_table
---@param timing table|nil
function recipe_chain_runner.run(data_table, timing)
  if should_build_analysis() then
    local recipe_chain_analysis = require("code.core.analysis.recipe-chain")
    local recipe_chain_decider = require("code.core.analysis.recipe-chain-decider")
    --#region debug
    if timing then timing.mark("data-updates", "load-recipe-chain") end
    --#endregion

    data_table.debug.recipe_chain_analysis = recipe_chain_analysis.build(data_table)
    --#region debug
    if timing then
      timing.mark("data-updates", "recipe-chain-analysis", {
        count = (data_table.debug.recipe_chain_analysis.target_candidate_summary or {}).materials or 0,
      })
    end
    --#endregion

    data_table.debug.recipe_chain_decisions =
      recipe_chain_decider.build(
        data_table.debug.recipe_chain_analysis,
        data_table
      )
    --#region debug
    if timing then
      timing.mark("data-updates", "recipe-chain-decider", {
        count = ((data_table.debug.recipe_chain_decisions.summary or {}).solid or {}).materials or 0,
      })
    end
    --#endregion
  end

  apply_recipe_chain_targets(data_table, data_table.debug.recipe_chain_decisions)
  --#region debug
  if timing then timing.mark("data-updates", "apply-recipe-chain-targets") end
  --#endregion
end

return recipe_chain_runner
