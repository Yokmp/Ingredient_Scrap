
---@class ISdata_table
---@field constants ISdata_table.constants
---@field ingredients ISdata_table.ingredients
---@field prototypes ISdata_table.prototypes
---@field inserts ISdata_table.inserts
---@field materials ISdata_table.materials
---@field debug table?


---@class ISdata_table.constants
---@field icon_path string
---@field recycle_categories {solid: string, fluid: string}
---@field icon_scrap table[]
---@field scrap_pictures integer


---@class ISdata_table.ingredients
---@field items ISdata_table.ingredients.items
---@field fluids ISdata_table.ingredients.fluids

  ---@class ISdata_table.ingredients.items
  ---@field [table] ISIngredientPrototype

  ---@class ISdata_table.ingredients.fluids
  ---@field [table] ISIngredientPrototype


---@class ISdata_table.prototypes
---@field items ISdata_table.prototypes.items
---@field recipes ISdata_table.prototypes.recipes
---@field technology ISdata_table.prototypes.technology

  ---@class ISdata_table.prototypes.items
  ---@field [string] ISItemPrototype

  ---@class ISdata_table.prototypes.recipes
  ---@field [string] ISRecipePrototype

  ---@class ISdata_table.prototypes.technology
  ---@field effects ISTechnologyEffect[]


---@class ISdata_table.inserts
---@field recipes ISRecipePrototype


---@class ISdata_table.materials
---@field solid_prefixes string[]
---@field solid_suffixes string[]
---@field fluid_prefixes string[]
---@field fluid_suffixes string[]
---@field solid string[]
---@field fluid string[]


---@class ISRecipePrototype
---@field type string
---@field name string
---@field localised_name table?[string]
---@field enabled boolean
---@field categories table?[string]
---@field main_product string?
---@field ingredients [ISIngredientPrototype]?
---@field results [ISResultPrototype]?
---@field icons table?[IconLayers]
---@field subgroup string?
---@field order string?
---@field always_show_products boolean?
---@field allow_as_intermediate boolean?
---@field hide_from_player_crafting boolean?

---@class ISItemPrototype
---@field type string
---@field name string
---@field localised_name table?[string]
---@field icons IconLayers
---@field pictures table[]
---@field subgroup string
---@field order string
---@field stack_size integer
---@field inventory_move_sound table
---@field pick_sound table
---@field drop_sound table
---@field default_import_location string?
---@field random_tint_color table?[r:integer, g:integer, b:integer, a:integer?]


---@class ISIngredientPrototype
---@field type string
---@field name string
---@field amount integer?
---@field amount_min integer?
---@field amount_max integer?

---@class ISResultPrototype
---@field type string
---@field name string
---@field amount integer
---@field probability number?

---@class ISTechnologyEffect
---@field type string
---@field recipe string



---@class IconLayers
---@field [table] ISIcon

---@class ISIcon
---@field icon string
---@field icon_size integer
---@field icon_mipmaps number?
---@field scale integer?
---@field shift table?[number, number]
---@field tint table?[r:integer, g:integer, b:integer, a:integer?]


---@class category
---@field [table] string
