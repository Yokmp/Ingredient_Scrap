# Design Notes

## Future: Recipe-Chain Based Recycle Targets

Status and sequencing:

- Krastorio 2 currently stays as an explicit compat smoke test. It verifies that
  the mod loads with K2, that known K2 aliases resolve to clean material names,
  and that no `kr-*` scrap types leak into generated prototypes.
- Do not hand-audit every K2 recipe before improving the resolver. A broader
  generated recipe summary would be more useful than manual inspection.
- Angels should wait until the recipe-chain work has at least an analysis mode.
  Angels is expected to add many ores, intermediate processing steps, fluids,
  gases, and parallel recipe routes; testing it too early would likely create
  one-off compat exceptions that a chain resolver may later replace.
- The first implementation step should be passive: collect and dump candidate
  chain information into the debug report/data-table without changing recycle
  recipe behavior. Once the report is understandable, enable selected behavior
  behind tests.

The current recycle target resolver intentionally uses a simple, player-friendly
priority for solid materials:

1. `<material>-plate`
2. `<material>-ingot`
3. `<material>-ore`
4. `<material>`
5. the matched ingredient itself

This keeps common cases such as `iron-scrap -> iron-plate` stable and avoids
creating recycle recipes that depend on later processing chains or fluid
handling.

A possible future improvement is a separate recipe-chain resolver. For a scrap
type such as `iron`, it could:

1. start from known products such as `iron-plate`;
2. find recipes that create that product;
3. inspect which `iron` ingredients are needed;
4. walk backwards through those ingredients until it reaches a resource or a
   first useful intermediate;
5. use technology unlocks to decide between multiple possible chains from the
   same resource.

This should stay out of the main collector until the mod is otherwise stable.
The logic can become complicated quickly because mods may add tech-gated,
multi-step chains such as ore -> crushed ore -> dust -> plate, or fluid chains
such as ore -> solution -> plate. In many cases, recycling scrap directly to a
plate or ingot remains the better compromise for gameplay.

If this is implemented later, it should be tested with synthetic fixtures before
being enabled for real prototypes:

- a simple ore -> plate chain;
- a chain with two valid products from the same resource;
- a tech-gated intermediate chain;
- a fluid intermediate chain similar to holmium solution;
- a modded chain where the best target is dust, crushed ore, or another custom
  intermediate.

The resolver should also log its decisions through `yokmods.ingredient_scrap.is_log`
so users can see why a recycle target was selected.
