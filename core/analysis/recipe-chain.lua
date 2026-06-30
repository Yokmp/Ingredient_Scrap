local analysis = {}

local MAX_EXAMPLES = 8
local MAX_INFERRED_CANDIDATES = 200
local MAX_TARGET_CANDIDATES = 10

---Adds a value to a list-like table only while it stays within the example limit.
---@param examples string[]
---@param value string
local function add_example(examples, value)
  if #examples >= MAX_EXAMPLES then return end
  for _, existing in ipairs(examples) do
    if existing == value then return end
  end
  table.insert(examples, value)
end

---Copies a list-like table of strings.
---@param values string[]|nil
---@return string[]
local function copy_string_list(values)
  local copy = {}
  for _, value in ipairs(values or {}) do
    table.insert(copy, value)
  end
  return copy
end

---Returns a deterministic empty type map for item/fluid indexed data.
---@return table
local function typed_map()
  return { item = {}, fluid = {} }
end

---Normalizes one Factorio ingredient or result entry into a compact record.
---@param entry table|string
---@param default_type string
---@return table|nil
local function normalize_entry(entry, default_type)
  if type(entry) == "string" then
    return { type = default_type, name = entry, amount = 1 }
  end
  if type(entry) ~= "table" then return nil end

  local name = entry.name or entry[1]
  if not name then return nil end

  local amount = entry.amount or entry[2] or entry.amount_min or entry.amount_max or 1
  local normalized = {
    type = entry.type or default_type,
    name = name,
    amount = amount,
  }

  if entry.amount_min then normalized.amount_min = entry.amount_min end
  if entry.amount_max then normalized.amount_max = entry.amount_max end
  if entry.probability then normalized.probability = entry.probability end

  return normalized
end

---Collects normalized recipe ingredients.
---@param recipe table
---@return table[]
local function recipe_ingredients(recipe)
  local ingredients = {}
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    local normalized = normalize_entry(ingredient, "item")
    if normalized then table.insert(ingredients, normalized) end
  end
  return ingredients
end

---Collects normalized recipe results without filtering by main_product.
---@param recipe table
---@return table[]
local function recipe_results(recipe)
  local results = {}
  for _, result in ipairs(recipe.results or {}) do
    local normalized = normalize_entry(result, "item")
    if normalized then table.insert(results, normalized) end
  end
  if recipe.result then
    table.insert(results, {
      type = "item",
      name = recipe.result,
      amount = recipe.result_count or 1,
    })
  end
  return results
end

---Adds a recipe reference to a typed index.
---@param index table
---@param entry table
---@param recipe table
local function add_recipe_reference(index, entry, recipe)
  local type_index = index[entry.type] or index.item
  type_index[entry.name] = type_index[entry.name] or {}
  table.insert(type_index[entry.name], {
    recipe = recipe.name,
    category = recipe.category,
    main_product = recipe.main_product,
    amount = entry.amount,
    amount_min = entry.amount_min,
    amount_max = entry.amount_max,
    probability = entry.probability,
  })
end

---Builds producer and consumer indexes over every recipe result and ingredient.
---@return table
function analysis.build_recipe_index()
  local index = {
    summary = {
      recipes = 0,
      ingredients = 0,
      results = 0,
      producer_keys = { item = 0, fluid = 0 },
      consumer_keys = { item = 0, fluid = 0 },
    },
    producers = typed_map(),
    consumers = typed_map(),
    recipes = {},
  }

  for _, recipe in pairs(data.raw.recipe or {}) do
    local ingredients = recipe_ingredients(recipe)
    local results = recipe_results(recipe)

    index.summary.recipes = index.summary.recipes + 1
    index.summary.ingredients = index.summary.ingredients + #ingredients
    index.summary.results = index.summary.results + #results

    index.recipes[recipe.name] = {
      name = recipe.name,
      category = recipe.category,
      enabled = recipe.enabled,
      hidden = recipe.hidden,
      main_product = recipe.main_product,
      ingredients = ingredients,
      results = results,
    }

    for _, ingredient in ipairs(ingredients) do
      add_recipe_reference(index.consumers, ingredient, recipe)
    end
    for _, result in ipairs(results) do
      add_recipe_reference(index.producers, result, recipe)
    end
  end

  for prototype_type, values in pairs(index.producers) do
    for _ in pairs(values) do
      index.summary.producer_keys[prototype_type] = index.summary.producer_keys[prototype_type] + 1
    end
  end
  for prototype_type, values in pairs(index.consumers) do
    for _ in pairs(values) do
      index.summary.consumer_keys[prototype_type] = index.summary.consumer_keys[prototype_type] + 1
    end
  end

  return index
end

---Splits a prototype name into dash-separated tokens.
---@param name string
---@return string[]
local function tokenize_name(name)
  local tokens = {}
  for token in name:gmatch("[^-]+") do
    table.insert(tokens, token)
  end
  return tokens
end

---Returns the positional role of an n-gram inside a token sequence.
---@param start_index integer
---@param length integer
---@param token_count integer
---@return string
local function ngram_position(start_index, length, token_count)
  if length == token_count then return "whole" end
  if start_index == 1 then return "prefix" end
  if start_index + length - 1 == token_count then return "suffix" end
  return "infix"
end

---Records one name n-gram occurrence.
---@param patterns table
---@param key string
---@param position string
---@param prototype_type string
---@param example string
local function add_ngram(patterns, key, position, prototype_type, example)
  patterns[key] = patterns[key] or {
    count = 0,
    positions = { prefix = 0, infix = 0, suffix = 0, whole = 0 },
    prototype_types = {},
    examples = {},
  }

  local pattern = patterns[key]
  pattern.count = pattern.count + 1
  pattern.positions[position] = (pattern.positions[position] or 0) + 1
  pattern.prototype_types[prototype_type] = (pattern.prototype_types[prototype_type] or 0) + 1
  add_example(pattern.examples, example)
end

---Records one place_result-based non-material pattern.
---@param exclusions table
---@param key string
---@param item_name string
local function add_place_result_exclusion(exclusions, key, item_name)
  exclusions.patterns[key] = exclusions.patterns[key] or {
    reason = "item-place-result",
    count = 0,
    examples = {},
  }

  local exclusion = exclusions.patterns[key]
  exclusion.count = exclusion.count + 1
  add_example(exclusion.examples, item_name)
end

---Builds non-material name patterns from items that place entities.
---@return table
local function build_place_result_exclusions()
  local exclusions = {
    summary = {
      items = 0,
      patterns = 0,
    },
    patterns = {},
  }

  for item_name, item in pairs(data.raw.item or {}) do
    if item.place_result then
      local tokens = tokenize_name(item_name)
      exclusions.summary.items = exclusions.summary.items + 1

      for length = 1, math.min(4, #tokens) do
        for start_index = 1, #tokens - length + 1 do
          local parts = {}
          for i = start_index, start_index + length - 1 do
            table.insert(parts, tokens[i])
          end
          add_place_result_exclusion(exclusions, table.concat(parts, "-"), item_name)
        end
      end
    end
  end

  for _ in pairs(exclusions.patterns) do
    exclusions.summary.patterns = exclusions.summary.patterns + 1
  end

  return exclusions
end

---Collects token n-gram statistics over item, fluid, resource, and recipe names.
---@return table
function analysis.build_name_patterns()
  local patterns = {
    summary = {
      prototype_names = 0,
      ngrams = 0,
    },
    ngrams = {},
  }

  local prototype_types = { "item", "fluid", "resource", "recipe" }
  for _, prototype_type in ipairs(prototype_types) do
    for name in pairs(data.raw[prototype_type] or {}) do
      local tokens = tokenize_name(name)
      patterns.summary.prototype_names = patterns.summary.prototype_names + 1

      for length = 1, math.min(4, #tokens) do
        for start_index = 1, #tokens - length + 1 do
          local parts = {}
          for i = start_index, start_index + length - 1 do
            table.insert(parts, tokens[i])
          end

          local key = table.concat(parts, "-")
          add_ngram(
            patterns.ngrams,
            key,
            ngram_position(start_index, length, #tokens),
            prototype_type,
            name
          )
        end
      end
    end
  end

  for _ in pairs(patterns.ngrams) do
    patterns.summary.ngrams = patterns.summary.ngrams + 1
  end

  return patterns
end

---Returns a compact view of the recycle targets selected by the current resolver.
---@param data_table ISdata_table
---@return table
local function current_recycle_targets(data_table)
  local targets = {}
  local recipe_sources = data_table.debug and data_table.debug.sources and data_table.debug.sources.recipes or {}

  for recipe_name, recipe in pairs(data_table.prototypes.recipes or {}) do
    local source = recipe_sources[recipe_name] or {}
    local result = recipe.results and recipe.results[1]
    local scrap_type = source.scrap_type

    if scrap_type and result then
      targets[scrap_type] = targets[scrap_type] or {}
      table.insert(targets[scrap_type], {
        recipe = recipe_name,
        category = recipe.category,
        result_type = source.result_type or result.type,
        result_name = source.result_name or result.name,
        result_amount = result.amount,
      })
    end
  end

  return targets
end

---Returns true when a string contains a dash-separated composite token.
---@param value string
---@return boolean
local function is_composite_name(value)
  return value:find("-", 1, true) ~= nil
end

---Copies a compact pattern record for material-candidate evidence.
---@param pattern table
---@return table
local function compact_pattern(pattern)
  local positions = {}
  for position, count in pairs(pattern.positions or {}) do
    positions[position] = count
  end

  local prototype_types = {}
  for prototype_type, count in pairs(pattern.prototype_types or {}) do
    prototype_types[prototype_type] = count
  end

  return {
    count = pattern.count,
    positions = positions,
    prototype_types = prototype_types,
    examples = copy_string_list(pattern.examples),
  }
end

---Returns true when a prototype name contains the material as a dash-bounded token sequence.
---@param name string
---@param material_name string
---@return boolean
local function name_contains_material(name, material_name)
  if name == material_name then return true end
  local left = name:find(material_name, 1, true)
  if not left then return false end

  while left do
    local right = left + #material_name - 1
    local before = left == 1 or name:sub(left - 1, left - 1) == "-"
    local after = right == #name or name:sub(right + 1, right + 1) == "-"
    if before and after then return true end
    left = name:find(material_name, left + 1, true)
  end

  return false
end

---Returns a stable priority bonus for common recycle target shapes.
---@param result_name string
---@return number
local function target_shape_score(result_name)
  if result_name:match("%-plate$") then return 24 end
  if result_name:match("%-ingot$") then return 22 end
  if result_name:match("%-solution$") then return 20 end
  if result_name:match("^molten%-") then return 18 end
  if result_name:match("%-ore$") then return 12 end
  return 0
end

---Adds one compact recipe name to a target candidate.
---@param candidate table
---@param recipe_name string
local function add_candidate_recipe(candidate, recipe_name)
  candidate.recipes = candidate.recipes or {}
  add_example(candidate.recipes, recipe_name)
end

---Adds or updates one passive recycle target candidate.
---@param candidates table
---@param material_name string
---@param result table
---@param recipe table
---@param reason string
---@param score number
local function add_target_candidate(candidates, material_name, result, recipe, reason, score)
  if name_contains_material(result.name, material_name .. "-scrap") then return end

  local key = (result.type or "item") .. "/" .. result.name
  candidates[key] = candidates[key] or {
    result_type = result.type or "item",
    result_name = result.name,
    score = 0,
    reasons = {},
    recipes = {},
  }

  local candidate = candidates[key]
  candidate.score = candidate.score + score + target_shape_score(result.name)
  candidate.reasons[reason] = (candidate.reasons[reason] or 0) + 1
  add_candidate_recipe(candidate, recipe.name)
end

---Returns true when at least one normalized recipe entry references the material.
---@param entries table[]
---@param material_name string
---@return boolean
local function entries_contain_material(entries, material_name)
  for _, entry in ipairs(entries or {}) do
    if name_contains_material(entry.name, material_name) then return true end
  end
  return false
end

---Converts a candidate map into a sorted compact candidate list.
---@param candidates table
---@return table[]
local function sorted_target_candidates(candidates)
  local list = {}
  for _, candidate in pairs(candidates) do
    table.insert(list, candidate)
  end

  table.sort(list, function(a, b)
    if a.score == b.score then return a.result_name < b.result_name end
    return a.score > b.score
  end)

  while #list > MAX_TARGET_CANDIDATES do
    table.remove(list)
  end

  return list
end

---Copies a target candidate so the Lua dump does not need shared-table placeholders.
---@param candidate table|nil
---@return table|nil
local function copy_target_candidate(candidate)
  if not candidate then return nil end

  local reasons = {}
  for reason, count in pairs(candidate.reasons or {}) do
    reasons[reason] = count
  end

  return {
    result_type = candidate.result_type,
    result_name = candidate.result_name,
    score = candidate.score,
    reasons = reasons,
    recipes = copy_string_list(candidate.recipes),
  }
end

---Copies current resolver target records for embedding in analysis sections.
---@param targets table[]|nil
---@return table[]
local function copy_current_targets(targets)
  local copy = {}
  for _, target in ipairs(targets or {}) do
    table.insert(copy, {
      recipe = target.recipe,
      category = target.category,
      result_type = target.result_type,
      result_name = target.result_name,
      result_amount = target.result_amount,
    })
  end
  return copy
end

---Builds passive recycle target candidates by comparing material-bearing ingredients and results.
---@param material_candidates table
---@param recipe_index table
---@param current_targets table
---@return table
local function build_target_candidates(material_candidates, recipe_index, current_targets)
  local targets = {}

  for material_name in pairs(material_candidates) do
    local candidates = {}

    for _, recipe in pairs(recipe_index.recipes or {}) do
      local ingredients_match = entries_contain_material(recipe.ingredients, material_name)
      local results_match = entries_contain_material(recipe.results, material_name)

      for _, result in ipairs(recipe.results or {}) do
        if results_match and name_contains_material(result.name, material_name) then
          add_target_candidate(candidates, material_name, result, recipe, "material-result", 14)
        end
        if ingredients_match then
          add_target_candidate(candidates, material_name, result, recipe, "material-input-to-result", 10)
        end
        if ingredients_match and results_match and name_contains_material(result.name, material_name) then
          add_target_candidate(candidates, material_name, result, recipe, "direct-chain-step", 18)
        end
      end
    end

    local list = sorted_target_candidates(candidates)
    if #list > 0 then
      local current = copy_current_targets(current_targets[material_name])
      targets[material_name] = {
        current = current,
        suggested = copy_target_candidate(list[1]),
        candidates = list,
      }

      if current[1] and list[1] then
        targets[material_name].agrees_with_current =
          current[1].result_type == list[1].result_type and
          current[1].result_name == list[1].result_name
      end
    end
  end

  return targets
end

---Builds a compact summary over passive recycle target candidates.
---@param target_candidates table
---@return table
local function summarize_target_candidates(target_candidates)
  local summary = {
    materials = 0,
    with_current_target = 0,
    analysis_only = 0,
    agrees_with_current = 0,
    differs_from_current = 0,
    differences = {},
  }

  local material_names = {}
  for material_name in pairs(target_candidates or {}) do
    table.insert(material_names, material_name)
  end
  table.sort(material_names)

  for _, material_name in ipairs(material_names) do
    local target = target_candidates[material_name]
    local current = target.current and target.current[1]
    local suggested = target.suggested

    summary.materials = summary.materials + 1
    if current then
      summary.with_current_target = summary.with_current_target + 1
      if target.agrees_with_current then
        summary.agrees_with_current = summary.agrees_with_current + 1
      else
        summary.differs_from_current = summary.differs_from_current + 1
        if #summary.differences < MAX_EXAMPLES then
          table.insert(summary.differences, {
            material = material_name,
            current = {
              result_type = current.result_type,
              result_name = current.result_name,
            },
            suggested = suggested and {
              result_type = suggested.result_type,
              result_name = suggested.result_name,
              score = suggested.score,
            } or nil,
          })
        end
      end
    else
      summary.analysis_only = summary.analysis_only + 1
    end
  end

  return summary
end

---Returns a material set from current solid and fluid material lists.
---@param data_table ISdata_table
---@return table<string, boolean>
local function current_material_set(data_table)
  local materials = {}
  for _, material_name in ipairs(data_table.materials.solid or {}) do
    materials[material_name] = true
  end
  for _, material_name in ipairs(data_table.materials.fluid or {}) do
    materials[material_name] = true
  end
  return materials
end

---Builds passive material candidates from current materials and name n-grams.
---@param data_table ISdata_table
---@param name_patterns table
---@param place_result_exclusions table
---@return table
local function build_material_candidates(data_table, name_patterns, place_result_exclusions)
  local candidates = {}
  local current_materials = current_material_set(data_table)

  for material_name in pairs(current_materials) do
    local pattern = name_patterns.ngrams[material_name]
    candidates[material_name] = {
      current_material = true,
      reasons = { "current-resolver-material" },
      pattern = pattern and compact_pattern(pattern) or nil,
    }
  end

  local inferred_keys = {}
  for ngram, pattern in pairs(name_patterns.ngrams or {}) do
    if is_composite_name(ngram) and pattern.count >= 4 and
        (current_materials[ngram] or not place_result_exclusions.patterns[ngram]) then
      table.insert(inferred_keys, ngram)
    end
  end

  table.sort(inferred_keys, function(a, b)
    local left = name_patterns.ngrams[a]
    local right = name_patterns.ngrams[b]
    if left.count == right.count then return a < b end
    return left.count > right.count
  end)

  for i = 1, math.min(MAX_INFERRED_CANDIDATES, #inferred_keys) do
    local ngram = inferred_keys[i]
    local pattern = name_patterns.ngrams[ngram]
    candidates[ngram] = candidates[ngram] or {
      current_material = current_materials[ngram] or false,
      reasons = {},
    }
    table.insert(candidates[ngram].reasons, "name-ngram")
    candidates[ngram].pattern = compact_pattern(pattern)
  end

  return candidates
end

---Compares current resolver materials with passive material candidates.
---@param data_table ISdata_table
---@param material_candidates table
---@return table
local function compare_current_to_candidates(data_table, material_candidates)
  local current_materials = current_material_set(data_table)
  local only_current = {}
  local only_analysis = {}
  local shared = {}

  for material_name in pairs(current_materials) do
    if material_candidates[material_name] then
      table.insert(shared, material_name)
    else
      table.insert(only_current, material_name)
    end
  end

  for material_name, candidate in pairs(material_candidates) do
    if not current_materials[material_name] and candidate.pattern then
      table.insert(only_analysis, {
        material = material_name,
        count = candidate.pattern.count,
        examples = copy_string_list(candidate.pattern.examples),
      })
    end
  end

  table.sort(only_current)
  table.sort(shared)
  table.sort(only_analysis, function(a, b)
    if a.count == b.count then return a.material < b.material end
    return a.count > b.count
  end)

  return {
    materials_only_current = only_current,
    materials_shared = shared,
    materials_only_analysis = only_analysis,
  }
end

---Builds the passive recipe-chain analysis dump.
---@param data_table ISdata_table
---@return table
function analysis.build(data_table)
  local recipe_index = analysis.build_recipe_index()
  local name_patterns = analysis.build_name_patterns()
  local place_result_exclusions = build_place_result_exclusions()
  local material_candidates = build_material_candidates(data_table, name_patterns, place_result_exclusions)
  local current_targets = current_recycle_targets(data_table)
  local target_candidates = build_target_candidates(material_candidates, recipe_index, current_targets)

  return {
    schema = "ingredient-scrap-recipe-chain-analysis/v1",
    mode = "passive",
    recipe_index = recipe_index,
    name_patterns = name_patterns,
    material_candidates = material_candidates,
    target_candidates = target_candidates,
    target_candidate_summary = summarize_target_candidates(target_candidates),
    comparison = compare_current_to_candidates(data_table, material_candidates),
    filters = {
      place_result = place_result_exclusions,
    },
    current = {
      materials = {
        solid = data_table.materials.solid,
        fluid = data_table.materials.fluid,
      },
      recycle_targets = current_targets,
    },
  }
end

return analysis
