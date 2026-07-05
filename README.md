# Ingredient Scrap

Ingredient Scrap adds material scrap as an extra byproduct to many recipes.
The generated scrap can be recycled back into the matching source material.

![Scrap byproducts](shot_01.png)
![Recycle recipes](shot_02.png)
![Mixed scrap sorting](shot_03.png)

The mod is built around Factorio 2.0 and Space Age style recycling, but it also
works without Space Age. It tries to follow the actual recipe chain instead of
only matching names, so components such as gears, cables, circuits, beams, and
plates can resolve back to useful material scrap.

## Current Behavior

- Recipes can receive extra scrap results based on their consumed ingredients.
- Component ingredients are traced back through recipe chains when possible.
- Very large scrap outputs are smoothed so a single huge recipe does not flood a
  factory with scrap.
- Generated recycle recipes stay present but start disabled, so they do not show
  up in handcrafting or machine recipe lists before their unlock trigger.
- Recycling technologies unlock automatically when the first matching scrap item
  is produced. Their visibility follows `Hide recycling technologies`; shallow
  logging keeps them visible for testing.
- Generated prototypes use the `yis-` prefix to avoid collisions with other mods.
- Complex or broad recipes can fall back to `yis-mixed-scrap`.

## Mixed Scrap

`yis-mixed-scrap` is the fallback for recipes whose ingredients resolve to too
many material families, cannot be fully resolved, or are intentionally handled as
mixed output. It keeps complex mod combinations playable without inventing a
large number of one-off scrap items.

Recycling mixed scrap behaves like a sorting process and is handled by the
recycler. The generated mixed recycling recipe has a total output chance of
about 60%. Common scrap families appear more often, rare families stay possible
with smaller probabilities.

## Fluids

Fluid handling is always active internally. Molten, solution, and similar fluid
materials can be resolved when Ingredient Scrap or a compatibility rule knows the
matching material family.

Chemistry-heavy chains are treated conservatively. If a chain is too broad or
unclear, mixed scrap or material settings are preferred over fragile guesses.

## Recycler

When Quality is active, Ingredient Scrap can use the game's recycler as a scrap
sink and as the mixed-scrap sorter. Without Quality, the mod provides a
compatible fallback recycler so mixed scrap still has a clear recycling path.

The recycler is allowed to be lossy. This is intentional: it gives late-game
factories a controlled way to reduce excess scrap.

Fish recycling is a small compatibility recipe that turns raw fish into mixed
scrap. It unlocks when a recycler is built.

## Settings

Important startup settings:

| Setting | Default | Meaning |
| --- | --- | --- |
| `yis-needed` | `5` | Base target for generated recycling recipes. |
| `yis-probability` | `24` | Chance that a source recipe produces scrap. |
| `yis-fixed-amount` | `false` | Use fixed scrap amounts instead of random ranges. |
| `yis-amount-limit` | `true` | Smooth very large scrap amounts. |
| `yis-hide-tech` | `true` | Hide generated recycling technologies in the tech tree. |
| `yis-ancestry-mode` | `balanced` | Controls how aggressively components resolve to material scrap. |
| `yis-ancestry-max-depth` | profile based | Maximum number of resolver rounds. |
| `yis-ancestry-mixed-limit` | profile based | Maximum direct material families before mixed scrap. |
| `yis-shallow-log` | `false` | Write short status logs useful for bug reports. |

Per-material startup settings can force a material to `auto`, `solid`, `fluid`,
`both`, or `none`. Use these when a mod combination needs a clearer rule than the
automatic resolver can infer.

## Compatibility

Supported and tested:

- Base game and official DLCs
- Quality recycler behavior
- Space Age molten and advanced material chains
- Krastorio 2
- Bob's mods
- Angel's mods
- Bob + Angel large combinations

Large overhaul mods can still have edge cases. Ingredient Scrap prefers safe
fallbacks and visible logs over crashing during prototype loading.

Chemistry-specific gameplay and preserve-shape recycling are intentionally kept
for future work.

## Troubleshooting

- If a material creates unwanted scrap, set its material mode to `none`.
- If a material is missed, try forcing it to `solid`, `fluid`, or `both`.
- If a complex chain creates mixed scrap, that usually means the resolver could
  not reduce the chain safely.
- Enable short logging when reporting bugs. The Factorio log will include compact
  Ingredient Scrap summaries.

## Modder API

Ingredient Scrap exposes a data-stage API for compatibility mods. It can register
materials, aliases, source ignores, recycle targets, crafting categories, and
typed patch operations.

See [docs/API.md](docs/API.md) for the public API.

## Development

The test harness, debug dumps, local tools, and deploy workflow are development
assets. They are kept in the dev branch and are not part of the Mod Portal zip.

See [docs/DEV.md](docs/DEV.md) for development notes.
