local report_name = "ingredient-scrap-test-report"
local report_path = "Ingredient_Scrap/test-report.json"
local data_table_dump_name = "ingredient-scrap-data-table-dump"

---Writes debug report and data table dumps from mod-data into script-output.
local function write_debug_files()
  if not prototypes or not prototypes.mod_data then return end

  local report = prototypes.mod_data[report_name]
  if report and report.data then
    helpers.write_file(report_path, helpers.table_to_json(report.data), false)
    log("[IS-TEST] Wrote " .. report_path)
  end

  local dump = prototypes.mod_data[data_table_dump_name]
  if dump and dump.data and dump.data.filename and dump.data.contents then
    helpers.write_file(dump.data.filename, dump.data.contents, false)
    log("[IS-TEST] Wrote " .. dump.data.filename)
  end
end

script.on_init(write_debug_files)
script.on_configuration_changed(write_debug_files)
