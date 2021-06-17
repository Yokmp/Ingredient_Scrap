
local _types = {}
local _results = {}

function table.extend(t1, t2)
  for i = 1, #t2 do t1[#t1+1] = t2[i] end
end


if (mods['Krastorio2']) then
  table.insert(_types, "imersium")
  table.insert(_results, "beam")
end
if (mods['bztitanium']) then
  table.insert(_types, "titanium")
end
if (mods['bztungsten']) then
  table.insert(_types, "tungsten")
end

return {_types, _results}