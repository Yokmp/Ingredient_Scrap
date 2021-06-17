data:extend({
  {
      type = "int-setting",
      name = "ingredient-scrap-needed",
      setting_type = "startup",
      minimum_value = 1,
      default_value = 10
  },
  {
      type = "int-setting",
      name = "ingredient-scrap-probability",
      setting_type = "startup",
      minimum_value = 1,
      default_value = 24
  },
  {
    type = "bool-setting",
      name = "ingredient-scrap-amount-by-ingredients",
      setting_type = "startup",
      hidden = true,
      default_value = true
  },
})
