---@meta

---@alias ISStringMap<T> table<string, T>
---@alias ISIngredientBuckets table<string, ISIngredientPrototype[]>
---@alias ISGeneratedItems table<string, ISItemPrototype>
---@alias ISGeneratedRecipes table<string, ISRecipePrototype>
---@alias ISGeneratedTechnologies table<string, ISTechnologyPrototype>
---@alias ISIconLayers ISIcon[]
---@alias category string[]

---@class ISdata_table
---@field constants ISdata_table_constants
---@field ingredients ISdata_table_ingredients
---@field prototypes ISdata_table_prototypes
---@field inserts ISdata_table_inserts
---@field materials ISdata_table_materials
---@field debug ISdata_table_debug

---@class ISdata_table_constants
---@field icon_path string
---@field recycle_categories {solid: string, fluid: string}
---@field icon_scrap string[]
---@field scrap_pictures integer

---@class ISdata_table_ingredients
---@field items ISIngredientBuckets
---@field fluids ISIngredientBuckets
---@field supplements table?

---@class ISdata_table_prototypes
---@field items ISGeneratedItems
---@field recipes ISGeneratedRecipes
---@field technology ISGeneratedTechnologies

---@class ISdata_table_inserts
---@field recipes table<string, ISRecipeInsert>

---@class ISdata_table_materials
---@field solid_prefixes string[]
---@field solid_suffixes string[]
---@field solid_aliases table<string, string>
---@field solid_exact_scrap table<string, boolean>
---@field fluid_prefixes string[]
---@field fluid_suffixes string[]
---@field fluid_aliases table<string, string>
---@field solid string[]
---@field fluid string[]

---@class ISdata_table_debug
---@field logs table[]?
---@field sources ISDebugSources?
---@field resolver table?
---@field recipe_chain_analysis table?
---@field recipe_chain_decisions table?
---@field performance table?
---@field furnace_result_inventory table?

---@class ISDebugSources
---@field items table<string, table>
---@field recipes table<string, table>
---@field inserts table<string, table[]>
---@field skipped table[]

---@class ISRecipeInsert
---@field main_product string?
---@field results ISResultPrototype[]?

---@class ISRecipePrototype
---@field type string
---@field name string
---@field localised_name table|string|nil
---@field hidden boolean?
---@field enabled boolean?
---@field category string?
---@field categories category?
---@field main_product string?
---@field ingredients ISIngredientPrototype[]?
---@field results ISResultPrototype[]?
---@field icons ISIconLayers?
---@field subgroup string?
---@field order string?
---@field always_show_products boolean?
---@field allow_as_intermediate boolean?
---@field hide_from_player_crafting boolean?

---@class ISItemPrototype
---@field type string
---@field name string
---@field localised_name table|string|nil
---@field icon string?
---@field icon_size integer?
---@field icon_mipmaps number?
---@field icons ISIconLayers?
---@field pictures table[]?
---@field subgroup string?
---@field order string?
---@field hidden boolean?
---@field stack_size integer
---@field inventory_move_sound table?
---@field pick_sound table?
---@field drop_sound table?
---@field default_import_location string?
---@field random_tint_color table?

---@class ISTechnologyPrototype
---@field type string
---@field name string
---@field localised_name table|string|nil
---@field icons ISIconLayers?
---@field enabled boolean?
---@field hidden boolean?
---@field effects ISTechnologyEffect[]?
---@field research_trigger table?

---@class ISIngredientPrototype
---@field type string?
---@field name string
---@field amount number?
---@field amount_min number?
---@field amount_max number?
---@field result_name string?
---@field defer_amount boolean?

---@class ISResultPrototype
---@field type string?
---@field name string
---@field amount number?
---@field amount_min number?
---@field amount_max number?
---@field probability number?
---@field yis_deferred_amount boolean?
---@field yis_source_amount number?
---@field yis_source_ingredient string?
---@field yis_normalized_after_results boolean?

---@class ISTechnologyEffect
---@field type string
---@field recipe string?

---@class ISIcon
---@field icon string
---@field icon_size integer
---@field icon_mipmaps number?
---@field scale number?
---@field shift number[]?
---@field tint table?
