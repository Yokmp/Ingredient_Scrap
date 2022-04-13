data:extend({
  {
      type = "int-setting",
      name = "yis-needed",
      setting_type = "startup",
      minimum_value = 1,
      default_value = 5
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
      name = "yis-handle-fluids",
      setting_type = "startup",
      hidden = true,
      default_value = true
  },
  {
      type = "bool-setting",
      name = "yis-amount-by-ingredients", -- balancing can be an issue here
      setting_type = "startup",
      hidden = true,
      default_value = true
  },
})
