require("lib.material-overrides")

local api = yokmods.ingredient_scrap.api
local has_space_age = mods and mods["space-age"] ~= nil

--------------------------------
---*BASE*                    --
--------------------------------

api.ignore.material("coal", { localized_setting_name = true })
api.ignore.material("crude", {
  localized_setting_name = true,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = {} },
    fluid = { prefixes = {}, suffixes = { "-oil", "" } },
  },
})
api.ignore.material("stone", { localized_setting_name = true })
api.ignore.material("sulfuric", {
  localized_setting_name = true,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = {} },
    fluid = { prefixes = {}, suffixes = { "-acid", "" } },
  },
})
api.ignore.material("uranium", {
  localized_setting_name = true,
  prototype_affixes = {
    item = { prefixes = {}, suffixes = { "-ore", "-238", "-235", "" } },
    fluid = { prefixes = {}, suffixes = {} },
  },
})

api.register.material.auto("copper", { localized_setting_name = true })
api.register.material.auto("iron", { localized_setting_name = true })
api.register.material.solid("steel", { localized_setting_name = true })

--------------------------------
---*SPACE AGE*               --
--------------------------------

if has_space_age then
  api.ignore.material("ammonia", { localized_setting_name = true })
  api.ignore.material("bacteria", {
    localized_setting_name = true,
    prototype_affixes = {
      item = { prefixes = {}, suffixes = {} },
      fluid = { prefixes = {}, suffixes = {} },
    },
  })
  api.ignore.material("calcite", { localized_setting_name = true })
  api.ignore.material("fluorine", { localized_setting_name = true })
  api.ignore.material("lithium", { localized_setting_name = true })
  api.ignore.material("scrap", { localized_setting_name = true })
  api.register.material.auto("holmium", { localized_setting_name = true })
end
