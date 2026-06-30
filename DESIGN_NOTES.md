# Design Notes

## Active: Recipe-Chain Based Recycle Target Analysis

## Intentional Behavior: Recycler Scrap Sink

The Quality recycler can recycle generated scrap because its `recycling`
crafting category is patched to accept Ingredient Scrap item recycling recipes.
This may create recipes where scrap can produce a reduced amount of scrap again
through the recycler, for example around 25% output depending on the generated
recipe shape and Factorio recycler behavior.

Keep this behavior. It acts as a useful late-game scrap sink and should not be
"fixed" away by future recipe-chain or category changes unless a separate
setting is deliberately introduced.

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
- The first implementation step is passive and already writes candidate chain
  information into the debug report/data-table without changing recycle recipe
  behavior. Once the report is understandable enough across compat runs, enable
  selected behavior behind tests.
- The existing resolver and the new recipe-chain analysis should run in
  parallel. The existing resolver remains authoritative and continues to
  generate prototypes; the chain analysis only writes diagnostic data to
  `yokmods.ingredient_scrap.data_table.debug.recipe_chain_analysis`.
- The current passive dump contains:
  - a recipe producer/consumer index;
  - name-pattern n-grams for prefixes, suffixes, and infixes;
  - material candidates from current resolver materials and recurring name
    patterns;
  - placeable-item filters derived from `item.place_result`, so machine and
    building names can still appear in raw evidence but are not inferred as
    materials by default;
  - passive recycle target candidates with compact recipe evidence;
  - a target-candidate summary comparing suggested targets with current
    resolver targets.
- The diagnostic dump should compare both approaches so K2, Angels, Bobs, and
  other compat runs can reveal gaps without changing gameplay:
  - materials found only by the current resolver;
  - materials found only by the chain analysis;
  - recycle target candidates where both approaches agree;
  - recycle target candidates where the chain analysis suggests a different
    target;
  - the evidence that led to each suggestion.

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

The analysis should not rely on `main_product` as a filter. It should index all
recipe results, including byproducts and probabilistic outputs, because some
mods expose important materials only as side products. `main_product` can still
be stored as metadata and used as weak evidence.

The name-pattern analysis should tokenize prototype names by `-` and collect
prefixes, suffixes, and infixes. It should count 1-, 2-, 3-, and possibly
4-token n-grams across items, fluids, resources, and recipes. Stable infixes
such as `rare-metal` are important material candidates, while high-frequency
leading tokens such as `kr` or mod-specific prefixes are likely namespace
markers. This is analysis-only at first; it should not create resolver rules by
itself.

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
