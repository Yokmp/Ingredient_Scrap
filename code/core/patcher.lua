--------------------------------
---*PATCHER*                  --
--------------------------------

---Appends a normalized validation error to the provided error list.
local function add_error(errors, id, name, message, details)
  table.insert(errors, {
    id = id,
    name = name,
    message = message,
    details = details,
  })
end

---Logs a disabled generated prototype as a warning without failing validation.
local function warn_disabled_prototype(prototype_type, name, prototype, source)
  if prototype.enabled ~= false then return end
  if yokmods.ingredient_scrap.is_log then
    yokmods.ingredient_scrap.is_log(
      "patcher",
      "warn",
      "validate-generated-prototypes",
      "Generated " .. prototype_type .. " is disabled; keeping it because API or compat mods may do this intentionally.",
      { prototype_type = prototype_type, name = name, source = source }
    )
  elseif log then
    log("[IS][warn][patcher][validate-generated-prototypes] Generated " .. prototype_type .. " is disabled: " .. name)
  end
end

---Returns true when a value is a valid RGB or RGBA Factorio color table.
local function is_color(value)
  if type(value) ~= "table" then return false end
  if value.r ~= nil or value.g ~= nil or value.b ~= nil then
    return type(value.r) == "number" and type(value.g) == "number" and type(value.b) == "number"
  end
  local count = 0
  for key, component in pairs(value) do
    if type(key) ~= "number" or type(component) ~= "number" then return false end
    count = count + 1
  end
  return count == 3 or count == 4
end

---Validates generated items, recipes, and technologies before they are registered with Factorio.
function yokmods.ingredient_scrap.validate_generated_prototypes()
  local data_table = yokmods.ingredient_scrap.data_table
  local errors = {}

  for name, item in pairs(data_table.prototypes.items or {}) do
    local source = data_table.debug and data_table.debug.sources and data_table.debug.sources.items[name] or nil
    if item.type ~= "item" then
      add_error(errors, "item.type", name, "Generated item has invalid type", { type = item.type, source = source })
    end
    if item.name ~= name then
      add_error(errors, "item.name", name, "Generated item name does not match table key", { prototype_name = item.name, source = source })
    end
    if not item.icon and not item.icons then
      add_error(errors, "item.icons", name, "Generated item has neither icon nor icons", { source = source })
    end
    if not item.stack_size or item.stack_size <= 0 then
      add_error(errors, "item.stack_size", name, "Generated item has invalid stack_size", { stack_size = item.stack_size, source = source })
    end
    for index, icon_layer in ipairs(item.icons or {}) do
      if icon_layer.tint and not is_color(icon_layer.tint) then
        add_error(errors, "item.tint", name, "Generated item icon layer has invalid tint", { icon_index = index, tint = icon_layer.tint, source = source })
      end
    end
  end

  for name, recipe in pairs(data_table.prototypes.recipes or {}) do
    local source = data_table.debug and data_table.debug.sources and data_table.debug.sources.recipes[name] or nil
    warn_disabled_prototype("recipe", name, recipe, source)
    if recipe.type ~= "recipe" then
      add_error(errors, "recipe.type", name, "Generated recipe has invalid type", { type = recipe.type, source = source })
    end
    if recipe.name ~= name then
      add_error(errors, "recipe.name", name, "Generated recipe name does not match table key", { prototype_name = recipe.name, source = source })
    end
    if not recipe.ingredients or not recipe.ingredients[1] then
      add_error(errors, "recipe.ingredients", name, "Generated recipe has no ingredients", { source = source })
    end
    if not recipe.results or not recipe.results[1] then
      add_error(errors, "recipe.results", name, "Generated recipe has no results", { source = source })
    end
    if not recipe.category then
      add_error(errors, "recipe.category", name, "Generated recycle recipe has no category", { source = source })
    end
  end

  for name, tech in pairs(data_table.prototypes.technology or {}) do
    warn_disabled_prototype("technology", name, tech)
    if tech.type ~= "technology" then
      add_error(errors, "technology.type", name, "Generated technology has invalid type", { type = tech.type })
    end
    if tech.name ~= name then
      add_error(errors, "technology.name", name, "Generated technology name does not match table key", { prototype_name = tech.name })
    end
    if not tech.effects or not tech.effects[1] then
      add_error(errors, "technology.effects", name, "Generated technology has no effects")
    end
    if not tech.research_trigger then
      add_error(errors, "technology.research_trigger", name, "Generated technology has no research_trigger")
    end
  end

  return errors
end

---Derives recycle recipe input amounts from the expected scrap output of all patched recipes.
function yokmods.ingredient_scrap.patch_recycle_amounts()
  local data_table = yokmods.ingredient_scrap.data_table
  local totals = {}

  for _, insert in pairs(data_table.inserts.recipes) do
    if insert.results then
      for _, result in ipairs(insert.results) do
        local scrap_name = result.name
        totals[scrap_name] = totals[scrap_name] or { sum = 0, count = 0 }
        local expected
        if ISsettings.fixed_amount then
          expected = (result.amount or 1) * (result.probability or 1)
        else
          local mid = ((result.amount_min or 1) + (result.amount_max or 1)) / 2
          expected = mid * (result.probability or 1)
        end
        totals[scrap_name].sum = totals[scrap_name].sum + expected
        totals[scrap_name].count = totals[scrap_name].count + 1
      end
    end
  end

  for scrap_name, total in pairs(totals) do
    local avg = total.sum / total.count
    local needed = ISsettings.needed
    if avg > 0 then
      needed = math.max(math.floor(ISsettings.needed / avg), 1)
    end
    local scrap_type = scrap_name:gsub("^yis%-", ""):gsub("%-scrap$", "")
    local base_recipe_name = yokmods.ingredient_scrap.get_recycle_recipe_name(scrap_type)
    local recipe_names = {
      base_recipe_name,
      base_recipe_name .. "-to-fluid",
    }

    for _, recipe_name in ipairs(recipe_names) do
      local recipe = data_table.prototypes.recipes[recipe_name]
      if recipe and recipe.ingredients and recipe.ingredients[1] then
        recipe.ingredients[1].amount = needed
        log("[IS-REECIPE] " .. recipe_name .. " needs " .. needed .. "x " .. scrap_name
          .. " (avg expected: " .. string.format("%.2f", avg) .. ")")
      end
    end
  end
end

---Registers generated prototypes and applies queued scrap result inserts to existing recipes.
function yokmods.ingredient_scrap.patch()
  local data_table = yokmods.ingredient_scrap.data_table

  local items_to_extend = {}
  for _, item_proto in pairs(data_table.prototypes.items) do
    table.insert(items_to_extend, item_proto)
  end
  if #items_to_extend > 0 then
    data:extend(items_to_extend)
    log("Registered " .. #items_to_extend .. " scrap item(s).")
  end

  local recipes_to_extend = {}
  for _, recipe_proto in pairs(data_table.prototypes.recipes) do
    table.insert(recipes_to_extend, recipe_proto)
  end
  if #recipes_to_extend > 0 then
    data:extend(recipes_to_extend)
    log("Registered " .. #recipes_to_extend .. " recycle recipe(s).")
  end

  local technologies_to_extend = {}
  for _, tech_proto in pairs(data_table.prototypes.technology) do
    table.insert(technologies_to_extend, tech_proto)
  end
  if #technologies_to_extend > 0 then
    data:extend(technologies_to_extend)
    log("Registered " .. #technologies_to_extend .. " technologies(s).")
  end

  local inserts = 0
  for recipe_name, insert_data in pairs(data_table.inserts.recipes) do
    local recipe = data.raw.recipe[recipe_name]
    local is_recycling_recipe = recipe and
      (recipe.category == "recycling" or recipe_name:match("%-recycling$") ~= nil)
    if recipe and insert_data.results and not is_recycling_recipe then
      recipe.main_product = insert_data.main_product
      recipe.results = recipe.results or {}
      for _, result in ipairs(insert_data.results) do
        local already_exists = false
        for _, existing in ipairs(recipe.results) do
          if existing.name == result.name then
            already_exists = true
            break
          end
        end
        if not already_exists then
          table.insert(recipe.results, result)
        end
      end
      inserts = inserts + 1
    end
  end
  log("Patched " .. inserts .. " recipe(s) with scrap results.")
end
