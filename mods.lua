local _types = {}
local _results = {}

if (mods['Molten_Metals']) then
  table.extend(_results, {"ingot"})
end
if (mods['Krastorio2']) then
  table.extend(_types, {"imersium"})
  table.extend(_results, {"beam"})
end
if (mods['angelssmelting']) then
  table.extend(_results, {"ingot"})
end
if (mods['bztitanium']) then
  table.extend(_types, {"titanium"})
end
if (mods['bztungsten']) then
  table.extend(_types, {"tungsten"})
end
if (mods['bzlead']) then
  table.extend(_types, {"lead"})
end
if (mods["bobplates"]) then
  table.extend(_types, {"lead", "titanium", "zinc", "nickel", "aluminium", "copper-tungsten", "tungsten", "tin", "silver", "gold",
  "brass", "bronze", "nitinol", "invar", "cobalt-steel", "cobalt", --[["glass", "silicon",]] "gunmetal" })
  table.extend(_results, {"plate", "alloy", "gear-wheel", "bearing"})

  -- local tech = { {"cobalt","cobalt"}, {"cobalt-steel","cobalt"}, {"nitinol", "nitinol"},
  --   {"silver", "lead"}, {"zinc", "zinc"}, {"brass", "zinc"}, {"gunmetal", "zinc"}} -- the bad batch
  -- for _, name in ipairs(tech) do
  --   data.raw.recipe["recycle-"..name[1].."-scrap"] = {enabled = false}
  --   table.insert( data.raw.technology[name[2].."-processing"].effects, { recipe = "recycle-"..name[1].."-scrap", type = "unlock-recipe" } )
  -- end
end

return {_types, _results}