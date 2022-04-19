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
        hidden = true,
        type = "string-setting",
        name = "yis-amount-method",
        setting_type = "startup",
        default_value = "al",
        allowed_values = {"cu", "cl", "au", "al"}
    },
    {
        hidden = false,
        type = "bool-setting",
        name = "yis-amount-by-ingredients",
        setting_type = "startup",
        default_value = true,
        order = "c",
    },
    {
        hidden = false,
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
