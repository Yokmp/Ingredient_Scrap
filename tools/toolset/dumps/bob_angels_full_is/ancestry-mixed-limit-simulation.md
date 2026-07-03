# bob_angels_full_is Mixed-Limit Simulation

Generated from `ancestry-flow-hybrid.json`. This is passive review evidence only.

Rules simulated: unresolved entries always become `yis-mixed-scrap`; resolved entries become mixed when ancestry width is greater than the tested limit.

## Summary Matrix

| Limit | Direct | Mixed by width | Mixed unresolved |
| ---: | ---: | ---: | ---: |
| 1 | 21 | 11 | 1 |
| 2 | 28 | 4 | 1 |
| 3 | 29 | 3 | 1 |
| 4 | 29 | 3 | 1 |
| 5 | 30 | 2 | 1 |
| 6 | 32 | 0 | 1 |

## Mixed Ingredients By Limit

### Limit 1

- `battery`: `battery` (mixed-width, width 2), `bob-battery-2` (mixed-width, width 2), `bob-battery-3` (mixed-width, width 2)
- `board`: `bob-basic-circuit-board` (mixed-width, width 2)
- `cable`: `bob-gilded-copper-cable` (mixed-width, width 2), `bob-insulated-cable` (mixed-width, width 2), `bob-tinned-copper-cable` (mixed-width, width 2)
- `electronics`: `advanced-circuit` (mixed-width, width 5), `bob-advanced-processing-unit` (mixed-width, width 6), `electronic-circuit` (mixed-width, width 3), `processing-unit` (mixed-width, width 6)
- `pipe`: `bob-ceramic-pipe` (mixed-unresolved, width 0)

### Limit 2

- `electronics`: `advanced-circuit` (mixed-width, width 5), `bob-advanced-processing-unit` (mixed-width, width 6), `electronic-circuit` (mixed-width, width 3), `processing-unit` (mixed-width, width 6)
- `pipe`: `bob-ceramic-pipe` (mixed-unresolved, width 0)

### Limit 3

- `electronics`: `advanced-circuit` (mixed-width, width 5), `bob-advanced-processing-unit` (mixed-width, width 6), `processing-unit` (mixed-width, width 6)
- `pipe`: `bob-ceramic-pipe` (mixed-unresolved, width 0)

### Limit 4

- `electronics`: `advanced-circuit` (mixed-width, width 5), `bob-advanced-processing-unit` (mixed-width, width 6), `processing-unit` (mixed-width, width 6)
- `pipe`: `bob-ceramic-pipe` (mixed-unresolved, width 0)

### Limit 5

- `electronics`: `bob-advanced-processing-unit` (mixed-width, width 6), `processing-unit` (mixed-width, width 6)
- `pipe`: `bob-ceramic-pipe` (mixed-unresolved, width 0)

### Limit 6

- `pipe`: `bob-ceramic-pipe` (mixed-unresolved, width 0)

## Reading

- Limit 1 keeps only single-material ancestry direct. It converts all alloyed cables, boards, electronics, and batteries to mixed.
- Limit 2 keeps simple two-material cables and boards direct, while wide electronics still become mixed.
- Limit 3 keeps most narrow component ancestry direct and still sends advanced electronics to mixed.
- Limits 5-6 start allowing wide electronics directly, which may create too many scrap outputs for normal gameplay.
