--------------------------------
---*COLLECTOR*                --
--------------------------------

---Collects scrap-producing recipe ingredients and queues generated scrap items, recipes, technologies, and result inserts.
---@return table
function yokmods.ingredient_scrap.collector()
  local data_table = yokmods.ingredient_scrap.data_table

  ---Checks whether an ingredient name belongs to the given scrap material type.
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

  ---Finds the preferred item prototype used as the recycle target for solid-based scrap.
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
  local function scrap_source_item_for_fluid(scrap_type, main_product)
    if main_product and data.raw.item[main_product] then
      return main_product, data.raw.item[main_product]
    end

    local fallback_name = scrap_type .. "-plate"
    local fallback_item = data.raw.item[fallback_name]
      or data.raw.item[scrap_type .. "-ingot"]
      or data.raw.item[scrap_type]

    if fallback_item then
      return fallback_item.name or fallback_name, fallback_item
    end

    return nil, nil
  end

  ---Returns true when generated prototypes should exist but stay hidden.
  local function should_hide_generated_prototypes(recipe, source_item, source_fluid)
    return recipe.hidden == true
      or recipe.enabled == false
      or (source_item and source_item.hidden == true)
      or (source_fluid and source_fluid.hidden == true)
  end

  for _, recipe in pairs(data.raw.recipe) do
    if recipe.ingredients and recipe.ingredients[1] then
      data_table.ingredients.items[recipe.name] = data_table.ingredients.items[recipe.name] or {}
      data_table.ingredients.fluids[recipe.name] = data_table.ingredients.fluids[recipe.name] or {}
      data_table.inserts.recipes[recipe.name] = data_table.inserts.recipes[recipe.name] or {}

      local main_product = yokmods.ingredient_scrap.get_main_product(data_table, recipe)
      local main_product_item = main_product and data.raw.item[main_product]
      local main_product_fluid = ISsettings.fluids and main_product and data.raw.fluid[main_product]

      if main_product_item or main_product_fluid then
        for _, ingredient in ipairs(recipe.ingredients or {}) do
          for _, scrap_type in ipairs(data_table.materials.solid) do
            if ingredient.type == "item" and matches_scrap_type(
              ingredient.name,
              scrap_type,
              data_table.materials.solid_prefixes,
              data_table.materials.solid_suffixes,
              data_table.materials.solid_aliases
            ) then
              local source_item_name, source_item = scrap_source_item_for_solid(scrap_type, ingredient.name)
              local hide_generated = should_hide_generated_prototypes(recipe, source_item)
              table.insert(data_table.ingredients.items[recipe.name], ingredient)

              yokmods.ingredient_scrap.add_recipe_results(data_table, ingredient, recipe, scrap_type)

              yokmods.ingredient_scrap.make_scrap_item({
                name = source_item_name,
                scrap_type = scrap_type,
                hidden = hide_generated,
                stack_size = util.clamp(source_item.stack_size * ISsettings.needed, 10, 200)
              })

              yokmods.ingredient_scrap.item_recycle_recipes({
                result_type = "item",
                result_name = source_item_name,
                scrap_type = scrap_type,
                categories = { data_table.constants.recycle_categories.solid },
                hidden = hide_generated,
              })

              yokmods.ingredient_scrap.technology_prototype({
                data_table = data_table,
                recipe_name = recipe.name,
                scrap_type = scrap_type
              })
            end
          end

          if ISsettings.fluids then
            for _, scrap_type in ipairs(data_table.materials.fluid) do
              if ingredient.type == "fluid" and matches_scrap_type(
                ingredient.name,
                scrap_type,
                data_table.materials.fluid_prefixes,
                data_table.materials.fluid_suffixes,
                data_table.materials.fluid_aliases
              ) then
                local source_item_name, source_item = scrap_source_item_for_fluid(scrap_type, main_product)
                if source_item_name and source_item then
                  local source_fluid = data.raw.fluid[ingredient.name]
                  local hide_generated = should_hide_generated_prototypes(recipe, source_item, source_fluid)
                  table.insert(data_table.ingredients.fluids[recipe.name], ingredient)

                  local normalized_amount = math.max(math.floor(ingredient.amount / 10), 1)
                  yokmods.ingredient_scrap.add_recipe_results(
                    data_table,
                    { type = "fluid", name = ingredient.name, amount = normalized_amount },
                    recipe,
                    scrap_type
                  )

                  yokmods.ingredient_scrap.make_scrap_item({
                    name = source_item_name,
                    scrap_type = scrap_type,
                    hidden = hide_generated,
                    stack_size = util.clamp(source_item.stack_size * ISsettings.needed, 10, 200)
                  })

                  yokmods.ingredient_scrap.item_recycle_recipes({
                    result_type = "fluid",
                    result_name = ingredient.name,
                    result_amount = math.max(ingredient.amount / ISsettings.needed, 10),
                    scrap_type = scrap_type,
                    categories = { data_table.constants.recycle_categories.fluid },
                    recipe_suffix = "-to-fluid",
                    hidden = hide_generated,
                  })

                  yokmods.ingredient_scrap.technology_prototype({
                    data_table = data_table,
                    recipe_name = recipe.name,
                    scrap_type = scrap_type,
                    recipe_suffix = "-to-fluid",
                  })
                end
              end
            end
          end
        end
      end

      if not next(data_table.ingredients.items[recipe.name]) then
        data_table.ingredients.items[recipe.name] = nil
      end
      if not next(data_table.ingredients.fluids[recipe.name]) then
        data_table.ingredients.fluids[recipe.name] = nil
      end
      if data_table.inserts.recipes[recipe.name] and
        (not data_table.inserts.recipes[recipe.name].main_product or
        not data_table.inserts.recipes[recipe.name].results) then
        data_table.inserts.recipes[recipe.name] = nil
      end
    else
      log("No ingredients: " .. recipe.name)
    end
  end

  return data_table
end
