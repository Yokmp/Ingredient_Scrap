
--[[
  Data table which holds every ingredient by type;
  scrap_results are accessible by recipe name;
  probability represents the base probability for scrap_results
  - result amounts are affected by this and a function which "smoothens out" some extreme values;

TODO
probability setting, amount or min/max setting, patcher
depending on addon/dlc:
item and recycle_recipe generators (quality -> recycler)
tech injection? (space-age, quality)
]]

yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}


-- yokmods.ingredient_scrap.UID = settings.startup["yis-uid"].value
--
-- local new_uid     = ""
-- for k,v in pairs(mods) do
--   new_uid = new_uid..k..v
--   -- collect every setting of every mod
-- end
-- log(helpers.encode_string(new_uid))
-- error()


yokmods.ingredient_scrap.settings = yokmods.ingredient_scrap.settings or {}
-- true will set an amount rather than a range
yokmods.ingredient_scrap.settings.amount_range = settings.startup["yis-amount-range"].value --[[@as boolean]]
-- the probability if no range is selected (0 - 100)
yokmods.ingredient_scrap.settings.probability  = settings.startup["yis-probability"].value  --[[@as integer]]
-- how should the scrap amount be calculated
yokmods.ingredient_scrap.settings.limit        = settings.startup["yis-amount-limit"].value --[[@as string]]
-- the scrap amount needed to recycle
yokmods.ingredient_scrap.settings.needed       = settings.startup["yis-needed"].value       --[[@as integer]]
-- the scrap amount needed to recycle
yokmods.ingredient_scrap.settings.fluids       = settings.startup["yis-fluid-recipes"].value--[[@as boolean]]

ISsettings = yokmods.ingredient_scrap.settings

--------------------------------
---*REQUIRES*                 --
--------------------------------

require("generator")
require("patcher")


--------------------------------
--- *INITIALIZE*              --
--------------------------------

--*Inititalizes the data_table*
---@return ISdata_table
function yokmods.ingredient_scrap.init_data_table()
  return {
    auto_recycle = false,     -- unused
    fluids_as_barrel = true,  -- unused
    probability = ISsettings.probability,
    ingredients = {
      items = {},
      fluids = {},
    },
    prototypes = {
      recipes = {},
      items = {},
    },
    inserts = {},
  }
end
yokmods.ingredient_scrap.data_table = yokmods.ingredient_scrap.init_data_table()


--------------------------------
---*FUNCTIONS*                --
--------------------------------

--TODO the whole probability vs min max thing needs a rewrite
--TODO so that the user simply switches between probability and min/max
--
---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@return integer amount
---@return integer? amount_min
---@return integer? amount_max
function yokmods.ingredient_scrap.scrap_amount_range(base_amount)
  local low, high, acc = -1, -1, 0
  local probability = ISsettings.probability / 100 --base probability
--Calculates the binomial coefficient n over p (or choose(n, p))
  local function binom(n, p) -- if n=1, p=1 -> 0
    local result = 1
    for i = 1, p do
      result = (result * (n + 1 - i) / i)
    end
    return result
  end
-- multiply base amount witz probability and binom, them more items in, the less maount out
  for i = 0, base_amount do
    local prob = math.pow(probability, i) * math.pow(1 - probability, base_amount - i) * binom(base_amount, i)
    acc = acc + prob
    if low < 0 and acc > 0.05 then low = i end
    if high < 0 and acc > 0.95 then high = i - 1 end
  end
-- prevent amount from reaching 0
  return math.max(math.ceil(high - low), 1), low, math.max(high, 1)
end



local scrap_types = { "iron", "copper", "steel", "tungsten", "lithium" } --? TESTING -> REPLACE ME
local blacklist_types = { "bacteria", "ore"} --? TESTING -> REPLACE ME


--------------------------------
---*COLLECT*                  --
--------------------------------

---gets the results, creates the scrap results and inserts them into ``_return.recipe.results``
---@return table
function yokmods.ingredient_scrap.data_table_collector()
  local recipe_data = {}
  local data_table = yokmods.ingredient_scrap.data_table


  for _, recipe in pairs(data.raw.recipe) do                -- loop over recipes
    if recipe.ingredients and recipe.ingredients[1] then    -- some recipes like biter-eggs don't have ingredients
      data_table.ingredients.items[recipe.name] = data_table.ingredients.items[recipe.name] or {}
      data_table.ingredients.fluids[recipe.name] = data_table.ingredients.fluids[recipe.name] or {}
      data_table.inserts[recipe.name] = data_table.inserts[recipe.name] or {}
      for _, ingredient in ipairs(recipe.ingredients) do    -- loop over ingredients
        local skip = false
        for _, blacklist_type in ipairs(blacklist_types) do -- loop over blacklist
          if string.find(ingredient.name, blacklist_type, 1) then skip = true break end
        end
        for _, scrap_type in ipairs(scrap_types) do         -- loop over scrap_types
          if string.find(ingredient.name, scrap_type, 1) and not skip then
            if ingredient.type == "item" then
              table.insert(data_table.ingredients.items[recipe.name], ingredient) -- source
              yokmods.ingredient_scrap.get_scrap_amount(data_table, ingredient, recipe, scrap_type)
              yokmods.ingredient_scrap.find_main_product(data_table, recipe, scrap_type)
              yokmods.ingredient_scrap.make_scrap_item({
                name = ingredient.name,
                type = scrap_type,
                -- item_tint= {}, -- TODO get_item_tint()
                stack_size = util.clamp(data.raw.item[ingredient.name].stack_size * ISsettings.needed, 10, 200)
              })

              yokmods.ingredient_scrap.make_recycle_recipes({
                result_type = "item",
                result_name = ingredient.name,
                scrap_type = scrap_type,
                category = "yis-recycle"
              })
            elseif ingredient.type == "fluid" then -- TODO this will enable scrap generation for fluid recipes
              table.insert(data_table.ingredients.fluids[recipe.name], ingredient)
              --fluid to plate ratio
              --adjust min required scrap, max 40?
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
      if not next(data_table.inserts[recipe.name]) then
        data_table.inserts[recipe.name] = nil
      end
      --#endregion
    else
      log("No ingredients: " .. recipe.name)
    end
  end

  return data_table
end

yokmods.ingredient_scrap.data_table_collector()
-- log(serpent.block(yokmods.ingredient_scrap.data_table))
helpers.write_file("IngredientScrap/data_table-prePatch.lua", "return " .. serpent.block(
  yokmods.ingredient_scrap.data_table,{refcomment = true, tablecomment = false}
))
