---gets the results, creates the scrap results and inserts them into ``_return.recipe.results``
---@return table
function yokmods.ingredient_scrap.collector()
  local data_table = yokmods.ingredient_scrap.data_table

  for _, recipe in pairs(data.raw.recipe) do                                      -- loop over recipes
    if recipe.ingredients and recipe.ingredients[1] then                          -- some recipes like biter-eggs don't have ingredients
      data_table.ingredients.items[recipe.name] = data_table.ingredients.items[recipe.name] or {}
      data_table.ingredients.fluids[recipe.name] = data_table.ingredients.fluids[recipe.name] or {}
      data_table.inserts.recipes[recipe.name] = data_table.inserts.recipes[recipe.name] or {}

      for _, ingredient in ipairs(recipe.ingredients or {}) do                    -- loop over ingredients

        for _, scrap_type in ipairs(data_table.materials.solid) do                -- filter

          local function matches_scrap_type(name, scrap_type)
            for _, suffix in ipairs(data_table.materials.suffixes) do
              if name == scrap_type .. suffix then return true end
            end
            return name == scrap_type
          end

          if matches_scrap_type(ingredient.name, scrap_type) then

            if ingredient.type == "item" then                                     -- ITEM
              if not recipe.results or not recipe.results[1] then
                log("[IS] Skipping void recipe: " .. recipe.name)
              else
                table.insert(data_table.ingredients.items[recipe.name], ingredient)   -- insert item into ISdata_table

                yokmods.ingredient_scrap.add_recipe_results(data_table, ingredient, recipe, scrap_type)

                yokmods.ingredient_scrap.get_main_product(data_table, recipe, scrap_type)

                yokmods.ingredient_scrap.make_scrap_item({
                  name = ingredient.name,
                  scrap_type = scrap_type,
                  stack_size = util.clamp(data.raw.item[ingredient.name].stack_size * ISsettings.needed, 10, 200)
                })

                yokmods.ingredient_scrap.item_recycle_recipes( {
                  result_type = "item",
                  result_name = ingredient.name,
                  scrap_type = scrap_type,
                  categories = {data_table.constants.recycle_categories.solid},
                } )

                yokmods.ingredient_scrap.technology_prototype( {
                  data_table = data_table,
                  recipe_name = recipe.name,
                  scrap_type = scrap_type
                } )
              end

            elseif ingredient.type == "fluid" and ISsettings.fluids then          -- FLUID
              local main_product = recipe.main_product or (recipe.results and recipe.results[1] and recipe.results[1].name)
              if not main_product or not data.raw.item[main_product] then break end

              local normalized_amount = math.max(math.floor(ingredient.amount / 10), 1)

              table.insert(data_table.ingredients.fluids[recipe.name], ingredient)

              yokmods.ingredient_scrap.add_recipe_results(data_table,
                { type = "fluid", name = ingredient.name, amount = normalized_amount },
                recipe, scrap_type
              )
              yokmods.ingredient_scrap.get_main_product(data_table, recipe)

              yokmods.ingredient_scrap.make_scrap_item({
                name       = main_product,
                scrap_type = scrap_type,
                stack_size = util.clamp(data.raw.item[main_product].stack_size * ISsettings.needed, 10, 200)
              })

              -- Rezept 1: Scrap -> Item (immer)
              yokmods.ingredient_scrap.item_recycle_recipes({
                result_type   = "item",
                result_name   = main_product,
                scrap_type    = scrap_type,
                categories    = { data_table.constants.recycle_categories.solid },
              })

              -- Rezept 2: Scrap -> Fluid (zusätzlich, nur in Foundry)
              yokmods.ingredient_scrap.item_recycle_recipes({
                result_type   = "fluid",
                result_name   = ingredient.name,
                result_amount = math.max(ingredient.amount / ISsettings.needed, 10),
                scrap_type    = scrap_type,
                categories    = { data_table.constants.recycle_categories.fluid },
                recipe_suffix = "-to-fluid",
              })

              yokmods.ingredient_scrap.technology_prototype({
                data_table  = data_table,
                recipe_name = recipe.name,
                scrap_type  = scrap_type
              })
            end
          end
        end
      end

      --#region delete empty tables
      if not next(data_table.ingredients.items[recipe.name]) then
        data_table.ingredients.items[recipe.name] = nil
      end
      if not next(data_table.ingredients.fluids[recipe.name]) then
        data_table.ingredients.fluids[recipe.name] = nil
      end
      if not next(data_table.inserts.recipes[recipe.name]) then
        data_table.inserts.recipes[recipe.name] = nil
      end
      --#endregion
    else
      log("No ingredients: " .. recipe.name)
    end
  end

  return data_table
end