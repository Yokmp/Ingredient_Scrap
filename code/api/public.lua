local public = {}

---Returns a JSON/mod-data friendly deep copy.
---@param value any
---@param seen table|nil
---@return any
local function deep_copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local copy = {}
  seen[value] = copy
  for key, item in pairs(value) do
    copy[deep_copy(key, seen)] = deep_copy(item, seen)
  end
  return copy
end

---Loads public API modules that publish functions under yokmods.ingredient_scrap.api.
---@return table
function public.load()
  yokmods = yokmods or {}
  yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}

  return {
    materials = require("code.override.materials"),
    sources = require("code.override.sources"),
    categories = require("code.override.categories"),
    recipe_chain = require("code.override.recipe-chain"),
  }
end

---Publishes generated prototype accessors backed by the internal API context.
---@param context table
function public.publish_generated(context)
  yokmods = yokmods or {}
  yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.generated = api.generated or {}

  api.generated.items = function()
    return deep_copy(context:generated_items())
  end

  api.generated.recipes = function()
    return deep_copy(context:generated_recipes())
  end

  api.generated.technologies = function()
    return deep_copy(context:generated_technologies())
  end
  api.generated.techs = api.generated.technologies

  api.generated.fluids = function()
    return deep_copy(context:generated_fluids())
  end
end

---Publishes the public typed FIFO patch queue registration API.
---@param context table
function public.publish_queue(context)
  yokmods = yokmods or {}
  yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.queue = api.queue or {}
  api.queue.patch = nil
  api.queue.prototype = api.queue.prototype or {}
  api.queue.mutate = api.queue.mutate or {}

  api.queue.prototype.item = function(label, prototype, options)
    options = options or {}
    context:enqueue_operation("prototype", "generated-item", {
      label = label,
      prototype = prototype,
      source = options.source,
      requirements = options.requirements or options.requires,
      details = options.details,
    })
  end

  api.queue.prototype.recipe = function(label, prototype, options)
    options = options or {}
    context:enqueue_operation("prototype", "generated-recipe", {
      label = label,
      prototype = prototype,
      source = options.source,
      requirements = options.requirements or options.requires,
      details = options.details,
    })
  end

  api.queue.prototype.technology = function(label, prototype, options)
    options = options or {}
    context:enqueue_operation("prototype", "generated-technology", {
      label = label,
      prototype = prototype,
      source = options.source,
      requirements = options.requirements or options.requires,
      details = options.details,
    })
  end
  api.queue.prototype.tech = api.queue.prototype.technology

  api.queue.mutate.recipe_results = function(label, recipe_name, results, options)
    options = options or {}
    context:enqueue_operation("mutate", "recipe-results", {
      label = label,
      recipe_name = recipe_name,
      results = results or {},
      replace = options.replace == true,
      main_product = options.main_product,
      source = options.source,
      requirements = options.requirements or options.requires or { recipe = recipe_name },
      details = options.details,
    })
  end

  api.queue.mutate.machine_category = function(label, prototype_type, name, category, options)
    options = options or {}
    context:enqueue_operation("mutate", "machine-category", {
      label = label,
      prototype_type = prototype_type,
      name = name,
      category = category,
      source = options.source,
      requirements = options.requirements or options.requires or { [prototype_type] = name },
      details = options.details,
    })
  end

  api.queue.mutate.unlock_recipe = function(label, technology, recipe, options)
    options = options or {}
    context:enqueue_operation("mutate", "unlock-recipe", {
      label = label,
      technology = technology,
      recipe = recipe,
      source = options.source,
      requirements = options.requirements or options.requires or { technology = technology, recipe = recipe },
      details = options.details,
    })
  end
end

return public
