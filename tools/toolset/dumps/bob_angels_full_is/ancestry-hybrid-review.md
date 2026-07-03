# bob_angels_full_is Hybrid Ancestry Review

Generated from `ancestry-flow-hybrid.json`. This is passive review evidence only.

## Summary

- Total flow comparisons: 1375
- Different flow rows: 790
- Unique different ingredients: 33
- Unresolved flow rows: 1
- Max ancestry width: 6

## Difference Families

- `battery`: 21 rows, 3 unique ingredients
- `bearing`: 39 rows, 4 unique ingredients
- `bearing-ball`: 2 rows, 2 unique ingredients
- `board`: 35 rows, 1 unique ingredients
- `cable`: 50 rows, 4 unique ingredients
- `electronics`: 286 rows, 4 unique ingredients
- `gear`: 154 rows, 6 unique ingredients
- `pipe`: 203 rows, 9 unique ingredients

## Ancestry Width

- `1` materials: 421 rows
- `2` materials: 83 rows
- `3` materials: 86 rows
- `5` materials: 77 rows
- `6` materials: 123 rows

## Reason Buckets

- `clean`: 455 rows
- `fluid-deferred`: 34 rows
- `unresolved-partial`: 301 rows

## Unique Differences By Family

### battery

- `battery`: current `battery` -> ancestry `lead:2.0, steel:1.0`; via `battery`; deferred-fluid:sulfuric-acid
- `bob-battery-2`: current `bob-battery-2` -> ancestry `plastic:1.0, zinc:1.0`; via `bob-battery-2`; unresolved:angels-solid-sodium-hydroxide, unresolved:bob-silver-oxide
- `bob-battery-3`: current `bob-battery-3` -> ancestry `holmium:0.1, plastic:1.0`; via `bob-battery-3`; unresolved:angels-solid-carbon, unresolved:bob-lithium-perchlorate

### bearing

- `bob-brass-bearing`: current `bob-brass-bearing` -> ancestry `brass:1.166667`; via `bob-brass-bearing`; clean
- `bob-nitinol-bearing`: current `bob-nitinol-bearing` -> ancestry `nitinol:1.166667`; via `bob-nitinol-bearing`; deferred-fluid:lubricant
- `bob-steel-bearing`: current `bob-steel-bearing` -> ancestry `steel:1.166667`; via `bob-steel-bearing`; clean
- `bob-titanium-bearing`: current `bob-titanium-bearing` -> ancestry `titanium:1.166667`; via `bob-titanium-bearing`; deferred-fluid:lubricant

### bearing-ball

- `bob-brass-bearing-ball`: current `bob-brass-bearing-ball` -> ancestry `brass:0.083333`; via `bob-brass-bearing-ball`; clean
- `bob-steel-bearing-ball`: current `bob-steel-bearing-ball` -> ancestry `steel:0.083333`; via `bob-steel-bearing-ball`; clean

### board

- `bob-basic-circuit-board`: current `bob-basic-circuit-board` -> ancestry `copper:1.5, iron:0.142857`; via `bob-basic-circuit-board`; clean

### cable

- `bob-gilded-copper-cable`: current `bob-gilded-copper-cable` -> ancestry `copper:1.0, gold:0.8`; via `angels-wire-gold`; clean
- `bob-insulated-cable`: current `bob-insulated-cable` -> ancestry `copper:1.0, tin:0.8`; via `bob-insulated-cable`; unresolved:bob-rubber
- `bob-tinned-copper-cable`: current `bob-tinned-copper-cable` -> ancestry `copper:1.0, tin:0.8`; via `angels-wire-tin`; clean
- `copper-cable`: current `copper-cable` -> ancestry `copper:0.5`; via `copper-cable`; clean

### electronics

- `advanced-circuit`: current `advanced-circuit` -> ancestry `copper:5.0, plastic:0.8, silicon:1.6, silver:1.92, tin:2.28`; via `advanced-circuit`; unresolved:bob-solder
- `bob-advanced-processing-unit`: current `bob-advanced-processing-unit` -> ancestry `copper:18.4, gold:7.12, plastic:2.8, silicon:13.6, silver:2.88, tin:1.92`; via `bob-advanced-processing-unit`; unresolved:bob-solder
- `electronic-circuit`: current `electronic-circuit` -> ancestry `copper:1.6, iron:0.142857, tin:1.28`; via `electronic-circuit`; unresolved:bob-solder
- `processing-unit`: current `processing-unit` -> ancestry `copper:12.2, gold:3.84, plastic:2.8, silicon:8.0, silver:4.84, tin:1.28`; via `processing-unit`; unresolved:bob-solder

### gear

- `bob-brass-gear-wheel`: current `bob-brass-gear-wheel` -> ancestry `brass:2.0`; via `bob-brass-gear-wheel`; clean
- `bob-nitinol-gear-wheel`: current `bob-nitinol-gear-wheel` -> ancestry `nitinol:2.0`; via `bob-nitinol-gear-wheel`; clean
- `bob-steel-gear-wheel`: current `bob-steel-gear-wheel` -> ancestry `steel:2.0`; via `bob-steel-gear-wheel`; clean
- `bob-titanium-gear-wheel`: current `bob-titanium-gear-wheel` -> ancestry `titanium:2.0`; via `bob-titanium-gear-wheel`; clean
- `bob-tungsten-gear-wheel`: current `bob-tungsten-gear-wheel` -> ancestry `tungsten:2.0`; via `bob-tungsten-gear-wheel`; clean
- `iron-gear-wheel`: current `iron-gear-wheel` -> ancestry `iron:2.0`; via `iron-gear-wheel`; clean

### pipe

- `bob-brass-pipe`: current `bob-brass-pipe` -> ancestry `brass:1.0`; via `bob-brass-pipe`; clean
- `bob-bronze-pipe`: current `bob-bronze-pipe` -> ancestry `bronze:1.0`; via `bob-bronze-pipe`; clean
- `bob-ceramic-pipe`: current `bob-ceramic-pipe` -> ancestry `-`; via `bob-ceramic-pipe`; unresolved:bob-silicon-nitride
- `bob-copper-tungsten-pipe`: current `bob-copper-tungsten-pipe` -> ancestry `copper-tungsten:1.0`; via `bob-copper-tungsten-pipe`; clean
- `bob-plastic-pipe`: current `bob-plastic-pipe` -> ancestry `plastic:1.0`; via `bob-plastic-pipe`; clean
- `bob-steel-pipe`: current `bob-steel-pipe` -> ancestry `steel:1.0`; via `bob-steel-pipe`; clean
- `bob-titanium-pipe`: current `bob-titanium-pipe` -> ancestry `titanium:1.0`; via `bob-titanium-pipe`; clean
- `bob-tungsten-pipe`: current `bob-tungsten-pipe` -> ancestry `tungsten:1.0`; via `bob-tungsten-pipe`; clean
- `pipe`: current `pipe` -> ancestry `iron:1.0`; via `pipe`; clean

## Unresolved

- `bob-ceramic-pipe` in `bob-ceramic-pipe-to-ground`: unresolved:bob-silicon-nitride

## Initial Reading

- Simple component families mostly look like good ancestry wins: gears, pipes, cables, bearings, and bearing balls collapse to stable base/alloy materials.
- Electronics are intentionally wider and are likely mixed-scrap limit candidates rather than direct one-to-one exact scrap candidates.
- Fluid-deferred rows are not necessarily wrong; they mark places where preserve-shape or a future sludge fallback may matter.
- The single unresolved flow is currently `bob-ceramic-pipe`, blocked by `bob-silicon-nitride`; this is an API/compat candidate or mixed fallback case.
