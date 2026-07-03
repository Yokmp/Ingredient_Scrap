# bob_angels_full_is Effective Output Review

Generated from `ancestry-flow-hybrid.json` with `mixed_limit = 3`. This is passive review evidence only.

## Summary

- Unique reviewed ingredients: 33
- `direct`: 29
- `mixed-width-limit`: 3
- `mixed-unresolved`: 1

## Current vs Effective

### Direct Effective Output

#### battery

- `battery`: current `yis-battery-scrap` -> effective `yis-lead-scrap, yis-steel-scrap`; ancestry `lead:2.0, steel:1.0`; within-limit
- `bob-battery-2`: current `yis-bob-battery-2-scrap` -> effective `yis-plastic-scrap, yis-zinc-scrap`; ancestry `plastic:1.0, zinc:1.0`; within-limit
- `bob-battery-3`: current `yis-bob-battery-3-scrap` -> effective `yis-holmium-scrap, yis-plastic-scrap`; ancestry `holmium:0.1, plastic:1.0`; within-limit

#### bearing

- `bob-brass-bearing`: current `yis-bob-brass-bearing-scrap` -> effective `yis-brass-scrap`; ancestry `brass:1.166667`; within-limit
- `bob-nitinol-bearing`: current `yis-bob-nitinol-bearing-scrap` -> effective `yis-nitinol-scrap`; ancestry `nitinol:1.166667`; within-limit
- `bob-steel-bearing`: current `yis-bob-steel-bearing-scrap` -> effective `yis-steel-scrap`; ancestry `steel:1.166667`; within-limit
- `bob-titanium-bearing`: current `yis-bob-titanium-bearing-scrap` -> effective `yis-titanium-scrap`; ancestry `titanium:1.166667`; within-limit

#### bearing-ball

- `bob-brass-bearing-ball`: current `yis-bob-brass-bearing-ball-scrap` -> effective `yis-brass-scrap`; ancestry `brass:0.083333`; within-limit
- `bob-steel-bearing-ball`: current `yis-bob-steel-bearing-ball-scrap` -> effective `yis-steel-scrap`; ancestry `steel:0.083333`; within-limit

#### board

- `bob-basic-circuit-board`: current `yis-bob-basic-circuit-board-scrap` -> effective `yis-copper-scrap, yis-iron-scrap`; ancestry `copper:1.5, iron:0.142857`; within-limit

#### cable

- `bob-gilded-copper-cable`: current `yis-bob-gilded-copper-cable-scrap` -> effective `yis-copper-scrap, yis-gold-scrap`; ancestry `copper:1.0, gold:0.8`; within-limit
- `bob-insulated-cable`: current `yis-bob-insulated-cable-scrap` -> effective `yis-copper-scrap, yis-tin-scrap`; ancestry `copper:1.0, tin:0.8`; within-limit
- `bob-tinned-copper-cable`: current `yis-bob-tinned-copper-cable-scrap` -> effective `yis-copper-scrap, yis-tin-scrap`; ancestry `copper:1.0, tin:0.8`; within-limit
- `copper-cable`: current `yis-copper-cable-scrap` -> effective `yis-copper-scrap`; ancestry `copper:0.5`; within-limit

#### electronics

- `electronic-circuit`: current `yis-electronic-circuit-scrap` -> effective `yis-copper-scrap, yis-iron-scrap, yis-tin-scrap`; ancestry `copper:1.6, iron:0.142857, tin:1.28`; within-limit

#### gear

- `bob-brass-gear-wheel`: current `yis-bob-brass-gear-wheel-scrap` -> effective `yis-brass-scrap`; ancestry `brass:2.0`; within-limit
- `bob-nitinol-gear-wheel`: current `yis-bob-nitinol-gear-wheel-scrap` -> effective `yis-nitinol-scrap`; ancestry `nitinol:2.0`; within-limit
- `bob-steel-gear-wheel`: current `yis-bob-steel-gear-wheel-scrap` -> effective `yis-steel-scrap`; ancestry `steel:2.0`; within-limit
- `bob-titanium-gear-wheel`: current `yis-bob-titanium-gear-wheel-scrap` -> effective `yis-titanium-scrap`; ancestry `titanium:2.0`; within-limit
- `bob-tungsten-gear-wheel`: current `yis-bob-tungsten-gear-wheel-scrap` -> effective `yis-tungsten-scrap`; ancestry `tungsten:2.0`; within-limit
- `iron-gear-wheel`: current `yis-iron-gear-wheel-scrap` -> effective `yis-iron-scrap`; ancestry `iron:2.0`; within-limit

#### pipe

- `bob-brass-pipe`: current `yis-bob-brass-pipe-scrap` -> effective `yis-brass-scrap`; ancestry `brass:1.0`; within-limit
- `bob-bronze-pipe`: current `yis-bob-bronze-pipe-scrap` -> effective `yis-bronze-scrap`; ancestry `bronze:1.0`; within-limit
- `bob-copper-tungsten-pipe`: current `yis-bob-copper-tungsten-pipe-scrap` -> effective `yis-copper-tungsten-scrap`; ancestry `copper-tungsten:1.0`; within-limit
- `bob-plastic-pipe`: current `yis-bob-plastic-pipe-scrap` -> effective `yis-plastic-scrap`; ancestry `plastic:1.0`; within-limit
- `bob-steel-pipe`: current `yis-bob-steel-pipe-scrap` -> effective `yis-steel-scrap`; ancestry `steel:1.0`; within-limit
- `bob-titanium-pipe`: current `yis-bob-titanium-pipe-scrap` -> effective `yis-titanium-scrap`; ancestry `titanium:1.0`; within-limit
- `bob-tungsten-pipe`: current `yis-bob-tungsten-pipe-scrap` -> effective `yis-tungsten-scrap`; ancestry `tungsten:1.0`; within-limit
- `pipe`: current `yis-pipe-scrap` -> effective `yis-iron-scrap`; ancestry `iron:1.0`; within-limit


### Mixed By Width Limit

#### electronics

- `advanced-circuit`: current `yis-advanced-circuit-scrap` -> effective `yis-mixed-scrap`; ancestry `copper:5.0, plastic:0.8, silicon:1.6, silver:1.92, tin:2.28`; width-limit
- `bob-advanced-processing-unit`: current `yis-bob-advanced-processing-unit-scrap` -> effective `yis-mixed-scrap`; ancestry `copper:18.4, gold:7.12, plastic:2.8, silicon:13.6, silver:2.88, tin:1.92`; width-limit
- `processing-unit`: current `yis-processing-unit-scrap` -> effective `yis-mixed-scrap`; ancestry `copper:12.2, gold:3.84, plastic:2.8, silicon:8.0, silver:4.84, tin:1.28`; width-limit


### Mixed By Unresolved Ancestry

#### pipe

- `bob-ceramic-pipe`: current `yis-bob-ceramic-pipe-scrap` -> effective `yis-mixed-scrap`; ancestry `-`; unresolved

## Reading

- Direct entries are the strongest candidates for replacing exact component scrap with ancestry-derived material scrap.
- Mixed-by-width entries are the expected advanced electronics candidates at limit 3.
- Mixed-unresolved entries should stay safe because `yis-mixed-scrap` can be migrated or rebalanced later.
