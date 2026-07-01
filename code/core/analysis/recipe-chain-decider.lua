local decider = {}
local recipe_chain_overrides = require("code.lib.recipe-chain-overrides")

local MAX_DECISION_EXAMPLES = 12

---Copies plain Lua tables without preserving shared references.
---@param value any
---@return any
local function copy_value(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, inner in pairs(value) do
    copy[key] = copy_value(inner)
  end
  return copy
end

---Returns the generated recycle recipe name for a material and mode.
---@param material_name string
---@param mode string
---@return string
local function recycle_recipe_name(material_name, mode)
  local suffix = mode == "fluid" and "-to-fluid" or ""
  return "recycle-" .. material_name .. "-scrap" .. suffix
end

---Returns the generated recycle category for a mode.
---@param mode string
---@param data_table table|nil
---@return string
local function recycle_category(mode, data_table)
  local categories = data_table and data_table.constants and data_table.constants.recycle_categories or {}
  if mode == "fluid" then return categories.fluid or "yis-recycle-to-fluid" end
  return categories.solid or "yis-recycle-to-item"
end

---Creates a data-table-shaped shell using the same keys as the operative table.
---@param data_table table|nil
---@return table
local function init_staged_data_table(data_table)
  local materials = data_table and data_table.materials or {}
  return {
    constants = copy_value(data_table and data_table.constants or {}),
    ingredients = {
      items = {},
      fluids = {},
      supplements = {},
    },
    prototypes = {
      recipes = {},
      items = {},
      technology = {},
    },
    inserts = {
      recipes = {},
    },
    materials = {
      solid_prefixes = copy_value(materials.solid_prefixes or {}),
      solid_suffixes = copy_value(materials.solid_suffixes or {}),
      solid_aliases = copy_value(materials.solid_aliases or {}),
      fluid_prefixes = copy_value(materials.fluid_prefixes or {}),
      fluid_suffixes = copy_value(materials.fluid_suffixes or {}),
      fluid_aliases = copy_value(materials.fluid_aliases or {}),
      solid = {},
      fluid = {},
    },
    debug = {
      sources = {
        items = {},
        recipes = {},
        inserts = {},
      },
    },
  }
end

---Copies a compact target record.
---@param target table|nil
---@return table|nil
local function copy_target(target)
  if not target then return nil end
  return {
    recipe = target.recipe,
    category = target.category,
    result_type = target.result_type,
    result_name = target.result_name,
    result_amount = target.result_amount,
    score = target.score,
  }
end

---Copies a compact list of recipe names.
---@param recipes string[]|nil
---@return string[]
local function copy_recipes(recipes)
  local copy = {}
  for _, recipe_name in ipairs(recipes or {}) do
    table.insert(copy, recipe_name)
  end
  return copy
end

---Copies a string-keyed count table.
---@param values table|nil
---@return table
local function copy_count_map(values)
  local copy = {}
  for key, value in pairs(values or {}) do
    copy[key] = value
  end
  return copy
end

---Copies one recipe-shape evidence record without sharing nested tables.
---@param shape table|nil
---@return table|nil
local function copy_shape(shape)
  if not shape then return nil end

  local function copy_entries(entries)
    local copy = {}
    for _, entry in ipairs(entries or {}) do
      table.insert(copy, {
        type = entry.type,
        name = entry.name,
        amount = entry.amount,
        amount_min = entry.amount_min,
        amount_max = entry.amount_max,
        probability = entry.probability,
        relation = entry.relation,
      })
    end
    return copy
  end

  return {
    recipe = shape.recipe,
    category = shape.category,
    target_result = copy_entries({ shape.target_result })[1],
    ingredients = copy_entries(shape.ingredients),
    results = copy_entries(shape.results),
  }
end

---Returns the first current target for a target candidate.
---@param target table
---@return table|nil
local function first_current_target(target)
  return target.current and target.current[1] or nil
end

---Returns the passive action label for a target candidate.
---@param target table
---@return string
local function decision_action(target)
  if target.agrees_with_current then return "keep-current" end
  if first_current_target(target) and target.suggested then return "review-difference" end
  if target.suggested then return "analysis-only" end
  return "no-suggestion"
end

---Returns passive review notes for one decision.
---@param action string
---@param suggested table|nil
---@return string[]
local function review_reasons(action, suggested)
  local reasons = {}

  if action == "review-difference" then
    table.insert(reasons, "differs-from-current")
  elseif action == "analysis-only" then
    table.insert(reasons, "no-current-target")
  elseif action == "no-suggestion" then
    table.insert(reasons, "no-suggestion")
  end

  if suggested then
    if not (suggested.reasons and suggested.reasons["direct-chain-step"]) then
      table.insert(reasons, "no-direct-chain-step")
    end
    if suggested.recipe_flags and suggested.recipe_flags.hidden and suggested.recipe_flags.hidden > 0 then
      table.insert(reasons, "hidden-source-evidence")
    end
    if (suggested.score or 0) < 40 then
      table.insert(reasons, "low-score")
    end
  end

  return reasons
end

---Returns true when a differing passive target is strong enough to stage as a possible future active change.
---@param action string
---@param suggested table|nil
---@return boolean
local function is_active_review_candidate(action, suggested)
  if action ~= "review-difference" or not suggested then return false end
  if not (suggested.reasons and suggested.reasons["direct-chain-step"]) then return false end
  if suggested.recipe_flags and suggested.recipe_flags.hidden and suggested.recipe_flags.hidden > 0 then return false end
  return (suggested.score or 0) >= 80
end

---Returns a compact confidence label for passive dump inspection.
---@param action string
---@param reasons string[]
---@param active_candidate boolean
---@return string
local function decision_confidence(action, reasons, active_candidate)
  if active_candidate then return "active-candidate" end
  if action == "api-forced-target" then return "api-forced" end
  if action == "review-difference" then return "manual-review" end
  if action == "analysis-only" then return "analysis-only" end
  if action == "no-suggestion" then return "none" end
  return #reasons == 0 and "high" or "medium"
end

---Copies the selected suggested target with enough evidence for passive review.
---@param suggested table|nil
---@return table|nil
local function copy_suggested_target(suggested)
  if not suggested then return nil end
  return {
    result_type = suggested.result_type,
    result_name = suggested.result_name,
    score = suggested.score,
    reasons = copy_count_map(suggested.reasons),
    recipe_categories = copy_count_map(suggested.recipe_categories),
    recipe_flags = {
      disabled = suggested.recipe_flags and suggested.recipe_flags.disabled or 0,
      hidden = suggested.recipe_flags and suggested.recipe_flags.hidden or 0,
    },
    recipes = copy_recipes(suggested.recipes),
    recipe_shape = copy_shape(suggested.recipe_shape_evidence and suggested.recipe_shape_evidence[1]),
  }
end

---Builds a suggested target from an explicit API override.
---@param override table
---@return table
local function forced_suggested_target(override)
  return {
    result_type = override.result_type,
    result_name = override.result_name,
    score = 9999,
    reasons = { ["api-forced-target"] = 1 },
    recipe_categories = {},
    recipe_flags = { disabled = 0, hidden = 0 },
    recipes = {},
    recipe_shape = nil,
    api_override = {
      source = override.source,
      reason = override.reason,
    },
  }
end

---Returns the current generated recycle target for a material and mode.
---@param data_table table|nil
---@param material_name string
---@param mode string
---@return table[]
local function current_target_from_data_table(data_table, material_name, mode)
  local recipe_name = recycle_recipe_name(material_name, mode)
  local recipe = data_table and data_table.prototypes and data_table.prototypes.recipes
    and data_table.prototypes.recipes[recipe_name]
  local result = recipe and recipe.results and recipe.results[1]
  if not result then return {} end

  return {
    {
      recipe = recipe_name,
      category = recipe.category,
      result_type = result.type or "item",
      result_name = result.name,
      result_amount = result.amount,
    }
  }
end

---Builds one compact passive decision record for a material and mode.
---@param material_name string
---@param mode string
---@param target table
---@return table
local function build_decision(material_name, mode, target)
  local forced_target = recipe_chain_overrides.forced_target(mode, material_name)
  local blocked_target = recipe_chain_overrides.blocked_target(mode, material_name)
  local suggested = forced_target and forced_suggested_target(forced_target) or copy_suggested_target(target.suggested)
  local current = first_current_target(target)
  local action = forced_target and "api-forced-target" or decision_action(target)
  local reasons = review_reasons(action, suggested)
  if forced_target then
    table.insert(reasons, "api-forced-target")
  end
  if blocked_target then
    table.insert(reasons, "api-blocked-target")
  end
  local active_candidate = forced_target ~= nil or is_active_review_candidate(action, suggested)
  if blocked_target then active_candidate = false end

  return {
    material = material_name,
    mode = mode,
    action = action,
    active_candidate = active_candidate,
    confidence = decision_confidence(action, reasons, active_candidate),
    review_reasons = reasons,
    api_override = forced_target and {
      kind = "forced-target",
      source = forced_target.source,
      reason = forced_target.reason,
    } or blocked_target and {
      kind = "blocked-target",
      reason = blocked_target.reason,
    } or nil,
    agrees_with_current = target.agrees_with_current or false,
    current = copy_target(current),
    suggested = suggested,
  }
end

---Sorts passive decisions by action and material for stable dumps.
---@param decisions table[]
local function sort_decisions(decisions)
  local action_order = {
    ["api-forced-target"] = 0,
    ["review-difference"] = 1,
    ["analysis-only"] = 2,
    ["keep-current"] = 3,
    ["no-suggestion"] = 4,
  }

  table.sort(decisions, function(a, b)
    local left = action_order[a.action] or 99
    local right = action_order[b.action] or 99
    if left == right then return a.material < b.material end
    return left < right
  end)
end

---Builds decisions for one target mode.
---@param mode string
---@param target_candidates table
---@param data_table table|nil
---@return table
local function build_mode_decisions(mode, target_candidates, data_table)
  local decisions = {}
  local summary = {
    materials = 0,
    keep_current = 0,
    review_difference = 0,
    analysis_only = 0,
    no_suggestion = 0,
    examples = {},
  }

  local material_names = {}
  local seen_materials = {}
  for material_name in pairs(target_candidates or {}) do
    seen_materials[material_name] = true
    table.insert(material_names, material_name)
  end
  for _, material_name in ipairs(recipe_chain_overrides.materials_for_mode(mode)) do
    if not seen_materials[material_name] then
      table.insert(material_names, material_name)
    end
  end
  table.sort(material_names)

  for _, material_name in ipairs(material_names) do
    local target = target_candidates and target_candidates[material_name] or nil
    if not target then
      target = {
        current = current_target_from_data_table(data_table, material_name, mode),
        suggested = nil,
        agrees_with_current = false,
      }
    end
    local decision = build_decision(material_name, mode, target)
    table.insert(decisions, decision)

    summary.materials = summary.materials + 1
    if decision.action == "keep-current" then
      summary.keep_current = summary.keep_current + 1
    elseif decision.action == "review-difference" then
      summary.review_difference = summary.review_difference + 1
    elseif decision.action == "api-forced-target" then
      summary.review_difference = summary.review_difference + 1
    elseif decision.action == "analysis-only" then
      summary.analysis_only = summary.analysis_only + 1
    elseif decision.action == "no-suggestion" then
      summary.no_suggestion = summary.no_suggestion + 1
    end
  end

  sort_decisions(decisions)
  for i = 1, math.min(MAX_DECISION_EXAMPLES, #decisions) do
    table.insert(summary.examples, {
      material = decisions[i].material,
      action = decisions[i].action,
      current = decisions[i].current and decisions[i].current.result_name or nil,
      suggested = decisions[i].suggested and decisions[i].suggested.result_name or nil,
    })
  end

  return {
    summary = summary,
    materials = decisions,
  }
end

---Builds a generated recycle recipe prototype in the same shape as the operative generator.
---@param decision table
---@param mode string
---@param data_table table|nil
---@return table
local function build_staged_recipe(decision, mode, data_table)
  local recipe_name = recycle_recipe_name(decision.material, mode)
  local target_result = decision.suggested.recipe_shape and decision.suggested.recipe_shape.target_result

  local existing = data_table and data_table.prototypes and data_table.prototypes.recipes and
    data_table.prototypes.recipes[recipe_name]
  local existing_result = existing and existing.results and existing.results[1]
  local recipe = existing and copy_value(existing) or {
    type = "recipe",
    name = recipe_name,
    localised_name = { "", { "item-name.recycle" }, " ", { "item-name." .. decision.material } },
    subgroup = "raw-material",
    order = "is-[" .. recipe_name .. "]",
    always_show_products = true,
    allow_as_intermediate = false,
    hide_from_player_crafting = false,
    ingredients = {
      { type = "item", name = decision.material .. "-scrap", amount = 0 },
    },
  }

  recipe.type = "recipe"
  recipe.name = recipe_name
  recipe.category = recycle_category(mode, data_table)
  recipe.ingredients = recipe.ingredients or {
    { type = "item", name = decision.material .. "-scrap", amount = 0 },
  }
  recipe.results = {
    {
      type = decision.suggested.result_type,
      name = decision.suggested.result_name,
      amount = (target_result and target_result.amount) or (existing_result and existing_result.amount) or 1,
    },
  }

  return recipe
end

---Returns true when a passive decision should be mirrored into staged_data_table.
---@param decision table
---@return boolean
local function should_stage_decision(decision)
  if decision.api_override and decision.api_override.kind == "blocked-target" then return false end
  return decision.action == "keep-current" or decision.active_candidate == true
end

---Creates a data-table-shaped passive staging table from decisions.
---@param by_mode table
---@param data_table table|nil
---@return table
local function build_staged_data_table(by_mode, data_table)
  local staged = init_staged_data_table(data_table)

  for _, mode in ipairs({ "solid", "fluid" }) do
    for _, decision in ipairs((by_mode[mode] and by_mode[mode].materials) or {}) do
      if decision.suggested and should_stage_decision(decision) then
        table.insert(staged.materials[mode], decision.material)

        local recipe_name = recycle_recipe_name(decision.material, mode)
        staged.prototypes.recipes[recipe_name] = build_staged_recipe(decision, mode, data_table)
        staged.debug.sources.recipes[recipe_name] = {
          scrap_type = decision.material,
          result_type = decision.suggested.result_type,
          result_name = decision.suggested.result_name,
          recipe_chain_decision = {
            action = decision.action,
            active_candidate = decision.active_candidate,
            confidence = decision.confidence,
            review_reasons = copy_recipes(decision.review_reasons),
            api_override = copy_value(decision.api_override),
            mode = mode,
            material = decision.material,
            current = copy_target(decision.current),
            suggested_score = decision.suggested.score,
            suggested_reasons = copy_count_map(decision.suggested.reasons),
            source_recipes = copy_recipes(decision.suggested.recipes),
            recipe_shape = copy_shape(decision.suggested.recipe_shape),
          },
        }
      end
    end
  end

  return staged
end

---Builds passive recipe-chain decisions from the analysis dump.
---@param analysis table
---@param data_table table|nil
---@return table
function decider.build(analysis, data_table)
  local by_mode = {
    solid = build_mode_decisions("solid", analysis.target_candidates_by_mode and analysis.target_candidates_by_mode.solid, data_table),
    fluid = build_mode_decisions("fluid", analysis.target_candidates_by_mode and analysis.target_candidates_by_mode.fluid, data_table),
  }
  local staged_data_table = build_staged_data_table(by_mode, data_table)

  return {
    schema = "ingredient-scrap-recipe-chain-decisions/v1",
    mode = "passive",
    by_mode = by_mode,
    staged_data_table = staged_data_table,
    summary = {
      solid = by_mode.solid.summary,
      fluid = by_mode.fluid.summary,
    },
  }
end

return decider
