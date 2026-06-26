local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints  = require("__base__.prototypes.item-tints")
local scrap_tints = require("lib.item-tints")

--TODO scrap amount per ingredient type and by ingredient amount

---Creates or accumulates the scrap result entry for the specified recipe.
---@param data_table ISdata_table
---@param ingredient ISIngredientPrototype
---@param recipe ISRecipePrototype
---@param scrap_type string
function yokmods.ingredient_scrap.add_recipe_results(data_table, ingredient, recipe, scrap_type)
  local amount, min, max = yokmods.ingredient_scrap.scrap_amount_range(ingredient.amount)
  local scrap_name = scrap_type .. "-scrap"

  data_table.inserts.recipes[recipe.name].results = data_table.inserts.recipes[recipe.name].results or {}

  -- Check whether this scrap_type already exists in results (accumulate)
  local existing = nil
  for _, result in ipairs(data_table.inserts.recipes[recipe.name].results) do
    if result.name == scrap_name then
      existing = result
      break
    end
  end

  if existing then                            -- adds up amount if scrap_type already exists
    if ISsettings.fixed_amount then
      existing.amount = existing.amount + amount
    else
      existing.amount_min = existing.amount_min + min
      existing.amount_max = existing.amount_max + max
    end
  else                                        -- new entry as array element
    table.insert(data_table.inserts.recipes[recipe.name].results, {
      type        = "item",
      name        = scrap_name,
      amount      = ISsettings.fixed_amount and amount or nil,
      amount_min  = ISsettings.fixed_amount and nil or min,
      amount_max  = ISsettings.fixed_amount and nil or max,
      probability = ISsettings.probability > 0 and (ISsettings.probability / 100) or nil,
    })
  end
end


---find and set the main product or nil
---@param data_table ISdata_table
---@param recipe ISRecipePrototype
---@param scrap_type? string
function yokmods.ingredient_scrap.get_main_product(data_table, recipe, scrap_type)
  local main_product
  data_table.inserts.recipes[recipe.name] = data_table.inserts.recipes[recipe.name] or {}

  -- If main_product is not set, use the first result as a fallback.
  main_product = recipe.main_product or recipe.results[1].name

  data_table.inserts.recipes[recipe.name].main_product = main_product
end


---scales and shifts the original item icon
---@param icon_data ISIcon
---@param shift? vector
---@return table
local function icon_scale_and_shift(icon_data, shift)
  local scale_factor = 64 / (icon_data.icon_size or 64)
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


---@param scrap_defines {name: string, scrap_type: string, stack_size?: number}
function yokmods.ingredient_scrap.make_scrap_item(scrap_defines)
  local scrap_name = yokmods.ingredient_scrap.get_scrap_name(scrap_defines.scrap_type)
  if data.raw["item"][scrap_name] then return end

  local scrap_pictures = yokmods.ingredient_scrap.data_table.constants.scrap_pictures
  local scrap_icons = yokmods.ingredient_scrap.data_table.constants.icon_scrap
  local icon_path = yokmods.ingredient_scrap.data_table.constants.icon_path
  local source_item = data.raw.item[scrap_defines.name]
  local pictures = {}

  for i = 1, scrap_pictures, 1 do
    pictures[i] = { size = 64, filename = icon_path .. "scrap-" .. i .. "-64.png", scale = 0.5, shift = {0, 0} }
  end

  ---@type ISItemPrototype
  local scrap_item = {
    type = "item",
    name = scrap_name,
    icons = { {
      icon_size = 64,
      icon = icon_path .. scrap_icons[1] .. ".png",
      tint = scrap_tints[scrap_defines.scrap_type] or item_tints.iron_rust
      }, },
    pictures = pictures,
    subgroup = "raw-material",
    order = "is-[" .. scrap_name .. "]",
    stack_size = scrap_defines.stack_size or 100,
    inventory_move_sound = item_sounds.metal_small_inventory_move,
    pick_sound = item_sounds.metal_small_inventory_pickup,
    drop_sound = item_sounds.metal_small_inventory_move,
    default_import_location = (mods["space-age"] and yokmods.ingredient_scrap.get_import_location(scrap_defines.scrap_type)) or nil,
    -- random_tint_color = scrap_defines.item_tint or scrap_tints[scrap_defines.scrap_type] or item_tints.iron_rust,
  }

  if not scrap_tints[scrap_defines.scrap_type] and not item_tints.iron_rust then
    log("no tint for: " .. scrap_defines.scrap_type)
  end

  if source_item.icon then
    scrap_item.icons[2] = icon_scale_and_shift({
      icon = source_item.icon,
      icon_size = source_item.icon_size or 64,
      icon_mipmaps = source_item.icon_mipmaps or 4
    })
  elseif source_item.icons then
    for _, v in ipairs(source_item.icons) do
      table.insert(scrap_item.icons, icon_scale_and_shift({
        icon = v.icon,
        icon_size = v.size or v.icon_size or 64
      }))
    end
  end

  yokmods.ingredient_scrap.data_table.prototypes.items[scrap_name] = scrap_item
end



--------------------------------
---*RECYCLE RECIPES*          --
--------------------------------


---Recycle recipes
---@param recipe_defines {scrap_type: string, result_type: string, result_name: string, categories: category, result_amount?: number, recipe_suffix?: string}
function yokmods.ingredient_scrap.item_recycle_recipes(recipe_defines)
  local recipe_name = yokmods.ingredient_scrap.get_recycle_recipe_name(recipe_defines.scrap_type) .. (recipe_defines.recipe_suffix or "")

  if data.raw["recipe"][recipe_name] then return end -- no duplicates

  local result_amount = recipe_defines.result_amount or (recipe_defines.result_type == "item" and 1 or 10)
  local constants = yokmods.ingredient_scrap.data_table.constants
  local icon_layers = yokmods.ingredient_scrap.get_icon_layers(recipe_defines.scrap_type, recipe_defines.scrap_type)
  table.insert(icon_layers, { icon = constants.icon_path .. "recycle.png", icon_size = 256, scale = 0.25})

  ---@type ISRecipePrototype
  local recycle_recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = { "recipe-name." .. recipe_name },
    icons = icon_layers,
    enabled = false,
    subgroup = "raw-material",
    categories = recipe_defines.categories,
    order = "is-[" .. recipe_name .. "]",
    always_show_products = true,
    allow_as_intermediate = false,
    hide_from_player_crafting = true,
    ingredients =
    {
      { type = "item", name = recipe_defines.scrap_type .. "-scrap", amount = 0 },
    },
    results = { { type = recipe_defines.result_type, name = recipe_defines.result_name, amount = result_amount } }
  }

  yokmods.ingredient_scrap.data_table.prototypes.recipes[recipe_name] = recycle_recipe
end



--------------------------------
---*TECHNOLOGIES*             --
--------------------------------


---Match recycle recipe name with technologies that unlock the original recipe and add them as unlocks to the tech
---@param tech_defines {scrap_type: string, recipe_name: string, data_table: ISdata_table}
function yokmods.ingredient_scrap.technology_prototype(tech_defines)

  local recycle_recipe_name = yokmods.ingredient_scrap.get_recycle_recipe_name(tech_defines.scrap_type)
  local constants = yokmods.ingredient_scrap.data_table.constants
  local icon_layers = yokmods.ingredient_scrap.get_icon_layers(tech_defines.scrap_type, tech_defines.scrap_type)
  table.insert(icon_layers, { icon = constants.icon_path .. "recycle.png", icon_size = 256, scale = 1})

  local scrap_technology = {
    type = "technology",
    name = recycle_recipe_name,
    icons = icon_layers,
    enabled = false,
    visible_when_disabled = false,
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = recycle_recipe_name
      }
    },
    research_trigger =
    {
      type = "craft-item",
      item = yokmods.ingredient_scrap.get_scrap_name(tech_defines.scrap_type),
      count = 1
    }
  }

  for _, tech in pairs(data.raw.technology) do
    tech_defines.data_table.prototypes.technology[tech.name] = tech_defines.data_table.prototypes.technology[tech.name] or {}
    for _, effect in ipairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" then
          if effect.recipe == tech_defines.recipe_name then
            tech_defines.data_table.prototypes.technology[recycle_recipe_name] = scrap_technology
            break
          end
        end
    end
    if not next(tech_defines.data_table.prototypes.technology[tech.name]) then
      tech_defines.data_table.prototypes.technology[tech.name] = nil
    end
  end
end
