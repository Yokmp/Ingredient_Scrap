# Recipe Form Classification Review

Generated from `_legacy/weighted/dumps/_comparisons/recipe-forms-comparison.json`.

| Mod profile | Roots | First | Named | Components | Multi | Possible alloy | Placeable | Unresolved rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| is_sa | 12 | 10 | 3 | 40 | 21 | 0 | 139 | 110 |
| krastorio_is | 14 | 19 | 5 | 73 | 35 | 0 | 277 | 192 |
| bobs_full_is | 29 | 23 | 13 | 119 | 35 | 2 | 318 | 167 |
| angels_full_is | 15 | 16 | 6 | 78 | 25 | 0 | 291 | 1143 |
| bob_angels_full_is | 15 | 21 | 15 | 140 | 33 | 2 | 463 | 1261 |

## Interpretation

- `named_material_product` is now mostly material-line output such as ores, plates, and explicit alloy families. Exact component families (`gear`, `pipe`, `cable`, `bearing`, `board`, `battery`) are classified as `component_candidate` instead.
- `possible_alloy` is intentionally very narrow. Generic smelting/metallurgy categories are no longer enough; the result or recipe must name an alloy/solder-style family.
- `multi_material_product` contains broad assembled products and process outputs. These are not alloy decisions by themselves; they are candidates for mixed scrap, preserve-shape, or later component-chain rules.
- Large Angels unresolved counts are mostly process, chemistry, biology, and non-item/fluid chains. They should not be solved by widening alloy detection.

## Likely Decisions

- Treat `named_material_product` as stable material-family evidence when the material is not an exact component family.
- Treat `possible_alloy` as manual/API review input. Current likely true positives are Bob solder alloy recipes; cobalt oxide and lithium-cobalt oxide look more like chemistry/process materials.
- Keep `multi_material_product` passive for now. It is the future input for mixed scrap or preserve-shape, not a direct alloy signal.

## possible_alloy

### is_sa (0)

### krastorio_is (0)

### bobs_full_is (3)
- `bob-solder` <- `bob-solder`; reason `material-plus-alloy`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-solder-alloy` <- `bob-solder-alloy`; reason `multiple-material-sources`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-solder-alloy` <- `bob-solder-alloy-lead`; reason `multiple-material-sources`; materials `{"lead": 1, "tin": 1}`

### angels_full_is (0)

### bob_angels_full_is (3)
- `bob-solder` <- `bob-solder`; reason `material-plus-alloy`; materials `{"copper": 1, "tin": 1}`
- `bob-solder-alloy` <- `bob-solder-alloy`; reason `multiple-material-sources`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-solder-alloy` <- `bob-solder-alloy-lead`; reason `multiple-material-sources`; materials `{"lead": 1, "tin": 1}`


## named_material_product

### is_sa (5)
- `plastic-bar` <- `plastic-bar`; reason `result-name-material`; materials `{"plastic": 1}`
- `steel-plate` <- `steel-plate`; reason `result-name-material`; materials `{"steel": 1}`
- `tungsten-plate` <- `tungsten-plate`; reason `result-name-material`; materials `{"tungsten": 1}`
- `uranium-235` <- `kovarex-enrichment-process`; reason `result-name-material`; materials `{"uranium": 1}`
- `uranium-238` <- `kovarex-enrichment-process`; reason `result-name-material`; materials `{"uranium": 1}`

### krastorio_is (8)
- `kr-glass` <- `kr-glass`; reason `result-name-material`; materials `{"glass": 1}`
- `kr-imersium-beam` <- `kr-easy-imersium-beam`; reason `result-name-material`; materials `{"imersium": 1}`
- `kr-imersium-gear-wheel` <- `kr-easy-imersium-gear-wheel`; reason `result-name-material`; materials `{"imersium": 1}`
- `kr-imersium-plate` <- `kr-imersium-plate`; reason `result-name-material`; materials `{"imersium": 1}`
- `plastic-bar` <- `plastic-bar`; reason `result-name-material`; materials `{"plastic": 1}`
- `steel-plate` <- `steel-plate`; reason `result-name-material`; materials `{"steel": 1}`
- `tungsten-plate` <- `tungsten-plate`; reason `result-name-material`; materials `{"tungsten": 1}`
- `uranium-235` <- `kovarex-enrichment-process`; reason `result-name-material`; materials `{"uranium": 1}`

### bobs_full_is (21)
- `bob-brass-alloy` <- `bob-brass-alloy`; reason `result-name-material`; materials `{"brass": 1}`
- `bob-bronze-alloy` <- `bob-bronze-alloy`; reason `result-name-material`; materials `{"bronze": 1}`
- `bob-cobalt-steel-alloy` <- `bob-cobalt-steel-alloy`; reason `result-name-material`; materials `{"cobalt-steel": 1}`
- `bob-gold-plate` <- `bob-gold-plate`; reason `result-name-material`; materials `{"gold": 1}`
- `bob-gunmetal-alloy` <- `bob-gunmetal-alloy`; reason `result-name-material`; materials `{"gunmetal": 1}`
- `bob-invar-alloy` <- `bob-invar-alloy`; reason `result-name-material`; materials `{"invar": 1}`
- `bob-lead-plate` <- `bob-silver-from-lead`; reason `result-name-material`; materials `{"lead": 1}`
- `bob-nickel-plate` <- `bob-nickel-plate`; reason `result-name-material`; materials `{"nickel": 1}`
- `bob-nitinol-alloy` <- `bob-nitinol-alloy`; reason `result-name-material`; materials `{"nitinol": 1}`
- `bob-silicon-plate` <- `bob-silicon-plate`; reason `result-name-material`; materials `{"silicon": 1}`
- `bob-silver-ore` <- `bob-silver-from-lead`; reason `result-name-material`; materials `{"silver": 1}`
- `bob-titanium-plate` <- `bob-titanium-plate`; reason `result-name-material`; materials `{"titanium": 1}`
- `bob-zinc-plate` <- `bob-zinc-plate`; reason `result-name-material`; materials `{"zinc": 1}`
- `copper-plate` <- `bob-cobalt-oxide-from-copper`; reason `result-name-material`; materials `{"copper": 1}`
- `plastic-bar` <- `plastic-bar`; reason `result-name-material`; materials `{"plastic": 1}`
- `steel-plate` <- `steel-plate`; reason `result-name-material`; materials `{"steel": 1}`
- `uranium-235` <- `bob-plutonium-nucleosynthesis`; reason `result-name-material`; materials `{"uranium": 1}`
- `uranium-235` <- `kovarex-enrichment-process`; reason `result-name-material`; materials `{"uranium": 1}`
- `uranium-238` <- `bob-plutonium-nucleosynthesis`; reason `result-name-material`; materials `{"uranium": 1}`
- `uranium-238` <- `bobingabout-enrichment-process`; reason `result-name-material`; materials `{"uranium": 1}`
- `uranium-238` <- `kovarex-enrichment-process`; reason `result-name-material`; materials `{"uranium": 1}`

### angels_full_is (16)
- `angels-nickel-ore` <- `angels-ore5-crushed-processing`; reason `result-name-material`; materials `{"angels-nickel": 1}`
- `copper-ore` <- `angels-ore-crushed-mix2-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore1-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore2-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore3-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore4-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-plate` <- `copper-plate`; reason `result-name-material`; materials `{"copper": 1}`
- `iron-ore` <- `angels-ore-crushed-mix1-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore1-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore2-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore3-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore4-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-plate` <- `iron-plate`; reason `result-name-material`; materials `{"iron": 1}`
- `plastic-bar` <- `plastic-bar`; reason `result-name-material`; materials `{"plastic": 1}`
- `steel-plate` <- `steel-plate`; reason `result-name-material`; materials `{"steel": 1}`
- `tungsten-plate` <- `tungsten-plate`; reason `result-name-material`; materials `{"tungsten": 1}`

### bob_angels_full_is (29)
- `bob-brass-alloy` <- `bob-brass-alloy`; reason `result-name-material`; materials `{"brass": 1}`
- `bob-bronze-alloy` <- `bob-bronze-alloy`; reason `result-name-material`; materials `{"bronze": 1}`
- `bob-cobalt-steel-alloy` <- `bob-cobalt-steel-alloy`; reason `result-name-material`; materials `{"cobalt-steel": 1}`
- `bob-gunmetal-alloy` <- `bob-gunmetal-alloy`; reason `result-name-material`; materials `{"gunmetal": 1}`
- `bob-invar-alloy` <- `bob-invar-alloy`; reason `result-name-material`; materials `{"invar": 1}`
- `bob-lead-ore` <- `angels-ore-crushed-mix3-processing`; reason `result-name-material`; materials `{"lead": 1}`
- `bob-lead-ore` <- `angels-ore5-crushed-processing`; reason `result-name-material`; materials `{"lead": 1}`
- `bob-lead-plate` <- `bob-silver-from-lead`; reason `result-name-material`; materials `{"lead": 1}`
- `bob-nickel-ore` <- `angels-ore5-crushed-processing`; reason `result-name-material`; materials `{"nickel": 1}`
- `bob-nickel-plate` <- `bob-nickel-plate`; reason `result-name-material`; materials `{"nickel": 1}`
- `bob-nitinol-alloy` <- `bob-nitinol-alloy`; reason `result-name-material`; materials `{"nitinol": 1}`
- `bob-silver-ore` <- `bob-silver-from-lead`; reason `result-name-material`; materials `{"silver": 1}`
- `bob-tin-ore` <- `angels-ore-crushed-mix4-processing`; reason `result-name-material`; materials `{"tin": 1}`
- `bob-tin-ore` <- `angels-ore6-crushed-processing`; reason `result-name-material`; materials `{"tin": 1}`
- `copper-ore` <- `angels-ore-crushed-mix2-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore1-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore2-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore3-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-ore` <- `angels-ore4-crushed-processing`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-plate` <- `bob-cobalt-oxide-from-copper`; reason `result-name-material`; materials `{"copper": 1}`
- `copper-plate` <- `copper-plate`; reason `result-name-material`; materials `{"copper": 1}`
- `iron-ore` <- `angels-ore-crushed-mix1-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore1-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore2-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`
- `iron-ore` <- `angels-ore3-crushed-processing`; reason `result-name-material`; materials `{"iron": 1}`


## multi_material_product

### is_sa (21)
- `artillery-shell` <- `artillery-shell`; reason `non-metallurgical-multiple-materials`; materials `{"calcite": 1, "tungsten": 1}`
- `battery` <- `battery`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `cannon-shell` <- `cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `car` <- `car`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `cargo-wagon` <- `cargo-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `combat-shotgun` <- `combat-shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `explosive-cannon-shell` <- `explosive-cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `grenade` <- `grenade`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "iron": 1}`
- `heavy-armor` <- `heavy-armor`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `low-density-structure` <- `low-density-structure`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "plastic": 1, "steel": 1}`
- `piercing-rounds-magazine` <- `piercing-rounds-magazine`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `piercing-shotgun-shell` <- `piercing-shotgun-shell`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `pistol` <- `pistol`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `poison-capsule` <- `poison-capsule`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "steel": 1}`
- `rail` <- `rail`; reason `non-metallurgical-multiple-materials`; materials `{"steel": 1, "stone": 1}`
- `shotgun` <- `shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `shotgun-shell` <- `shotgun-shell`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `slowdown-capsule` <- `slowdown-capsule`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "steel": 1}`
- `submachine-gun` <- `submachine-gun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `superconductor` <- `superconductor`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "plastic": 1}`
- `uranium-fuel-cell` <- `uranium-fuel-cell`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "uranium": 2}`

### krastorio_is (37)
- `artillery-shell` <- `artillery-shell`; reason `non-metallurgical-multiple-materials`; materials `{"calcite": 1, "tungsten": 1}`
- `artillery-wagon` <- `artillery-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"rare-metal": 1, "steel": 1}`
- `battery` <- `battery`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `cannon-shell` <- `cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `car` <- `car`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `combat-shotgun` <- `combat-shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1, "steel": 1}`
- `electronic-circuit` <- `electronic-circuit`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `explosive-cannon-shell` <- `explosive-cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `firearm-magazine` <- `firearm-magazine`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "iron": 1}`
- `flamethrower` <- `flamethrower`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `fluid-wagon` <- `fluid-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `grenade` <- `grenade`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "iron": 1}`
- `kr-advanced-tank` <- `kr-advanced-tank`; reason `non-metallurgical-multiple-materials`; materials `{"imersium": 2, "rare-metal": 1}`
- `kr-anti-materiel-rifle-magazine` <- `kr-anti-materiel-rifle-magazine`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "copper": 1, "iron": 1}`
- `kr-automation-core` <- `kr-automation-core`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 2}`
- `kr-blank-tech-card` <- `kr-blank-tech-card`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `kr-electronic-components` <- `kr-easy-electronic-components`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "stone": 1}`
- `kr-electronic-components` <- `kr-electronic-components`; reason `non-metallurgical-multiple-materials`; materials `{"glass": 1, "plastic": 1}`
- `kr-electronic-components` <- `kr-electronic-components-with-lithium`; reason `non-metallurgical-multiple-materials`; materials `{"glass": 1, "plastic": 1}`
- `kr-heavy-rocket` <- `kr-heavy-rocket`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `kr-matter-research-data` <- `kr-matter-research-data`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "rare-metal": 1}`
- `kr-nuclear-artillery-shell` <- `kr-nuclear-artillery-shell`; reason `non-metallurgical-multiple-materials`; materials `{"steel": 1, "uranium": 1}`
- `kr-nuclear-turret-rocket` <- `kr-nuclear-turret-rocket`; reason `non-metallurgical-multiple-materials`; materials `{"steel": 1, "uranium": 1}`
- `kr-pollution-filter` <- `kr-pollution-filter`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `kr-rifle-magazine` <- `kr-rifle-magazine`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "copper": 1, "iron": 1}`

### bobs_full_is (36)
- `bob-armoured-cargo-wagon` <- `bob-armoured-cargo-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"cobalt-steel": 1, "gunmetal": 1}`
- `bob-armoured-fluid-wagon` <- `bob-armoured-fluid-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"cobalt-steel": 1, "gunmetal": 1}`
- `bob-armoured-locomotive` <- `bob-armoured-locomotive`; reason `non-metallurgical-multiple-materials`; materials `{"cobalt-steel": 1, "gunmetal": 1}`
- `bob-circuit-board` <- `bob-circuit-board`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "tin": 1}`
- `bob-cobalt-oxide` <- `bob-cobalt-oxide`; reason `non-metallurgical-multiple-materials`; materials `{"cobalt": 1, "stone": 1}`
- `bob-cobalt-oxide` <- `bob-cobalt-oxide-from-copper`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "stone": 1}`
- `bob-electronic-components` <- `bob-electronic-components`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "silicon": 1}`
- `bob-empty-canister` <- `bob-empty-canister`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "plastic": 1}`
- `bob-empty-nuclear-fuel-cell` <- `bob-empty-nuclear-fuel-cell`; reason `non-metallurgical-multiple-materials`; materials `{"lead": 1, "steel": 1}`
- `bob-fibreglass-board` <- `bob-fibreglass-board`; reason `non-metallurgical-multiple-materials`; materials `{"bob-quartz": 1, "plastic": 1}`
- `bob-integrated-electronics` <- `bob-integrated-electronics`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "silicon": 1}`
- `bob-multi-layer-circuit-board` <- `bob-multi-layer-circuit-board`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "gold": 1}`
- `bob-roboport-antenna-4` <- `bob-roboport-antenna-4`; reason `non-metallurgical-multiple-materials`; materials `{"gold": 1, "nitinol": 1}`
- `bob-robot-brain` <- `bob-robot-brain`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-robot-brain-2` <- `bob-robot-brain-2`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-robot-brain-3` <- `bob-robot-brain-3`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-robot-brain-4` <- `bob-robot-brain-4`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "silver": 1, "tin": 1}`
- `bob-superior-circuit-board` <- `bob-superior-circuit-board`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "silver": 1}`
- `bob-thorium-fuel-cell` <- `bob-thorium-fuel-cell`; reason `non-metallurgical-multiple-materials`; materials `{"bob-thorium": 1, "uranium": 1}`
- `cannon-shell` <- `cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `car` <- `car`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `combat-shotgun` <- `combat-shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `explosive-cannon-shell` <- `explosive-cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `grenade` <- `grenade`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "iron": 1}`
- `heavy-armor` <- `heavy-armor`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`

### angels_full_is (26)
- `angels-catalyst-metal-red` <- `angels-catalyst-metal-red`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `angels-filter-frame` <- `angels-filter-frame`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `angels-ore8-crushed` <- `angels-ore8-crushed`; reason `non-metallurgical-multiple-materials`; materials `{"angels-ore1": 1, "angels-ore2": 1, "angels-ore5": 1}`
- `angels-ore9-crushed` <- `angels-ore9-crushed`; reason `non-metallurgical-multiple-materials`; materials `{"angels-ore3": 1, "angels-ore4": 1, "angels-ore6": 1}`
- `angels-void` <- `angels-ore-crushed-mix3-processing`; reason `non-metallurgical-multiple-materials`; materials `{"angels-ore4": 1, "angels-ore5": 1}`
- `angels-void` <- `angels-ore-crushed-mix4-processing`; reason `non-metallurgical-multiple-materials`; materials `{"angels-ore3": 1, "angels-ore6": 1}`
- `artillery-shell` <- `artillery-shell`; reason `non-metallurgical-multiple-materials`; materials `{"calcite": 1, "tungsten": 1}`
- `battery` <- `battery`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `cannon-shell` <- `cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `car` <- `car`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `cargo-wagon` <- `cargo-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `combat-shotgun` <- `combat-shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `explosive-cannon-shell` <- `explosive-cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `grenade` <- `grenade`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "iron": 1}`
- `heavy-armor` <- `heavy-armor`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `low-density-structure` <- `low-density-structure`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "plastic": 1, "steel": 1}`
- `piercing-rounds-magazine` <- `piercing-rounds-magazine`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `piercing-shotgun-shell` <- `piercing-shotgun-shell`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `pistol` <- `pistol`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `poison-capsule` <- `poison-capsule`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "steel": 1}`
- `rail` <- `rail`; reason `non-metallurgical-multiple-materials`; materials `{"steel": 1, "stone": 1}`
- `shotgun` <- `shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `shotgun-shell` <- `shotgun-shell`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `slowdown-capsule` <- `slowdown-capsule`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "steel": 1}`
- `submachine-gun` <- `submachine-gun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`

### bob_angels_full_is (33)
- `angels-catalyst-metal-red` <- `angels-catalyst-metal-red`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "iron": 1}`
- `angels-filter-frame` <- `angels-filter-frame`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `angels-ore8-crushed` <- `angels-ore8-crushed`; reason `non-metallurgical-multiple-materials`; materials `{"angels-ore1": 1, "angels-ore2": 1, "angels-ore5": 1}`
- `angels-ore9-crushed` <- `angels-ore9-crushed`; reason `non-metallurgical-multiple-materials`; materials `{"angels-ore3": 1, "angels-ore4": 1, "angels-ore6": 1}`
- `bob-armoured-cargo-wagon` <- `bob-armoured-cargo-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"gunmetal": 1, "invar": 1}`
- `bob-armoured-fluid-wagon` <- `bob-armoured-fluid-wagon`; reason `non-metallurgical-multiple-materials`; materials `{"gunmetal": 1, "invar": 1}`
- `bob-armoured-locomotive` <- `bob-armoured-locomotive`; reason `non-metallurgical-multiple-materials`; materials `{"gunmetal": 1, "invar": 1}`
- `bob-circuit-board` <- `bob-circuit-board`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "tin": 1}`
- `bob-cobalt-oxide` <- `bob-cobalt-oxide-from-copper`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "stone": 1}`
- `bob-empty-canister` <- `bob-empty-canister`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "plastic": 1}`
- `bob-empty-nuclear-fuel-cell` <- `bob-empty-nuclear-fuel-cell`; reason `non-metallurgical-multiple-materials`; materials `{"lead": 1, "steel": 1}`
- `bob-robot-brain` <- `bob-robot-brain`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "tin": 1}`
- `bob-robot-brain-2` <- `bob-robot-brain-2`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "tin": 1}`
- `bob-robot-brain-3` <- `bob-robot-brain-3`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "tin": 1}`
- `bob-robot-brain-4` <- `bob-robot-brain-4`; reason `non-metallurgical-material-plus-alloy`; materials `{"copper": 1, "tin": 1}`
- `bob-superior-circuit-board` <- `bob-superior-circuit-board`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "silver": 1}`
- `cannon-shell` <- `cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `car` <- `car`; reason `non-metallurgical-multiple-materials`; materials `{"iron": 1, "steel": 1}`
- `combat-shotgun` <- `combat-shotgun`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `explosive-cannon-shell` <- `explosive-cannon-shell`; reason `non-metallurgical-multiple-materials`; materials `{"plastic": 1, "steel": 1}`
- `grenade` <- `grenade`; reason `non-metallurgical-multiple-materials`; materials `{"coal": 1, "iron": 1}`
- `heavy-armor` <- `heavy-armor`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `low-density-structure` <- `low-density-structure`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "plastic": 1, "steel": 1}`
- `piercing-rounds-magazine` <- `piercing-rounds-magazine`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`
- `piercing-shotgun-shell` <- `piercing-shotgun-shell`; reason `non-metallurgical-multiple-materials`; materials `{"copper": 1, "steel": 1}`


## component_candidate

### is_sa (43)
- `advanced-circuit` <- `advanced-circuit`; reason `single-material-source`; materials `{"plastic": 1}`
- `artillery-wagon` <- `artillery-wagon`; reason `single-material-source`; materials `{"tungsten": 1}`
- `atomic-bomb` <- `atomic-bomb`; reason `single-material-source`; materials `{"uranium": 1}`
- `automation-science-pack` <- `automation-science-pack`; reason `single-material-source`; materials `{"copper": 1}`
- `capture-robot-rocket` <- `capture-robot-rocket`; reason `single-material-source`; materials `{"steel": 1}`
- `carbon` <- `carbon`; reason `single-material-source`; materials `{"coal": 1}`
- `cliff-explosives` <- `cliff-explosives`; reason `single-material-with-unknowns`; materials `{"calcite": 1}`
- `cluster-grenade` <- `cluster-grenade`; reason `single-material-source`; materials `{"steel": 1}`
- `copper-cable` <- `copper-cable`; reason `single-material-source`; materials `{"copper": 1}`
- `destroyer-capsule` <- `destroyer-capsule`; reason `single-material-source`; materials `{"steel": 1}`
- `electronic-circuit` <- `electronic-circuit`; reason `single-material-source`; materials `{"iron": 1}`
- `engine-unit` <- `engine-unit`; reason `single-material-source`; materials `{"steel": 1}`
- `explosive-uranium-cannon-shell` <- `explosive-uranium-cannon-shell`; reason `single-material-source`; materials `{"uranium": 1}`
- `explosives` <- `explosives`; reason `single-material-source`; materials `{"coal": 1}`
- `firearm-magazine` <- `firearm-magazine`; reason `single-material-source`; materials `{"iron": 1}`
- `flamethrower` <- `flamethrower`; reason `single-material-source`; materials `{"steel": 1}`
- `flamethrower-ammo` <- `flamethrower-ammo`; reason `single-material-source`; materials `{"steel": 1}`
- `fluid-wagon` <- `fluid-wagon`; reason `single-material-source`; materials `{"steel": 1}`
- `flying-robot-frame` <- `flying-robot-frame`; reason `single-material-source`; materials `{"steel": 1}`
- `iron-gear-wheel` <- `iron-gear-wheel`; reason `single-material-source`; materials `{"iron": 1}`
- `iron-stick` <- `iron-stick`; reason `single-material-source`; materials `{"iron": 1}`
- `light-armor` <- `light-armor`; reason `single-material-source`; materials `{"iron": 1}`
- `locomotive` <- `locomotive`; reason `single-material-source`; materials `{"steel": 1}`
- `low-density-structure` <- `casting-low-density-structure`; reason `single-material-source`; materials `{"plastic": 1}`
- `metallurgic-science-pack` <- `metallurgic-science-pack`; reason `single-material-source`; materials `{"tungsten": 1}`

### krastorio_is (85)
- `advanced-circuit` <- `advanced-circuit`; reason `single-material-source`; materials `{"copper": 1}`
- `atomic-bomb` <- `atomic-bomb`; reason `single-material-source`; materials `{"uranium": 1}`
- `capture-robot-rocket` <- `capture-robot-rocket`; reason `single-material-source`; materials `{"steel": 1}`
- `carbon` <- `carbon`; reason `single-material-source`; materials `{"coal": 1}`
- `cargo-wagon` <- `cargo-wagon`; reason `single-material-source`; materials `{"iron": 2}`
- `chemical-science-pack` <- `chemical-science-pack`; reason `single-material-source`; materials `{"glass": 1}`
- `cliff-explosives` <- `cliff-explosives`; reason `single-material-with-unknowns`; materials `{"calcite": 1}`
- `cluster-grenade` <- `cluster-grenade`; reason `single-material-source`; materials `{"steel": 1}`
- `copper-cable` <- `copper-cable`; reason `single-material-source`; materials `{"copper": 1}`
- `defender-capsule` <- `defender-capsule`; reason `single-material-source`; materials `{"iron": 1}`
- `destroyer-capsule` <- `destroyer-capsule`; reason `single-material-source`; materials `{"steel": 1}`
- `engine-unit` <- `engine-unit`; reason `single-material-source`; materials `{"iron": 2}`
- `explosive-uranium-cannon-shell` <- `explosive-uranium-cannon-shell`; reason `single-material-source`; materials `{"uranium": 1}`
- `explosives` <- `explosives`; reason `single-material-source`; materials `{"coal": 1}`
- `flamethrower-ammo` <- `flamethrower-ammo`; reason `single-material-source`; materials `{"iron": 1}`
- `flying-robot-frame` <- `flying-robot-frame`; reason `single-material-source`; materials `{"steel": 1}`
- `heavy-armor` <- `heavy-armor`; reason `single-material-source`; materials `{"steel": 1}`
- `iron-gear-wheel` <- `iron-gear-wheel`; reason `single-material-source`; materials `{"iron": 1}`
- `iron-stick` <- `iron-stick`; reason `single-material-source`; materials `{"iron": 1}`
- `kr-advanced-fuel` <- `kr-advanced-fuel`; reason `single-material-source`; materials `{"kr-imersite": 1}`
- `kr-advanced-tech-card` <- `kr-advanced-tech-card`; reason `single-material-source`; materials `{"imersium": 1}`
- `kr-anti-materiel-rifle` <- `kr-anti-materiel-rifle`; reason `single-material-source`; materials `{"steel": 1}`
- `kr-antimatter-artillery-shell` <- `kr-antimatter-artillery-shell`; reason `single-material-source`; materials `{"imersium": 1}`
- `kr-antimatter-railgun-shell` <- `kr-antimatter-railgun-shell`; reason `single-material-source`; materials `{"imersium": 1}`
- `kr-antimatter-rocket` <- `kr-antimatter-rocket`; reason `single-material-source`; materials `{"imersium": 1}`

### bobs_full_is (129)
- `advanced-circuit` <- `advanced-circuit`; reason `exact-scrap-component`; materials `{"circuit": 1}`
- `artillery-shell` <- `artillery-shell`; reason `single-material-source`; materials `{"calcite": 1}`
- `atomic-bomb` <- `atomic-bomb`; reason `single-material-source`; materials `{"uranium": 1}`
- `automation-science-pack` <- `automation-science-pack`; reason `single-material-source`; materials `{"copper": 1}`
- `battery` <- `battery`; reason `exact-scrap-component`; materials `{"battery": 1}`
- `bob-advanced-processing-unit` <- `bob-advanced-processing-unit`; reason `exact-scrap-component`; materials `{"circuit": 1}`
- `bob-alumina` <- `bob-alumina`; reason `single-material-source`; materials `{"bob-bauxite": 1}`
- `bob-amethyst-4` <- `bob-amethyst-4`; reason `single-material-source`; materials `{"bob-amethyst": 1}`
- `bob-armoured-cargo-wagon-2` <- `bob-armoured-cargo-wagon-2`; reason `single-material-source`; materials `{"titanium": 1}`
- `bob-armoured-fluid-wagon-2` <- `bob-armoured-fluid-wagon-2`; reason `single-material-source`; materials `{"titanium": 1}`
- `bob-armoured-locomotive-2` <- `bob-armoured-locomotive-2`; reason `single-material-source`; materials `{"titanium": 1}`
- `bob-basic-circuit-board` <- `bob-basic-circuit-board`; reason `exact-scrap-component`; materials `{"board": 1}`
- `bob-battery-2` <- `bob-battery-2`; reason `exact-scrap-component`; materials `{"battery": 1}`
- `bob-battery-3` <- `bob-battery-3`; reason `exact-scrap-component`; materials `{"battery": 1}`
- `bob-brass-gear-wheel` <- `bob-brass-gear-wheel`; reason `exact-scrap-component`; materials `{"gear": 1}`
- `bob-brass-pipe` <- `bob-brass-pipe`; reason `exact-scrap-component`; materials `{"pipe": 1}`
- `bob-bronze-pipe` <- `bob-bronze-pipe`; reason `exact-scrap-component`; materials `{"pipe": 1}`
- `bob-calcium-chloride` <- `bob-calcium-chloride`; reason `single-material-source`; materials `{"stone": 1}`
- `bob-calcium-chloride` <- `bob-tungstic-acid`; reason `single-material-source`; materials `{"tungsten": 1}`
- `bob-cargo-wagon-2` <- `bob-cargo-wagon-2`; reason `single-material-source`; materials `{"cobalt-steel": 1}`
- `bob-cargo-wagon-3` <- `bob-cargo-wagon-3`; reason `single-material-source`; materials `{"titanium": 1}`
- `bob-cobalt-steel-bearing` <- `bob-cobalt-steel-bearing`; reason `single-material-source`; materials `{"cobalt-steel": 1}`
- `bob-cobalt-steel-bearing-ball` <- `bob-cobalt-steel-bearing-ball`; reason `single-material-source`; materials `{"cobalt-steel": 1}`
- `bob-cobalt-steel-gear-wheel` <- `bob-cobalt-steel-gear-wheel`; reason `single-material-source`; materials `{"cobalt-steel": 1}`
- `bob-copper-tungsten-pipe` <- `bob-copper-tungsten-pipe`; reason `exact-scrap-component`; materials `{"pipe": 1}`

### angels_full_is (99)
- `advanced-circuit` <- `advanced-circuit`; reason `single-material-source`; materials `{"plastic": 1}`
- `angels-anode-lead` <- `angels-anode-lead`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-catalyst-metal-carrier` <- `angels-catalyst-metal-carrier`; reason `single-material-source`; materials `{"iron": 1}`
- `angels-catalyst-metal-carrier` <- `angels-coal-cracking-2`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-catalyst-metal-yellow` <- `angels-catalyst-metal-yellow`; reason `single-material-source`; materials `{"angels-nickel": 1}`
- `angels-copper-pebbles` <- `angels-copper-pebbles`; reason `single-material-source`; materials `{"copper": 1}`
- `angels-crystal-grindstone` <- `angels-crystal-grindstone`; reason `single-material-source`; materials `{"iron": 1}`
- `angels-deuterium-fuel-cell` <- `angels-deuterium-fuel-cell`; reason `single-material-source`; materials `{"steel": 1}`
- `angels-electrode` <- `angels-electrode`; reason `single-material-source`; materials `{"steel": 1}`
- `angels-filter-coal` <- `angels-filter-coal`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-geode-blue` <- `angels-ore1-chunk`; reason `single-material-source`; materials `{"angels-ore1": 1}`
- `angels-geode-cyan` <- `angels-ore5-chunk`; reason `single-material-source`; materials `{"angels-ore5": 1}`
- `angels-geode-lightgreen` <- `angels-ore4-chunk`; reason `single-material-source`; materials `{"angels-ore4": 1}`
- `angels-geode-purple` <- `angels-ore2-chunk`; reason `single-material-source`; materials `{"angels-ore2": 1}`
- `angels-geode-red` <- `angels-ore6-chunk`; reason `single-material-source`; materials `{"angels-ore6": 1}`
- `angels-geode-yellow` <- `angels-ore3-chunk`; reason `single-material-source`; materials `{"angels-ore3": 1}`
- `angels-ingot-copper` <- `angels-ingot-copper`; reason `single-material-source`; materials `{"copper": 1}`
- `angels-ingot-iron` <- `angels-ingot-iron`; reason `single-material-source`; materials `{"iron": 1}`
- `angels-ingot-iron` <- `angels-ingot-iron-2`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-iron` <- `angels-ingot-iron-3`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-iron` <- `angels-solid-iron-hydroxide-smelting`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-manganese` <- `angels-ingot-manganese`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-nickel` <- `angels-ingot-nickel`; reason `single-material-source`; materials `{"angels-nickel": 1}`
- `angels-ingot-tin` <- `angels-ingot-tin-2`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-iron-pebbles` <- `angels-iron-pebbles`; reason `single-material-source`; materials `{"iron": 1}`

### bob_angels_full_is (180)
- `advanced-circuit` <- `advanced-circuit`; reason `exact-scrap-component`; materials `{"circuit": 1}`
- `angels-anode-lead` <- `angels-anode-lead`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-catalyst-metal-carrier` <- `angels-catalyst-metal-carrier`; reason `single-material-source`; materials `{"iron": 1}`
- `angels-catalyst-metal-carrier` <- `angels-coal-cracking-2`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-catalyst-metal-green` <- `angels-catalyst-metal-green`; reason `single-material-source`; materials `{"silver": 1}`
- `angels-catalyst-metal-yellow` <- `angels-catalyst-metal-yellow`; reason `single-material-source`; materials `{"tungsten": 1}`
- `angels-copper-pebbles` <- `angels-copper-pebbles`; reason `single-material-source`; materials `{"copper": 1}`
- `angels-electrode` <- `angels-electrode`; reason `single-material-source`; materials `{"steel": 1}`
- `angels-filter-coal` <- `angels-filter-coal`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-geode-blue` <- `angels-ore1-chunk`; reason `single-material-source`; materials `{"angels-ore1": 1}`
- `angels-geode-cyan` <- `angels-ore5-chunk`; reason `single-material-source`; materials `{"angels-ore5": 1}`
- `angels-geode-lightgreen` <- `angels-ore4-chunk`; reason `single-material-source`; materials `{"angels-ore4": 1}`
- `angels-geode-purple` <- `angels-ore2-chunk`; reason `single-material-source`; materials `{"angels-ore2": 1}`
- `angels-geode-red` <- `angels-ore6-chunk`; reason `single-material-source`; materials `{"angels-ore6": 1}`
- `angels-geode-yellow` <- `angels-ore3-chunk`; reason `single-material-source`; materials `{"angels-ore3": 1}`
- `angels-ingot-copper` <- `angels-ingot-copper`; reason `single-material-source`; materials `{"copper": 1}`
- `angels-ingot-iron` <- `angels-ingot-iron`; reason `single-material-source`; materials `{"iron": 1}`
- `angels-ingot-iron` <- `angels-ingot-iron-2`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-iron` <- `angels-ingot-iron-3`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-iron` <- `angels-solid-iron-hydroxide-smelting`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-lead` <- `angels-ingot-lead`; reason `single-material-source`; materials `{"lead": 1}`
- `angels-ingot-manganese` <- `angels-ingot-manganese`; reason `single-material-source`; materials `{"coal": 1}`
- `angels-ingot-nickel` <- `angels-ingot-nickel`; reason `single-material-source`; materials `{"nickel": 1}`
- `angels-ingot-silver` <- `angels-ingot-silver`; reason `single-material-source`; materials `{"silver": 1}`
- `angels-ingot-tin` <- `angels-ingot-tin`; reason `single-material-source`; materials `{"tin": 1}`

