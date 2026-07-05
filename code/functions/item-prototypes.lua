local item_prototypes = {}

local ITEM_PROTOTYPE_TYPES = {
  "item",
  "ammo",
  "armor",
  "capsule",
  "gun",
  "item-with-entity-data",
  "item-with-inventory",
  "item-with-label",
  "item-with-tags",
  "module",
  "rail-planner",
  "repair-tool",
  "selection-tool",
  "space-platform-starter-pack",
  "spidertron-remote",
  "tool",
}

---Returns the item-like prototype table for a recipe item name.
---@param name string|nil
---@return table|nil, string|nil
function item_prototypes.get(name)
  if not name then return nil, nil end
  for _, prototype_type in ipairs(ITEM_PROTOTYPE_TYPES) do
    local group = data.raw[prototype_type]
    if group and group[name] then return group[name], prototype_type end
  end
  return nil, nil
end

---Returns true when a recipe item name has an item-like prototype.
---@param name string|nil
---@return boolean
function item_prototypes.exists(name)
  return item_prototypes.get(name) ~= nil
end

return item_prototypes
