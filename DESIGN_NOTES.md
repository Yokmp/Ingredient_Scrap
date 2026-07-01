# Design Notes

## Active: Recipe-Chain Based Recycle Target Analysis

## Current Roadmap

Use this section as the working order. The detailed notes below explain the
reasoning, edge cases, and future ideas.

### Done

1. Keep the existing resolver authoritative while the recipe-chain work is
   passive.
2. Build recipe producer/consumer indexes and name-pattern evidence.
3. Split target analysis into solid and fluid modes.
4. Filter obvious non-material/placeable artifacts from material and solid
   target suggestions.
5. Record recipe-shape evidence for target candidates without changing
   generated prototypes.
6. Build passive decider output with:
   - human-readable decisions;
   - confidence and review reasons;
   - a data-table-shaped `staged_data_table`;
   - no `analysis-only` entries mirrored into staged prototypes.
7. Classify `review-difference` decisions into manual review and strong
   `active-candidate` suggestions. Only strong candidates are mirrored into the
   staged table.
8. Add synthetic hidden and disabled source fixtures. Hidden source chains
   generate stable hidden prototypes, while disabled-but-unlocked-by-tech source
   chains keep generated scrap prototypes visible. Generated recipes do not set
   `enabled = false`, and disabled-only chain evidence does not lower decider
   confidence by itself.
9. Allow API/compat-modified generated recipes or technologies to be
   `enabled = false` without failing validation. The validator logs a warning
   through `is_log` instead, because disabled generated objects can be an
   intentional compatibility choice.
10. Add hidden startup setting `yis-use-recipe-chain-targets`. When enabled,
    only strong `active-candidate` recipe-chain decisions can override generated
    recycle recipe targets. K2 steel is the first covered case; weak/manual
    review decisions such as K2 rare-metal stay unchanged.
11. Keep Krastorio 2 as an explicit compat smoke test.
12. Add recipe-chain API hooks so compat code can force a solid/fluid target or
    block automatic staging for one material and mode.

### Next

1. Run broader compat passes against Angels and Bobs, using the recipe-chain API
   hooks only for cases where automatic evidence is not enough:
   - Done 2026-07-02: Generate fresh `material-flow.json` and
     `production-flow.json` dumps for `krastorio_is`, `angels_is`, `bobs_is`,
     and `bob_angels_is`.
     The archived copies live under `tools/toolset/dumps/<profile>/`.
     The JSON viewer is now the primary review surface; the older text target
     lists are considered a legacy helper and do not need to be regenerated for
     normal compat passes.
     Current counts:
     - `krastorio_is`: 18 materials, 271 material-flow entries, 1935
       production recipes, 673 production nodes.
     - `angels_is`: 29 materials, 277 material-flow entries, 2318 production
       recipes, 1017 production nodes.
     - `bobs_is`: 33 materials, 226 material-flow entries, 1047 production
       recipes, 533 production nodes.
     - `bob_angels_is`: 36 materials, 391 material-flow entries, 2659
       production recipes, 1116 production nodes.
   - Review the generated material list for obvious missing base materials such
     as `plastic-bar`/plastic, rubber, glass, and other non-metal process
     materials that should still produce scrap. Plastic is now visible through
     the `-bar` suffix; glass and rubber are not visible in the current generated
     material-flow dumps and need review against the production-flow dumps.
     First review pass:
     - K2 `kr-glass` is used by real recipes such as `chemical-science-pack`,
       `kr-electronic-components`, `solar-panel`, and machines. It should be a
       stable `glass` material override. Done: K2 `glass` override maps
       `kr-glass` to `glass`.
     - K2 `kr-silicon` is used by real recipes such as
       `kr-electronic-components` and `solar-panel`. It should be a stable
       `silicon` material override. Done: K2 `silicon` override maps
       `kr-silicon` to `silicon`.
     - Bob's `bob-rubber` exists in the base Bob profile, but current evidence
       mostly shows production/recycling rather than normal downstream
       consumption. Keep it under review instead of forcing it immediately.
     - Angel's glass/rubber/resin/silicon chains are mostly hidden,
       disabled, `auto_recycle=false`, barreling, or intermediate process
       chains in the current profiles. Keep them visible in `production-flow`
       review before adding overrides.
   - Use `production-flow.json` to separate true materials from ore-processing,
     slag, sorting, powder, ingot, chemical, barreling, recycling, and other
     side-chain artifacts.
   - Record any ambiguous chains as review notes instead of immediately adding
     compat overrides.
   - Add recipe-chain API overrides only for stable, mod-specific facts that the
     automatic evidence cannot infer reliably.
   - Re-run the compat profiles after every override batch and compare the
     material-flow/production-flow dumps in the viewer before moving the case to
     Done.
   - Last experiment in this queue: test composable evidence/weight profiles.
     The idea is to feed the recipe-chain decider profile-specific weights and
     aliases, then mix profiles for active mod combinations. This is explicitly
     experimental because it may cost more time than it saves; keep hard facts
     such as aliases, forced targets, and blocked materials in the existing API
     unless the experiment proves useful.
2. Before a release build, restore the `yis-hide-tech` behavior for generated
   recycling technologies. During development they stay `hidden = false` so
   in-game testing can see every generated unlock and research trigger.
3. Before a release build, update `deploy.py` ignore rules so local-only tooling
   and generated debug artifacts stay out of the release archive. In particular,
   exclude `tools/`, `tools/toolset/dumps/`, `tools/toolset/target-lists/`,
   `__pycache__/`, and other generated viewer/test outputs unless a specific
   file is intentionally packaged. The deploy script should produce two release
   artifacts:
   - `_release_/public/Ingredient_Scrap/` as clean production source intended to
     be merged/pushed to the public GitHub `main` branch.
   - `_release_/Ingredient_Scrap_<version>.zip` as the Mod Portal upload.
4. Before publishing on GitHub, decide the repository/release layout. The
   project should keep private/local development source, test harnesses, dumps,
   tools, and backup data separate from the public production mod code. The
   intended split is "backup/source project" vs "public production code", not
   simply pushing the whole local working tree to `main`.
5. Generated Ingredient Scrap prototypes use a mod-owned `yis-` prefix:
   `yis-<material>-scrap` for scrap items and
   `yis-recycle-<material>-scrap` for recycle recipes/technologies. Before a
   release, check whether development saves need a migration from the older
   unprefixed names.
   Name helpers must not double-prefix API-provided material names that already
   start with `yis-`.
6. Once the mod has been published, future prototype renames must ship with
   Factorio migration scripts. The current prefix rename can stay unmigrated
   because it happened before release, but this should not become the update
   policy for public versions.

### Later

1. Test Angels and Bobs after the decider has enough API escape hatches.
2. Split long documentation into `docs/`:
   - API details;
   - compat strategy;
   - testing/debugging;
   - recipe-chain design.
3. Build a JSON/HTML dump viewer after the analysis schema stabilizes.
4. Build a Python weight tuner after a golden-table test set exists.
5. Implement `Preserve recipe shape` in small tested steps.
6. Expand the Python tool UI beyond the mod-list workflow.
7. Consider an `Advanced scrap recycling` chain. This should be separate from
   the basic recycle recipes and could consume an acid to improve yield per
   scrap while producing wastewater or another cleanup byproduct. It needs
   careful tech placement: if a suitable acid and acid technology already exist,
   advanced recycling should depend on that technology; if no suitable acid
   exists, the mod would need to provide one and place the unlock at a sensible
   point in the tech tree.
8. Split test/report severities so review output can distinguish:
   - minor issues such as missing localisations;
   - important behavior problems such as wrong recycle results;
   - critical failures such as crashes or invalid icon definitions that make
     Factorio reject prototypes.

## Intentional Behavior: Recycler Scrap Sink

The Quality recycler can recycle generated scrap because its `recycling`
crafting category is patched to accept Ingredient Scrap item recycling recipes.
This may create recipes where scrap can produce a reduced amount of scrap again
through the recycler, for example around 25% output depending on the generated
recipe shape and Factorio recycler behavior.

Keep this behavior. It acts as a useful late-game scrap sink and should not be
"fixed" away by future recipe-chain or category changes unless a separate
setting is deliberately introduced.

## Note: Quality Recycling Recipes Are Side Chains

Quality does not create separate item prototypes for each quality level. Item
quality is carried as quality state on an item stack/filter rather than through
names such as `rare-iron-plate`. The auto-generated Quality recycling recipes
do have a reliable recipe shape:

- recipe name usually ends in `-recycling`;
- recipe category is `recycling`.

Use `recipe.category == "recycling"` as the robust filter for normal material
collection and production-chain analysis. The name suffix can be useful for
debugging, but should not be the primary rule because other mods may use similar
names for unrelated recipes.

Quality recycling recipes should stay visible in future side-chain/debug views,
but they must not be treated as ordinary production recipes that generate extra
scrap results. A later tree-viewer mode can show them as a dedicated Quality or
recycling side chain.

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
  - placeable-item filters derived from `item.place_result`,
    `item.place_as_tile`, and `item.place_as_equipment_result`, so machine,
    building, tile, and equipment names can still appear in raw evidence but are
    not inferred as materials by default;
  - passive recycle target candidates with compact recipe evidence, with
    placeable item results and hidden result prototypes filtered out of solid
    suggestions;
  - a target-candidate summary comparing suggested targets with current
    resolver targets.
  - a compact top-level summary with top analysis-only materials, target
    differences, and high-volume placement filter patterns.

Target analysis is split by mode. The legacy flat target view remains useful as
raw evidence, but solid and fluid target candidates are also built separately.
Solid target analysis ignores recipe-name artifacts such as `barrel`,
`recycling`, `matter-to`, `to-matter`, and `from-dirty-water`, because those
recipes usually describe fluid packaging, reverse item recycling, matter
conversion, or recovery side paths rather than the primary solid material
chain. It also filters obvious solid result artifacts such as barrels, science
packs, fuel cells, equipment, and generic `product` test outputs. Fluid target
analysis can later get its own artifact rules instead of sharing the solid
rules blindly.

Barreling recipes deserve special care. Depending on Factorio and mod load
order, barrel recipes may already exist when Ingredient Scrap analyzes recipes.
An unpacking recipe such as `empty-*-barrel` consumes a barrel item and produces
fluid plus an empty barrel. Ingredient Scrap may currently treat the consumed
barrel item as the matched material carrier and add scrap based on that barrel
item rather than on the fluid chain itself. Keep this visible in analysis dumps,
but do not let barreling evidence become the preferred source for preserve-shape
or active target decisions without an explicit barrel-specific rule.

Recipe evidence records `enabled` and `hidden` flags. `enabled = false` is not
treated as a negative signal by itself because tech-gated recipes are commonly
disabled at startup. `hide_from_player_crafting` and
`hidden_in_factoriopedia` are also not target-quality signals: many valid
machine recipes cannot be hand-crafted, and Factoriopedia visibility mostly
affects documentation presentation. Only explicit `hidden = true` should be
treated as strong evidence that a prototype is an internal compatibility stub
or player-facing artifact.

Disabled or hidden source recipes/items should still be allowed to produce
matching scrap when their material chain is otherwise valid. For save stability,
the generated prototypes should exist even when they are not currently usable:
hidden source chains create hidden scrap items and hidden recycle recipes. The
generated recycle recipes intentionally do not set `enabled = false`; visibility
is controlled through `hidden` only. That keeps stable prototype names in saves
and lets later mod/config changes, or another mod in a later data stage, reveal
the recipes without having to migrate or recreate them. If the same material is
also found through a visible source, the visible source wins and the shared
generated scrap/recycle prototypes stay visible. The same rule applies to fluid
chains: an explicitly hidden fluid ingredient should keep the generated scrap
item and fluid recycle recipe hidden even when the visual source item is
visible.

K2 steel is the motivating edge case: vanilla should keep
`steel-scrap -> steel-plate`, while K2 can legitimately prefer
`steel-scrap -> kr-steel-beam` when the chain evidence shows that K2's visible
steel progression has moved there. The current passive analysis already reports
that difference without changing generated recipes.
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

The recipe-chain analysis exposes the first API controls for explicit solid and
fluid recycle targets. As the active resolver grows, mod authors still need more
ways to force, block, or redirect chain decisions without patching Ingredient
Scrap internals. Required or partially completed override areas:

- material inclusion/exclusion, including solid/fluid/none modes;
- explicit source prototypes or aliases for materials whose names do not follow
  detectable affixes;
- explicit solid and fluid recycle targets; done for target forcing/blocking;
- ingredient/result rewrites for known compat edge cases where a mod uses names
  that do not expose the intended material relation through affixes or recipe
  chains alone, for example pluralized or intermediate products;
- recipe-pattern or recipe-category deny/allow rules for artifact recipes such
  as barreling, recycling, crushing, burning, and matter conversion;
- score/priority overrides for ambiguous chains, for example ore vs. plate vs.
  ingot vs. mod-specific intermediates;
- category/machine support hooks so compat mods can define where generated
  recycle recipes should be craftable.

The passive analysis dump should report which decisions came from automatic
evidence and which were forced by API/compat rules.

## Future: Python Tool UI

The Tkinter tool shell currently starts with the mod-list manager, but the
Factorio-style top tab bar should become the shared navigation for other local
tools later. Keep the tab bar as the place where future tools such as settings
editing, debug dump viewers, test runners, or weight-tuning helpers are exposed.

The goal is a single local maintenance app with consistent Factorio-inspired
styling, not separate one-off windows for each script. New tools should register
their own frame with the shell and keep long-running work off the Tkinter event
loop, following the current mod-list UI pattern.

## Future: Debug Report Viewer

The data-table dump can become very large, especially with compat mods. A second
Lua dump would not make manual inspection much easier. Once the recipe-chain
analysis schema is stable, build a small local HTML viewer around JSON dumps
instead.

Useful viewer features:

- searchable/collapsible tree view for the full dump;
- focused tabs for analysis summary, material candidates, target differences,
  filters, current recycle targets, and target candidates;
- comparison mode for two dumps, for example vanilla vs. K2 or before/after a
  resolver change;
- evidence links from a material or target candidate back to recipes, name
  patterns, and filter reasons;
- visual highlighting for agreement with the current resolver, differing target
  suggestions, filtered candidates, and API/compat-provided materials.

## Future: Recipe-Chain Weight Tuner

The recipe-chain scoring knobs can be tuned offline once the passive analysis
and decider schemas are stable. A Python tool can read a predictable JSON dump,
compare suggested targets against a small golden table, and try different score
weights until the expected decisions improve.

This should remain a diagnostic helper, not an automatic source-code editor:

- Factorio produces the analysis dump from real prototypes;
- Python compares it against expected targets such as `iron -> iron-plate` or
  K2-specific `steel -> kr-steel-beam`;
- candidate weights are reported with the cases they improve or break;
- accepted weights are still reviewed and changed manually in the Lua resolver.

The tool should support separate Factorio installs or profiles so long-running
tuning does not block normal gameplay testing.

## Future: Preserve Recipe Shape

`Preserve recipe shape` is a good user-facing option name for keeping relevant
process ingredients and byproducts from the source production chain when
building scrap recycling recipes. This should be implemented carefully and in
small steps. The first pass should be diagnostic or test-only before changing
gameplay.

The intended staging model is simple: optional generated ingredients and results
can carry an internal `use` marker while they are still in
`yokmods.ingredient_scrap.data_table`. Before `data:extend`, the patcher removes
the marker. Entries with `use = true` are kept, entries with `use = false` are
dropped, and entries without `use` are treated as required.

Example staged recipe:

```lua
ingredients = {
  { type = "item", name = "tungsten-scrap", amount = 5 },
  { type = "item", name = "calcite", amount = 1, use = true },
},
results = {
  { type = "item", name = "tungsten-plate", amount = 5 },
  { type = "item", name = "slag", amount = 1, use = true },
}
```

Ratios must be derived from the source recipe shape. If preserving a process
ingredient or byproduct would create amounts below the valid minimum, the
required scrap input should be increased until all active optional entries have
valid amounts. For example, a recipe like `2 ore + 1 calcite -> 5 plate + 1 slag`
should scale recycling to a 5-plate unit before adding `calcite` and `slag`,
rather than producing fractional item amounts.

Initial constraints:

- keep the normal scrap material target logic authoritative;
- collect process ingredients and byproducts as supplementary evidence, not as
  normal solid/fluid material types;
- only preserve known or explicitly registered process materials at first;
- remove all internal `use` markers before generated prototypes reach
  Factorio;
- test both enabled and disabled variants of the option;
- start with fixed `amount` entries and handle `amount_min`, `amount_max`, and
  `probability` only after the base behavior is stable.

The recipe-chain analysis can already collect bounded recipe-shape evidence for
target candidates without making preserve-shape decisions. This evidence lives
on target candidates as `recipe_shape_evidence` and records:

- the source recipe name and category;
- the target result that caused the candidate;
- normalized ingredients with relation labels such as `material` or `other`;
- normalized results with relation labels such as `target`, `material`, or
  `other`;
- amount, range, and probability fields when they exist.

This is analysis evidence only. It must not write optional `use` markers or
modify generated recycling recipes until the decider intentionally writes those
entries into a data-table-shaped staging table.

Targeted structure:

collector()
  -> creates the current data_table

recipe_chain_analysis.build(data_table)
  -> writes to debug/evidence

recipe_chain_decider.build(analysis, data_table)
  -> writes passive decisions plus a data-table-shaped staged_data_table
  -> later can directly stage “recycle target,” “preserve shape,” and
     “supplements” without a separate translation pass

validate_generated_prototypes()
patch()

The passive decider should expose two views:

- a human-readable decision list grouped by mode, with actions such as
  `keep-current`, `review-difference`, and `analysis-only`;
- a `staged_data_table` shaped like the current operational `data_table`, with
  `materials`, `ingredients`, `prototypes`, and `inserts` keys.

The staged table is still passive evidence. It should be formatted closely
enough to the real data table that existing generator/patcher paths can consume
it later without a separate translation pass, but it must not be passed to
`data:extend` directly while the decider is passive.
