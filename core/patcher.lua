
--------------------------------
---*PATCHER*                  --
--------------------------------
-- Imports all collected prototypes (items + recipes) from the data_table
-- into data:extend(), and updates existing recipes with the scrap results.

---Calculates and sets the required amount of scrap for all recycling recipes
---based on the average of the actual scrap generated.
function yokmods.ingredient_scrap.patch_recycle_amounts()
  local data_table = yokmods.ingredient_scrap.data_table

  -- For each scrap_type: Collect the expected values of all inserts
  local totals = {}  -- [scrap_name] = { sum = 0, count = 0 }

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
        totals[scrap_name].sum   = totals[scrap_name].sum + expected
        totals[scrap_name].count = totals[scrap_name].count + 1
      end
    end
  end

  -- Recycling-Recipes updates
  for scrap_name, total in pairs(totals) do
    local avg      = total.sum / total.count
    local needed   = util.clamp(math.ceil(avg), 1, ISsettings.needed * 2)
    local recipe_name = "recycle-" .. scrap_name  -- z.B. "recycle-copper-scrap"

    local recipe = data_table.prototypes.recipes[recipe_name]
    if recipe and recipe.ingredients and recipe.ingredients[1] then
      recipe.ingredients[1].amount = needed
      log("[IS] " .. recipe_name .. " needs " .. needed .. "x " .. scrap_name
        .. " (avg expected: " .. string.format("%.2f", avg) .. ")")
    end
  end
end


function yokmods.ingredient_scrap.patch()
  local data_table = yokmods.ingredient_scrap.data_table

  -- 1) Items

  local items_to_extend = {}
  for _, item_proto in pairs(data_table.prototypes.items) do
    table.insert(items_to_extend, item_proto)
  end
  if #items_to_extend > 0 then
    data:extend(items_to_extend)
    log("Registered " .. #items_to_extend .. " scrap item(s).")
  end

  -- 2) Recycling-Recipes

  local recipes_to_extend = {}
  for _, recipe_proto in pairs(data_table.prototypes.recipes) do
    table.insert(recipes_to_extend, recipe_proto)
  end
  if #recipes_to_extend > 0 then
    data:extend(recipes_to_extend)
    log("Registered " .. #recipes_to_extend .. " recycle recipe(s).")
  end

  -- 3) technologies

  local technologies_to_extend = {}
  for _, tech_proto in pairs(data_table.prototypes.technology) do
    table.insert(technologies_to_extend, tech_proto)
  end
  if #technologies_to_extend > 0 then
    data:extend(technologies_to_extend)
    log("Registered " .. #technologies_to_extend .. " technologies(s).")
  end

  -- 4) insert Scrap-Results

  local inserts = 0
  for recipe_name, insert_data in pairs(data_table.inserts.recipes) do
    local recipe = data.raw.recipe[recipe_name]
    if recipe and insert_data.results then
      recipe.results = recipe.results or {}
      for _, result in ipairs(insert_data.results) do
        -- check for duplicates
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
