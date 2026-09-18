local result = require("__Ingredient_Scrap__/code/migrations/normalize-scrap-quality").run()
local lines = assert(storage.migration_test_lines)
assert(result.items == 59 + #lines, "Expected legacy stock from saved test world")
local inventory = assert(storage.migration_test_chest, "Migrated test chest missing")
assert(inventory.valid and inventory[1].count == 17 and inventory[1].quality.name == "normal")
for _, check in ipairs(lines) do
  local contents = check.line.get_detailed_contents()
  assert(#contents == 1 and contents[1].stack.count == 1
    and contents[1].stack.quality.name == "normal" and contents[1].position == check.position,
    "Saved transport migration failed: " .. check.label)
end
local other = assert(storage.migration_test_other_inventory)
assert(other[1].count == 23 and other[1].quality.name == "normal")
assert(other[2].count == 19 and other[2].quality.name == "normal")
assert(require("__Ingredient_Scrap__/code/migrations/normalize-scrap-quality").run().items == 0)
log("IS-MIGRATION-LOAD PASS")
