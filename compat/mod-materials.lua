require("lib.material-overrides")

local api = yokmods.ingredient_scrap.api
local angel_source = { name = "Angel's Mods", color = "#C97A40" }
local bob_source = { name = "Bob's Mods", color = "#4DA3D9" }
local bz_source = { name = "BZ Mods", color = "#9E7BD9" }
local krastorio_source = { name = "Krastorio 2", color = "#78C850" }

---Returns true when at least one mod in the list is active.
---@param mod_names string[]
---@return boolean
local function has_any_mod(mod_names)
  for _, mod_name in ipairs(mod_names) do
    if mods and mods[mod_name] then return true end
  end
  return false
end

local common_mod_solid_affixes = {
  item = {
    prefixes = {},
    suffixes = { "-plate", "-ore", "" },
  },
  fluid = {
    prefixes = { "molten-", "liquid-" },
    suffixes = { "-solution" },
  },
}

--------------------------------
---*ANGELMODS*               --
--------------------------------
--TODO: glass is not a vvalid material for scrap -> ignore
if has_any_mod({ "angelsrefining", "angelssmelting", "angelspetrochem", "SeaBlock" }) then
  for _, material_name in ipairs({ "aluminium", "brass", "bronze", "cobalt", "cobalt-steel", "copper-tungsten",
    "glass", "gold", "gunmetal", "invar", "lead", "nickel", "nitinol", "silver", "tin", "titanium", "zinc" }) do
    api.register.material.solid(material_name, {
      localized_setting_name = material_name == "brass"
        or material_name == "bronze"
        or material_name == "invar"
        or material_name == "nitinol",
      source = angel_source,
      prototype_affixes = common_mod_solid_affixes,
    })
  end
end

--------------------------------
---*BOBSMODS*                --
--------------------------------

if has_any_mod({ "bobplates", "bobores", "bobrevamp", "bobmetals" }) then
  for _, material_name in ipairs({ "aluminium", "brass", "bronze", "cobalt", "cobalt-steel", "gold", "invar",
    "lead", "nickel", "nitinol", "silver", "tin", "titanium", "zinc" }) do
    api.register.material.solid(material_name, {
      localized_setting_name = material_name == "brass"
        or material_name == "bronze"
        or material_name == "invar"
        or material_name == "nitinol",
      source = bob_source,
      prototype_affixes = common_mod_solid_affixes,
    })
  end
end

--------------------------------
---*BZMODS*                  --
--------------------------------

if has_any_mod({ "bzaluminum" }) then
  api.register.material.solid("aluminum", {
    source = bz_source,
    prototype_affixes = common_mod_solid_affixes,
  })
end

if has_any_mod({ "bzlead" }) then
  api.register.material.solid("lead", {
    source = bz_source,
    prototype_affixes = common_mod_solid_affixes,
  })
end

--------------------------------
---*KRASTORIO*               --
--------------------------------

if has_any_mod({ "Krastorio2" }) then
  api.register.material.solid("rare-metal", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_affixes = common_mod_solid_affixes,
    prototype_aliases = {
      item = { "kr-rare-metal-ore", "kr-rare-metals" },
    },
    tint = "#8FB8B8",
  })
  api.register.material.solid("imersium", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_affixes = common_mod_solid_affixes,
    prototype_aliases = {
      item = { "kr-imersium-plate", "kr-imersium-beam", "kr-imersium-gear-wheel" },
    },
  })
  api.register.material.solid("black-reinforced", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_aliases = {
      item = { "kr-black-reinforced-plate" },
    },
    tint = "#2A2A2A",
  })
  api.register.material.solid("white-reinforced", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_aliases = {
      item = { "kr-white-reinforced-plate" },
    },
    tint = "#D8D8D8",
  })
end

return api
