# Reference Chain Results

For the additional recovery from recycling the finished product, see
[Product And Scrap Recycling Cycle](recycling-cycle-results.md).

Offline analysis of the Base + DLC `data-raw-dump.json` snapshot from 2026-09-17.
One finished item, expected values, no in-game quality quantity changes enabled.
Manufacturing and recovery route assumptions are in [quality-balancing.md](quality-balancing.md).

## Entire Chain, No Productivity

| Target | Iron ore input | Copper ore input | Total expected scrap | Final assembly scrap |
| --- | ---: | ---: | ---: | ---: |
| Rocket silo | 12220 | 8600 | 9356.40 | 37.20 |
| Locomotive | 340 | 15 | 77.88 | 4.08 |

The silo chain also uses stone, coal, water and crude oil. The table lists only
iron/copper inputs; total scrap includes all scrap families.

| Production / recycling | Silo iron recovery | Silo copper recovery | Locomotive iron recovery | Locomotive copper recovery |
| --- | ---: | ---: | ---: | ---: |
| Normal / normal | 9.80% | 33.41% | 7.96% | 32.80% |
| Normal / legendary | 10.97% | 37.42% | 8.91% | 36.74% |
| Legendary / normal | 1.96% | 6.68% | 1.59% | 6.56% |
| Legendary / legendary | 2.19% | 7.48% | 1.78% | 7.35% |

Largest silo contributors: electronic circuits (3744 scrap), copper cable
(3096), advanced circuits (624), processing units (624), and steel production
(432). Circuits and cable together contribute about 73% of all scrap.
Largest locomotive contributors: engines (21.6), steel (18), and pipes (14.4).

## Current Results: Recycling Productivity Disabled

Rechecked against the 2026-09-18 Base + DLC dump. All IS recycling recipes
have `allow_productivity = false` and `maximum_productivity = 0`.
Requesting +300% recycling productivity in the model therefore adds nothing.
With +50% productivity on eligible manufacturing recipes:

| Production / recycling | Silo iron recovery | Silo copper recovery | Locomotive iron recovery | Locomotive copper recovery |
| --- | ---: | ---: | ---: | ---: |
| Normal / normal | 12.97% | 65.09% | 10.96% | 60.30% |
| Normal / legendary | 14.52% | 72.91% | 12.27% | 67.54% |
| Legendary / normal | 2.59% | 13.02% | 2.19% | 12.06% |
| Legendary / legendary | 2.90% | 14.58% | 2.45% | 13.51% |

Quality quantity modifiers remain simulation-only, not active game behavior.
The no-productivity baseline above is unchanged by this restriction.

This is not a universal guarantee against excess recovery. At the theoretical
+300% manufacturing stress bound, normal production / normal recycling still
returns 463.03% copper for the silo and 308.80% for the locomotive. With the
proposed legendary recycling bonus those become 518.59% and 345.86%.
These uniform productivity assumptions are not validated machine setups.
Upstream manufacturing productivity remains a separate balancing concern.

## Historical Sensitivity: Before The Recycling Restriction

With +50% productivity in each recipe allowing it, on both manufacturing and
recycling, normal production plus legendary recycling gives:

| Target | Iron recovery | Copper recovery |
| --- | ---: | ---: |
| Rocket silo | 21.79% | 109.36% |
| Locomotive | 18.41% | 101.30% |

At normal recycling quality those copper ratios are already 97.64% and 90.45%.
The +300% recipe-cap stress case reaches copper ratios of 2074.37% and 1383.42%
for normal production plus legendary recycling. These are model bounds, not
validated achievable machine configurations.

The mechanism is cumulative: upstream productivity reduces fresh input for
intermediates while downstream recipes still produce scrap from their fixed
ingredient composition. Productivity can also multiply scrap and recycling
outputs where the recipes permit it.

Exceeding 100% for copper flags a material-specific imbalance, not proof of a
fully self-sustaining factory: iron, other resources, energy and the finished
main product remain part of the whole process.

Mixed sorting contributes tiny amounts of holmium plate in the silo chain.
Its raw-input valuation is unresolved (holmium ore comes from excluded recycling
routes); it is reported separately and is not counted in the iron/copper quotas.
The complete silo resource balance is therefore explicitly partial.
