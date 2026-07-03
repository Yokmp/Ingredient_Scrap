# Design Notes

## Active: Recipe-Chain Based Recycle Target Analysis

## Current Roadmap

Use this section as the working order. The detailed notes below explain the
reasoning, edge cases, and future ideas.

### Release Gate

Do not publish the first public release until the current resolver and the
future ancestry-based solver have been compared at least passively. Generated
scrap items, recipes, technologies, logistic filters, requests, inventory
contents, and save references all depend on prototype names. Releasing one
naming model and switching later would require migration scripts and fragile
compat handling. Prototype names are not considered final until the
current-vs-ancestry comparison is complete.

### Next

1. Before active ancestry wiring (DONE):
   - 1.1. Stabilize the `data_table` boundary after the move into
     `code/core/data-table/`.
   - 1.2. Done: write new operational outputs through the writer instead of adding
     direct `data_table` writes.
   - 1.3. Planning: add only passive runtime comparison data until reasoning is
     raised to high and active ancestry wiring is explicitly started.
   - 1.4. Planning: preserve the current patcher contract; generated prototypes and
     `inserts.recipes` keep the same shape regardless of resolver.
2. Continue ancestry planning (DONE):
   - 2.1. Planning: name the future Lua modules for graph building, resolving, effective
     output, and mixed-scrap fallback.
   - 2.2. Planning: define which passive runtime comparison tables should be dumped before
     any active patching happens.
   - 2.3. Done: do not start active ancestry wiring until the user switches
     reasoning to high.
3. Keep broad compat review focused (DONE):
   - 3.1. Planning: use archived K2/Bob/Angels/Bob+Angels dumps and the viewer for review.
   - 3.2. Planning: record ambiguous chains as notes instead of adding one-off
     overrides.
   - 3.3. Planning: add compat/API rules only for stable facts that automatic
     evidence cannot infer reliably.
4. Release preparation (DONE):
   - 4.1. Done: restore `yis-hide-tech` behavior for generated recycling
     technologies.
   - 4.2. Done: update `deploy.py` ignore/strip rules for local tools, dumps,
     caches, local planning files, and debug regions.
   - 4.3. Done: produce `_release_/public/Ingredient_Scrap/` for public source
     and `_release_/Ingredient_Scrap_<version>.zip` for the Mod Portal.
   - 4.4. Done: keep public GitHub `main` separate from local
     development/source backup.
5. Before public release:
   - 5.1. Done: confirm generated prototype names and `yis-` prefix behavior
     are consistent for the current resolver.
   - 5.2. Done: no pre-release migration is needed; future public renames
     require Factorio migration scripts.
   - 5.3. Done: do not publish exact component scrap as final public behavior
     until it has been compared with ancestry/mixed-scrap behavior.
6. Continue runtime ancestry work (DONE for first active pass):
   - 6.1. Done: add Lua ancestry modules and write passive runtime ancestry
     output without changing generated prototypes.
   - 6.2. Done: compare runtime `ancestry-runtime.json` against offline
     `ancestry-flow-hybrid.json` for K2, Bob, Angels, and Bob+Angels profiles.
   - 6.3. Done: add `yis-ancestry-mode`, mapping the expected scrap mix to
     passive ancestry root policy, search depth, component fallback intent, and
     mixed limits.
   - 6.4. Done: wire active direct ancestry for non-`component-heavy` modes.
     Direct ancestry differences rewrite `data_table.inserts.recipes` through
     the data-table writer; mixed and unresolved rows keep the current Collector
     output until mixed-scrap behavior is implemented.
   - 6.5. Done: remove orphan generated exact-component scrap prototypes after
     active rewrites, so recipes no longer produced by any source insert cannot
     leave invalid recycle recipes behind.
7. Review active ancestry output:
   - 7.1. Done: compare active Bob/Angels and K2 dumps in the viewer and test
     harness. K2 remains unchanged; Bob+Angels Full applies direct ancestry to
     component families while keeping mixed/unresolved rows as current component
     scrap.
   - 7.2. Plan mixed-scrap fallback before deciding release behavior. Add
     explicit startup controls for ancestry search depth and output width, then
     calibrate their defaults against Base+DLC, K2, Bob, Angels, and Bob+Angels.
   - 7.3. Done: measure load-time cost of active ancestry and debug dumps.
     Main hotspots in debug/test mode are `data-final-fixes/serialize-data-table`
     and `data-updates/recipe-chain-analysis`; active direct ancestry is visible
     but smaller.

### Load-Time Snapshot

Measured on 2026-07-03 with `python tools/test/run_tests.py`, `IS_DEBUG=true`,
and `tools/toolset/is_timing.py` reading `factorio-current.log`.

| Profile | Factorio run | Biggest IS timing gaps |
| --- | ---: | --- |
| Base+DLC+IS default | 6.5s | serialize data-table 1.076s; recipe-chain analysis 0.534s; active ancestry 0.040s |
| Base+DLC+IS component-heavy | 6.5s | serialize data-table 1.146s; recipe-chain analysis 0.522s; active ancestry skipped |
| K2+IS default | 11.0s | serialize data-table 2.614s; recipe-chain analysis 1.960s; active ancestry 0.114s |
| K2+IS component-heavy | 9.7s | serialize data-table 2.193s; recipe-chain analysis 1.885s; active ancestry skipped |
| Bob+Angels Full+IS default | 23.3s | serialize data-table 6.154s; recipe-chain analysis 4.995s; active ancestry 0.874s |
| Bob+Angels Full+IS component-heavy | 23.5s | serialize data-table 6.918s; recipe-chain analysis 5.801s; active ancestry skipped |

Interpretation:

- Debug serialization is the largest controlled cost. The 30 MB
  `data-table.lua` dump dominates large mod mixes.
- Recipe-chain analysis is currently much more expensive than active direct
  ancestry in Bob+Angels Full.
- Active direct ancestry adds roughly 0.9s in the heavy profile, but total run
  time variance and debug dump size can hide this in wall-clock comparisons.
- Release stripping of debug regions should remove most dump/report overhead,
  but active ancestry still builds material and production flow in
  `data-updates.lua` for non-`component-heavy` modes and should be watched.
- The `component-heavy` rows are the best current proxy for the previous
  exact-component method. Older pre-timing-helper measurements were not kept in
  a structured form.

### Active Ancestry Review Snapshot

Measured on 2026-07-03 with `python tools/test/run_tests.py --profile default`.

- K2+IS: `160/160` tests pass. Active ancestry summary is `rewritten_recipes =
  0`, `applied_rows = 0`, `removed_orphans = 0`; all 253 comparison rows are
  already `same`.
- Bob+Angels Full+IS: `154/154` tests pass. Active ancestry summary is
  `rewritten_recipes = 442`, `applied_rows = 791`, `skipped_rows = 0`,
  `mixed_rows = 201`, `removed_orphans = 33`.
- Bob+Angels Full direct rewrite details are concentrated in expected component
  families: `electronic-circuit -> copper/iron/tin`,
  `bob-basic-circuit-board -> copper/iron`, cable variants -> their plated
  metals, batteries -> their metal/plastic components, and pipes/gears/bearings
  -> their base material.
- Mixed rows are now active. Broad or unresolved ancestry rows create
  `yis-mixed-scrap`; `yis-recycle-mixed-scrap` sorts it back into the currently
  used specific scrap families.
- A strict width test with Bob+Angels Full and `yis-ancestry-mixed-limit = 1`
  passes and raises `mixed_rows` from 201 to 370. Large machine recipes show
  mixed ranges such as `amount_min = 3`, `amount_max = 8`, which is useful
  evidence before deciding whether mixed-share rounding should use `floor` or
  `ceil`.
- Important debug caveat: `active_ancestry.comparison_summary` is built before
  rewrites in `data-updates.lua`, while `ancestry-runtime.json` is rebuilt after
  rewrites in `data-final-fixes.lua`. The post-rewrite runtime graph can see
  generated recycling results and produce misleading root aliases such as
  `electronic-circuit -> tin`, `battery -> steel`, or
  `bob-basic-circuit-board -> iron`. Use the active report and archived
  pre-active dumps for release decisions until the post-active debug comparison
  either reuses the pre-active graph or explicitly filters generated recycling
  recipes.

### Mixed-Scrap Fallback Direction

Mixed scrap should mirror the familiar Quality-DLC recycler pattern instead of
inventing a completely separate recovery mechanic. Ingredient Scrap should apply
that idea to the machines it already owns for recycling, such as furnaces,
assemblers, and foundries, not require the Quality recycler as the only path.

Two independent resolver controls are needed:

- ancestry search depth: how far an ingredient can be followed through
  producer recipes before it is kept as a component or becomes mixed;
- output width: how many distinct material families may be emitted directly
  before the result collapses to `yis-mixed-scrap`.

`yis-ancestry-mode` remains the friendly preset selector. The actual depth and
width now also exist as startup settings so balancing can be tested without
changing code. Defaults still need calibration against at least Base+DLC, K2,
Bob Full, Angels Full, and Bob+Angels Full.

Mixed-scrap recycling should reflect its source uncertainty. The first active
implementation generates a recycle recipe that returns a probability
distribution over the specific scrap families still produced by source recipes
in the current mod set. This keeps Mixed as a sorting step into known scrap
types rather than a direct plate/material shortcut.

Mixed output should also be allowed to flow through ancestry resolution as a
normal material family. If an ingredient already resolves to a composition that
contains `yis-mixed`, downstream recipes can preserve that mixed share instead
of replacing the whole output. Example shape:

```text
2 iron + 5 mixed -> 4 iron scrap + 10 mixed scrap
```

If a recipe ingredient is only mixed, the output rule is simple: keep it mixed
and scale by amount. If no mixed share appears and the output width is too high,
the resolver can try deeper ancestry first; when deeper resolution still exceeds
the width limit or becomes unresolved, the excess share collapses into mixed.
This makes mixed scrap a propagated remainder rather than an all-or-nothing
replacement.

Working mixed-output rules:

1. Pure known inputs and narrow output:
   - If the resolved ingredient composition contains only known material
     families, or only `yis-mixed`, and the resulting output width is within the
     configured limit, emit only the corresponding scrap families.
2. Mixed plus material inputs:
   - If the resolved input already contains `yis-mixed` plus known materials,
     keep the proportional relation. Known materials create their normal scrap;
     the mixed share creates `yis-mixed-scrap`.
   - Rounding for the mixed share is intentionally undecided until active dumps
     show how much mixed scrap appears in extreme recipes. Start with one
     central rounding helper so `floor`/`ceil` can be swapped after review; any
     non-zero mixed share must still yield at least one result when it is
     actually emitted.
3. Pure material inputs but output too wide:
   - If no mixed share exists and the resolved output is still wider than the
     configured output width, collapse the whole over-wide output to
     `yis-mixed-scrap`.
   - This is less elegant than keeping the top N materials, but it is the safer
     first implementation because it avoids pretending the discarded tail was
     precisely known.

Mixed-scrap recycling is similar to the Quality-DLC scrap recycling pattern:
one generated `yis-recycle-mixed-scrap` recipe with possible results for all
known material scrap families still used in the current mod set. The current
first pass assigns each possible result `amount = 1` and `probability =
1 / result_count`, so expected total output stays near one sorted scrap item.
The existing recycle-amount patcher then adjusts the required
`yis-mixed-scrap` input from observed source recipe output.

Mixed source recipe amounts are intentionally written as internal pseudo
results. Each mixed contribution keeps its source ingredient in the staged name,
for example `yis-mixed-scrap_processing-unit`. Before Factorio receives the
recipe, each pseudo result is normalized after all recipe results are present.
The patcher then derives the final result name by taking everything before the
last `_`, merges matching entries, strips internal `yis_*` fields, and inserts
one valid `yis-mixed-scrap` result. This preserves per-ingredient
debug/balancing hooks while keeping the actual prototype output clean.

Furnace output slots are adjusted after patching, not during collection. The
patcher measures the final item-result width per recipe category after Mixed
pseudo-results have been merged, then raises `result_inventory_size` only on
furnaces that support a category whose widest recipe needs more slots. Input
inventory size is intentionally ignored because Ingredient Scrap does not add
extra ingredients; even future preserve-shape logic should replace ingredients
rather than increasing ingredient-slot width.

#### 1.1 Data-Table Boundary

Goal: the `data_table` move should remain a mechanical structure change, not a
behavior change.

Rules:

- `code/core/data-table/init.lua` owns the initial table shape.
- `code/core/data-table/writer.lua` owns semantically important writes.
- Existing collector/generator behavior remains authoritative.
- Debug dumps, patcher, and analysis code may still read plain tables directly.
- No active ancestry behavior belongs in this step.

Acceptance checks:

- No old `code.core.data-table-writer` require paths remain.
- The default Factorio harness passes.
- The full profile harness passes before larger follow-up refactors.
- Future code that writes inserts or generated prototypes uses the writer.

#### 1.2 Operational Writes Through Writer

Goal: new behavior should not create another style of operational
`data_table` mutation. The writer is the single entry point for inserts,
generated prototypes, and generated-prototype debug sources.

Status: done for the current active hotspots. `apply_recipe_chain_targets()`
now uses the writer for generated recipe lookup and debug-source updates.
Technology generation no longer creates temporary empty technology entries
directly in `data_table.prototypes.technology`.

Operational writes that should use `code/core/data-table/writer.lua`:

- source recipe insert creation and scrap-result accumulation;
- generated item, recipe, and technology storage;
- generated recipe source metadata;
- source ingredient tracking and source-filter skip records;
- active recipe-chain target application;
- future active ancestry/effective-output writes.

Allowed direct table access:

- patcher iteration over completed generated prototypes and inserts;
- debug/report builders that read broad table sections;
- passive analysis staging tables that are not passed to `data:extend`;
- API accessors that intentionally return staging tables to compat code;
- direct writes inside the writer itself.

Acceptance checks:

- No active/generated recipe or technology mutation outside the writer unless
  the code is only modifying a prototype object already returned by the writer.
- Passive staged evidence remains clearly separate from operational data.
- Default and full Factorio harnesses pass after any writer-boundary refactor.

#### 1.3 Passive Runtime Comparison Data

Goal: prepare the runtime-side evidence shape for ancestry comparison without
activating ancestry behavior or changing generated prototypes.

Status: planning only. Do not implement the active ancestry resolver until
reasoning is raised to high.

Runtime passive comparison should eventually live under:

```lua
data_table.debug.passive_runtime = {
  schema = "ingredient-scrap-passive-runtime/v1",
  ancestry = {
    summary = {},
    comparisons = {},
    items = {},
  },
}
```

The runtime ancestry comparison should mirror the offline
`tools/toolset/ancestry_flow.py` output closely enough that both can be compared
profile-by-profile:

- `profile` or active mod summary;
- `root_policy`;
- `mixed_limit`;
- `summary`;
- `items`;
- `comparisons`.

Each comparison row should contain:

- source `recipe`;
- matched `ingredient` and `ingredient_amount`;
- current generated scrap material(s);
- passive ancestry material composition;
- passive `effective_output`;
- resolver status and reasons;
- no patching action.

The runtime comparison must stay separate from operational tables:

- do not write passive ancestry results to `data_table.inserts.recipes`;
- do not create generated prototypes from passive ancestry rows;
- do not mutate existing generated recipes;
- do not let the patcher read `data_table.debug.passive_runtime`.

The first passive runtime implementation should reuse current material-flow
evidence where possible:

- current output comes from `data_table.inserts.recipes` and
  `data_table.debug.sources.inserts`;
- recipe graph input comes from `data.raw.recipe`, `data.raw.item`, and
  `data.raw.fluid`;
- root/material stop rules come from current material overrides and resolver
  affixes/aliases;
- effective output uses the same mixed-limit rules as the offline tool.

Acceptance checks before active ancestry wiring:

- Base+DLC runtime passive summary matches the offline `is_sa` ancestry profile.
- K2 runtime passive summary matches the offline `krastorio_is` ancestry profile.
- Bob/Angels profile summaries match the archived offline profiles closely
  enough that differences are explainable by changed mods or settings.
- Test report and material-flow dump can expose the passive summary, but no
  generated recipe, item, technology, or source recipe result changes.

#### 1.4 Patcher Contract

Goal: every resolver path must present the same operational data-table shape to
the patcher. The patcher should not become a resolver and should not need to
know whether entries came from the current collector, recipe-chain decisions,
future ancestry decisions, or API overrides.

Status: planning/contract. The existing patcher remains unchanged unless a
future implementation finds a specific validation gap.

Operational inputs consumed by the patcher:

```lua
data_table.prototypes.items[name] = item_prototype
data_table.prototypes.recipes[name] = recipe_prototype
data_table.prototypes.technology[name] = technology_proto
data_table.inserts.recipes[source_recipe_name] = {
  main_product = "result-name",
  results = {
    {
      type = "item",
      name = "yis-iron-scrap",
      amount = 1,
      amount_min = nil,
      amount_max = nil,
      probability = 0.24,
    },
  },
}
```

Generated prototype contract:

- table key and prototype `name` must match;
- generated items must have `type = "item"`, `stack_size > 0`, and `icon` or
  `icons`;
- generated recipes must have `type = "recipe"`, ingredients, results, and a
  category;
- generated technologies must have `type = "technology"`, effects, and a
  `research_trigger`;
- generated recipes and technologies may be `hidden`, but should generally not
  be `enabled = false`;
- disabled generated prototypes are warnings, not hard errors, because API or
  compat mods may intentionally stage them that way.

Source insert contract:

- only existing source recipes may be patched;
- Quality/recycling recipes must not receive extra Ingredient Scrap results;
- `main_product` is copied to the source recipe when the insert is applied;
- each scrap result is appended only if the source recipe does not already
  contain a result with the same name;
- range mode uses `amount_min`/`amount_max`;
- fixed mode uses `amount`;
- `probability` is optional and should be omitted only when Factorio defaults
  are intended.

What the patcher may read:

- `data_table.prototypes.*`;
- `data_table.inserts.recipes`;
- generated prototype debug sources only for validation warnings/errors.

What the patcher must not read:

- `data_table.debug.passive_runtime`;
- passive recipe-chain or ancestry staged tables;
- material-flow or production-flow debug dumps;
- resolver-specific scoring/evidence tables.

Future resolver requirement:

- If a resolver wants to become active, it must write the same prototype and
  insert shape through `code/core/data-table/writer.lua`.
- If a resolver only produces evidence, it must stay under `data_table.debug`
  and must not be visible to the patcher.
- Any new optional internal fields on generated ingredients/results, such as
  future `use` markers for preserve-shape, must be stripped before `data:extend`
  or before source recipes are patched.

Acceptance checks:

- `patcher.validate_generated_prototypes(data_table)` stays green.
- The full Factorio harness passes.
- A diff of `test-report.json`, `material-flow.json`, and generated prototype
  counts shows no behavior change for passive-only resolver work.

#### 2.1 Ancestry Module Layout

Goal: name the future runtime ancestry modules before any active implementation
starts. This keeps the later high-reasoning implementation from turning into a
large undifferentiated solver file.

Planned folder:

```text
code/core/ancestry/
  graph.lua
  roots.lua
  resolver.lua
  effective-output.lua
  comparison.lua
  mixed.lua
```

Module responsibilities:

- `graph.lua`
  - Build item/fluid producer indexes from `data.raw.recipe`.
  - Filter generated Ingredient Scrap recipes and obvious side chains.
  - Keep normalized recipe ingredients/results and weak recipe metadata.
- `roots.lua`
  - Build root/stop aliases from current material overrides, resources, and
    stable material matches.
  - Keep the root policy explicit: `current`, `resources`, or `hybrid`.
  - Keep exact-component handling separate from stable material stops.
- `resolver.lua`
  - Resolve one item/fluid prototype to a material composition.
  - Track status, recursion depth, cycles, chosen producer recipe, deferred
    fluids, unresolved inputs, and reasons.
  - Cache resolved prototypes for performance.
- `effective-output.lua`
  - Convert a resolved composition into direct material scrap or fallback scrap.
  - Apply mixed-limit rules.
  - Preserve enough reason data to explain why output became mixed.
- `mixed.lua`
  - Own fallback material/prototype names such as `yis-mixed` and
    `yis-mixed-scrap`.
  - Later, define fallback recycle recipe/technology behavior if mixed scrap
    becomes active.
- `comparison.lua`
  - Compare current collector output with passive ancestry/effective output.
  - Build `data_table.debug.passive_runtime.ancestry`.
  - Stay passive; never write to `data_table.inserts.recipes`.

Dependency direction:

```text
graph.lua
roots.lua
  -> resolver.lua
resolver.lua
mixed.lua
  -> effective-output.lua
effective-output.lua
  -> comparison.lua
comparison.lua
  -> data_table.debug.passive_runtime only
```

The runtime modules should be modeled after the offline
`tools/toolset/ancestry_flow.py`, but not mechanically ported line-by-line. The
Lua version must use real `data.raw` prototypes, current override state, and the
data-table writer boundary.

Post-implementation review gate:

- After the runtime ancestry resolver exists and matches the offline profiles,
  review which parts of the current system it can replace.
- Candidate replacements:
  - exact component-family scrap;
  - some prefix/suffix material inference;
  - parts of recipe-chain target scoring;
  - some broad compat target overrides.
- Likely remaining pieces:
  - API hard facts and overrides;
  - source filters;
  - category/machine support;
  - debug/report tooling;
  - special process/chemistry/preserve-shape rules.
- If method 1 and method 2 become mostly redundant, consolidate what remains
  into smaller focused modules instead of carrying three parallel resolver
  systems forever.

#### 2.2 Passive Runtime Dump Tables

Goal: define the passive runtime output shape before implementing it. The first
runtime ancestry pass should be measurable, comparable, and viewer-friendly
without changing any recipe, item, technology, or source recipe result.

Primary data table location:

```lua
data_table.debug.passive_runtime = {
  schema = "ingredient-scrap-passive-runtime/v1",
  ancestry = {
    profile = nil,
    active_mods = {},
    root_policy = "hybrid",
    mixed_limit = 3,
    max_depth = 8,
    root_aliases = {},
    exact_components = {},
    summary = {},
    items = {},
    comparisons = {},
    effective_outputs = {},
  },
}
```

Full JSON dump:

```text
script-output/Ingredient_Scrap/ancestry-runtime.json
```

This file should mirror the offline `ancestry-flow*.json` structure closely
enough that the same review tooling can compare:

- offline `tools/toolset/dumps/<profile>/ancestry-flow-hybrid.json`;
- runtime `script-output/Ingredient_Scrap/ancestry-runtime.json`.

Summary-only report data:

```lua
test_report.passive_runtime = {
  ancestry = {
    schema = "...",
    root_policy = "hybrid",
    mixed_limit = 3,
    summary = {},
  },
}
```

The test report should not embed the full comparison list by default. It should
only expose enough to assert that passive runtime analysis ran and produced the
expected headline counts.

Comparison row shape:

```lua
{
  status = "same" | "different" | "unresolved",
  recipe = "source-recipe-name",
  ingredient = "input-name",
  ingredient_type = "item" | "fluid",
  ingredient_amount = 1,
  current = {
    ["iron"] = 1,
  },
  ancestry = {
    ["iron"] = 1,
  },
  effective_output = {
    kind = "direct" | "mixed",
    reason = "within-limit" | "width-limit" | "unresolved",
    width = 1,
    materials = {
      ["iron"] = 1,
    },
  },
  resolve_status = "root" | "resolved" | "composed" | "unresolved" | "cycle" | "depth-limit",
  resolve_recipe = "producer-recipe-name",
  reasons = {},
}
```

Item resolve cache shape:

```lua
items = {
  ["iron-gear-wheel"] = {
    status = "resolved",
    composition = {
      iron = 2,
    },
    recipe = "iron-gear-wheel",
    reasons = {},
    ingredients = {},
  },
}
```

Summary shape:

```lua
summary = {
  comparisons = {
    same = 0,
    different = 0,
    unresolved = 0,
  },
  effective_outputs = {
    direct = 0,
    mixed = 0,
  },
  effective_reasons = {
    ["within-limit"] = 0,
    ["width-limit"] = 0,
    unresolved = 0,
  },
  resolved_items = {
    root = 0,
    resolved = 0,
    composed = 0,
    unresolved = 0,
  },
  ancestry_widths = {},
  max_ancestry_width = 0,
}
```

Viewer/export integration:

- `material-flow.json` may include a compact
  `passive_runtime_summary.ancestry` block for quick sidebar display.
- `ancestry-runtime.json` should contain the full comparison data.
- The tree viewer can load `ancestry-runtime.json` as an ancestry/comparison
  mode later, instead of overloading material-flow rows.
- The UI/tool runner may copy profile-specific files such as
  `ancestry-runtime-bob_angels_full_is.json` next to material/production-flow
  dumps.

Strict passive rules:

- Do not write ancestry output to `data_table.inserts.recipes`.
- Do not create `yis-mixed-scrap` from passive rows yet.
- Do not mutate generated recycle recipes.
- Do not alter source recipe results.
- Do not require the patcher to understand this table.

Acceptance checks:

- Runtime summary keys match offline `ancestry_flow.py` summary keys.
- Base+DLC and K2 runtime summaries match archived offline profiles.
- Full comparison dumps are only written when debug/test output is enabled.
- The normal test harness still reports identical generated prototype counts
  before and after passive runtime dumps are enabled.

#### 2.3 Active Ancestry Start Guard

Goal: prevent the passive planning work from sliding into active resolver
implementation without an explicit reasoning and user-confirmation checkpoint.

Status: done as a process guard.

Stop before implementing any of these:

- creating `code/core/ancestry/*.lua` runtime modules;
- running ancestry logic in the data stage;
- writing ancestry-derived results to `data_table.inserts.recipes`;
- creating `yis-mixed-scrap`, mixed recycle recipes, or mixed technologies;
- changing collector behavior based on ancestry output;
- changing patcher behavior to understand ancestry-specific data.

Before any of those begin:

1. Tell the user that active ancestry wiring is about to start.
2. Ask the user to switch reasoning to high.
3. Re-read the latest `DESIGN_NOTES.md` sections:
   - `1.3 Passive Runtime Comparison Data`;
   - `1.4 Patcher Contract`;
   - `2.1 Ancestry Module Layout`;
   - `2.2 Passive Runtime Dump Tables`;
   - `Future: Ancestry-Based Scrap Solver`.
4. Start with passive runtime output only. Active patching comes later and only
   after passive runtime summaries match the offline profiles.

Allowed at medium reasoning:

- planning module names and schemas;
- editing notes;
- adding tests for existing behavior;
- improving tools that read existing dumps;
- non-behavioral refactors that keep the current harness green.

#### 3.1 Compat Review Inputs

Goal: keep broad compat review evidence-based. Use archived dumps and viewer
outputs first, then decide whether a case is a real compat rule, a future
extension, or simply noise.

Archived profiles currently available:

```text
tools/toolset/dumps/is_sa/
tools/toolset/dumps/krastorio_is/
tools/toolset/dumps/bobs_full_is/
tools/toolset/dumps/angels_full_is/
tools/toolset/dumps/bob_angels_full_is/
```

Old minimal Bob/Angels dumps were moved to `_legacy/static/dumps/`.

Primary review files per profile:

- `material-flow.json`: current Ingredient Scrap source flows, scrap outputs,
  recycle recipes, skipped sources, resources by material, and active mods.
- `production-flow.json`: neutral recipe/item/fluid graph with classifications.
- `ancestry-flow-hybrid.json`: offline ancestry comparison using the planned
  hybrid policy.

Primary stress profile:

- `bob_angels_full_is` is the broadest currently installed compat profile and
  should be used for stress review.

Control profiles:

- `is_sa`: Base + DLC control.
- `krastorio_is`: first non-trivial mod sanity profile.
- `bobs_full_is` and `angels_full_is`: isolate each large mod family before
  looking at the combined Bob+Angels profile.

Viewer workflow:

1. Open `material-flow.json` to review current scrap source flows and recycle
   targets.
2. Open `production-flow.json` to inspect producer/consumer context and
   classification reasons.
3. Open `ancestry-flow-hybrid.json` to compare current exact/component scrap
   against ancestry effective output.
4. Only after checking at least material-flow and production-flow should a case
   become a compat/API candidate.

Review buckets:

- `stable_fact`: hard compat fact suitable for API/override code.
- `ambiguous_chain`: needs note or future ancestry/preserve-shape handling.
- `future_extension`: chemistry, slurry, slag, catalyst, fluid waste, advanced
  recycling, or preserve-shape territory.
- `false_positive`: should be filtered or ignored.
- `expected_behavior`: keep as-is and maybe document.

Acceptance checks:

- Review decisions cite the profile and dump file used.
- No one-off override is added from a single confusing row without checking
  producer/consumer context.
- Combined Bob+Angels cases are checked against Bob-only and Angels-only when
  the source of the behavior is unclear.
- Active ancestry guard remains in effect; compat review may inspect ancestry
  dumps but must not implement runtime ancestry modules.

#### 3.2 Ambiguous Chain Notes

Goal: suspicious recipe chains should become searchable review notes before
they become compat code. This keeps broad mod support from turning into a pile
of one-off fixes.

Record a note when a chain is surprising but not yet proven wrong. Good
examples:

- a recipe name suggests one material but the actual ingredients/results point
  to another material;
- a material appears as both a resource-processing intermediate and a real
  crafting component;
- a fluid, chemical, catalyst, slag, slurry, or waste-like result looks like
  `future_extension` territory;
- Bob+Angels combined behavior differs from Bob-only or Angels-only behavior;
- ancestry output and current resolver output disagree, but both are plausible.

Suggested note shape:

```text
- id:
  profile:
  dump_files:
  source_recipe:
  observed_chain:
  current_behavior:
  expected_or_possible_behavior:
  bucket:
  decision:
  next_action:
```

Use the review buckets from 3.1:

- `stable_fact`: can become API/compat code once verified across the relevant
  profile(s).
- `ambiguous_chain`: keep as note and revisit after ancestry/preserve-shape
  work.
- `future_extension`: park for chemistry, fluids, advanced recycling, or
  preserve-shape.
- `false_positive`: candidate for a source filter, ignore rule, or explicit API
  override.
- `expected_behavior`: no code change; document only if players may wonder
  about it.

Escalation rules:

- A case may become compat/API code only after checking `material-flow.json` and
  `production-flow.json`.
- If the case appears in `bob_angels_full_is`, compare with Bob-only and
  Angels-only where practical.
- If the issue is a hidden/disabled compatibility stub, prefer a filter or
  weight/evidence rule over a material-specific override.
- If the issue is chemistry, catalyst, slurry, slag, acid, waste, or fluid
  treatment, do not force it into core metal scrap unless there is a stable
  gameplay reason.
- If a generated prototype would be invalid, points at a missing icon, or
  creates an impossible recipe, treat it as `false_positive` and fix the guard
  before adding more compat data.

Acceptance checks:

- Ambiguous chains are searchable by profile, recipe name, and bucket.
- No compat rule is added without a note or directly cited dump evidence.
- The note states whether the next action is code, documentation, future work,
  or no action.
- Active ancestry guard remains in effect.

#### 3.3 Stable Compat/API Rule Criteria

Goal: compat code should describe stable facts, not temporary guesses from one
viewer session.

Stable facts are things automatic evidence is unlikely to infer reliably:

- exact material aliases, especially singular/plural or mod-prefix cases such
  as `rare-metals`;
- exact source-to-target decisions where two plausible products share the same
  material family;
- mod-specific prototype naming rules that are consistent across that mod;
- known disabled or hidden compatibility stubs that should be penalized or
  ignored;
- explicit source filters for families that are never useful scrap materials;
- category rules for mod machines where type and crafting category are both
  needed to decide item/fluid recycling support;
- icon/tint facts that cannot be discovered safely from generic affixes.

Do not add compat/API rules for:

- a single confusing recipe name if ingredients/results already explain the
  behavior;
- chemistry, slurry, slag, catalyst, acid, waste, or fluid-treatment chains
  that belong in a later extension;
- hidden `Factoriopedia` behavior or player-crafting visibility alone;
- recipe-shape preservation questions, such as keeping `calcite` for tungsten,
  until the preserve-shape task starts;
- ancestry-derived decisions while the active ancestry guard is still in
  effect.

Preferred rule order:

1. Source filters for whole unwanted prototype families.
2. Material aliases or exact material definitions.
3. Recipe-chain target overrides for hard target facts.
4. Category rules for machine support.
5. Icon/tint metadata.
6. Weight/evidence tuning only when the bias is systematic and repeatable.

Minimum evidence before adding a rule:

- profile name;
- dump file(s) used;
- source recipe or prototype name;
- current generated behavior;
- desired behavior;
- reason the automatic resolver cannot infer this safely.

Acceptance checks:

- Each new compat/API rule maps to a stable fact entry or directly cited dump
  evidence.
- Rules remain mod-scoped where possible.
- Rules avoid changing vanilla/DLC behavior unless the control profile shows
  the same issue.
- Active ancestry guard remains in effect.

#### 4.1 Hide-Tech Release Behavior

Status: done. Generated recycling technologies now use `yis-hide-tech` again:

```lua
hidden = ISsettings.hide_tech == true and ISsettings.shallow_log == false
```

This keeps release/default player behavior clean when `yis-hide-tech` is active,
while short logging still overrides the setting and keeps generated technologies
visible during in-game debugging.

Test coverage:

- `default`: `shallow_log = true`, technologies stay visible.
- `hide_tech_quiet`: `shallow_log = false`, `yis-hide-tech = true`,
  technologies are hidden.
- `tools/test/run_tests.py --all --no-color`: all profiles passed after the
  change.

#### 4.2 Deploy Ignore And Strip Rules

Status: done for the Mod Portal ZIP path. `deploy.py` now uses explicit
path-aware release filters instead of the older broad substring blacklist.

Excluded from release ZIPs:

- local tool/test folders such as `tools/` and `test/`;
- generated caches such as `__pycache__/`, `.pytest_cache/`, and `.mypy_cache/`;
- editor, Git, and local agent folders;
- local scripts and source assets such as `.py`, `.pyc`, `.xcf`, and `.7z`;
- local screenshots matching `shot_` or `shot-`;
- local planning/repo files such as `DESIGN_NOTES.md`, `.gitignore`, and
  `.gitattributes`;
- `locale/en/test.cfg`.

Lua files are copied through the debug-region stripper. Everything between
`--#region debug` and `--#endregion` is removed for the release ZIP. Empty Lua
files after stripping are skipped.

Verification:

- `python deploy.py` created `_release_/Ingredient_Scrap_2.0.0.zip`.
- ZIP audit found 123 entries, 0 suspicious tool/cache/test/planning files, and
  0 remaining debug-region markers.

#### 4.3 Public Source And Mod Portal ZIP

Status: done. `deploy.py` now writes both release artifacts from the same
filtered and debug-stripped file set:

- `_release_/public/Ingredient_Scrap/`: clean public source folder intended for
  the public GitHub branch.
- `_release_/Ingredient_Scrap_<version>.zip`: versionspaced Mod Portal ZIP.

The public source folder is rebuilt on each deploy run. The ZIP is created by
copying that public source folder into a temporary versionspaced directory, so
both outputs use the same release filters and debug-region stripping.

Verification:

- `python deploy.py` created `_release_/public/Ingredient_Scrap/`.
- `python deploy.py` created `_release_/Ingredient_Scrap_2.0.0.zip`.
- Public source and ZIP contain the same 123 release files.
- ZIP audit found 0 suspicious tool/cache/test/planning files and 0 remaining
  debug-region markers.

#### 4.4 Public Main Separation

Status: done as a documented workflow. The local working branch is `dev`, and
`_release_` is ignored by Git. This keeps local development files, tools, dumps,
and generated release artifacts out of the public branch unless they are copied
intentionally.

Intended branch split:

- `dev`: full development workspace, including tools, tests, notes, dumps,
  debug helpers, and local release tooling.
- `main`: public production mod source only.
- Mod Portal ZIP: `_release_/Ingredient_Scrap_<version>.zip`.
- Public source candidate:
  `_release_/public/Ingredient_Scrap/`.

Recommended publication workflow:

1. Work and test on `dev`.
2. Run `python deploy.py`.
3. Review `_release_/public/Ingredient_Scrap/`.
4. Copy the contents of `_release_/public/Ingredient_Scrap/` into a separate
   `main` checkout or worktree.
5. Commit that clean production source on `main`.
6. Upload `_release_/Ingredient_Scrap_<version>.zip` to the Mod Portal.

Do not merge the whole local `dev` tree into `main`. The public source folder is
the boundary between local development/backups and the published mod source.

#### 5.1 Generated Prototype Names And Prefixes

Status: done for the current resolver. Generated Ingredient Scrap-owned
prototypes use the mod-owned `yis-` prefix consistently:

- scrap items: `yis-<material>-scrap`;
- recycle recipes: `yis-recycle-<material>-scrap`;
- fluid recycle recipes: `yis-recycle-<material>-scrap-to-fluid`;
- recycle technologies: `yis-recycle-<material>-scrap`.

The name helpers strip an existing `yis-` material prefix before composing a
prototype name, then add the mod-owned prefix only once. This protects API and
test materials such as `yis-testium` from becoming `yis-yis-testium-scrap` or
`yis-recycle-yis-testium-scrap`.

Harness coverage:

- prefixed and unprefixed material inputs both produce the same generated names;
- generated item, recipe, and technology staging tables do not contain
  double-prefixed `yis-yis-*` names;
- full harness passed with 10 profiles and 144 assertions per profile.

Release caveat:

- These names are consistent for the current resolver.
- The public release is still blocked by the release gate until current
  resolver output and the future ancestry-based solver have been compared and a
  final naming strategy is chosen.

#### 5.2 Migration Policy

Status: done. The old pre-release `2.0.0-yis-prefix-rename` migration was
removed because existing saves are only test saves and can be recreated. Built
test setups are preserved as blueprints where needed.

Migration policy:

- Before the first public release, development saves may break and be recreated.
- Do not carry migrations for prototype names that were never part of a public
  release.
- After the first public release, any rename of generated scrap items, recycle
  recipes, technologies, mixed-scrap prototypes, or other save-relevant
  prototypes must ship with a Factorio migration.
- Prototype names should therefore stay frozen once published, unless a
  migration is explicitly planned and tested.

#### 5.3 Exact Component Scrap Release Decision

Status: decided. Do not publish the current exact-component behavior as the
final public release behavior before it has been compared with the
ancestry/mixed-scrap approach.

Reasoning:

- A public release with exact component scrap would freeze save-relevant
  prototype names such as `yis-bob-titanium-bearing-scrap`.
- Switching later to ancestry output such as `yis-titanium-scrap` or
  `yis-mixed-scrap` would require migrations and would change gameplay more
  than a normal balancing update.
- Supporting both behaviors as player-facing options would add settings,
  compat branches, migration edge cases, and documentation burden.
- There is no release pressure, so it is safer to compare both approaches before
  freezing public behavior.

Current policy:

- Exact component scrap remains a development/current-resolver behavior only.
- The first public release should wait until the ancestry/mixed-scrap comparison
  is complete and the final prototype naming model is chosen.
- If exact component scrap survives, it should survive because it won the
  comparison, not because it shipped first.

Potential player setting:

- Prefer a dropdown that describes the expected scrap mix instead of exposing a
  raw recursion depth number.
- Example labels:
  - `++ component scrap, scrap, - mixed`
  - `+ component scrap, + scrap, mixed`
  - `component scrap, ++ scrap, + mixed`
- More `+` means that scrap family is expected to appear more often.
- `-` means that scrap family is expected to be avoided, not that it is
  impossible.
- The setting description must say that the exact output is not guaranteed.
  Recipe graphs, unresolved chains, mixed limits, fluids, and compatibility
  rules can still change which scrap is generated.
- Internally this can still map to ancestry search depth, mixed-output limits,
  and exact-component fallback rules.

### Later

1. Test Angels and Bobs after the decider has enough API escape hatches.
2. Split long documentation into `docs/`:
   - API details;
   - compat strategy;
   - testing/debugging;
   - recipe-chain design.
3. Build a JSON/HTML dump viewer after the analysis schema stabilizes.
4. Build a Python weight tuner after a golden-table test set exists.
5. Implement `Preserve recipe shape` in small tested steps. Keep this behind the
   current compat/source-filter work. The feature is desirable for cases such as
   tungsten production, where `calcite` is a process ingredient and should
   likely remain required when recycling tungsten scrap, but it reintroduces
   recipe-chain, ore/resource, ratio, byproduct, and technology questions.
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

### Done

1. Test harness:
   - Factorio-runner creates temporary saves, writes JSON/Lua reports, formats
     terminal output, cleans temp saves, and supports profile runs.
   - Synthetic Testium fixtures cover fixed/ranged amounts, mixed solid/fluid
     inputs, unlock techs, settings profiles, category patching, and edge cases.
2. Data-table/debug infrastructure:
   - `data_table.lua`, `material-flow.json`, and `production-flow.json` dumps.
   - `data_table.debug.sources.skipped` audit trail for source-filter skips.
   - Timing/logging helpers and debug-region stripping plan for release builds.
3. Tooling:
   - Factorio-style local tool UI, mod-list/profile helpers, material-flow dump
     runner, JSON/tree/production viewer, and ancestry-flow offline reviewer.
   - Archived compat dumps for Base+DLC, K2, Bob, Angels, and Bob+Angels
     profiles under `tools/toolset/dumps/`.
   - Debug-only `/is-debug-inventory` runtime command for manual test saves.
     It inserts one stack of every generated scrap item, one stack of every
     `*-ore`, one stack of every item that places an assembling machine or
     furnace, plus coal, personal roboport equipment, battery MK2 equipment, and
     50 construction robots. The command is inside `--#region debug` and is
     removed from release builds.
4. Core resolver hardening:
   - Solid/fluid material split, prefix/suffix/alias resolver, `-bar` support,
     source filters, ore-source suppression, Quality recycling side-chain
     filtering, and hidden/disabled prototype handling.
   - `yis-` prefix for generated scrap items, recycle recipes, and
     technologies.
5. Compat/API:
   - Material override API, category API, source-filter API, recipe-chain target
     API, nested public wrappers, and README API documentation.
   - K2 and Bob/Angels compat smoke work for glass, silicon, rare metals,
     prefixed metals/alloys, component families, and ore false positives.
6. Recipe-chain analysis:
   - Passive recipe indexes, target candidates, material candidates, production
     classification, active-candidate staging, recipe-shape evidence, and
     recipe-chain setting.
7. Component review:
   - Exact component-family scrap avoids broad tier collapse for batteries,
     bearings, cables, circuits, gears, pipes, and related Bob/Angels
     components.
8. Internal structure:
   - `code/core/data-table/init.lua` and `code/core/data-table/writer.lua`
     isolate data-table initialization and semantically important writes.
9. Ancestry research:
   - Offline `ancestry_flow.py` compares current output with hybrid ancestry
     effective output and writes review files.
   - Hybrid baseline is stable for Base+DLC, K2, Bob-only, and Angels-only; the
     combined Bob+Angels profile exposes the remaining component/mixed-scrap
     design questions.

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

Current recipe-chain design rules:

- The current resolver remains authoritative unless a tested setting or future
  resolver profile explicitly changes that.
- Passive analysis may dump evidence, candidates, and differences, but must not
  patch recipes by itself.
- Target analysis is split by solid/fluid mode. Solid target analysis filters
  obvious artifacts such as barrels, Quality recycling, science packs, fuel
  cells, equipment, matter conversion, dirty-water recovery, and generic test
  products.
- `main_product` is metadata and weak evidence, not a filter. Analysis should
  index all recipe results, including byproducts and probabilistic outputs.
- `enabled = false`, `hide_from_player_crafting`, and
  `hidden_in_factoriopedia` are not target-quality failures. Explicit
  `hidden = true` is stronger evidence for internal stubs or player-facing
  artifacts.
- Hidden source chains may still generate hidden scrap/recycle prototypes.
  Generated recycle recipes should stay present and use `hidden`, not
  `enabled = false`, for visibility control.
- Barreling and Quality recycling should stay visible in debug/side-chain
  views, but should not become normal material evidence without explicit rules.

Current recycle target priority for solid materials:

1. `<material>-plate`
2. `<material>-ingot`
3. `<material>-ore`
4. `<material>`
5. the matched ingredient itself

This keeps common cases such as `iron-scrap -> iron-plate` stable and avoids
making basic recycling depend on later processing chains or fluid handling.

Recipe-chain/API escape hatches already exist for:

- material inclusion/exclusion with solid/fluid/none modes;
- explicit source aliases and exact source prototypes;
- explicit solid/fluid recycle targets through
  `api.register.recipe_chain.solid.to_item/to_fluid`,
  `api.register.recipe_chain.fluid.to_item/to_fluid`, and matching
  `api.ignore.recipe_chain.*` wrappers;
- source recipe/category filters for cases where a recipe should not receive
  scrap even though the material target is valid;
- category/machine support hooks for generated recycle recipe availability.

Future API candidates:

- ingredient/result rewrites for compat cases that cannot be expressed through
  aliases or target overrides;
- score/priority overrides for ambiguous chains;
- pattern-level allow/deny rules for barreling, crushing, burning, matter
  conversion, and other artifacts.

Important test fixtures for any future active chain resolver:

- simple ore -> plate;
- one resource with multiple valid products;
- tech-gated intermediate chains;
- fluid intermediate chains similar to holmium solution;
- modded dust/crushed/ingot targets.

Resolver decisions should log through `code.lib.is-log` so
users can see why a recycle target was selected.

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
- technology view links from origins and unlocks into the matching JSON entry or
  related dump, once the viewer has a shared index across separate dump files;
- visual highlighting for agreement with the current resolver, differing target
  suggestions, filtered candidates, and API/compat-provided materials.
- Try a dropdown selector as an alternative to free-text search for the material
  list or grouped views. It may be easier to scan when the list is short enough
  and avoids cramped sidebar headers.

## Future: Recipe-Chain Weight Tuner

The recipe-chain scoring knobs can be tuned offline once the passive analysis
and decider schemas are stable. A Python tool can read a predictable JSON dump,
compare suggested targets against a small golden table, and try different score
weights until the expected decisions improve.

## Future: Ancestry-Based Scrap Solver

The most promising long-term model may be to stop treating every matched
ingredient as its own scrap family and instead resolve ingredients back to their
base material ancestry. In that model, scrap generation follows material
composition rather than prototype names:

- `copper-cable + plastic-bar -> electronic-circuit` would generate
  `copper-scrap + plastic-scrap`, not `copper-cable-scrap + plastic-scrap`;
- gears, simple pipes, bearings, and other linear components could collapse
  back to their plate/alloy source material;
- complex components such as circuits or batteries could be decomposed as far
  as the recipe graph remains useful, then reviewed or deferred for
  preserve-shape/chemistry handling.

The theoretical pipeline:

1. Detect base roots from resources, forced material overrides, and known
   vanilla/DLC material roots.
2. Build a recipe graph from items/fluids to their ingredient composition.
3. Resolve each item prototype to a weighted set of base material families.
4. When patching a source recipe, generate scrap results from the ancestry of
   its ingredients rather than from the ingredient prototype itself.
5. Dump the ancestry table and compare it against the current resolver before
   enabling it.

This could eventually replace large parts of the current material/target solver,
because everything that can be traced cleanly lands back at a resource or base
material root. It should start as passive analysis only and run in parallel with
the current resolver.

Prototype status:

- `tools/toolset/ancestry_flow.py` reads existing `material-flow.json` and
  `production-flow.json` archives and writes `ancestry-flow.json`.
- The tool is offline only: it does not launch Factorio and does not change
  generated prototypes.
- Effective output simulation is included in each comparison. With the planned
  default `--mixed-limit 3`, ancestry with more than three material families or
  unresolved ancestry becomes `yis-mixed` in `effective_output`; narrower
  ancestry remains direct.
- Root policies:
  - `current`: use current material-flow roots and aliases as stop markers;
  - `resources`: alias-free baseline that only stops at mined resource results;
  - `hybrid`: intended long-term comparison shape where stable materials stop
    and exact component aliases keep resolving through producer recipes.
- First `is_sa` run, covering Base + DLCs + Ingredient Scrap:
  - 146 flow comparisons;
  - all 146 unchanged compared with the current resolver;
  - 20 root items;
  - maximum ancestry width was 1 material.
- First `krastorio_is` run, after the Base+DLC control profile:
  - 253 flow comparisons;
  - all 253 unchanged compared with the current resolver;
  - 26 root items;
  - maximum ancestry width was 1 material.
  This makes K2 a clean intermediate profile before moving to the much larger
  Bob+Angels stress test.
- `krastorio_is` with `--root-policy resources`, using only mined resource
  results as stop nodes:
  - 253 flow comparisons;
  - 99 unchanged, 103 different, 51 unresolved;
  - maximum ancestry width was 4 materials.
  This is useful as an alias-free baseline, but too naive for gameplay by
  itself. Examples: `plastic-bar` prefers a matter-conversion recipe and expands
  into coal/copper/iron/rare-metal; `steel-plate` becomes coal+iron; imersium
  collapses mostly to rare-metal because `kr-imersite-powder` remains blocked
  behind unresolved sand/quartz-style intermediates. This supports the hybrid
  rule: known material affixes/aliases/API overrides should be stop markers,
  while component-like prototypes may opt into deeper ancestry resolution.
  More precisely, component-follow does not need to be a separate explicit
  category. The ancestry resolver can use this order:
  1. If the prototype matches a stable material stop marker, stop there
     (`steel`, `plastic`, `rare-metal`, `imersium`, alloys, etc.).
  2. If the chain becomes fluid/process-heavy or unresolved, collapse to a
     stable fallback such as `yis-mixed-scrap` or a later
     `yis-mixed-sludge`.
  3. Otherwise keep following producer recipes backward. Components such as
     gears, cables, pipes, bearings, and circuit parts naturally fall into this
     default path because they are neither stable stop markers nor fluid/process
     fallbacks.
  Resource/fuel inputs such as coal may need special handling: they are useful
  as mined roots for diagnostics, but should not automatically make
  `steel-plate` recycle into coal+iron when `steel` is the better gameplay
  material stop.
- `krastorio_is` with `--root-policy hybrid`:
  - 253 flow comparisons;
  - all 253 unchanged compared with the current resolver;
  - `steel-plate`, `plastic-bar`, `kr-imersium-plate`, and
    `kr-imersium-beam` all stop at their stable material roots.
- `bob_angels_full_is` with `--root-policy hybrid`:
  - same headline counts as the current policy for now;
  - stable materials such as `steel-plate` and `plastic-bar` stop;
  - components follow ancestry, for example `copper-cable -> copper`,
    `iron-gear-wheel -> iron`, `bob-brass-pipe -> brass`, and
    `bob-titanium-bearing -> titanium`;
  - wide electronics such as `processing-unit` decompose into up to 6 material
    families and remain candidates for mixed-scrap limits.
  - With `--mixed-limit 3`, effective outputs are 1174 direct and 201 mixed
    flow rows. K2 remains 253 direct and 0 mixed under the same limit.
- Hybrid profile matrix:
  - `is_sa`: 146 same, 0 different, 0 unresolved, width 1;
  - `krastorio_is`: 253 same, 0 different, 0 unresolved, width 1;
  - `bobs_full_is`: 394 same, 0 different, 0 unresolved, width 1;
  - `angels_full_is`: 239 same, 0 different, 0 unresolved, width 1;
  - `bob_angels_full_is`: 584 same, 790 different, 1 unresolved, width 6.
  This suggests the hybrid model is conservative for single large mod families
  and only diverges in the combined Bob+Angels stress case where exact
  component scrap became visible.
- Hybrid difference review:
  - `tools/toolset/dumps/bob_angels_full_is/ancestry-hybrid-review.md` groups
    the 790 different flow rows into 32 unique ingredients.
  - Clean/simple component wins are concentrated in gears, pipes, cables,
    bearings, and bearing balls.
  - Electronics and batteries are wider or partially unresolved and are better
    candidates for mixed-scrap limits, preserve-shape, or compat API rules.
  - The only fully unresolved source-flow is `bob-ceramic-pipe`, blocked by
    unresolved `bob-silicon-nitride`.
- Hybrid decision review:
  - `tools/toolset/dumps/bob_angels_full_is/ancestry-hybrid-decisions.md`
    classifies the unique review ingredients into likely action groups.
  - Current grouping: 22 Safe Hybrid, 7 Mixed Candidate, 2 API/Compat
    Candidate, 2 Preserve/Future Chemistry.
  - `bob-basic-circuit-board` resolves narrowly and is listed as Safe Hybrid
    for now, but should be reviewed with electronics before active use.
- Mixed-limit simulation:
  - `tools/toolset/dumps/bob_angels_full_is/ancestry-mixed-limit-simulation.md`
    simulates material-count limits from 1 to 6.
  - Limit 1 is very strict: 21 direct, 11 mixed by width, 1 unresolved mixed.
  - Limit 2 keeps narrow two-material components direct: 28 direct, 4 mixed by
    width, 1 unresolved mixed.
  - Limits 3 and 4 look like the first plausible gameplay range: 29 direct, 3
    mixed by width, 1 unresolved mixed. This keeps `electronic-circuit` direct
    but sends wider advanced/processing electronics to mixed.
  - Planned first default: 3. Limit 4 currently produces the same result in the
    Bob+Angels Full test, while 3 is the clearer gameplay boundary.
  - Limit 6 allows all resolved examples direct and only leaves unresolved
    `bob-ceramic-pipe` as mixed, which may be too noisy for gameplay.
- Effective-output review:
  - `tools/toolset/dumps/bob_angels_full_is/ancestry-effective-output-review.md`
    shows the concrete current scrap vs. effective output at mixed limit 3.
  - Unique ingredients: 29 direct, 3 mixed by width, 1 mixed unresolved.
  - Examples:
    - `copper-cable`: `yis-copper-cable-scrap` -> `yis-copper-scrap`;
    - `bob-brass-pipe`: `yis-bob-brass-pipe-scrap` -> `yis-brass-scrap`;
    - `electronic-circuit`: `yis-electronic-circuit-scrap` ->
      `yis-copper-scrap`, `yis-iron-scrap`, `yis-tin-scrap`;
    - `advanced-circuit`, `processing-unit`, and
      `bob-advanced-processing-unit` -> `yis-mixed-scrap`;
    - `bob-ceramic-pipe` -> `yis-mixed-scrap` because ancestry is unresolved.
- Review file generation:
  - `tools/toolset/ancestry_flow.py --root-policy hybrid --mixed-limit 3 --write-reviews`
    regenerates the hybrid review, decision groups, mixed-limit simulation, and
    effective-output preview from the archived JSON dumps.
- First `bob_angels_full_is` run:
  - 1375 flow comparisons;
  - 584 unchanged compared with the current resolver;
  - 790 different ancestry suggestions;
  - 1 unresolved comparison (`bob-ceramic-pipe`, blocked by unresolved
    `bob-silicon-nitride`);
  - resolved item cache: 37 roots, 29 fully resolved, 20 partially composed,
    51 unresolved helper/intermediate items;
  - maximum ancestry width was 6 materials.
- Early examples look promising:
  - `copper-cable -> copper`;
  - `iron-gear-wheel -> iron`;
  - `bob-brass-pipe -> brass`;
  - `bob-titanium-bearing -> titanium`;
  - circuit tiers decompose into wider copper/plastic/silicon/gold/silver/tin
    compositions and are good candidates for a future mixed-scrap limit.

`mixed-scrap` is a useful fallback for unresolved or overly broad ancestry. A
future startup setting could define a material-output limit. If an ingredient
would decompose into more than that number of base materials, Ingredient Scrap
could emit `mixed-scrap` instead. This is both a safety valve for very large mod
packs and a gameplay knob: lowering the limit would intentionally create more
mixed scrap, similar in spirit to Space Age's scrap recycling.

If the ancestry solver becomes active, it should run in the real data stage
against `data.raw.recipe` rather than depending on the offline JSON dump. The
offline tool remains a measurement and comparison helper. Runtime rules should
try to resolve ancestry up to a configurable depth before falling back to mixed
scrap. Mixed scrap should be a stable, migrations-friendly fallback prototype,
and all Ingredient Scrap-owned prototypes must keep the `yis-` prefix, for
example `yis-mixed-scrap`, `yis-recycle-mixed-scrap`, and related technologies.

### Active Ancestry Activation Plan

Do not start active ancestry wiring until reasoning is raised to high. The first
implementation should be a staged, switchable path, not an immediate replacement
for the current collector.

Current status:

- Done: `code/core/ancestry/graph.lua`, `roots.lua`, `resolver.lua`,
  `effective-output.lua`, `mixed.lua`, and `comparison.lua` implement the first
  passive Lua ancestry path.
- Done: `data-final-fixes.lua` writes
  `data_table.debug.passive_runtime.ancestry`.
- Done: `control.lua` writes
  `script-output/Ingredient_Scrap/ancestry-runtime.json`.
- Done: the test report includes the passive ancestry summary only, not the
  full comparison list.
- Done: `yis-ancestry-mode` exposes three startup choices:
  `component-heavy`, `balanced`, and `material-heavy`. The setting currently
  affects passive ancestry debug output only.
- Done: Base+DLC debug harness output matches the offline headline:
  146 comparisons, all `same`, width 1, 20 root items.
- Done: K2 runtime output matches the archived offline hybrid summary:
  253 comparisons, all `same`, width 1, 26 root items.
- Done: Angels Full runtime output matches the Python prototype on current
  dumps: 239 comparisons, all `same`, width 1, 20 root items. The archived
  summary has the same comparison headline but uses an older summary schema
  without `effective_*` fields.
- Done: Bob+Angels Full runtime output matches both the Python prototype on
  current dumps and the archived offline hybrid summary: 1375 comparisons,
  584 `same`, 790 `different`, 1 `unresolved`, max width 6, 1174 direct
  effective outputs, and 201 mixed effective outputs.
- Done: `yis-ancestry-mode` behavior comparison across Base+DLC, K2, Bob Full,
  Angels Full, and Bob+Angels Full:
  - `component-heavy`/`stable` is effectively current behavior: all tested rows
    stay `same`, no mixed output, max width 1.
  - `balanced`/`hybrid` is the useful candidate: Base+DLC, K2, and Angels Full
    remain unchanged, while Bob Full and Bob+Angels expose component/material
    differences plus bounded mixed fallback.
  - `material-heavy`/`resources` is too aggressive as currently defined. It
    produces large unresolved/mixed counts because many prototype ingredients
    cannot be traced back to resource aliases alone.
  - The old comparison snapshot was moved to
    `_legacy/weighted/dumps/_comparisons/ancestry-mode-comparison.json`.
- Done: add passive recipe-form classification as the first step toward the
  principle "derive everything from recipes, then handle edge cases through
  explicit overrides." The pass builds resource-output roots from
  `resources_by_material`, classifies item-result recipes as
  `resource_output`, `first_material_product`, `named_material_product`,
  `component_candidate`, `multi_material_product`, `possible_alloy`,
  `placeable_product`, or `unresolved`, and writes
  `script-output/Ingredient_Scrap/recipe-forms.json`.
- Done: recipe-form classification now augments current IS material roots with
  direct `data.raw.resource` item outputs. This is required for Angels, where
  generic ores such as `angels-ore1` are the resource roots and named material
  products such as `iron-ore` are produced later by ore sorting.
- Done: exact component scrap families from the current API (`gear`, `pipe`,
  `cable`, `bearing`, `board`, `battery`, and related aliases) are classified
  as `component_candidate`, not `named_material_product`.
- Done: recipe-form comparison snapshot was moved to:
  `_legacy/weighted/dumps/_comparisons/recipe-forms-comparison.json`.
  Human-readable review:
  `_legacy/weighted/dumps/_comparisons/recipe-forms-review.md`.
  Current headline counts:
  - Base+DLC: 12 roots, 10 first material products, 3 named material products,
    40 component candidates, 21 multi-material products, 0 possible alloys.
  - K2: 14 roots, 19 first, 5 named, 73 components, 35 multi, 0 possible alloys.
  - Bob Full: 29 roots, 23 first, 13 named, 119 components, 35 multi, 2 item
    classes/3 recipe rows as possible alloys.
  - Angels Full: 15 roots, 16 first, 6 named, 78 components, 25 multi,
    0 possible alloys.
  - Bob+Angels Full: 15 roots, 21 first, 15 named, 140 components, 33 multi,
    2 item classes/3 recipe rows as possible alloys.
  `possible_alloy` is intentionally narrow now: recipe category alone is not
  enough. The recipe/result must name an alloy/solder-style family, which keeps
  K2 electronic components out of the alloy bucket while still surfacing Bob
  solder alloy recipes for manual/API review.
  The remaining large unresolved counts in Angels and Bob+Angels mostly point
  at process/chemistry/biology chains, not alloy detection.
- Note: Bob Full runtime output matches the Python prototype on current dumps,
  but the archived `bobs_full_is` dump is stale for the currently installed Bob
  set. Current runtime/Python summary is 802 comparisons, 409 `same`, 393
  `different`, max width 6, 682 direct effective outputs, and 120 mixed
  effective outputs. Refresh the archived Bob Full dumps before using them as
  a regression baseline.
- Still passive: no generated items, recipes, technologies, source recipe
  inserts, or patcher behavior are changed by ancestry data.

Planned order:

1. Extract a runtime ancestry resolver from the offline Python prototype's
   rules, but implement it in Lua against `data.raw.recipe`, `data.raw.item`,
   `data.raw.fluid`, and the current material override state.
2. Keep the current collector authoritative. Let the ancestry resolver produce
   a second, passive comparison table first, shaped like the current
   `data_table.inserts.recipes` output but stored under debug/evidence.
3. Done: add visible startup setting `yis-ancestry-mode` for ancestry
   effective-output simulation. It writes comparison data and dumps, but must
   not patch recipes yet.
4. Generate or reuse stable fallback prototypes for mixed output:
   `yis-mixed-scrap`, its recycle recipe, and technology. These names should be
   treated as final before public release.
5. Once passive runtime comparison matches the offline tool for Base+DLC, K2,
   Bob, Angels, and Bob+Angels profiles, add an active mode that writes via
   `code/core/data-table/writer.lua`.
6. In active mode, ancestry-generated scrap results must flow through the same
   writer functions as collector results, so the patcher receives the same
   operational data-table shape.
7. Keep a fallback path that can switch individual materials, source recipes, or
   ingredient families back to the current collector behavior through API
   overrides.
8. Only after active mode is stable, decide whether the old exact-component
   collector rules are removed, kept as compatibility mode, or treated as one
   resolver profile.

This plan intentionally separates four concerns:

- input discovery: current collector/material override state and runtime
  recipe graph;
- processing: ancestry resolution, width limit, unresolved fallback, and API
  overrides;
- data-table output: writer-backed inserts, generated prototypes, and debug
  sources;
- patching: unchanged patcher behavior wherever possible.

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

scrap-resolver.collect_baseline()
  -> baseline-collector creates the initial data_table inserts and prototypes

scrap-resolver.apply_active_ancestry()
  -> optionally rewrites the baseline data_table through the writer

recipe_chain_analysis.build(data_table)
  -> writes to debug/evidence

recipe_chain_decider.build(analysis, data_table)
  -> writes passive decisions plus a data-table-shaped staged_data_table
  -> later can directly stage “recycle target,” “preserve shape,” and
     “supplements” without a separate translation pass

patcher.validate_generated_prototypes(data_table)
patcher.patch(data_table)

The passive decider should expose two views:

- a human-readable decision list grouped by mode, with actions such as
  `keep-current`, `review-difference`, and `analysis-only`;
- a `staged_data_table` shaped like the current operational `data_table`, with
  `materials`, `ingredients`, `prototypes`, and `inserts` keys.

The staged table is still passive evidence. It should be formatted closely
enough to the real data table that existing generator/patcher paths can consume
it later without a separate translation pass, but it must not be passed to
`data:extend` directly while the decider is passive.

## Internal Data-Table Writer

`code/core/data-table/init.lua` creates the shared plain data table. The current
runtime still initializes it in `data-updates.lua`, close to where the collector
and generator fill it. A future stage cleanup may initialize the empty table
earlier in `data.lua`, but only after the API registration model is moved into
the same state shape.

Future stage cleanup idea:

- `data.lua`: expose registration API and possibly create an empty
  `data_table.registrations` area;
- `data-updates.lua`: ideally little or no operational work;
- `data-final-fixes.lua`: collect materials, collect source recipes, run
  processing, generate prototypes, patch outputs, and write debug data.

This future split must document exactly when the API is available and when the
operational data table is populated. For now, the smaller move keeps behavior
unchanged.

`code/core/data-table/writer.lua` is the internal abstraction layer for
semantically important writes to `yokmods.ingredient_scrap.data_table`. It keeps
the table itself plain and dump-friendly, while centralizing fragile operations
such as:

- creating source recipe insert staging tables;
- accumulating generated scrap results without duplicate entries;
- recording source ingredients and skipped source reasons;
- storing main-product metadata on recipe inserts;
- storing generated item, recipe, and technology prototypes;
- attaching debug-source metadata for generated prototypes and inserts.

The old public helper functions `add_recipe_results()` and
`get_main_product()` remain in place for compatibility, but now delegate to this
writer. The active data-stage resolver entrypoint is
`code/core/scrap-resolver.lua`: it runs the collector as the baseline pass, then
optionally applies active ancestry rewrites through the same writer-backed
data-table shape. Patcher, debug dumps, and analysis code may still iterate over
plain tables directly when they only need broad read access.

Any future resolver should write operational output through this layer so the
patcher receives the same data-table shape regardless of whether entries came
from the collector baseline, recipe-chain decisions, ancestry decisions, or API
overrides.
