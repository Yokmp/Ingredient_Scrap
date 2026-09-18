# Product And Scrap Recycling Cycle

Offline analysis of the Base + DLC dump from 2026-09-18 (Factorio 2.1.17).
No game recipes, research or quality behavior changed.

## Method

Produce one finished item, account for all upstream IS scrap, then recycle the
finished item once using its actual `<item>-recycling` recipe from the dump.
Recover IS scrap using the canonical solid recycling recipes, without productivity.
Returned components are kept for reuse, not shredded through another 25% step.

Each returned material is valued at its replacement raw-resource cost using the
same production routes and productivity as the input chain. This is an avoided
raw-input equivalent, not a claim that the recycler outputs ore or molten metal.
Replacement valuation does not generate additional credited scrap.

All values are expectations. Fuel, electricity, research cost, mining productivity,
unused coproducts and recursive reinvestment are excluded. A material-specific
surplus does not establish a self-sustaining factory across every resource.
The proposed machine-quality scrap/recovery curve is not applied.

## Results

Percentages refer to the fresh input of the listed resource in the whole chain.
All seven cases resolved completely for the selected routes.

| Production setup | Resource | Product recycling | IS scrap | Combined |
| --- | --- | ---: | ---: | ---: |
| Assembler pipe, no productivity | Iron | 25.00% | 12.00% | 37.00% |
| Foundry pipe, inherent bonuses only | Iron | 25.00% | 12.00% | 37.00% |
| EM green circuits, inherent bonuses only | Copper | 37.50% | 54.00% | 91.50% |
| EM green circuits, five normal productivity-3 modules | Copper | 50.00% | 84.00% | 134.00% |
| EM green circuits, five legendary productivity-3 modules | Copper | 68.75% | 140.25% | 209.00% |
| Foundry LDS, inherent bonuses only | Copper | 20.00% | 1.44% | 21.44% |
| Foundry LDS, four normal productivity-3 modules + LDS research 21 | Copper | 42.11% | 3.03% | 45.14% |
| Same researched LDS setup | Coal | 100.00% | 7.20% | 107.20% |

EM cases use the same plant/module setup for copper cable and green circuits.
Iron/copper plates use conventional smelting without productivity. The EM base
bonus is +50%; five normal productivity-3 modules add +50%, five legendary ones
add +125%. Iron recovery for the three EM cases is 55.50%, 74.00%, and 101.75%.

Foundry cases use ore melting (not lava), and casting routes for replacement
plates/steel. Every relevant Foundry has the specified setup. Plastic production
uses the ordinary recipe and basic oil processing, without productivity.
At LDS research 21 the LDS recipe reaches +300% (50% inherent + 40% modules +
210% research); the other Foundry recipes stay at +90%.

The pipe result is intentionally not 37.5% plus scrap: casting both pipes and
replacement iron plates benefits from the same inherent bonus, which cancels
in the resource-equivalent comparison. Conventional plate valuation would give
a different number. Foundry LDS similarly returns solids, not its original
molten ingredients, so the generic 25% times productivity shortcut is invalid.

Explicit per-recipe productivity totals include inherent bonuses even when
productivity modules are disallowed, and still respect `maximum_productivity`.
The older uniform-productivity sensitivity model only applied bonuses to recipes
allowing productivity; it should not be used for this Foundry comparison.

## Reproduce

From the mod root, using a current Base + DLC data dump:

```text
python tools/test/recycling_cycle.py <data-raw-dump.json> tools/test/recycling-cycle-cases.json --output tools/test/recycling-cycle-results.json
python -m unittest discover -s tools/test -p "test_recycling_cycle.py"
python -m unittest discover -s tools/test -p "test_quality*.py"
```

The config lists every route and productivity override. The generated JSON retains
input resources, selected recipes, craft counts, returned items, separate recovery
contributions and unresolved cases. Only simulation/test files were added or changed.
