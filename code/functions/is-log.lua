local is_log = {}

---Returns a mod-data and JSON friendly copy of a log detail value.
---@param value any
---@param depth integer
---@param seen table
---@return any
local function sanitize_log_value(value, depth, seen)
  local value_type = type(value)
  if value == nil or value_type == "string" or value_type == "number" or value_type == "boolean" then
    return value
  end
  if value_type ~= "table" then
    return tostring(value)
  end
  if depth <= 0 then
    return "<max-depth>"
  end
  if seen[value] then
    return "<cycle>"
  end

  seen[value] = true
  local out = {}
  local count = 0
  for key, item in pairs(value) do
    count = count + 1
    if count > 50 then
      out["..."] = "<truncated>"
      break
    end

    local safe_key = key
    local key_type = type(key)
    if key_type ~= "string" and key_type ~= "number" then
      safe_key = tostring(key)
    end
    out[safe_key] = sanitize_log_value(item, depth - 1, seen)
  end
  seen[value] = nil
  return out
end

---Adds a structured Ingredient Scrap log entry and writes a concise Factorio log message.
---@param source string
---@param level string
---@param step string
---@param description string
---@param details? any
function is_log.write(source, level, step, description, details)
  local context = yokmods and yokmods.ingredient_scrap and yokmods.ingredient_scrap.internal
  local data_table = context and context.debug_data_table and context:debug_data_table()
    or (yokmods and yokmods.ingredient_scrap and yokmods.ingredient_scrap.data_table)
  if data_table then
    data_table.debug = data_table.debug or {}
    data_table.debug.logs = data_table.debug.logs or {}
  end

  local entry = {
    source = tostring(source or "unknown"),
    level = tostring(level or "info"),
    step = tostring(step or "unknown"),
    description = tostring(description or ""),
    details = details ~= nil and sanitize_log_value(details, 4, {}) or nil,
  }

  if data_table and data_table.debug and data_table.debug.logs then
    table.insert(data_table.debug.logs, entry)
  end

  local message = "[IS][" .. entry.level .. "][" .. entry.source .. "][" .. entry.step .. "] " .. entry.description
  if IS_DEBUG and entry.details ~= nil and serpent then
    local ok, rendered = pcall(serpent.line, entry.details, { comment = false, nocode = true })
    if ok and rendered then
      message = message .. " " .. rendered
    end
  end

  if log and (not ISsettings or ISsettings.shallow_log ~= false) then
    log(message)
  end
end

return is_log
