require("code.override.materials")
require("code.override.sources")
require("code.override.categories")

local api = yokmods.ingredient_scrap.api
local angel_source = { name = "Angel's Mods", color = "#C97A40" }
local bob_source = { name = "Bob's Mods", color = "#4DA3D9" }
local bz_source = { name = "BZ Mods", color = "FF7BD9A7" }
local krastorio_source = { name = "Krastorio 2", color = "#9e50c8" }

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
    suffixes = { "-plate", "-bar", "-ore", "" },
  },
  fluid = {
    prefixes = { "molten-", "liquid-" },
    suffixes = { "-solution" },
  },
}

local ore_source_filter = {
  ingredient_suffixes = { "-ore" },
  ingredient_exclude_prefixes = { "yis-" },
  reason = "Ore processing chains should not create Ingredient Scrap byproducts.",
}

local bob_material_aliases = {
  aluminium = { "bob-aluminium-plate" },
  brass = { "bob-brass-alloy" },
  bronze = { "bob-bronze-alloy" },
  cobalt = { "bob-cobalt-plate", "bob-cobalt-ore" },
  ["cobalt-steel"] = { "bob-cobalt-steel-alloy" },
  ["copper-tungsten"] = { "bob-copper-tungsten-alloy" },
  gold = { "bob-gold-plate", "bob-gold-ore" },
  gunmetal = { "bob-gunmetal-alloy" },
  invar = { "bob-invar-alloy" },
  lead = { "bob-lead-plate", "bob-lead-ore" },
  nickel = { "bob-nickel-plate", "bob-nickel-ore" },
  nitinol = { "bob-nitinol-alloy" },
  silicon = { "bob-silicon-plate", "bob-silicon-wafer" },
  silver = { "bob-silver-plate", "bob-silver-ore" },
  tin = { "bob-tin-plate", "bob-tin-ore" },
  titanium = { "bob-titanium-plate" },
  zinc = { "bob-zinc-plate", "bob-zinc-ore" },
}

local component_source = { name = "Component Families", color = "#D6A34D" }
local component_aliases = {
  battery = { "battery", "bob-battery-2", "bob-battery-3" },
  board = { "bob-basic-circuit-board" },
  circuit = { "electronic-circuit", "advanced-circuit", "processing-unit", "bob-advanced-processing-unit" },
  gear = {
    "iron-gear-wheel",
    "bob-brass-gear-wheel",
    "bob-steel-gear-wheel",
    "bob-titanium-gear-wheel",
    "bob-nitinol-gear-wheel",
    "bob-tungsten-gear-wheel",
  },
  bearing = {
    "bob-brass-bearing",
    "bob-steel-bearing",
    "bob-titanium-bearing",
    "bob-nitinol-bearing",
  },
  ["bearing-ball"] = {
    "bob-brass-bearing-ball",
    "bob-steel-bearing-ball",
  },
  cable = {
    "bob-tinned-copper-cable",
    "bob-gilded-copper-cable",
    "bob-insulated-cable",
  },
  pipe = {
    "pipe",
    "bob-brass-pipe",
    "bob-bronze-pipe",
    "bob-ceramic-pipe",
    "bob-copper-tungsten-pipe",
    "bob-plastic-pipe",
    "bob-steel-pipe",
    "bob-titanium-pipe",
    "bob-tungsten-pipe",
  },
}

---Returns exact item aliases for a Bob material, if known.
---@param material_name string
---@return table|nil
local function bob_aliases(material_name)
  local aliases = bob_material_aliases[material_name]
  if not aliases then return nil end
  return {
    item = aliases,
  }
end

---Returns exact item aliases for a component family, if known.
---@param material_name string
---@return table|nil
local function component_aliases_for(material_name)
  local aliases = component_aliases[material_name]
  if not aliases then return nil end
  return {
    item = aliases,
  }
end

---Ignores ore inputs in process categories that should not create Ingredient Scrap.
---@param categories string[]
local function ignore_ore_source_categories(categories)
  for _, category in ipairs(categories) do
    api.ignore.source.category(category, ore_source_filter)
  end
end

ignore_ore_source_categories({
  "bob-chemical-furnace",
  "bob-electrolysis",
  "chemistry",
  "chemistry-or-cryogenics",
  "crafting",
  "crafting-with-fluid",
  "kr-smelting-crafting",
  "metallurgy",
  "smelting",
})

--------------------------------
---*ANGELMODS*               --
--------------------------------

if has_any_mod({ "angelsrefining", "angelssmelting", "angelspetrochem", "SeaBlock" }) then
  for _, register_category in ipairs({
    api.register.category.furnace,
    api.register.category.assembling_machine,
  }) do
    register_category({
      fast_replaceable_groups = { "angels-casting-machine" },
      add_item_recycling = true,
    })
    register_category({
      fast_replaceable_groups = { "angels-induction-furnace" },
      add_item_recycling = false,
      add_fluid_recycling_if_fluid_boxes = true,
    })
  end

  ignore_ore_source_categories({
    "angels-ore-processing",
    "angels-ore-processing-2",
    "angels-ore-processing-3",
    "angels-ore-processing-4",
    "angels-ore-refining-t1",
    "angels-ore-refining-t2",
    "angels-ore-refining-t3",
    "angels-blast-smelting",
    "angels-blast-smelting-2",
    "angels-blast-smelting-3",
    "angels-blast-smelting-4",
    "angels-chemical-smelting",
    "angels-chemical-smelting-2",
    "angels-chemical-smelting-3",
    "angels-chemical-smelting-4",
    "angels-liquifying",
    "angels-petrochem-electrolyser",
    "bob-electrolysis",
    "smelting",
    "metallurgy",
  })

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
  for _, material_name in ipairs({
    "angels-bauxite",
    "angels-chrome",
    "angels-cobalt",
    "angels-fluorite",
    "angels-manganese",
    "angels-nickel",
    "angels-platinum",
    "angels-rutile",
    "angels-silver",
    "angels-thorium",
    "angels-tungsten",
  }) do
    api.ignore.material(material_name, {
      localized_setting_name = true,
      source = angel_source,
      setting_icon = material_name .. "-ore",
    })
  end
end

--------------------------------
---*BOBSMODS*                --
--------------------------------

if has_any_mod({ "bobplates", "bobores", "bobrevamp", "bobmetals" }) then
  for _, material_name in ipairs({ "aluminium", "brass", "bronze", "cobalt", "cobalt-steel",
    "copper-tungsten", "gold", "gunmetal", "invar", "lead", "nickel", "nitinol", "silver",
    "tin", "titanium", "zinc" }) do
    api.register.material.solid(material_name, {
      localized_setting_name = material_name == "brass"
        or material_name == "bronze"
        or material_name == "copper-tungsten"
        or material_name == "gunmetal"
        or material_name == "invar"
        or material_name == "nitinol",
      source = bob_source,
      prototype_affixes = common_mod_solid_affixes,
      prototype_aliases = bob_aliases(material_name),
    })
  end
  api.register.material.solid("glass", {
    localized_setting_name = true,
    source = bob_source,
    prototype_affixes = common_mod_solid_affixes,
    prototype_aliases = {
      item = { "bob-glass" },
    },
    tint = "#A9D7E8",
  })
  api.register.material.solid("silicon", {
    localized_setting_name = true,
    source = bob_source,
    prototype_affixes = common_mod_solid_affixes,
    prototype_aliases = bob_aliases("silicon"),
    tint = "#6E6F72",
  })
  for _, material_name in ipairs({ "battery", "bearing", "bearing-ball", "board", "cable", "circuit", "gear", "pipe" }) do
    api.register.material.solid(material_name, {
      localized_setting_name = true,
      source = component_source,
      prototype_aliases = component_aliases_for(material_name),
      exact_scrap = true,
    })
  end
  for _, material_name in ipairs({
    "bob-amethyst",
    "bob-bauxite",
    "bob-diamond",
    "bob-emerald",
    "bob-ruby",
    "bob-rutile",
    "bob-sapphire",
    "bob-thorium",
    "bob-topaz",
  }) do
    api.ignore.material(material_name, {
      localized_setting_name = true,
      source = bob_source,
      setting_icon = material_name .. "-ore",
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
  api.register.material.solid("glass", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_aliases = {
      item = { "kr-glass" },
    },
    tint = "#A9D7E8",
  })
  api.register.material.solid("silicon", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_aliases = {
      item = { "kr-silicon" },
    },
    tint = "#6E6F72",
  })
  api.register.material.solid("rare-metal", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_affixes = common_mod_solid_affixes,
    prototype_aliases = {
      item = { "kr-rare-metal-ore", "kr-rare-metals" },
    },
    tint = "#8FB8B8",
  })
  api.ignore.source.recipe("kr-rare-metals", ore_source_filter)
  api.ignore.source.recipe("kr-enriched-rare-metals", ore_source_filter)
  api.register.recipe_chain.solid.to_item("rare-metal", "kr-rare-metals", {
    source = krastorio_source,
    reason = "K2 rare metal scrap should recycle to processed rare metals, not the raw ore.",
    active = true,
  })
  api.register.material.solid("imersium", {
    localized_setting_name = true,
    source = krastorio_source,
    prototype_affixes = common_mod_solid_affixes,
    prototype_aliases = {
      item = { "kr-imersium-plate", "kr-imersium-beam", "kr-imersium-gear-wheel" },
    },
  })
  api.register.recipe_chain.solid.to_item("imersium", "kr-imersium-plate", {
    source = krastorio_source,
    reason = "K2 imersium scrap should recycle to the base plate, not the beam intermediate.",
    active = true,
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
