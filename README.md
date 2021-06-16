# A small Mod for Factorio built around Scrap.

This Mod is written under Factorio 1.1.33.
It inserts its data in the data-updates stage.
Affected are only "vanilla-names" (iron, copper, steel). If you want to add scrap for 
other mods recipes then just edit data-updates.lua where youll find the two array at the top of the file.


<table>
<tr>
<td>
<img src=shot_01.png>
</td>
<td>
<img src=shot_02.png>
</td>
</tr>
</table>

### [Download the Zip-File here!](https://github.com/Yokmp/Ingredient_Scrap/raw/main/Ingredient_Scrap_1.0.2.zip)


## Customize
The ``_types`` table holds the phrases and looks into the recipes with string.match() to find them.
So iron will match iron-plate and hardenend-iron-plate. Even superironbar would be a match.
To exclude like copper-plate but still use copper-cables just be more specific. It is also used
to contruct the scrap-items like ``iron-scrap``.

<pre lang=lua> local _types = {"iron", "copper", "steel"} </pre>

This table holds the result suffix which is then be constructed to ``_types.."-".._results`` (eg iron-plate).
Like the _types table, this one also goes by priority, so position 1 is taken if possible, if not pos 2 will be checked etc until
it runs out of options, then the script will log it and **ignore** the recipe.
As there will be no recycling of this scrap-item place some kind of fallback match at the end of the table.<br/> "*plate*"" is a good candidate.

<pre lang=lua> local _results = {"plate"} </pre>

## Updates
* Initial release

## Known Issues
* None yet

## Languages
* english
* deutsch

## ToDo
* [ ] recipe and Tech-Cost Balancing
* [ ] better Icons
* [ ] Techtree overhaul (maybe)
* [ ] Options/Settings
* [ ] Interface
* [ ] Additional recipes (maybe)

## How to contribute?

Please use the Issues Tab and share your suggestions and/or code.