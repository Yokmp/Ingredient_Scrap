--------------------------------
---*LOCALS*                   --
--------------------------------

local item_sounds = require("__base__.prototypes.item_sounds")
local item_tints  = require("__base__.prototypes.item-tints")
local scrap_tints = require("code.functions.item-tints")
local data_table_reader = require("code.data_table.reader")
local data_table_writer = require("code.data_table.writer")
local icon_layers = require("code.functions.icon-layers")
local is_log = require("code.functions.is-log")
local naming = require("code.functions.naming")
local item_prototypes = require("code.functions.item-prototypes")

local prototype_builder = {}

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
    shift = shift or { -6, 0 }
  }
end

--------------------------------
---*SCRAP ITEM*               --
--------------------------------

---@param scrap_defines {name: string, scrap_type: string, stack_size?: number, hidden?: boolean}
---Creates and stores the generated scrap item prototype for a material type.
---@param data_table ISdata_table
function prototype_builder.ensure_scrap_item(data_table, scrap_defines)
  local scrap_name = naming.get_scrap_name(scrap_defines.scrap_type)
  local existing_scrap_item = data_table_reader.generated_item(data_table, scrap_name)
  if data.raw["item"][scrap_name] then return end
  if existing_scrap_item then
    existing_scrap_item.hidden = existing_scrap_item.hidden and scrap_defines.hidden or nil
    return
  end

  local constants = data_table_reader.constants(data_table)
  local scrap_pictures = constants.scrap_pictures
  local scrap_icons = constants.icon_scrap
  local icon_path = constants.icon_path
  local source_item = item_prototypes.get(scrap_defines.name)
  local pictures = {}

  for i = 1, scrap_pictures, 1 do
    pictures[i] = { size = 64, filename = icon_path .. "scrap-" .. i .. "-64.png", scale = 0.5, shift = {0, 0} }
  end

  ---@type ISItemPrototype
  local scrap_item = {
    type = "item",
    name = scrap_name,
    localised_name = {
      "item-name.yis-scrap-name",
      {"item-name." .. scrap_defines.scrap_type},
      {"item-name.scrap"}
    },
    localised_description = {
      "item-description.yis-scrap-description",
      { "item-name." .. scrap_defines.scrap_type },
    },
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
    default_import_location = (mods["space-age"] and naming.get_import_location(scrap_defines.scrap_type)) or nil,
  }

  if not scrap_tints[scrap_defines.scrap_type] and not item_tints.iron_rust then
    is_log.write(
      "generator",
      "warn",
      "missing-scrap-tint",
      "No scrap tint or base fallback tint is available.",
      { scrap_type = scrap_defines.scrap_type }
    )
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

  data_table_writer.set_generated_item(data_table, scrap_name, scrap_item, {
    source_item = scrap_defines.name,
    scrap_type = scrap_defines.scrap_type,
    stack_size = scrap_defines.stack_size,
  })
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
---@param data_table ISdata_table
function prototype_builder.ensure_recycle_recipe(data_table, recipe_defines)
  local recipe_name = naming.get_recycle_recipe_name(recipe_defines.scrap_type) .. (recipe_defines.recipe_suffix or "")

  local existing_recycle_recipe = data_table_reader.generated_recipe(data_table, recipe_name)
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
      existing_recycle_recipe.icons = icon_layers.get(
        data_table,
        recipe_defines.scrap_type,
        false,
        recipe_defines.result_type,
        recipe_defines.result_name
      )
      data_table_writer.merge_recipe_source(data_table, recipe_name, {
        result_type = recipe_defines.result_type,
        result_name = recipe_defines.result_name,
      })
    end
    return
  end -- no duplicates

  local result_amount = recipe_defines.result_amount or (recipe_defines.result_type == "item" and 1 or 10)
  local recipe_icon_layers = icon_layers.get(
    data_table,
    recipe_defines.scrap_type,
    false,
    recipe_defines.result_type,
    recipe_defines.result_name
  )

  ---@type ISRecipePrototype
  local recycle_recipe = {
    type = "recipe",
    name = recipe_name,
    localised_name = {
      "recipe-name.yis-recycle-name",
      { "item-name.recycle" },
      {
        "item-name.yis-scrap-name",
        { "item-name." .. recipe_defines.scrap_type },
        { "item-name.scrap" },
      },
    },
    localised_description = { "recipe-description.yis-recycle-description" },
    icons = recipe_icon_layers,
    hidden = recipe_defines.hidden or nil,
    enabled = false,
    subgroup = "raw-material",
    category = recipe_defines.categories[1],
    order = "is-[" .. recipe_name .. "]",
    always_show_products = true,
    allow_as_intermediate = false,
    allow_intermediates = false,
    hide_from_player_crafting = true,
    ingredients =
    {
      { type = "item", name = naming.get_scrap_name(recipe_defines.scrap_type), amount = 0 },
    },
    results = { { type = recipe_defines.result_type, name = recipe_defines.result_name, amount = result_amount } }
  }

  data_table_writer.set_generated_recipe(data_table, recipe_name, recycle_recipe, {
    scrap_type = recipe_defines.scrap_type,
    result_type = recipe_defines.result_type,
    result_name = recipe_defines.result_name,
  })
end

--------------------------------
---*TECHNOLOGIES*             --
--------------------------------

---Creates and stores a recycle technology when the source recipe is unlocked by an existing technology.
---@param tech_defines {scrap_type: string, recipe_name: string, data_table: ISdata_table, recipe_suffix?: string}
function prototype_builder.ensure_technology(tech_defines)

  local recycle_recipe_name = naming.get_recycle_recipe_name(tech_defines.scrap_type)
  local unlock_recipe_name = recycle_recipe_name .. (tech_defines.recipe_suffix or "")
  local recycle_recipe = data_table_reader.generated_recipe(tech_defines.data_table, unlock_recipe_name)
  local recycle_result = recycle_recipe and recycle_recipe.results and recycle_recipe.results[1]
  local technology_icon_layers = icon_layers.get(
    tech_defines.data_table,
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
    localised_name = {
      "technology-name.yis-recycling-name",
      { "item-name.recycling" },
      {
        "item-name.yis-scrap-name",
        { "item-name." .. tech_defines.scrap_type },
        { "item-name.scrap" },
      },
    },
    localised_description = { "technology-description.yis-recycling-description" },
    icons = technology_icon_layers,
    enabled = true,
    hidden = ISsettings.hide_tech == true and ISsettings.shallow_log == false,
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
      item = naming.get_scrap_name(tech_defines.scrap_type),
      count = 1
    }
  }

  local found_source_unlock = false
  local is_primary_recycle_unlock = not tech_defines.recipe_suffix or tech_defines.recipe_suffix == ""
  for _, tech in pairs(data.raw.technology) do
    for _, effect in ipairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" then
          if effect.recipe == tech_defines.recipe_name then
            found_source_unlock = true
            local technology = data_table_reader.generated_technology(tech_defines.data_table, recycle_recipe_name) or scrap_technology
            if is_primary_recycle_unlock then
              technology.icons = technology_icon_layers
            end
            if not has_unlock_effect(technology, unlock_recipe_name) then
              if is_primary_recycle_unlock then
                table.insert(technology.effects, 1, { type = "unlock-recipe", recipe = unlock_recipe_name })
              else
                table.insert(technology.effects, { type = "unlock-recipe", recipe = unlock_recipe_name })
              end
            end
            data_table_writer.set_generated_technology(tech_defines.data_table, recycle_recipe_name, technology)
            break
          end
        end
    end
  end

  if not found_source_unlock then
    local technology = data_table_reader.generated_technology(tech_defines.data_table, recycle_recipe_name) or scrap_technology
    if not has_unlock_effect(technology, unlock_recipe_name) then
      table.insert(technology.effects, { type = "unlock-recipe", recipe = unlock_recipe_name })
    end
    data_table_writer.set_generated_technology(tech_defines.data_table, recycle_recipe_name, technology)
  end
end

return prototype_builder
