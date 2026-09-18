# Machine Quality: Experimental Balance Model

Status: offline proposal only. Production recipes and machine behavior are not
changed by this tool. Scrap quality itself remains clamped to normal.

Decision (2026-09-18): do not activate this curve. Retain it as an experimental
reference, not planned release behavior. See the
[design decision and trade-offs](DESIGN_NOTES.md#decision-no-additional-machine-quality-scaling-2026-09-18).
Only demonstrated gameplay congestion should reopen quality-based scrap reduction;
an additional recycling yield bonus is not currently planned.

```text
python tools/test/quality_balance.py path/to/data-raw-dump.json --output quality-balance.json
python tools/test/quality_balance.py path/to/data-raw-dump.json --source-productivity 3 --recycle-productivity 3 --output quality-stress.json
python tools/test/test_quality_balance.py
```

Productivity arguments are fractions: `3` means +300%. The stress model applies
them only to recipes allowing productivity, caps them at recipe maximums, and
respects result productivity exclusions. This is a recipe-level stress bound,
not a claim that every machine can reach those bonuses.

| Machine quality | Scrap per craft | Recycling yield | Default crafting speed | Scrap per second |
| --- | ---: | ---: | ---: | ---: |
| Normal | 100% | 100% | 1.0 | 100% |
| Uncommon | 65% | 103% | 1.3 | 84.5% |
| Rare | 45% | 106% | 1.6 | 72% |
| Epic | 30% | 109% | 1.9 | 57% |
| Legendary | 20% | 112% | 2.5 | 50% |

Factors are indexed by vanilla quality names, not numeric quality level:
legendary has level 5. Only qualities present in the dump are included.
The throughput column assumes the same machine and external speed effects;
machine-specific quality speed overrides need separate evaluation.
Legendary production halves scrap throughput under those assumptions.

## Recovery Extremes

Relative to normal production and normal recycling, without productivity:

| Production / recycling | Recovery per production craft | Scrap per second | Recovery per second |
| --- | ---: | ---: | ---: |
| Normal / normal | 100% | 100% | 100% |
| Normal / legendary | 112% | 100% | 112% |
| Legendary / normal | 20% | 50% | 50% |
| Legendary / legendary | 22.4% | 50% | 56% |

Only terminal material recovery receives the quality bonus. Mixed sorting does
not, so the same relative factors apply to complete mixed-scrap recovery chains.
Recovery per second assumes sufficient recycling capacity. Recycling machine
speed changes processing capacity, not material yield per scrap.

These are multipliers on existing recovery, not percentages of original material
input. Each output material stays separate in the JSON. Fluid units are not
summed with item counts.

The report evaluates canonical solid recycling paths. Missing paths, cycles,
shared probabilities and extra recycling ingredients are reported as gaps.
The per-recipe report records direct ingredients. Full-chain analysis is available
with `--chain-target` (see below). Proposed amounts still require a rounding policy.

## Full Manufacturing Chains

```text
python tools/test/quality_balance.py path/to/data-raw-dump.json --chain-target rocket-silo --chain-target locomotive --output chains.json
python tools/test/quality_balance.py path/to/data-raw-dump.json --chain-target rocket-silo --chain-target locomotive --source-productivity .5 --recycle-productivity .5 --output chains-productivity.json
python -m unittest discover -s tools/test -p "test_quality*.py"
```

The analysis recursively counts every required intermediate craft, including
scrap from those crafts. Batch sizes, result probabilities and productivity
change the number of crafts needed per finished target. Shared intermediate
demands are added, not deduplicated. Recycling is excluded from manufacturing.

Inputs are traced to resource and fluid-source boundaries. Recovered materials
are valued using replacement raw inputs at the same production productivity.
Ratios are calculated separately for each resource; fluids and items are never
added together. Unknown recovery values remain visible in `unvalued_recovery`;
incomplete manufacturing chains do not receive ratios.

Same-name recipes are preferred; ambiguous alternatives are listed and require
`--producer TYPE:ITEM=RECIPE`. Default explicit routes use basic oil processing
for petroleum gas, advanced oil processing for heavy oil, sulfuric acid production
and iron ore melting. Overrides take precedence over extraction boundaries.
Oil coproducts receive no credit, so oil requirements can be overestimated.
Fuel, energy, mining productivity, machine capacity and reinvestment of recovered
materials are excluded. Uniform productivity inputs are sensitivity/stress cases,
not verified machine/module layouts. See [reference results](quality-chain-results.md).

## Implementation Boundary

Factorio 2.1.17 exposes machine quality and completed-craft counters, but no
machine-craft-completed event and no machine-quality multiplier for individual
recipe products. Polling output inventories could miss scrap removed by inserters.

An active implementation needs a separate design for quality-specific recipe
variants and their reliable selection. Circuit recipe changes, furnaces,
blueprints, recipe quality, and compatibility must be considered before enabling
it. No runtime inventory polling or hidden recipe switching is activated here.
