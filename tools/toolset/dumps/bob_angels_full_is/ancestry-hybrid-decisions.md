# bob_angels_full_is Hybrid Decisions

Generated from `ancestry-flow-hybrid.json`. This is a manual review aid, not active mod behavior.

## Summary

- Unique reviewed ingredients: 33
- `safe_hybrid`: 22
- `mixed_candidate`: 7
- `api_compat_candidate`: 2
- `preserve_future_chemistry`: 2

## Safe Hybrid

- `bob-basic-circuit-board`: `bob-basic-circuit-board` -> `copper:1.5, iron:0.142857`; via `bob-basic-circuit-board`; clean
- `bob-brass-bearing`: `bob-brass-bearing` -> `brass:1.166667`; via `bob-brass-bearing`; clean
- `bob-brass-bearing-ball`: `bob-brass-bearing-ball` -> `brass:0.083333`; via `bob-brass-bearing-ball`; clean
- `bob-brass-gear-wheel`: `bob-brass-gear-wheel` -> `brass:2.0`; via `bob-brass-gear-wheel`; clean
- `bob-brass-pipe`: `bob-brass-pipe` -> `brass:1.0`; via `bob-brass-pipe`; clean
- `bob-bronze-pipe`: `bob-bronze-pipe` -> `bronze:1.0`; via `bob-bronze-pipe`; clean
- `bob-copper-tungsten-pipe`: `bob-copper-tungsten-pipe` -> `copper-tungsten:1.0`; via `bob-copper-tungsten-pipe`; clean
- `bob-gilded-copper-cable`: `bob-gilded-copper-cable` -> `copper:1.0, gold:0.8`; via `angels-wire-gold`; clean
- `bob-nitinol-gear-wheel`: `bob-nitinol-gear-wheel` -> `nitinol:2.0`; via `bob-nitinol-gear-wheel`; clean
- `bob-plastic-pipe`: `bob-plastic-pipe` -> `plastic:1.0`; via `bob-plastic-pipe`; clean
- `bob-steel-bearing`: `bob-steel-bearing` -> `steel:1.166667`; via `bob-steel-bearing`; clean
- `bob-steel-bearing-ball`: `bob-steel-bearing-ball` -> `steel:0.083333`; via `bob-steel-bearing-ball`; clean
- `bob-steel-gear-wheel`: `bob-steel-gear-wheel` -> `steel:2.0`; via `bob-steel-gear-wheel`; clean
- `bob-steel-pipe`: `bob-steel-pipe` -> `steel:1.0`; via `bob-steel-pipe`; clean
- `bob-tinned-copper-cable`: `bob-tinned-copper-cable` -> `copper:1.0, tin:0.8`; via `angels-wire-tin`; clean
- `bob-titanium-gear-wheel`: `bob-titanium-gear-wheel` -> `titanium:2.0`; via `bob-titanium-gear-wheel`; clean
- `bob-titanium-pipe`: `bob-titanium-pipe` -> `titanium:1.0`; via `bob-titanium-pipe`; clean
- `bob-tungsten-gear-wheel`: `bob-tungsten-gear-wheel` -> `tungsten:2.0`; via `bob-tungsten-gear-wheel`; clean
- `bob-tungsten-pipe`: `bob-tungsten-pipe` -> `tungsten:1.0`; via `bob-tungsten-pipe`; clean
- `copper-cable`: `copper-cable` -> `copper:0.5`; via `copper-cable`; clean
- `iron-gear-wheel`: `iron-gear-wheel` -> `iron:2.0`; via `iron-gear-wheel`; clean
- `pipe`: `pipe` -> `iron:1.0`; via `pipe`; clean

## Mixed Candidate

- `advanced-circuit`: `advanced-circuit` -> `copper:5.0, plastic:0.8, silicon:1.6, silver:1.92, tin:2.28`; via `advanced-circuit`; unresolved:bob-solder
- `battery`: `battery` -> `lead:2.0, steel:1.0`; via `battery`; deferred-fluid:sulfuric-acid
- `bob-advanced-processing-unit`: `bob-advanced-processing-unit` -> `copper:18.4, gold:7.12, plastic:2.8, silicon:13.6, silver:2.88, tin:1.92`; via `bob-advanced-processing-unit`; unresolved:bob-solder
- `bob-battery-2`: `bob-battery-2` -> `plastic:1.0, zinc:1.0`; via `bob-battery-2`; unresolved:angels-solid-sodium-hydroxide, unresolved:bob-silver-oxide
- `bob-battery-3`: `bob-battery-3` -> `holmium:0.1, plastic:1.0`; via `bob-battery-3`; unresolved:angels-solid-carbon, unresolved:bob-lithium-perchlorate
- `electronic-circuit`: `electronic-circuit` -> `copper:1.6, iron:0.142857, tin:1.28`; via `electronic-circuit`; unresolved:bob-solder
- `processing-unit`: `processing-unit` -> `copper:12.2, gold:3.84, plastic:2.8, silicon:8.0, silver:4.84, tin:1.28`; via `processing-unit`; unresolved:bob-solder

## API/Compat Candidate

- `bob-ceramic-pipe`: `bob-ceramic-pipe` -> `-`; via `bob-ceramic-pipe`; unresolved:bob-silicon-nitride
- `bob-insulated-cable`: `bob-insulated-cable` -> `copper:1.0, tin:0.8`; via `bob-insulated-cable`; unresolved:bob-rubber

## Preserve/Future Chemistry

- `bob-nitinol-bearing`: `bob-nitinol-bearing` -> `nitinol:1.166667`; via `bob-nitinol-bearing`; deferred-fluid:lubricant
- `bob-titanium-bearing`: `bob-titanium-bearing` -> `titanium:1.166667`; via `bob-titanium-bearing`; deferred-fluid:lubricant

## Reading

- Safe Hybrid items are the strongest candidates for replacing exact component scrap with ancestry-derived material scrap.
- `bob-basic-circuit-board` is currently in Safe Hybrid because it resolves cleanly and narrowly, but it should be reviewed together with electronics before active use.
- Mixed Candidates should probably use a material-count limit or `yis-mixed-scrap` fallback instead of emitting many separate scrap outputs directly.
- API/Compat Candidates need explicit composition or ignore rules before an active ancestry solver can rely on them.
- Preserve/Future Chemistry entries contain process fluids such as lubricant and should stay out of the first active ancestry pass.
