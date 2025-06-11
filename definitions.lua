
---@class ISdata_table
---@field auto_recycle boolean
---@field fluids_as_barrel boolean
---@field probability number
---@field ingredients ISdata_table.ingredients
---@field prototypes ISdata_table.prototypes
---@field inserts ISdata_table.inserts


---@class ISdata_table.ingredients
---@field items ISdata_table.ingredients.items
---@field fluids ISdata_table.ingredients.fluids

---@class ISdata_table.ingredients.items
---@field [string] {type: string, name:string, amount:integer, probability?:number}

---@class ISdata_table.ingredients.fluids
---@field [string] {type: string, name:string, amount:integer, probability?:number}


---@class ISdata_table.prototypes
---@field items ISdata_table.prototypes.items
---@field recipes data.RecipePrototype

---@class ISdata_table.prototypes.items
---@field [string] data.ItemPrototype

---@class ISdata_table.prototypes.recipes
---@field [string] data.RecipePrototype


---@class ISdata_table.inserts
---@field [table] data.ItemPrototype



---@class IconLayers
---@field table data.IconData
