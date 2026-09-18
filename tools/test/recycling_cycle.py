"""Offline one-pass product + IS scrap recovery; never changes game recipes."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

from quality_balance import expected, recovery
from quality_chain import Chain, key


def cycle_report(raw, target, routes=None, productivity=None):
    chain = Chain(raw, producers=routes, recipe_productivity=productivity)
    base = chain.expand("item:" + target)
    gaps = set(base["gaps"])
    recipe_name = target + "-recycling"
    recipe = raw["recipe"].get(recipe_name)
    product, scrap = defaultdict(float), defaultdict(float)
    if recipe is None:
        gaps.add("missing:" + recipe_name)
    else:
        ingredients = recipe.get("ingredients", [])
        if (len(ingredients) != 1 or key(ingredients[0]) != "item:" + target
                or ingredients[0].get("amount", 0) <= 0):
            gaps.add("unsupported-inputs:" + recipe_name)
        else:
            for result in recipe.get("results", []):
                if "shared_probability" in result:
                    gaps.add("shared-probability:" + recipe_name)
                else:
                    product[key(result)] += expected(result) / ingredients[0]["amount"]
    for name, amount in base["scrap"].items():
        recovered, missing = recovery(raw["recipe"], name, amount, 1, 0)
        gaps.update(missing)
        for material, quantity in recovered.items():
            scrap[material] += quantity

    equivalents, unvalued = {}, {}
    for label, materials in (("product", product), ("scrap", scrap)):
        equivalent = defaultdict(float)
        for material, amount in materials.items():
            value = chain.expand(material, amount)
            if value["gaps"]:
                unvalued[label + "/" + material] = value["gaps"]
                continue
            for resource, quantity in value["resources"].items():
                equivalent[resource] += quantity
        equivalents[label] = dict(equivalent)
    ratios = {}
    if not gaps:
        for resource, amount in base["resources"].items():
            if amount > 0:
                p = equivalents["product"].get(resource, 0) / amount
                s = equivalents["scrap"].get(resource, 0) / amount
                ratios[resource] = dict(product=p, scrap=s, total=p + s)
    return dict(target=target, production=base, recycling_recipe=recipe_name,
                returned_product=dict(product), returned_scrap=dict(scrap),
                resource_equivalents=equivalents, ratios=ratios,
                complete=not gaps and not unvalued, gaps=sorted(gaps), unvalued=unvalued)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump", type=Path)
    parser.add_argument("config", type=Path, help="Explicit producer routes and per-recipe total productivity")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    raw = json.loads(args.dump.read_text(encoding="utf-8"))
    config = json.loads(args.config.read_text(encoding="utf-8"))
    rows = []
    for case in config["cases"]:
        productivity = case.get("productivity", {})
        if any(not isinstance(v, (int, float)) or v < 0 for v in productivity.values()):
            parser.error("Productivity totals must be non-negative numbers")
        unknown = set(productivity) - raw["recipe"].keys()
        if unknown:
            parser.error("Unknown productivity recipes: " + ", ".join(sorted(unknown)))
        row = cycle_report(raw, case["target"], case.get("routes"), productivity)
        row.update(label=case["label"], configuration=case)
        rows.append(row)
        print(case["label"], "complete=" + str(row["complete"]))
        for resource, ratios in row["ratios"].items():
            print(" ", resource, " ".join(f"{k}={v:.2%}" for k, v in ratios.items()))
        if row["gaps"] or row["unvalued"]:
            print("  gaps:", row["gaps"], "unvalued:", row["unvalued"])
    report = dict(schema="ingredient-scrap-recycling-cycle/v1", active=False,
                  assumptions=["One finished item, including all upstream IS scrap; main item recycled once.",
                               "Returned components are reused and valued at replacement raw cost, not recursively shredded.",
                               "No new scrap credited for replacement valuation; no reinvestment simulation.",
                               "No recycling productivity or proposed quality modifiers.",
                               "Explicit per-recipe manufacturing productivity includes all bonuses and respects recipe caps.",
                               "No energy, fuel, mining productivity, research costs or credit for unused coproducts.",
                               "Ratios are per resource, not proof of an entirely self-sustaining factory."], cases=rows)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
