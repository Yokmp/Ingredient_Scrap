data:extend({
    {
        type = "int-setting",
        name = "yis-needed",
        setting_type = "startup",
        minimum_value = 1,
        default_value = 5,
        order = "a",
    },
    {
        type = "int-setting",
        name = "yis-probability",
        setting_type = "startup",
        minimum_value = 1,
        default_value = 24,
        order = "b",
    },
    {
        type = "bool-setting",
        name = "yis-amount-by-ingredients", --//FIXME scrap amount can outweight the cost
        setting_type = "startup",
        hidden = false,
        default_value = false,
        order = "c",
    },
    {
        type = "bool-setting",
        name = "yis-amount-limit",
        setting_type = "startup",
        default_value = true,
        order = "d",
    },
    {
        type = "string-setting",
        name = "yis-unlock-scraps",
        setting_type = "startup",
        default_value = "iron-scrap, copper-scrap",
        order = "e",
    },
    {
        type = "bool-setting",
        name = "yis-handle-fluids", -- fluid mixer could also do this
        setting_type = "startup",
        hidden = true,
        default_value = true,
        order = "z",
    },
})
