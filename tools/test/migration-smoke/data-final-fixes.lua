-- Recreate old output permissions so a machine can hold legacy-quality scrap.
for _, result in pairs(data.raw.recipe["iron-gear-wheel"].results) do
  if result.name == "yis-iron-scrap" then
    result.quality_min = nil
    result.quality_max = nil
    result.quality_change = nil
    result.affected_by_quality = nil
  end
end
