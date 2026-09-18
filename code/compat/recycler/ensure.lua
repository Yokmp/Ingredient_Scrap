local ensure = {}

---Returns true when the machine already has the given crafting category.
---@param machine table|nil
---@param category string
---@return boolean
local function has_category(machine, category)
  for _, existing in ipairs((machine and machine.crafting_categories) or {}) do
    if existing == category then return true end
  end
  return false
end

---Adds a crafting category to a machine prototype if it is missing.
---@param machine table|nil
---@param category string
local function add_category_once(machine, category)
  if not machine then return end
  machine.crafting_categories = machine.crafting_categories or {}
  if not has_category(machine, category) then
    table.insert(machine.crafting_categories, category)
  end
end

---Reloads an idempotent fallback recycler prototype module.
---@param module_name string
local function reload(module_name)
  package.loaded[module_name] = nil
  require(module_name)
end

---Ensures the recycling recipe category exists.
function ensure.category()
  if data.raw["recipe-category"] and data.raw["recipe-category"].recycling then return end
  data:extend({
    {
      type = "recipe-category",
      name = "recycling",
    },
  })
end

---Ensures a recycler prototype set exists and can craft recycling recipes.
function ensure.recycler()
  ensure.category()

  if not data.raw.furnace or not data.raw.furnace.recycler then
    reload("code.compat.recycler.explosions")
    reload("code.compat.recycler.remnants")
    reload("code.compat.recycler.recycler")
  elseif not data.raw.item.recycler or not data.raw.recipe.recycler then
    reload("code.compat.recycler.recycler")
  end

  add_category_once(data.raw.furnace and data.raw.furnace.recycler, "recycling")
end

return ensure
