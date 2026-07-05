local data_table_init = require("code.data_table.init")
local material_flow = require("code.resolver.debug.material-flow")
local materials_collector = require("code.resolver.materials")
local active_ancestry = require("code.resolver.ancestry.active")
local patcher = require("code.patcher.init")
local item_prototypes = require("code.functions.item-prototypes")
local is_log = require("code.functions.is-log")
local data_table_writer = require("code.data_table.writer")

local internal = {}

local queue_phases = { "prototype", "mutate", "finalize" }
local valid_queue_phases = {
  prototype = true,
  mutate = true,
  finalize = true,
}

---Counts map entries without depending on Factorio's global table_size helper.
---@param values table|nil
---@return integer
local function map_size(values)
  local count = 0
  for _, _ in pairs(values or {}) do count = count + 1 end
  return count
end

---Returns true when a prototype required by an explicit patch exists.
---@param prototype_type string
---@param name string
---@return boolean
local function has_required_prototype(prototype_type, name)
  if prototype_type == "item" then return item_prototypes.exists(name) end
  if prototype_type == "recipe" then return data.raw.recipe and data.raw.recipe[name] ~= nil end
  if prototype_type == "fluid" then return data.raw.fluid and data.raw.fluid[name] ~= nil end
  if prototype_type == "technology" or prototype_type == "tech" then
    return data.raw.technology and data.raw.technology[name] ~= nil
  end
  local group = data.raw[prototype_type]
  return group and group[name] ~= nil or false
end

---Expands one queue requirement field into normalized prototype requirements.
---@param requirements table[]
---@param prototype_type string
---@param value string|string[]|nil
local function add_requirements(requirements, prototype_type, value)
  if type(value) == "string" then
    table.insert(requirements, { type = prototype_type, name = value })
  elseif type(value) == "table" then
    for _, name in ipairs(value) do
      if type(name) == "string" then
        table.insert(requirements, { type = prototype_type, name = name })
      end
    end
  end
end

---Returns the missing required prototypes for a queued explicit patch operation.
---@param entry table
---@return table[]
local function missing_requirements(entry)
  local details = entry and entry.details
  local explicit = entry and entry.requirements
  local requires = details and details.requires
  if type(explicit) == "table" then requires = explicit end
  if type(requires) ~= "table" then return {} end

  local requirements = {}
  add_requirements(requirements, "recipe", requires.recipe or requires.recipes)
  add_requirements(requirements, "item", requires.item or requires.items)
  add_requirements(requirements, "fluid", requires.fluid or requires.fluids)
  add_requirements(requirements, "technology", requires.technology or requires.technologies or requires.tech or requires.techs)
  for prototype_type, value in pairs(requires) do
    if prototype_type ~= "recipe"
        and prototype_type ~= "recipes"
        and prototype_type ~= "item"
        and prototype_type ~= "items"
        and prototype_type ~= "fluid"
        and prototype_type ~= "fluids"
        and prototype_type ~= "technology"
        and prototype_type ~= "technologies"
        and prototype_type ~= "tech"
        and prototype_type ~= "techs" then
      add_requirements(requirements, prototype_type, value)
    end
  end

  local missing = {}
  for _, requirement in ipairs(requirements) do
    if not has_required_prototype(requirement.type, requirement.name) then
      table.insert(missing, requirement)
    end
  end
  return missing
end

---Stores a generated prototype from a typed queue operation.
---@param data_table ISdata_table
---@param prototype_type "item"|"recipe"|"technology"
---@param prototype table
---@param source table|nil
local function set_generated_prototype(data_table, prototype_type, prototype, source)
  if prototype_type == "item" then
    data_table_writer.set_generated_item(data_table, prototype.name, prototype, source)
  elseif prototype_type == "recipe" then
    data_table_writer.set_generated_recipe(data_table, prototype.name, prototype, source)
  elseif prototype_type == "technology" then
    data_table_writer.set_generated_technology(data_table, prototype.name, prototype)
  else
    error("Ingredient Scrap queue received unsupported generated prototype type: " .. tostring(prototype_type))
  end
end

---Applies a typed public patch queue operation.
---@param context table
---@param entry table
local function apply_typed_operation(context, entry)
  local payload = entry.payload or {}
  if entry.type == "generated-item" then
    set_generated_prototype(context._data_table, "item", payload.prototype, entry.details)
  elseif entry.type == "generated-recipe" then
    set_generated_prototype(context._data_table, "recipe", payload.prototype, entry.details)
  elseif entry.type == "generated-technology" then
    set_generated_prototype(context._data_table, "technology", payload.prototype, entry.details)
  elseif entry.type == "recipe-results" then
    local recipe_name = payload.recipe_name
    if type(recipe_name) ~= "string" or recipe_name == "" then
      error("Ingredient Scrap recipe-results queue operation requires recipe_name")
    end
    local insert = data_table_writer.recipe_insert(context._data_table, recipe_name)
    if payload.main_product ~= nil then insert.main_product = payload.main_product end
    if payload.replace == true then insert.results = {} end
    insert.results = insert.results or {}
    for _, result in ipairs(payload.results or {}) do
      table.insert(insert.results, result)
    end
  elseif entry.type == "machine-category" then
    local group = data.raw[payload.prototype_type or ""]
    local machine = group and group[payload.name]
    if machine and payload.category then
      machine.crafting_categories = machine.crafting_categories or {}
      for _, category in ipairs(machine.crafting_categories) do
        if category == payload.category then return end
      end
      table.insert(machine.crafting_categories, payload.category)
    end
  elseif entry.type == "unlock-recipe" then
    local tech = data.raw.technology and data.raw.technology[payload.technology]
    if tech and payload.recipe then
      tech.effects = tech.effects or {}
      for _, effect in ipairs(tech.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == payload.recipe then return end
      end
      table.insert(tech.effects, { type = "unlock-recipe", recipe = payload.recipe })
    end
  else
    error("Ingredient Scrap queue operation has unsupported type: " .. tostring(entry.type))
  end
end

---Creates the internal Ingredient Scrap API context that owns the private data table.
---@param material_overrides table
---@return table
function internal.create(material_overrides)
  local context = {
    _data_table = data_table_init.create(material_overrides),
    _queues = {
      prototype = {},
      mutate = {},
      finalize = {},
    },
    _queue_history = {},
    _registration_index = 0,
  }

  ---Returns the private data table for modules that are still inside the trusted core.
  ---New code should prefer narrower context methods when one exists.
  ---@return ISdata_table
  function context:data_table()
    return self._data_table
  end

  ---Returns the private data table for debug/test dump generation.
  ---@return ISdata_table
  function context:debug_data_table()
    return self._data_table
  end

  ---Adds an internal post-resolver operation to one FIFO patch queue phase.
  ---@param phase "prototype"|"mutate"|"finalize"
  ---@param label string
  ---@param handler function
  ---@param details table|nil
  function context:enqueue_internal(phase, label, handler, details)
    if not valid_queue_phases[phase] then
      error("Ingredient Scrap internal queue entry '" .. tostring(label) .. "' has invalid phase: " .. tostring(phase))
    end
    if type(label) ~= "string" or label == "" then
      error("Ingredient Scrap internal queue entry requires a non-empty label")
    end
    if type(handler) ~= "function" then
      error("Ingredient Scrap internal queue entry '" .. label .. "' requires a function handler")
    end
    self._registration_index = self._registration_index + 1
    table.insert(self._queues[phase], {
      label = label,
      phase = phase,
      type = "internal-handler",
      handler = handler,
      details = details,
      requirements = details and details.requires or nil,
      source = details and details.source or nil,
      registration_index = self._registration_index,
    })
  end

  ---Adds a typed public operation to one FIFO patch queue phase.
  ---@param phase "prototype"|"mutate"
  ---@param operation_type string
  ---@param payload table
  function context:enqueue_operation(phase, operation_type, payload)
    if phase == "finalize" then
      error("Ingredient Scrap finalize queue is internal only")
    end
    if not valid_queue_phases[phase] then
      error("Ingredient Scrap queue operation has invalid phase: " .. tostring(phase))
    end
    if type(operation_type) ~= "string" or operation_type == "" then
      error("Ingredient Scrap queue operation requires a non-empty type")
    end
    payload = payload or {}
    local label = payload.label or operation_type
    if type(label) ~= "string" or label == "" then
      error("Ingredient Scrap queue operation requires a non-empty label")
    end

    self._registration_index = self._registration_index + 1
    table.insert(self._queues[phase], {
      label = label,
      phase = phase,
      type = operation_type,
      payload = payload,
      details = payload.details,
      requirements = payload.requirements or payload.requires,
      source = payload.source,
      registration_index = self._registration_index,
    })
  end

  ---Runs queued post-resolver operations in strict FIFO order.
  ---@return table[]
  function context:drain_queue()
    for _, phase in ipairs(queue_phases) do
      local queue = self._queues[phase]
      while queue[1] do
        local entry = table.remove(queue, 1)
        local missing = missing_requirements(entry)
        if missing[1] then
          is_log.write(
            "api.queue",
            "info",
            "skip-missing-prototype",
            "Skipped explicit patch because a required prototype does not exist.",
            { label = entry.label, phase = entry.phase, type = entry.type, missing = missing, details = entry.details }
          )
        elseif entry.handler then
          entry.handler(self)
        else
          apply_typed_operation(self, entry)
        end
        table.insert(self._queue_history, {
          label = entry.label,
          phase = entry.phase,
          type = entry.type,
          source = entry.source,
          details = entry.details,
          requirements = entry.requirements,
          skipped = missing[1] ~= nil,
          missing = missing[1] and missing or nil,
          registration_index = entry.registration_index,
          index = #self._queue_history + 1,
        })
      end
    end
    self._data_table.debug = self._data_table.debug or {}
    self._data_table.debug.patch_queue = {
      schema = "ingredient-scrap-patch-queue/v2",
      mode = "phase-fifo",
      phases = queue_phases,
      history = self._queue_history,
    }
    return self._queue_history
  end

  ---Collects enabled materials into the internal data table.
  ---@return table
  function context:collect_materials()
    materials_collector.collect(self._data_table)
    return self._data_table.materials
  end

  ---Applies the active ancestry lookup resolver.
  ---@param policy table|nil
  ---@return table
  function context:apply_ancestry(policy)
    local production_flow_dump = material_flow.build_production_flow()
    local material_flow_dump = material_flow.build(self._data_table)
    local report = active_ancestry.apply(self._data_table, material_flow_dump, production_flow_dump, policy or {})
    self._data_table.debug = self._data_table.debug or {}
    self._data_table.debug.resolver = self._data_table.debug.resolver or {
      schema = "ingredient-scrap-resolver/v2",
      active_only = true,
    }
    self._data_table.debug.resolver.active = {
      schema = "ingredient-scrap-resolver-active/v2",
      skipped = false,
      mode = report.mode,
      root_policy = report.root_policy,
      mixed_limit = report.mixed_limit,
      max_depth = report.max_depth,
      summary = report.summary,
    }
    return report
  end

  ---Patches recycle input amounts from collected source outputs.
  function context:patch_recycle_amounts()
    patcher.patch_recycle_amounts(self._data_table)
  end

  ---Validates generated prototypes before registration.
  ---@return table
  function context:validate_generated_prototypes()
    return patcher.validate_generated_prototypes(self._data_table)
  end

  ---Applies generated prototypes and source inserts to data.raw.
  function context:patch()
    patcher.patch(self._data_table)
  end

  ---Returns generated item prototypes staged by Ingredient Scrap.
  ---@return table
  function context:generated_items()
    return self._data_table.prototypes.items
  end

  ---Returns generated recipe prototypes staged by Ingredient Scrap.
  ---@return table
  function context:generated_recipes()
    return self._data_table.prototypes.recipes
  end

  ---Returns generated technology prototypes staged by Ingredient Scrap.
  ---@return table
  function context:generated_technologies()
    return self._data_table.prototypes.technology
  end

  ---Returns generated fluid targets inferred from generated recipe sources.
  ---@return table
  function context:generated_fluids()
    local fluids = {}
    local sources = self._data_table.debug
      and self._data_table.debug.sources
      and self._data_table.debug.sources.recipes
      or {}

    for _, source in pairs(sources) do
      if source.result_type == "fluid" and source.result_name then
        fluids[source.result_name] = data.raw.fluid[source.result_name] or true
      end
    end

    return fluids
  end

  ---Returns a compact count of all staged generated prototypes.
  ---@return integer
  function context:generated_prototype_count()
    return map_size(self._data_table.prototypes.items)
      + map_size(self._data_table.prototypes.recipes)
      + map_size(self._data_table.prototypes.technology)
  end

  return context
end

return internal
