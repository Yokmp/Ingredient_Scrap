require("lib.material-overrides")

local api = yokmods.ingredient_scrap.api
local has_space_age = mods and mods["space-age"] ~= nil
local base_source = { name = "Base", color = "#8DA0AA" }
local space_age_source = { name = "Space Age", color = "#E6A23C" }

--------------------------------
---*BASE*                    --
--------------------------------

api.ignore.material("coal", { localized_setting_name = true, source = base_source })
api.ignore.material("crude", {
  localized_setting_name = true,
  source = base_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = {} },
    fluid = { prefixes = {}, suffixes = { "-oil", "" } },
  },
})
api.ignore.material("stone", { localized_setting_name = true, source = base_source })
api.ignore.material("sulfuric", {
  localized_setting_name = true,
  source = base_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = {} },
    fluid = { prefixes = {}, suffixes = { "-acid", "" } },
  },
})
api.ignore.material("uranium", {
  localized_setting_name = true,
  source = base_source,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-ore", "-238", "-235", "" } },
    fluid = { prefixes = {}, suffixes = {} },
  },
})

api.register.material.auto("copper", { localized_setting_name = true, source = base_source, tint = "#CB6015" })
api.register.material.auto("iron", { localized_setting_name = true, source = base_source, tint = "#888b8d" })
api.register.material.solid("steel", { localized_setting_name = true, source = base_source, tint = "#888b8d" })

--------------------------------
---*SPACE AGE*               --
--------------------------------

if has_space_age then
  api.ignore.material("ammonia", { localized_setting_name = true, source = space_age_source })
  api.ignore.material("bacteria", {
    localized_setting_name = true,
    source = space_age_source,
    prototype_affixes = {
      item = { prefixes = {}, suffixes = {} },
      fluid = { prefixes = {}, suffixes = {} },
    },
  })
  api.ignore.material("calcite", { localized_setting_name = true, source = space_age_source })
  api.ignore.material("fluorine", { localized_setting_name = true, source = space_age_source })
  api.ignore.material("lithium", { localized_setting_name = true, source = space_age_source, tint = "#7B867A" })
  api.ignore.material("scrap", { localized_setting_name = true, source = space_age_source })
  api.register.material.auto("holmium", { localized_setting_name = true, source = space_age_source, tint = "#bb8997" })
  api.register.material.tint("tungsten", "#6555B1")
end
