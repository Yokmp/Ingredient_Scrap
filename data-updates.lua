yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}

--[[
  Data table which holds every ingredient by type
  scrap_results are accessible by recipe name
  probability represents the base probability for scrap_results
  result amounts are affected by this and a function which "smoothens out" some extreme values

TODO
icons, probability setting, amount or min/max setting, icons, patcher, item and recycle_recipe generators
]]

---@class ISdata_table
---@field auto_recycle boolean
---@field fluids_as_barrel boolean
---@field probability number
---@field recipes ISdata_table.recipes
---@field scrap_results ISdata_table.scrap_recipes

---@class ISdata_table.recipes
---@field items ISdata_table.recipes.items
---@field fluids ISdata_table.recipes.fluids

---@class ISdata_table.recipes.items
---@field [string] {type: string, name:string, amount:integer, probability?:number}

---@class ISdata_table.recipes.fluids
---@field [string] {type: string, name:string, amount:integer, probability?:number}

---@class ISdata_table.scrap_recipes
---@field [table] ISdata_table.scrap_recipes.scrap_results

---@class ISdata_table.scrap_recipes.scrap_results
---@field [string] {type: string, name:string, amount:integer, amount_min:integer, amount_max:integer, probability?:integer}



function create_data_table()
  ---@type ISdata_table
  yokmods.ingredient_scrap.data_table = {
    auto_recycle = false,
    fluids_as_barrel = true,
    probability = util.clamp(24, 1, 100) / 100,
    recipes = {
      items = {},       -- recipe_name = {}
      fluids = {}       --
    },
    scrap_results = {}  -- scrap_name = { "affected", "recipes"}
  }
end

---Calculates an appropriate range of scrap results. Uses binomial coefficients
---to simulate independent scrap chance per item and returns low and high amounts
---such that they cover a 90% confidence interval of the true distribution.
---@param base_amount integer
---@return integer amount
---@return integer amount_min
---@return integer amount_max
local function scrap_amount_range(base_amount)
  local low, high, acc = -1, -1, 0
  local probability = yokmods.ingredient_scrap.data_table.probability
  ---Calculates the binomial coefficient n over p (or choose(n, p))
  local function binom(n, p) -- if n=1, p=1 -> 0
    local result = 1
    for i = 1, p do
      result = (result * (n + 1 - i) / i)
    end
    return result
  end

  for i = 0, base_amount do
    local prob = math.pow(probability, i) * math.pow(1 - probability, base_amount - i) * binom(base_amount, i)
    acc = acc + prob
    if low < 0 and acc > 0.05 then low = i end
    if high < 0 and acc > 0.95 then high = i - 1 end
  end
  return math.max(math.ceil(high - low), 1), math.max(low, 1), math.max(high, 1)
end



local do_test = false
local amountRange = false
local scrap_types = { "iron", "copper", "steel" }


create_data_table()

---gets the results, creates the scrap results and inserts them into ``_return.recipe.results``
---@return table
function yokmods.ingredient_scrap.ingredient_collector()
  local recipe_data = {}
  local data_table = yokmods.ingredient_scrap.data_table


  --#region fill the ingredients table
  for _, recipe in pairs(data.raw.recipe) do             -- loop over recipes
    if recipe.ingredients and recipe.ingredients[1] then -- some recipes like biter-eggs don't have ingredients
      data_table.recipes.items[recipe.name] = data_table.recipes.items[recipe.name] or {}
      data_table.recipes.fluids[recipe.name] = data_table.recipes.fluids[recipe.name] or {}
      data_table.scrap_results[recipe.name] = data_table.scrap_results[recipe.name] or {}

      for _, ingredient in ipairs(recipe.ingredients) do -- loop over ingredients
        for _, scrap_type in ipairs(scrap_types) do      -- loop over scrap_types
          if string.find(ingredient.name, scrap_type, 1) then
            if ingredient.type == "item" then
              local amount, min, max = scrap_amount_range(ingredient.amount)
              local scrap_name = scrap_type .. "-scrap"
              table.insert(data_table.recipes.items[recipe.name], ingredient) -- source
              data_table.scrap_results[recipe.name][scrap_name] = data_table.scrap_results[recipe.name][scrap_name] or {}

              if data_table.scrap_results[recipe.name][scrap_name].amount_min then
                if not amountRange then
                  data_table.scrap_results[recipe.name][scrap_name].amount =
                  data_table.scrap_results[recipe.name][scrap_name].amount + amount
                end
                data_table.scrap_results[recipe.name][scrap_name].amount_min =
                data_table.scrap_results[recipe.name][scrap_name].amount_min + min
                data_table.scrap_results[recipe.name][scrap_name].amount_max =
                data_table.scrap_results[recipe.name][scrap_name].amount_max + max
              else
                data_table.scrap_results[recipe.name][scrap_name] = {
                  type = "item",
                  name = scrap_name,
                  amount_max = max,
                  amount_min = min,
                  probability = data_table.probability
                }
                if not amountRange then data_table.scrap_results[recipe.name][scrap_name].amount = amount end
              end
            elseif ingredient.type == "fluid" then
              table.insert(data_table.recipes.fluids[recipe.name], ingredient)
            end
          end
        end
      end

      if not next(data_table.recipes.items[recipe.name]) then
        data_table.recipes.items[recipe.name] = nil
      end
      if not next(data_table.recipes.fluids[recipe.name]) then
        data_table.recipes.fluids[recipe.name] = nil
      end
      if not next(data_table.scrap_results[recipe.name]) then
        data_table.scrap_results[recipe.name] = nil
      end
    else
      log("No ingredients: " .. recipe.name)
    end
  end
  --#endregion

  return recipe_data
end

yokmods.ingredient_scrap.ingredient_collector()
log(serpent.block(yokmods.ingredient_scrap.data_table))
helpers.write_file("IngredientScrap/data_table-prePatch.lua", "return "..serpent.block(yokmods.ingredient_scrap.data_table))

