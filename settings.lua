local material_overrides = require("code.lib.material-overrides")
require("code.lib.recipe-chain-overrides")
require("code.compat.vanilla-materials")
require("code.compat.mod-materials")

local has_test_profile = pcall(require, "tools.test.profile")
if has_test_profile then
    require("tools.test.material-overrides")
end

data:extend({
    {
        type = "int-setting",
        name = "yis-needed",
        localised_name = { "", "[img=sum-symbol]", " - ", { "mod-setting-name.yis-needed" } },
        setting_type = "startup",
        minimum_value = 1,
        default_value = 5,
        order = "a",
    },
    {
        type = "int-setting",
        name = "yis-probability",
        localised_name = { "", "[img=percent-symbol]", " - ", { "mod-setting-name.yis-probability" } },
        setting_type = "startup",
        minimum_value = 1,
        maximum_value = 100,
        default_value = 24,
        order = "b",
    },
    {
        hidden = false,
        type = "bool-setting",
        name = "yis-fixed-amount",
        localised_name = { "", "[img=fixed-symbol]", " - ", { "mod-setting-name.yis-fixed-amount" } },
        setting_type = "startup",
        default_value = false,
        order = "c",
    },
    {
        hidden = false,
        type = "bool-setting",
        name = "yis-amount-limit",
        localised_name = { "", "[img=sigma-symbol]", " - ", { "mod-setting-name.yis-amount-limit" } },
        setting_type = "startup",
        default_value = true,
        order = "d",
    },
    {
        hidden = false,
        type = "bool-setting",
        name = "yis-shallow-log",
        localised_name = { "", "[img=gears-symbol]", " - ", { "mod-setting-name.yis-shallow-log" } },
        setting_type = "startup",
        default_value = true,
        order = "e",
    },
    {
        hidden = false,
        type = "bool-setting",
        name = "yis-fluid-recipes",
        localised_name = { "", "[img=drop-symbol]", " - ", { "mod-setting-name.yis-fluid-recipes" } },
        setting_type = "startup",
        default_value = true,
        order = "f",
    },

    {
        hidden = false,
        type = "bool-setting",
        name = "yis-hide-tech",
        localised_name = { "", "[img=unlock-symbol]", " - ", { "mod-setting-name.yis-hide-tech" } },
        setting_type = "startup",
        default_value = true,
        order = "g",
    },
    {
        hidden = true,
        type = "bool-setting",
        name = "yis-barreling",
        setting_type = "startup",
        default_value = true,
    },
    {
        hidden = true,
        type = "bool-setting",
        name = "yis-IS_DEBUG",
        setting_type = "startup",
        default_value = false,
    },
    {
        hidden = true,
        type = "bool-setting",
        name = "yis-use-recipe-chain-targets",
        setting_type = "startup",
        default_value = false,
    },
})

local material_settings = {}
for _, material_name in ipairs(material_overrides.sorted_materials()) do
    table.insert(material_settings, {
        type = "string-setting",
        name = material_overrides.setting_name(material_name),
        localised_name = material_overrides.localised_setting_name(material_name),
        localised_description = material_overrides.localised_setting_description(material_name),
        setting_type = "startup",
        default_value = material_overrides.default_modes[material_name],
        allowed_values = material_overrides.allowed_values,
        order = "m[" .. material_name .. "]",
    })
end

data:extend(material_settings)
