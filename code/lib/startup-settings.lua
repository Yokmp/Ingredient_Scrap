local startup_settings = {}

---Builds Ingredient Scrap startup settings from Factorio settings and optional debug profiles.
---@param material_overrides table
---@param ancestry_settings table
---@return table
function startup_settings.load(material_overrides, ancestry_settings)
  local loaded = yokmods.ingredient_scrap.settings or {}
  loaded.fixed_amount = settings.startup["yis-fixed-amount"].value
  loaded.probability = settings.startup["yis-probability"].value
  loaded.limit = settings.startup["yis-amount-limit"].value
  loaded.needed = settings.startup["yis-needed"].value
  loaded.fluid_setting = settings.startup["yis-fluid-recipes"].value
  loaded.fluids = true
  loaded.hide_tech = settings.startup["yis-hide-tech"].value
  loaded.shallow_log = settings.startup["yis-shallow-log"].value
  loaded.barreling = settings.startup["yis-barreling"].value
  loaded.recipe_chain_targets = settings.startup["yis-use-recipe-chain-targets"].value
  loaded.ancestry_mode = settings.startup[ancestry_settings.setting_name].value
  loaded.ancestry_max_depth = settings.startup[ancestry_settings.max_depth_setting_name].value
  loaded.ancestry_mixed_limit = settings.startup[ancestry_settings.mixed_limit_setting_name].value
  loaded.ancestry_policy = ancestry_settings.policy(
    loaded.ancestry_mode,
    {
      max_depth = loaded.ancestry_max_depth,
      mixed_limit = loaded.ancestry_mixed_limit,
    }
  )
  loaded.material_modes = {}

  for _, material_name in ipairs(material_overrides.sorted_materials()) do
    local setting = settings.startup[material_overrides.setting_name(material_name)]
    loaded.material_modes[material_name] = setting and setting.value or material_overrides.default_modes[material_name]
  end

  --#region debug
  if IS_DEBUG then
    local ok, profile = pcall(require, "tools.test.profile")
    if ok and type(profile) == "table" then
      yokmods.ingredient_scrap.test_profile = profile.name or "custom"
      for key, value in pairs(profile.settings or {}) do
        if loaded[key] ~= nil then
          loaded[key] = value
        end
      end
      loaded.ancestry_policy =
        ancestry_settings.policy(
          loaded.ancestry_mode,
          {
            max_depth = loaded.ancestry_max_depth,
            mixed_limit = loaded.ancestry_mixed_limit,
          }
        )
      for material_name, default_mode in pairs(material_overrides.default_modes) do
        loaded.material_modes[material_name] = default_mode
      end
      for material_name, mode in pairs(profile.material_modes or {}) do
        if material_overrides.default_modes[material_name] then
          loaded.material_modes[material_name] = mode
        end
      end
      log("[IS-TEST] Loaded profile: " .. yokmods.ingredient_scrap.test_profile)
    else
      yokmods.ingredient_scrap.test_profile = "default"
    end
  end
  --#endregion

  loaded.fluids = true
  yokmods.ingredient_scrap.settings = loaded
  ISsettings = loaded
  return loaded
end

return startup_settings
