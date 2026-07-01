local analysis = {}

local MAX_EXAMPLES = 8
local MAX_INFERRED_CANDIDATES = 200
local MAX_TARGET_CANDIDATES = 10
local MAX_SUMMARY_ENTRIES = 12
local MAX_RECIPE_SHAPE_EVIDENCE = 3
local MAX_RECIPE_SHAPE_ENTRIES = 12

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
    enabled = recipe.enabled,
    hidden = recipe.hidden,
    hide_from_player_crafting = recipe.hide_from_player_crafting,
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
      hide_from_player_crafting = recipe.hide_from_player_crafting,
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

---Records one item-field-based non-material pattern.
---@param exclusions table
---@param key string
---@param item_name string
---@param reason string
local function add_item_field_exclusion(exclusions, key, item_name, reason)
  exclusions.patterns[key] = exclusions.patterns[key] or {
    reason = reason,
    count = 0,
    examples = {},
  }

  local exclusion = exclusions.patterns[key]
  exclusion.count = exclusion.count + 1
  add_example(exclusion.examples, item_name)
end

---Builds non-material name patterns from items carrying a specific placement field.
---@param field_name string
---@param reason string
---@return table
local function build_item_field_exclusions(field_name, reason)
  local exclusions = {
    summary = {
      items = 0,
      patterns = 0,
    },
    patterns = {},
  }

  for item_name, item in pairs(data.raw.item or {}) do
    if item[field_name] then
      local tokens = tokenize_name(item_name)
      exclusions.summary.items = exclusions.summary.items + 1

      for length = 1, math.min(4, #tokens) do
        for start_index = 1, #tokens - length + 1 do
          local parts = {}
          for i = start_index, start_index + length - 1 do
            table.insert(parts, tokens[i])
          end
          add_item_field_exclusion(exclusions, table.concat(parts, "-"), item_name, reason)
        end
      end
    end
  end

  for _ in pairs(exclusions.patterns) do
    exclusions.summary.patterns = exclusions.summary.patterns + 1
  end

  return exclusions
end

---Builds all passive non-material filters used by material inference.
---@return table
local function build_candidate_filters()
  local filters = {
    place_result = build_item_field_exclusions("place_result", "item-place-result"),
    place_as_tile = build_item_field_exclusions("place_as_tile", "item-place-as-tile"),
    place_as_equipment_result = build_item_field_exclusions("place_as_equipment_result", "item-place-as-equipment-result"),
    patterns = {},
  }

  for filter_name, filter in pairs(filters) do
    if filter_name ~= "patterns" then
      for pattern, exclusion in pairs(filter.patterns or {}) do
        filters.patterns[pattern] = filters.patterns[pattern] or {
          reasons = {},
          count = 0,
          examples = {},
        }

        local combined = filters.patterns[pattern]
        combined.reasons[exclusion.reason] = (combined.reasons[exclusion.reason] or 0) + exclusion.count
        combined.count = combined.count + exclusion.count
        for _, example in ipairs(exclusion.examples or {}) do
          add_example(combined.examples, example)
        end
      end
    end
  end

  return filters
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
  if result_name:match("%-beam$") then return 20 end
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

---Returns a compact copy of a normalized ingredient or result entry with a relation label.
---@param entry table
---@param material_name string
---@param target_result table|nil
---@param is_result boolean
---@return table
local function copy_shape_entry(entry, material_name, target_result, is_result)
  local relation = name_contains_material(entry.name, material_name) and "material" or "other"
  if is_result and target_result and
      (entry.type or "item") == (target_result.type or "item") and
      entry.name == target_result.name then
    relation = "target"
  end

  local copy = {
    type = entry.type or "item",
    name = entry.name,
    relation = relation,
  }

  if entry.amount then copy.amount = entry.amount end
  if entry.amount_min then copy.amount_min = entry.amount_min end
  if entry.amount_max then copy.amount_max = entry.amount_max end
  if entry.probability then copy.probability = entry.probability end

  return copy
end

---Copies a bounded list of normalized recipe entries as recipe-shape evidence.
---@param entries table[]|nil
---@param material_name string
---@param target_result table|nil
---@param is_result boolean
---@return table[]
local function copy_shape_entries(entries, material_name, target_result, is_result)
  local copy = {}
  for _, entry in ipairs(entries or {}) do
    if #copy >= MAX_RECIPE_SHAPE_ENTRIES then break end
    table.insert(copy, copy_shape_entry(entry, material_name, target_result, is_result))
  end
  return copy
end

---Copies already-built recipe-shape entries without sharing tables in the dump.
---@param entries table[]|nil
---@return table[]
local function copy_existing_shape_entries(entries)
  local copy = {}
  for _, entry in ipairs(entries or {}) do
    local entry_copy = {
      type = entry.type,
      name = entry.name,
      relation = entry.relation,
    }
    if entry.amount then entry_copy.amount = entry.amount end
    if entry.amount_min then entry_copy.amount_min = entry.amount_min end
    if entry.amount_max then entry_copy.amount_max = entry.amount_max end
    if entry.probability then entry_copy.probability = entry.probability end
    table.insert(copy, entry_copy)
  end
  return copy
end

---Copies recipe-shape evidence without shared nested tables.
---@param evidence table[]|nil
---@return table[]
local function copy_recipe_shape_evidence(evidence)
  local copy = {}
  for _, shape in ipairs(evidence or {}) do
    table.insert(copy, {
      recipe = shape.recipe,
      category = shape.category,
      target_result = copy_existing_shape_entries({ shape.target_result })[1],
      ingredients = copy_existing_shape_entries(shape.ingredients),
      results = copy_existing_shape_entries(shape.results),
    })
  end
  return copy
end

---Adds one compact recipe-shape evidence record to a target candidate.
---@param candidate table
---@param material_name string
---@param target_result table
---@param recipe table
local function add_recipe_shape_evidence(candidate, material_name, target_result, recipe)
  candidate.recipe_shape_evidence = candidate.recipe_shape_evidence or {}
  candidate.recipe_shape_recipe_seen = candidate.recipe_shape_recipe_seen or {}
  if candidate.recipe_shape_recipe_seen[recipe.name] then return end
  if #candidate.recipe_shape_evidence >= MAX_RECIPE_SHAPE_EVIDENCE then return end

  candidate.recipe_shape_recipe_seen[recipe.name] = true
  table.insert(candidate.recipe_shape_evidence, {
    recipe = recipe.name,
    category = recipe.category,
    target_result = copy_shape_entry(target_result, material_name, target_result, true),
    ingredients = copy_shape_entries(recipe.ingredients, material_name, target_result, false),
    results = copy_shape_entries(recipe.results, material_name, target_result, true),
  })
end

---Adds or updates one passive recycle target candidate.
---@param candidates table
---@param material_name string
---@param result table
---@param recipe table
---@param reason string
---@param score number
---@param candidate_filters table
local function add_target_candidate(candidates, material_name, result, recipe, reason, score, candidate_filters)
  if name_contains_material(result.name, material_name .. "-scrap") then return end
  if (result.type or "item") == "item" and candidate_filters.patterns[result.name] then return end

  local key = (result.type or "item") .. "/" .. result.name
  candidates[key] = candidates[key] or {
    result_type = result.type or "item",
    result_name = result.name,
    score = 0,
    reasons = {},
    recipes = {},
    recipe_shape_evidence = {},
    recipe_categories = {},
    recipe_flags = {
      disabled = 0,
      hidden = 0,
    },
  }

  local candidate = candidates[key]
  candidate.score = candidate.score + score + target_shape_score(result.name)
  candidate.reasons[reason] = (candidate.reasons[reason] or 0) + 1
  if recipe.category then
    candidate.recipe_categories[recipe.category] = (candidate.recipe_categories[recipe.category] or 0) + 1
  end
  if recipe.enabled == false then
    candidate.recipe_flags.disabled = candidate.recipe_flags.disabled + 1
  end
  if recipe.hidden then
    candidate.recipe_flags.hidden = candidate.recipe_flags.hidden + 1
  end
  add_candidate_recipe(candidate, recipe.name)
  add_recipe_shape_evidence(candidate, material_name, result, recipe)
end

---Returns true when a result prototype is explicitly hidden.
---@param result table
---@return boolean
local function is_hidden_result_prototype(result)
  local result_type = result.type or "item"
  local prototype = data.raw[result_type] and data.raw[result_type][result.name]
  return prototype and prototype.hidden or false
end

---Returns true when an item result should not provide solid target evidence.
---@param result table
---@return boolean
local function is_solid_target_artifact_result(result)
  local name = result.name or ""
  return is_hidden_result_prototype(result) or
    name:find("barrel", 1, true) ~= nil or
    name:find("science-pack", 1, true) ~= nil or
    name:find("fuel-cell", 1, true) ~= nil or
    name:find("equipment", 1, true) ~= nil or
    name:find("product", 1, true) ~= nil
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
    recipe_categories = copy_count_map(candidate.recipe_categories),
    recipe_flags = {
      disabled = candidate.recipe_flags and candidate.recipe_flags.disabled or 0,
      hidden = candidate.recipe_flags and candidate.recipe_flags.hidden or 0,
    },
    recipe_shape_evidence = copy_recipe_shape_evidence(candidate.recipe_shape_evidence),
    recipes = copy_string_list(candidate.recipes),
  }
end

---Copies a list of target candidates without internal bookkeeping fields.
---@param candidates table[]
---@return table[]
local function copy_target_candidate_list(candidates)
  local copy = {}
  for _, candidate in ipairs(candidates or {}) do
    table.insert(copy, copy_target_candidate(candidate))
  end
  return copy
end

---Copies current resolver target records for embedding in analysis sections.
---@param targets table[]|nil
---@param result_type string|nil
---@return table[]
local function copy_current_targets(targets, result_type)
  local copy = {}
  for _, target in ipairs(targets or {}) do
    if not result_type or target.result_type == result_type then
      table.insert(copy, {
        recipe = target.recipe,
        category = target.category,
        result_type = target.result_type,
        result_name = target.result_name,
        result_amount = target.result_amount,
      })
    end
  end
  return copy
end

---Returns true when two target records point to the same prototype.
---@param current table
---@param suggested table
---@return boolean
local function target_records_match(current, suggested)
  return current.result_type == suggested.result_type and current.result_name == suggested.result_name
end

---Returns true when a suggested target matches any current resolver target for the same mode.
---@param current_targets table[]|nil
---@param suggested table|nil
---@return boolean
local function any_current_target_matches(current_targets, suggested)
  if not suggested then return false end
  for _, current in ipairs(current_targets or {}) do
    if target_records_match(current, suggested) then return true end
  end
  return false
end

---Returns a compact copy of one passive target candidate for summaries.
---@param material_name string
---@param target table
---@return table
local function compact_target_difference(material_name, target)
  local current = target.current and target.current[1]
  local suggested = target.suggested

  return {
    material = material_name,
    current = current and {
      result_type = current.result_type,
      result_name = current.result_name,
    } or nil,
    suggested = suggested and {
      result_type = suggested.result_type,
      result_name = suggested.result_name,
      score = suggested.score,
      recipes = copy_string_list(suggested.recipes),
    } or nil,
  }
end

---Builds passive recycle target candidates by comparing material-bearing ingredients and results.
---@param material_candidates table
---@param recipe_index table
---@param current_targets table
---@param candidate_filters table
---@param result_type string|nil
---@param skip_recipe fun(recipe: table): boolean|nil
---@param skip_result fun(result: table): boolean|nil
---@return table
local function build_target_candidates(material_candidates, recipe_index, current_targets, candidate_filters, result_type, skip_recipe, skip_result)
  local targets = {}

  for material_name in pairs(material_candidates) do
    local candidates = {}

    for _, recipe in pairs(recipe_index.recipes or {}) do
      if not skip_recipe or not skip_recipe(recipe) then
        local ingredients_match = entries_contain_material(recipe.ingredients, material_name)
        local results_match = entries_contain_material(recipe.results, material_name)

        for _, result in ipairs(recipe.results or {}) do
          if (not result_type or (result.type or "item") == result_type) and
              (not skip_result or not skip_result(result)) then
            if results_match and name_contains_material(result.name, material_name) then
              add_target_candidate(candidates, material_name, result, recipe, "material-result", 14, candidate_filters)
            end
            if ingredients_match then
              add_target_candidate(candidates, material_name, result, recipe, "material-input-to-result", 10, candidate_filters)
            end
            if ingredients_match and results_match and name_contains_material(result.name, material_name) then
              add_target_candidate(candidates, material_name, result, recipe, "direct-chain-step", 18, candidate_filters)
            end
          end
        end
      end
    end

    local list = sorted_target_candidates(candidates)
    if #list > 0 then
      local current = copy_current_targets(current_targets[material_name], result_type)
      targets[material_name] = {
        current = current,
        suggested = copy_target_candidate(list[1]),
        candidates = copy_target_candidate_list(list),
      }

      targets[material_name].agrees_with_current = any_current_target_matches(current, list[1])
    end
  end

  return targets
end

---Returns true when a recipe should not provide solid target evidence.
---@param recipe table
---@return boolean
local function is_solid_target_artifact_recipe(recipe)
  local name = recipe.name or ""
  return name:find("barrel", 1, true) ~= nil or
    name:find("recycling", 1, true) ~= nil or
    name:find("matter-to", 1, true) ~= nil or
    name:find("to-matter", 1, true) ~= nil or
    name:find("from-dirty-water", 1, true) ~= nil
end

---Builds recipe artifact filter diagnostics.
---@param recipe_index table
---@return table
local function build_recipe_filters(recipe_index)
  local solid_artifacts = {
    summary = {
      recipes = 0,
      patterns = 5,
    },
    patterns = {
      barrel = {
        reason = "recipe-name-barrel",
        count = 0,
        examples = {},
      },
      recycling = {
        reason = "recipe-name-recycling",
        count = 0,
        examples = {},
      },
      ["from-dirty-water"] = {
        reason = "recipe-name-from-dirty-water",
        count = 0,
        examples = {},
      },
      ["matter-to"] = {
        reason = "recipe-name-matter-to",
        count = 0,
        examples = {},
      },
      ["to-matter"] = {
        reason = "recipe-name-to-matter",
        count = 0,
        examples = {},
      },
    },
  }

  for recipe_name, recipe in pairs(recipe_index.recipes or {}) do
    local matched = false
    if recipe_name:find("barrel", 1, true) then
      solid_artifacts.patterns.barrel.count = solid_artifacts.patterns.barrel.count + 1
      add_example(solid_artifacts.patterns.barrel.examples, recipe_name)
      matched = true
    end
    if recipe_name:find("recycling", 1, true) then
      solid_artifacts.patterns.recycling.count = solid_artifacts.patterns.recycling.count + 1
      add_example(solid_artifacts.patterns.recycling.examples, recipe_name)
      matched = true
    end
    if recipe_name:find("from-dirty-water", 1, true) then
      solid_artifacts.patterns["from-dirty-water"].count = solid_artifacts.patterns["from-dirty-water"].count + 1
      add_example(solid_artifacts.patterns["from-dirty-water"].examples, recipe_name)
      matched = true
    end
    if recipe_name:find("matter-to", 1, true) then
      solid_artifacts.patterns["matter-to"].count = solid_artifacts.patterns["matter-to"].count + 1
      add_example(solid_artifacts.patterns["matter-to"].examples, recipe_name)
      matched = true
    end
    if recipe_name:find("to-matter", 1, true) then
      solid_artifacts.patterns["to-matter"].count = solid_artifacts.patterns["to-matter"].count + 1
      add_example(solid_artifacts.patterns["to-matter"].examples, recipe_name)
      matched = true
    end
    if matched then
      solid_artifacts.summary.recipes = solid_artifacts.summary.recipes + 1
    end
  end

  return {
    solid_artifact = solid_artifacts,
  }
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
          table.insert(summary.differences, compact_target_difference(material_name, target))
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
---@param candidate_filters table
---@return table
local function build_material_candidates(data_table, name_patterns, candidate_filters)
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
        (current_materials[ngram] or not candidate_filters.patterns[ngram]) then
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

---Builds a compact top list of analysis-only material candidates.
---@param comparison table
---@return table[]
local function summarize_analysis_only_materials(comparison)
  local top = {}
  for i = 1, math.min(MAX_SUMMARY_ENTRIES, #(comparison.materials_only_analysis or {})) do
    local candidate = comparison.materials_only_analysis[i]
    table.insert(top, {
      material = candidate.material,
      count = candidate.count,
      examples = copy_string_list(candidate.examples),
    })
  end
  return top
end

---Builds a compact top list of target differences sorted by suggested score.
---@param target_candidates table
---@return table[]
local function summarize_target_differences(target_candidates)
  local differences = {}
  for material_name, target in pairs(target_candidates or {}) do
    if target.current and target.current[1] and target.suggested and not target.agrees_with_current then
      table.insert(differences, compact_target_difference(material_name, target))
    end
  end

  table.sort(differences, function(a, b)
    local left = a.suggested and a.suggested.score or 0
    local right = b.suggested and b.suggested.score or 0
    if left == right then return a.material < b.material end
    return left > right
  end)

  while #differences > MAX_SUMMARY_ENTRIES do
    table.remove(differences)
  end

  return differences
end

---Builds a compact top list of filter patterns.
---@param filter table
---@return table[]
local function summarize_filter_patterns(filter)
  local patterns = {}
  for pattern, exclusion in pairs(filter.patterns or {}) do
    table.insert(patterns, {
      pattern = pattern,
      count = exclusion.count,
      reason = exclusion.reason,
      reasons = exclusion.reasons and copy_count_map(exclusion.reasons) or nil,
      examples = copy_string_list(exclusion.examples),
    })
  end

  table.sort(patterns, function(a, b)
    if a.count == b.count then return a.pattern < b.pattern end
    return a.count > b.count
  end)

  while #patterns > MAX_SUMMARY_ENTRIES do
    table.remove(patterns)
  end

  return patterns
end

---Builds the top-level human-readable analysis summary.
---@param recipe_index table
---@param name_patterns table
---@param candidate_filters table
---@param recipe_filters table
---@param comparison table
---@param target_candidates table
---@param target_candidates_by_mode table
---@return table
local function build_analysis_summary(recipe_index, name_patterns, candidate_filters, recipe_filters, comparison, target_candidates, target_candidates_by_mode)
  return {
    recipe_index = {
      recipes = recipe_index.summary.recipes,
      ingredients = recipe_index.summary.ingredients,
      results = recipe_index.summary.results,
      producer_keys = copy_count_map(recipe_index.summary.producer_keys),
      consumer_keys = copy_count_map(recipe_index.summary.consumer_keys),
    },
    name_patterns = {
      prototype_names = name_patterns.summary.prototype_names,
      ngrams = name_patterns.summary.ngrams,
    },
    materials_only_analysis_top = summarize_analysis_only_materials(comparison),
    target_differences_top = summarize_target_differences(target_candidates),
    target_differences_top_by_mode = {
      solid = summarize_target_differences(target_candidates_by_mode.solid),
      fluid = summarize_target_differences(target_candidates_by_mode.fluid),
    },
    filters = {
      place_result = {
        summary = {
          items = candidate_filters.place_result.summary.items,
          patterns = candidate_filters.place_result.summary.patterns,
        },
        top_patterns = summarize_filter_patterns(candidate_filters.place_result),
      },
      place_as_tile = {
        summary = {
          items = candidate_filters.place_as_tile.summary.items,
          patterns = candidate_filters.place_as_tile.summary.patterns,
        },
        top_patterns = summarize_filter_patterns(candidate_filters.place_as_tile),
      },
      place_as_equipment_result = {
        summary = {
          items = candidate_filters.place_as_equipment_result.summary.items,
          patterns = candidate_filters.place_as_equipment_result.summary.patterns,
        },
        top_patterns = summarize_filter_patterns(candidate_filters.place_as_equipment_result),
      },
      combined_top_patterns = summarize_filter_patterns(candidate_filters),
      recipe = {
        solid_artifact = {
          summary = {
            recipes = recipe_filters.solid_artifact.summary.recipes,
            patterns = recipe_filters.solid_artifact.summary.patterns,
          },
          top_patterns = summarize_filter_patterns(recipe_filters.solid_artifact),
        },
      },
    },
  }
end

---Builds the passive recipe-chain analysis dump.
---@param data_table ISdata_table
---@return table
function analysis.build(data_table)
  local recipe_index = analysis.build_recipe_index()
  local name_patterns = analysis.build_name_patterns()
  local candidate_filters = build_candidate_filters()
  local recipe_filters = build_recipe_filters(recipe_index)
  local material_candidates = build_material_candidates(data_table, name_patterns, candidate_filters)
  local current_targets = current_recycle_targets(data_table)
  local target_candidates = build_target_candidates(material_candidates, recipe_index, current_targets, candidate_filters)
  local target_candidates_by_mode = {
    solid = build_target_candidates(
      material_candidates,
      recipe_index,
      current_targets,
      candidate_filters,
      "item",
      is_solid_target_artifact_recipe,
      is_solid_target_artifact_result
    ),
    fluid = build_target_candidates(material_candidates, recipe_index, current_targets, candidate_filters, "fluid"),
  }
  local comparison = compare_current_to_candidates(data_table, material_candidates)

  return {
    schema = "ingredient-scrap-recipe-chain-analysis/v1",
    mode = "passive",
    summary = build_analysis_summary(recipe_index, name_patterns, candidate_filters, recipe_filters, comparison, target_candidates, target_candidates_by_mode),
    recipe_index = recipe_index,
    name_patterns = name_patterns,
    material_candidates = material_candidates,
    target_candidates = target_candidates,
    target_candidates_by_mode = target_candidates_by_mode,
    target_candidate_summary = summarize_target_candidates(target_candidates),
    target_candidate_summary_by_mode = {
      solid = summarize_target_candidates(target_candidates_by_mode.solid),
      fluid = summarize_target_candidates(target_candidates_by_mode.fluid),
    },
    comparison = comparison,
    filters = candidate_filters,
    recipe_filters = recipe_filters,
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
