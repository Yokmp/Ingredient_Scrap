require("lib.material-overrides")

local api = yokmods.ingredient_scrap.api

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
    suffixes = { "-plate", "-ingot", "-ore", "-alloy", "-sheet", "" },
  },
  fluid = {
    prefixes = { "molten-", "liquid-" },
    suffixes = { "-solution" },
  },
}

--------------------------------
---*ANGELMODS*               --
--------------------------------

if has_any_mod({ "angelsrefining", "angelssmelting", "angelspetrochem", "SeaBlock" }) then
  for _, material_name in ipairs({ "aluminium", "brass", "bronze", "cobalt", "cobalt-steel", "copper-tungsten",
    "glass", "gold", "gunmetal", "invar", "lead", "nickel", "nitinol", "silver", "tin", "titanium", "zinc" }) do
    api.register.material.solid(material_name, {
      localized_setting_name = material_name == "brass"
        or material_name == "bronze"
        or material_name == "invar"
        or material_name == "nitinol",
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
      prototype_affixes = common_mod_solid_affixes,
    })
  end
end

--------------------------------
---*BZMODS*                  --
--------------------------------

if has_any_mod({ "bzaluminum" }) then
  api.register.material.solid("aluminum", {
    prototype_affixes = common_mod_solid_affixes,
  })
end

if has_any_mod({ "bzlead" }) then
  api.register.material.solid("lead", {
    prototype_affixes = common_mod_solid_affixes,
  })
end

--------------------------------
---*KRASTORIO*               --
--------------------------------

if has_any_mod({ "Krastorio2" }) then
  api.register.material.solid("imersium", {
    prototype_affixes = common_mod_solid_affixes,
  })
end

return api
