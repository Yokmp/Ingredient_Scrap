data:extend({
    {
        type = "int-setting",
        name = "yis-needed",
        setting_type = "startup",
        minimum_value = 1,
        default_value = 5,
        order = "",
    },
    {
        type = "int-setting",
        name = "yis-probability",
        setting_type = "startup",
        minimum_value = 1,
        default_value = 24
    },
    {
        type = "bool-setting",
        name = "yis-handle-fluids", -- fluid mixer could also do this
        setting_type = "startup",
        hidden = true,
        default_value = true
    },
    {
        type = "bool-setting",
        name = "yis-amount-by-ingredients", -- balancing can be an issue here
        setting_type = "startup",
        hidden = false,
        default_value = false
    },
    {
        type = "string-setting",
        name = "yis-unlock-scraps",
        setting_type = "startup",
        default_value = "iron-scrap, copper-scrap",
    },
})
