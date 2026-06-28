# Design Notes

## Future: Recipe-Chain Based Recycle Targets

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
