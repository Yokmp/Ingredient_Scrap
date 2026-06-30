# Ingredient Scrap

Ingredient Scrap automatically adds scrap byproducts to crafting recipes based on
the materials they consume.

Instead of crafting without waste, recipes now produce small amounts of scrap
such as `iron-scrap`, `copper-scrap` or modded materials. Generated scrap can be
recycled back into useful resources.

## Features

- Automatically analyzes recipes during the data stage.
- Supports vanilla, Space Age and many modded materials.
- Generates scrap items and recycle recipes automatically.
- Supports both solid and fluid material families.
- Startup settings for scrap amount, probability and balancing.
- Public API for registering custom materials and crafting categories.

## Example

A recipe requiring

- 20 Iron Plates
- 10 Iron Gear Wheels
- 10 Copper Plates

will additionally produce

- Iron Scrap
- Copper Scrap

The exact amount depends on your startup settings and an average (base_amount_needed/average).

## Mod compatibility

Ingredient Scrap is designed to work with vanilla as well as many overhaul mods.
Unknown materials can easily be added through the public API or compatibility
modules.

## Documentation

For detailed documentation, API usage, compatibility information and the latest
changes, please visit the GitHub repository:

https://github.com/Yokmp/Ingredient_Scrap