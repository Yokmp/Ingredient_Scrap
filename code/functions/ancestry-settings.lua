local ancestry_settings = {}

ancestry_settings.setting_name = "yis-ancestry-mode"
ancestry_settings.max_depth_setting_name = "yis-ancestry-max-depth"
ancestry_settings.mixed_limit_setting_name = "yis-ancestry-mixed-limit"

ancestry_settings.allowed_values = {
  "component-heavy",
  "balanced",
  "material-heavy",
}

ancestry_settings.default_value = "balanced"

local policies = {
  ["component-heavy"] = {
    root_policy = "stable",
    mixed_limit = 999,
    max_depth = 1,
    component_fallback = true,
  },
  balanced = {
    root_policy = "hybrid",
    mixed_limit = 3,
    max_depth = 8,
    component_fallback = true,
  },
  ["material-heavy"] = {
    root_policy = "resources",
    mixed_limit = 3,
    max_depth = 8,
    component_fallback = false,
  },
}

---Returns the ancestry policy for a startup setting value.
---@param value string|nil
---@param overrides? {max_depth?: integer, mixed_limit?: integer}
---@return table
function ancestry_settings.policy(value, overrides)
  local mode = policies[value or ancestry_settings.default_value] and value or ancestry_settings.default_value
  local selected = policies[mode]
  overrides = overrides or {}
  return {
    mode = mode,
    root_policy = selected.root_policy,
    mixed_limit = overrides.mixed_limit or selected.mixed_limit,
    max_depth = overrides.max_depth or selected.max_depth,
    component_fallback = selected.component_fallback,
  }
end

return ancestry_settings
