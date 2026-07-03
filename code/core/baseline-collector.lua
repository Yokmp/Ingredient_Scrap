--------------------------------
---*BASELINE COLLECTOR*       --
--------------------------------

local source_overrides = require("code.lib.source-overrides")
local data_table_writer = require("code.core.data-table.writer")
local prototype_builder = require("code.core.prototype-builder")

local baseline_collector = {}

---Returns true for Quality-style recycling recipes that should not create additional scrap.
---@param recipe table
---@return boolean
local function is_recycling_recipe(recipe)
  return recipe.category == "recycling" or (recipe.name and recipe.name:match("%-recycling$") ~= nil)
end

---Checks whether an ingredient name belongs to the given scrap material type.
---@param name string
---@param scrap_type string
---@param prefixes string[]
---@param suffixes string[]
---@param aliases table<string, string>|nil
---@return boolean
local function matches_scrap_type(name, scrap_type, prefixes, suffixes, aliases)
  if aliases and aliases[name] == scrap_type then return true end
  for _, suffix in ipairs(suffixes) do
    if name == scrap_type .. suffix then return true end
  end
  for _, prefix in ipairs(prefixes) do
    if name == prefix .. scrap_type then return true end
  end
  return name == scrap_type
end

---Returns the scrap type that should be generated for a matched solid ingredient.
---Component-like exact aliases use the concrete input prototype as their scrap type.
---@param data_table ISdata_table
---@param scrap_type string
---@param ingredient_name string
---@return string
local function solid_scrap_type_for_match(data_table, scrap_type, ingredient_name)
  if data_table.materials.solid_exact_scrap
    and data_table.materials.solid_exact_scrap[scrap_type]
    and data_table.materials.solid_aliases
    and data_table.materials.solid_aliases[ingredient_name] == scrap_type then
    return ingredient_name
  end
  return scrap_type
end

---Finds the preferred item prototype used as the recycle target for solid-based scrap.
---@param scrap_type string
---@param ingredient_name string
---@return string|nil, table|nil
local function scrap_source_item_for_solid(scrap_type, ingredient_name)
  local preferred_names = {
    scrap_type .. "-plate",
    scrap_type .. "-ingot",
    scrap_type .. "-ore",
    scrap_type,
    ingredient_name,
  }

  for _, preferred_name in ipairs(preferred_names) do
    if preferred_name and data.raw.item[preferred_name] then
      return preferred_name, data.raw.item[preferred_name]
    end
  end

  return ingredient_name, data.raw.item[ingredient_name]
end

---Finds the item prototype used as the visual and stack-size source for fluid-based scrap.
---@param scrap_type string
---@param main_product string|nil
---@return string|nil, table|nil
local function scrap_source_item_for_fluid(scrap_type, main_product)
  if main_product and data.raw.item[main_product] then
    return main_product, data.raw.item[main_product]
  end

  local fallback_name = scrap_type .. "-plate"
  local fallback_item = data.raw.item[fallback_name]
    or data.raw.item[scrap_type .. "-bar"]
    or data.raw.item[scrap_type .. "-ingot"]
    or data.raw.item[scrap_type]

  if fallback_item then
    return fallback_item.name or fallback_name, fallback_item
  end

  return nil, nil
end

---Returns true when generated prototypes should exist but stay hidden.
---@param recipe table
---@param source_item table|nil
---@param source_fluid table|nil
---@return boolean
local function should_hide_generated_prototypes(recipe, source_item, source_fluid)
  return recipe.hidden == true
    or (source_item and source_item.hidden == true)
    or (source_fluid and source_fluid.hidden == true)
end

---Records a source-filter skip for debug reports and material-flow dumps.
---@param data_table ISdata_table
---@param recipe table
---@param ingredient table
---@param scrap_type string
---@param mode "solid"|"fluid"
---@param rule table
local function record_skipped_source(data_table, recipe, ingredient, scrap_type, mode, rule)
  data_table_writer.record_skipped_source(
    data_table,
    recipe,
    ingredient,
    scrap_type,
    mode,
    rule and rule.reason or "source-filter"
  )
end

---Collects scrap output for one solid ingredient when it matches a known material.
---@param data_table ISdata_table
---@param recipe table
---@param ingredient table
local function collect_solid_ingredient(data_table, recipe, ingredient)
  if ingredient.type ~= "item" then return end

  for _, scrap_type in ipairs(data_table.materials.solid) do
    if matches_scrap_type(
      ingredient.name,
      scrap_type,
      data_table.materials.solid_prefixes,
      data_table.materials.solid_suffixes,
      data_table.materials.solid_aliases
    ) then
      local ignored_source = source_overrides.ignored_source(recipe, ingredient, scrap_type, "solid")
      if ignored_source then
        record_skipped_source(data_table, recipe, ingredient, scrap_type, "solid", ignored_source)
        goto continue_solid_material
      end

      local generated_scrap_type = solid_scrap_type_for_match(data_table, scrap_type, ingredient.name)
      local source_item_name, source_item = scrap_source_item_for_solid(generated_scrap_type, ingredient.name)
      if source_item_name and source_item then
        local hide_generated = should_hide_generated_prototypes(recipe, source_item)
        data_table_writer.record_ingredient(data_table, recipe.name, "solid", ingredient)

        data_table_writer.add_scrap_result(data_table, ingredient, recipe, generated_scrap_type)

        prototype_builder.ensure_scrap_item(data_table, {
          name = source_item_name,
          scrap_type = generated_scrap_type,
          hidden = hide_generated,
          stack_size = util.clamp(source_item.stack_size * ISsettings.needed, 10, 200)
        })

        prototype_builder.ensure_recycle_recipe(data_table, {
          result_type = "item",
          result_name = source_item_name,
          scrap_type = generated_scrap_type,
          categories = { data_table.constants.recycle_categories.solid },
          hidden = hide_generated,
        })

        prototype_builder.ensure_technology({
          data_table = data_table,
          recipe_name = recipe.name,
          scrap_type = generated_scrap_type
        })
      end
    end
    ::continue_solid_material::
  end
end

---Collects scrap output for one fluid ingredient when it matches a known material.
---@param data_table ISdata_table
---@param recipe table
---@param ingredient table
---@param main_product string|nil
local function collect_fluid_ingredient(data_table, recipe, ingredient, main_product)
  if not ISsettings.fluids or ingredient.type ~= "fluid" then return end

  for _, scrap_type in ipairs(data_table.materials.fluid) do
    if matches_scrap_type(
      ingredient.name,
      scrap_type,
      data_table.materials.fluid_prefixes,
      data_table.materials.fluid_suffixes,
      data_table.materials.fluid_aliases
    ) then
      local ignored_source = source_overrides.ignored_source(recipe, ingredient, scrap_type, "fluid")
      if ignored_source then
        record_skipped_source(data_table, recipe, ingredient, scrap_type, "fluid", ignored_source)
        goto continue_fluid_material
      end

      local source_item_name, source_item = scrap_source_item_for_fluid(scrap_type, main_product)
      if source_item_name and source_item then
        local source_fluid = data.raw.fluid[ingredient.name]
        local hide_generated = should_hide_generated_prototypes(recipe, source_item, source_fluid)
        data_table_writer.record_ingredient(data_table, recipe.name, "fluid", ingredient)

        local normalized_amount = math.max(math.floor(ingredient.amount / 10), 1)
        data_table_writer.add_scrap_result(
          data_table,
          { type = "fluid", name = ingredient.name, amount = normalized_amount },
          recipe,
          scrap_type
        )

        prototype_builder.ensure_scrap_item(data_table, {
          name = source_item_name,
          scrap_type = scrap_type,
          hidden = hide_generated,
          stack_size = util.clamp(source_item.stack_size * ISsettings.needed, 10, 200)
        })

        prototype_builder.ensure_recycle_recipe(data_table, {
          result_type = "fluid",
          result_name = ingredient.name,
          result_amount = math.max(ingredient.amount / ISsettings.needed, 10),
          scrap_type = scrap_type,
          categories = { data_table.constants.recycle_categories.fluid },
          recipe_suffix = "-to-fluid",
          hidden = hide_generated,
        })

        prototype_builder.ensure_technology({
          data_table = data_table,
          recipe_name = recipe.name,
          scrap_type = scrap_type,
          recipe_suffix = "-to-fluid",
        })
      end
    end
    ::continue_fluid_material::
  end
end

---Collects scrap-producing recipe ingredients and queues generated scrap items, recipes, technologies, and result inserts.
---@param data_table ISdata_table
---@return table
function baseline_collector.collect(data_table)
  for _, recipe in pairs(data.raw.recipe) do
    if is_recycling_recipe(recipe) then
      goto continue
    end

    if recipe.ingredients and recipe.ingredients[1] then
      data_table_writer.begin_recipe_collection(data_table, recipe.name)

      local main_product = data_table_writer.set_main_product(data_table, recipe)
      local main_product_item = main_product and data.raw.item[main_product]
      local main_product_fluid = ISsettings.fluids and main_product and data.raw.fluid[main_product]

      if main_product_item or main_product_fluid then
        for _, ingredient in ipairs(recipe.ingredients or {}) do
          collect_solid_ingredient(data_table, recipe, ingredient)
          collect_fluid_ingredient(data_table, recipe, ingredient, main_product)
        end
      end

      data_table_writer.cleanup_recipe_collection(data_table, recipe.name)
    end

    ::continue::
  end

  return data_table
end

return baseline_collector
