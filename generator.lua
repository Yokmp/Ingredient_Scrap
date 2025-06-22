local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints  = require("__base__.prototypes.item-tints")
local scrap_tints = require("__Ingredient_Scrap__.item-tints")

local icon_path   = "__Ingredient_Scrap__/graphics/icons/"


--TODO scrap amount per ingredient type and by ingrdient amount

---comment
---@param data_table ISdata_table
---@param ingredient data.IngredientPrototype
---@param recipe data.RecipePrototype
---@param scrap_type string
function yokmods.ingredient_scrap.get_scrap_amount(data_table, ingredient, recipe, scrap_type)
  local amount, min, max
  if ISsettings.needed then --TODO check if the recipe has min/max already
    amount, min , max = yokmods.ingredient_scrap.scrap_amount_range(ingredient.amount)
  else
    amount, min ,max = ingredient.amount, ingredient.amount/2, ingredient.amount*2
  end
  local scrap_name = scrap_type .. "-scrap"

  data_table.inserts[recipe.name].results = data_table.inserts[recipe.name].results or {}
  data_table.inserts[recipe.name].results[scrap_name] = data_table.inserts[recipe.name].results[scrap_name] or {}

-- set amounts
  if data_table.inserts[recipe.name].results[scrap_name].amount_min then
    if not ISsettings.fixed_amount then
      data_table.inserts[recipe.name].results[scrap_name].amount =
          data_table.inserts[recipe.name].results[scrap_name].amount + amount
    end
    data_table.inserts[recipe.name].results[scrap_name].amount_min =
        data_table.inserts[recipe.name].results[scrap_name].amount_min + min
    data_table.inserts[recipe.name].results[scrap_name].amount_max =
        data_table.inserts[recipe.name].results[scrap_name].amount_max + max
  else
    data_table.inserts[recipe.name].results[scrap_name] = {
      type = "item",
      name = scrap_name,
      amount = ISsettings.fixed_amount and amount or nil,
      amount_max = ISsettings.fixed_amount and nil or max,
      amount_min = ISsettings.fixed_amount and nil or min,
      probability = ISsettings.probability > 0 and (ISsettings.probability / 100) or nil
    }
    -- if not ISsettings.fixed_amount then data_table.inserts[recipe.name].results[scrap_name].amount = amount end
  end
end


---find and set the main product or nil
---@param data_table ISdata_table
---@param recipe data.RecipePrototype
---@param scrap_type string
function yokmods.ingredient_scrap.find_main_product(data_table, recipe, scrap_type)
  local main_product
  data_table.inserts[recipe.name] = data_table.inserts[recipe.name] or {}

  if (not recipe.results) then main_product = nil end -- void recipes
  main_product = recipe.main_product and recipe.main_product or recipe.results[1].name
  for _,v in ipairs(recipe.results) do
    if string.find(v.name, main_product, 1) then
      main_product = v.name
      break
    end
  end
  data_table.inserts[recipe.name].main_product = main_product
end


---scales and shifts the original item icon
---@param icon_data data.IconData
---@param shift? vector
---@return table
local function icon_scale_and_shift(icon_data, shift)
  local scale_factor = 64 / (icon_data.icon_size or 1)
  return {
    icon = icon_data.icon,
    size = icon_data.icon_size,
    scale = 0.25 * scale_factor,
    shift = shift or { -8, -8 }
  }
end


--------------------------------
---*SCRAP ITEM*               --
--------------------------------


---@param scrap_defines {name: string, scrap_type: string, item_tint?: data.Color, stack_size?: number}
function yokmods.ingredient_scrap.make_scrap_item(scrap_defines)
  local scrap_name = scrap_defines.scrap_type .. "-scrap"
  if data.raw["item"][scrap_name] then return end

  local scrap_item = {
    type = "item",
    name = scrap_name,
    icons = { { size = 64, filename = icon_path .. "scrap.png" }, },
    pictures =
    {
      { size = 64, filename = icon_path .. "scrap-1.png", scale = 0.5 },
      { size = 64, filename = icon_path .. "scrap-2.png", scale = 0.5 },
      { size = 64, filename = icon_path .. "scrap-3.png", scale = 0.5 }
    },
    subgroup = "raw-material",
    order = "is-[" .. scrap_name .. "]",
    stack_size = scrap_defines.stack_size or 100,
    inventory_move_sound = item_sounds.metal_small_inventory_move,
    pick_sound = item_sounds.metal_small_inventory_pickup,
    drop_sound = item_sounds.metal_small_inventory_move,
    default_import_location = mods["space-age"] and data.raw.item[scrap_defines.name].default_import_location or nil,
    random_tint_color = scrap_defines.item_tint
      or scrap_tints[scrap_defines.scrap_type]
      or item_tints.iron_rust and log("no tint for: "..scrap_defines.scrap_type)
  }

  if data.raw.item[scrap_defines.name].icon then
    scrap_item.icons[2] = icon_scale_and_shift({
      icon = data.raw.item[scrap_defines.name].icon, icon_size = data.raw.item[scrap_defines.name].icon_size
    })
  else
    for _, v in ipairs(data.raw.item[scrap_defines.name].icons) do
      table.insert(scrap_item.icons, icon_scale_and_shift({ icon = v.icon, v.icon_size }))
    end
  end
  yokmods.ingredient_scrap.data_table.prototypes.items[scrap_name] = scrap_item
end


--------------------------------
---*RECYCLE RECIPES*          --
--------------------------------


---Recycle recipes
---@param recipe_defines {scrap_type: string, result_type: string, result_name: string, enabled?: boolean, category: data.RecipeCategoryID}
function yokmods.ingredient_scrap.item_recycle_recipes(recipe_defines)
  local recipe_name = "recycle-" .. recipe_defines.scrap_type .. "-scrap"
  if data.raw["recipe"][recipe_name] then return end
  local recycle_icon = mods["quality"] and "__quality__/graphics/icons/recycling.png" or icon_path .. "recycle.png"
  local result_amount = recipe_defines.result_type == "item" and 1 or 10 --TODO get value from recipes

  local recycle_recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = { "recipe-name." .. recipe_name },
    icons = yokmods.ingredient_scrap.data_table.prototypes.items[recipe_defines.scrap_type .. "-scrap"].icons, --TODO icons
    subgroup = "raw-material",
    category = recipe_defines.category,
    order = "is-[" .. recipe_name .. "]",
    always_show_products = true,
    allow_as_intermediate = false,
    enabled = recipe_defines.enabled or true,
    hide_from_player_crafting = true,
    ingredients =
    {
      { type = "item", name = recipe_defines.scrap_type .. "-scrap", amount = ISsettings.needed },
    },
    results = { { type = recipe_defines.result_type, name = recipe_defines.result_name, amount = result_amount } }
  }

  table.insert(recycle_recipe.icons, { filename = recycle_icon, size = 64 })
  yokmods.ingredient_scrap.data_table.prototypes.recipes[recipe_name] = recycle_recipe
end

