local init = {}

---Creates the shared data table used to collect inputs, generated prototypes, inserts, and debug sources.
---@param material_overrides table
---@return ISdata_table
function init.create(material_overrides)
  local affixes = material_overrides.resolver_affixes()
  local aliases = material_overrides.resolver_aliases()
  local exact_scrap = material_overrides.exact_scrap_materials()

  return {
    constants = {
      icon_path = "__Ingredient_Scrap__/graphics/icons/",
      recycle_categories = { solid = "yis-recycle-to-item", fluid = "yis-recycle-to-fluid" },
      icon_scrap = { "scrap-64" },
      scrap_pictures = 3,
    },
    ingredients = {
      items = {},
      fluids = {},
    },
    prototypes = {
      recipes = {},
      items = {},
      technology = {},
    },
    inserts = {
      recipes = {},
    },
    materials = {
      solid_prefixes = affixes.solid_prefixes,
      solid_suffixes = affixes.solid_suffixes,
      solid_aliases = aliases.item,
      solid_exact_scrap = exact_scrap,
      fluid_prefixes = affixes.fluid_prefixes,
      fluid_suffixes = affixes.fluid_suffixes,
      fluid_aliases = aliases.fluid,
      solid = {},
      fluid = {},
    },
    debug = {
      logs = {},
      sources = {
        items = {},
        recipes = {},
        inserts = {},
        skipped = {},
      },
    },
  }
end

return init
