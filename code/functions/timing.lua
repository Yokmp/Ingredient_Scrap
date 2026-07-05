--#region debug
yokmods = yokmods or {}
yokmods.ingredient_scrap = yokmods.ingredient_scrap or {}

local timing = {}

local start_time = nil
local last_time = nil

---Returns the current CPU clock time, or 0 when the host does not expose it.
---@return number
local function now()
  if os and os.clock then
    local ok, value = pcall(os.clock)
    if ok and type(value) == "number" then return value end
  end
  return 0
end

---Returns true when shallow timing should be written to factorio-current.log.
---@return boolean
local function should_log()
  if IS_DEBUG == true then return true end
  if settings and settings.startup and settings.startup["yis-shallow-log"] then
    return settings.startup["yis-shallow-log"].value ~= false
  end
  local mod_settings = yokmods.ingredient_scrap.settings
  return not mod_settings or mod_settings.shallow_log ~= false
end

---Formats seconds as a compact millisecond string.
---@param seconds number
---@return string
local function format_ms(seconds)
  return string.format("%.1fms", seconds * 1000)
end

---Initializes the timing state on first use.
local function ensure_started()
  if start_time then return end
  start_time = now()
  last_time = start_time
  yokmods.ingredient_scrap.performance = yokmods.ingredient_scrap.performance or {
    started_at = start_time,
    steps = {},
  }
end

---Records a load timing checkpoint and optionally writes it to the Factorio log.
---@param stage string
---@param step string
---@param details? table
function timing.mark(stage, step, details)
  ensure_started()
  local current = now()
  local delta = current - last_time
  local total = current - start_time
  last_time = current

  local entry = {
    stage = tostring(stage or "unknown"),
    step = tostring(step or "unknown"),
    delta = delta,
    total = total,
    details = details,
  }

  local performance = yokmods.ingredient_scrap.performance
  if performance and performance.steps then
    table.insert(performance.steps, entry)
  end

  if log and should_log() then
    local message = "[IS][time][" .. entry.stage .. "][" .. entry.step .. "]"
    if current ~= 0 or start_time ~= 0 then
      message = message .. " +" .. format_ms(delta) .. " total=" .. format_ms(total)
    else
      message = message .. " marker"
    end
    if details and details.count ~= nil then
      message = message .. " count=" .. tostring(details.count)
    end
    log(message)
  end
end

---Returns all recorded timing entries.
---@return table
function timing.steps()
  ensure_started()
  return yokmods.ingredient_scrap.performance.steps
end

return timing
--#endregion
