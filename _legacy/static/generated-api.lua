local generated_api = {}

---Publishes read/write accessors for generated prototype staging tables.
---@param data_table ISdata_table
function generated_api.publish(data_table)
  yokmods.ingredient_scrap.api = yokmods.ingredient_scrap.api or {}
  local api = yokmods.ingredient_scrap.api
  api.generated = api.generated or {}

  api.generated.items = function()
    return data_table.prototypes.items
  end

  api.generated.recipes = function()
    return data_table.prototypes.recipes
  end

  api.generated.technologies = function()
    return data_table.prototypes.technology
  end
  api.generated.techs = api.generated.technologies

  api.generated.fluids = function()
    local fluids = {}
    local sources = data_table.debug
      and data_table.debug.sources
      and data_table.debug.sources.recipes
      or {}

    for _, source in pairs(sources) do
      if source.result_type == "fluid" and source.result_name then
        fluids[source.result_name] = data.raw.fluid[source.result_name] or true
      end
    end

    return fluids
  end
end

return generated_api
