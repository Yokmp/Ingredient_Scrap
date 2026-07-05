# Ingredient Scrap

Ingredient Scrap adds scrap as an extra byproduct to recipes based on the
materials they consume. That scrap can then be recycled back into useful material
families, giving production chains a little more texture without replacing the
original recipe outputs.

The mod resolves ingredients through recipe chains where possible, so components
such as gears, cables, circuits, pipes, beams, or plates can contribute scrap
from the materials they are made of.

## Normal Scrap

Normal scrap is tied to a material family, for example iron scrap, copper scrap,
steel scrap, or modded metals. Generated recycling recipes turn that scrap back
into the matching material target.

Recycling recipes start locked. They are unlocked automatically by generated
trigger technologies when the matching scrap is first produced; these
technologies can be hidden through the startup settings.

## Mixed Scrap

When a recipe is too complex, too broad, or cannot be resolved safely,
Ingredient Scrap creates mixed scrap instead. Mixed scrap is sorted in the
recycler through a weighted recipe, where common material scraps appear more
often and rare materials remain possible.

## Recycler

The recycler sorts mixed scrap and can also act as a scrap drain. It can process
scrap-heavy recipes and may return only part of the expected output, giving
late-game factories a controlled way to reduce excess scrap.

If Quality is not active, Ingredient Scrap provides a compatible fallback
recycler.

Fish recycling unlocks when a recycler is built and turns raw fish into mixed
scrap.

## API And Compatibility

Ingredient Scrap includes a public data-stage API for compatibility mods. It
supports material overrides, aliases, source filters, recycle target rules,
crafting category rules, generated prototype snapshots, and typed patch
operations.

Built-in compatibility currently covers Base game, Space Age, Quality, Krastorio
2, Bob's Mods, and Angel's Mods.

More details, API documentation, and development notes are available on GitHub:

https://github.com/Yokmp/Ingredient_Scrap
