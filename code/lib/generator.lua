--------------------------------
---*LOCALS*                   --
--------------------------------

local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints  = require("__base__.prototypes.item-tints")
local scrap_tints = require("code.lib.item-tints")

---Scales and shifts a source item icon so it can be layered over the scrap icon.
---@param icon_data ISIcon
---@param shift? vector
---@return table
local function icon_scale_and_shift(icon_data, shift)
  local scale_factor = 64 / (icon_data.icon_size or 64)
  return {
    icon = icon_data.icon,
    icon_size = icon_data.icon_size,
    scale = 0.33 * scale_factor,
    shift = shift or { -6, -0 }
  }
end



--------------------------------
---*SCRAP ITEM*               --
--------------------------------


---@param scrap_defines {name: string, scrap_type: string, stack_size?: number, hidden?: boolean}
---Creates and stores the generated scrap item prototype for a material type.
function yokmods.ingredient_scrap.make_scrap_item(scrap_defines)
  local scrap_name = yokmods.ingredient_scrap.get_scrap_name(scrap_defines.scrap_type)
  local existing_scrap_item = yokmods.ingredient_scrap.data_table.prototypes.items[scrap_name]
  if data.raw["item"][scrap_name] then return end
  if existing_scrap_item then
    existing_scrap_item.hidden = existing_scrap_item.hidden and scrap_defines.hidden or nil
    return
  end

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
    -- localised_name = {"item-name." .. scrap_name},
    localised_name = { "", {"item-name." .. scrap_defines.scrap_type}, " ", {"item-name.scrap"}},
    icons = { {
      icon_size = 64,
      icon = icon_path .. scrap_icons[1] .. ".png",
      tint = scrap_tints[scrap_defines.scrap_type] or item_tints.iron_rust
      }, },
    pictures = pictures,
    subgroup = "raw-material",
    order = "is-[" .. scrap_name .. "]",
    hidden = scrap_defines.hidden or nil,
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

  if yokmods.ingredient_scrap.data_table.debug and yokmods.ingredient_scrap.data_table.debug.sources then
    yokmods.ingredient_scrap.data_table.debug.sources.items[scrap_name] = {
      source_item = scrap_defines.name,
      scrap_type = scrap_defines.scrap_type,
      stack_size = scrap_defines.stack_size,
    }
  end

  yokmods.ingredient_scrap.data_table.prototypes.items[scrap_name] = scrap_item
end



--------------------------------
---*RECYCLE RECIPES*          --
--------------------------------

---Scores solid recycle targets so base materials can replace later intermediates.
---@param result_type string|nil
---@param result_name string|nil
---@param scrap_type string
---@return number
local function solid_recycle_target_priority(result_type, result_name, scrap_type)
  if result_type ~= "item" or not result_name then return 0 end
  if result_name == scrap_type .. "-plate" or result_name:match("%-plate$") then return 50 end
  if result_name == scrap_type .. "-ingot" or result_name:match("%-ingot$") then return 40 end
  if result_name == scrap_type .. "-ore" or result_name:match("%-ore$") then return 30 end
  if result_name == scrap_type then return 20 end
  return 10
end

---Returns true when a newly seen recycle target should replace the current one.
---@param existing_recipe table
---@param recipe_defines table
---@return boolean
local function should_replace_recycle_target(existing_recipe, recipe_defines)
  local existing_result = existing_recipe.results and existing_recipe.results[1]
  if not existing_result then return true end
  if existing_result.type ~= "item" or recipe_defines.result_type ~= "item" then return false end
  local existing_priority = solid_recycle_target_priority(existing_result.type, existing_result.name, recipe_defines.scrap_type)
  local new_priority = solid_recycle_target_priority(recipe_defines.result_type, recipe_defines.result_name, recipe_defines.scrap_type)
  return new_priority > existing_priority
end


---Creates and stores the generated recycle recipe prototype for item or fluid recovery.
---@param recipe_defines {scrap_type: string, result_type: string, result_name: string, categories: category, result_amount?: number, recipe_suffix?: string, hidden?: boolean}
function yokmods.ingredient_scrap.item_recycle_recipes(recipe_defines)

  local recipe_name = yokmods.ingredient_scrap.get_recycle_recipe_name(recipe_defines.scrap_type) .. (recipe_defines.recipe_suffix or "")
  -- local scrap_name = yokmods.ingredient_scrap.get_scrap_name(recipe_defines.scrap_type)

  local existing_recycle_recipe = yokmods.ingredient_scrap.data_table.prototypes.recipes[recipe_name]
  if data.raw["recipe"][recipe_name] then return end
  if existing_recycle_recipe then
    if existing_recycle_recipe.hidden and not recipe_defines.hidden then
      existing_recycle_recipe.hidden = nil
    end
    if should_replace_recycle_target(existing_recycle_recipe, recipe_defines) then
      local result_amount = recipe_defines.result_amount or 1
      existing_recycle_recipe.results = {
        { type = recipe_defines.result_type, name = recipe_defines.result_name, amount = result_amount }
      }
      existing_recycle_recipe.icons = yokmods.ingredient_scrap.get_icon_layers(
        recipe_defines.scrap_type,
        false,
        recipe_defines.result_type,
        recipe_defines.result_name
      )
      if yokmods.ingredient_scrap.data_table.debug and yokmods.ingredient_scrap.data_table.debug.sources then
        yokmods.ingredient_scrap.data_table.debug.sources.recipes[recipe_name] =
          yokmods.ingredient_scrap.data_table.debug.sources.recipes[recipe_name] or {}
        yokmods.ingredient_scrap.data_table.debug.sources.recipes[recipe_name].result_type = recipe_defines.result_type
        yokmods.ingredient_scrap.data_table.debug.sources.recipes[recipe_name].result_name = recipe_defines.result_name
      end
    end
    return
  end -- no duplicates

  local result_amount = recipe_defines.result_amount or (recipe_defines.result_type == "item" and 1 or 10)
  local icon_layers = yokmods.ingredient_scrap.get_icon_layers(
    recipe_defines.scrap_type,
    false,
    recipe_defines.result_type,
    recipe_defines.result_name
  )

  ---@type ISRecipePrototype
  local recycle_recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = { "", {"item-name.recycle"}, " ", {"item-name." .. recipe_defines.scrap_type}},
    icons = icon_layers,
    hidden = recipe_defines.hidden or nil,
    subgroup = "raw-material",
    category = recipe_defines.categories[1],
    order = "is-[" .. recipe_name .. "]",
    always_show_products = true,
    allow_as_intermediate = false,
    hide_from_player_crafting = false,
    ingredients =
    {
      { type = "item", name = yokmods.ingredient_scrap.get_scrap_name(recipe_defines.scrap_type), amount = 0 },
    },
    results = { { type = recipe_defines.result_type, name = recipe_defines.result_name, amount = result_amount } }
  }

  if yokmods.ingredient_scrap.data_table.debug and yokmods.ingredient_scrap.data_table.debug.sources then
    yokmods.ingredient_scrap.data_table.debug.sources.recipes[recipe_name] = {
      scrap_type = recipe_defines.scrap_type,
      result_type = recipe_defines.result_type,
      result_name = recipe_defines.result_name,
    }
  end

  yokmods.ingredient_scrap.data_table.prototypes.recipes[recipe_name] = recycle_recipe
end



--------------------------------
---*TECHNOLOGIES*             --
--------------------------------


---Creates and stores a recycle technology when the source recipe is unlocked by an existing technology.
---@param tech_defines {scrap_type: string, recipe_name: string, data_table: ISdata_table, recipe_suffix?: string}
function yokmods.ingredient_scrap.technology_prototype(tech_defines)

  local recycle_recipe_name = yokmods.ingredient_scrap.get_recycle_recipe_name(tech_defines.scrap_type)
  local unlock_recipe_name = recycle_recipe_name .. (tech_defines.recipe_suffix or "")
  local scrap_name = yokmods.ingredient_scrap.get_scrap_name(tech_defines.scrap_type)
  local recycle_recipe = tech_defines.data_table.prototypes.recipes[unlock_recipe_name]
  local recycle_result = recycle_recipe and recycle_recipe.results and recycle_recipe.results[1]
  local icon_layers = yokmods.ingredient_scrap.get_icon_layers(
    tech_defines.scrap_type,
    true,
    recycle_result and recycle_result.type,
    recycle_result and recycle_result.name
  )

  ---Returns true when the technology already unlocks the requested recipe.
  ---@param technology table
  ---@param recipe_name string
  ---@return boolean
  local function has_unlock_effect(technology, recipe_name)
    for _, effect in ipairs(technology.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
        return true
      end
    end
    return false
  end

  local scrap_technology = {
    type = "technology",
    name = recycle_recipe_name,
    -- localised_name = {"", { "recipe-name." .. recycle_recipe_name }},
    localised_name = { "", {"item-name." .. tech_defines.scrap_type}, " ",{"item-name.scrap"}, " ", {"item-name.recycling"} },
    icons = icon_layers,
    enabled = true,
    -- Keep generated recycle technologies visible during development. Re-enable
    -- yis-hide-tech handling before release.
    hidden = false,
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = unlock_recipe_name
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
            local technology = tech_defines.data_table.prototypes.technology[recycle_recipe_name] or scrap_technology
            if not has_unlock_effect(technology, unlock_recipe_name) then
              table.insert(technology.effects, { type = "unlock-recipe", recipe = unlock_recipe_name })
            end
            tech_defines.data_table.prototypes.technology[recycle_recipe_name] = technology
            break
          end
        end
    end
    if not next(tech_defines.data_table.prototypes.technology[tech.name]) then
      tech_defines.data_table.prototypes.technology[tech.name] = nil
    end
  end
end
