local material_flow = require("code.core.debug.material-flow")
local active_ancestry = require("code.core.ancestry.active")
local baseline_collector = require("code.core.baseline-collector")

local scrap_resolver = {}

---Counts map entries without depending on Factorio's global table_size helper.
---@param values table|nil
---@return integer
local function map_size(values)
  local count = 0
  for _, _ in pairs(values or {}) do count = count + 1 end
  return count
end

---Returns true when the active ancestry resolver should rewrite collector output.
---@param policy table|nil
---@return boolean
local function active_ancestry_enabled(policy)
  return policy ~= nil and policy.mode ~= "component-heavy"
end

---Stores a compact resolver-stage report in the shared debug table.
---@param data_table ISdata_table
---@param key string
---@param report table
local function record_report(data_table, key, report)
  data_table.debug = data_table.debug or {}
  data_table.debug.resolver = data_table.debug.resolver or {
    schema = "ingredient-scrap-resolver/v1",
  }
  data_table.debug.resolver[key] = report
end

---Runs the collector baseline that creates the initial data-table inserts.
---@param data_table ISdata_table
---@return table
function scrap_resolver.collect_baseline(data_table)
  baseline_collector.collect(data_table)

  local report = {
    schema = "ingredient-scrap-resolver-baseline/v1",
    method = "collector",
    inserts = map_size(data_table.inserts and data_table.inserts.recipes),
    generated_items = map_size(data_table.prototypes and data_table.prototypes.items),
    generated_recipes = map_size(data_table.prototypes and data_table.prototypes.recipes),
    generated_technologies = map_size(data_table.prototypes and data_table.prototypes.technology),
  }
  record_report(data_table, "baseline", report)
  return report
end

---Builds resolver flow inputs from the current data table and applies active ancestry rewrites.
---@param data_table ISdata_table
---@param policy table|nil
---@return table
function scrap_resolver.apply_active_ancestry(data_table, policy)
  if not active_ancestry_enabled(policy) then
    local report = {
      schema = "ingredient-scrap-resolver-active/v1",
      skipped = true,
      reason = policy and "component-heavy-mode" or "missing-policy",
    }
    record_report(data_table, "active", report)
    return report
  end

  local production_flow_dump = material_flow.build_production_flow()
  local material_flow_dump = material_flow.build(data_table)
  local report = active_ancestry.apply(
    data_table,
    material_flow_dump,
    production_flow_dump,
    policy
  )
  record_report(data_table, "active", {
    schema = "ingredient-scrap-resolver-active/v1",
    skipped = false,
    mode = report.mode,
    root_policy = report.root_policy,
    mixed_limit = report.mixed_limit,
    max_depth = report.max_depth,
    summary = report.summary,
  })
  return report
end

return scrap_resolver
