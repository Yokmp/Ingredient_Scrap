"""Offline quality balancing proposal; does not change recipes or save data."""
import argparse
import json
from pathlib import Path


CURVE = (("normal", 1.00, 1.00), ("uncommon", .65, 1.03),
         ("rare", .45, 1.06), ("epic", .30, 1.09), ("legendary", .20, 1.12))


def is_scrap(name):
    return name.startswith("yis-") and name.endswith("-scrap")


def expected(result, productivity=0):
    low = result.get("amount", result.get("amount_min", 0))
    high = result.get("amount", result.get("amount_max", low))
    extra = result.get("extra_count_fraction", 0)
    probability = result.get("independent_probability", result.get("probability", 1))
    ignored = result.get("ignored_by_productivity", result.get("ignored_by_stats", 0))
    # Integer uniform ranges: expectation of max(amount - ignored, 0).
    if low == high:
        bonus = max(low - ignored, 0) + extra * (max(low + 1 - ignored, 0) - max(low - ignored, 0))
    else:
        start = max(low, ignored + 1)
        count = max(0, high - start + 1)
        bonus = count * ((start + high) / 2 - ignored) / (high - low + 1)
        bonus += extra * max(0, high - max(low, ignored) + 1) / (high - low + 1)
    return probability * ((low + high) / 2 + extra + productivity * bonus)


def productivity_for(recipe, requested):
    return min(requested, recipe.get("maximum_productivity", 3)) if recipe.get("allow_productivity", False) else 0


def recovery(recipes, name, quantity, bonus, productivity, seen=()):
    if name in seen:
        return {}, ["cycle:" + name]
    recipe_name = "yis-recycle-" + name.removeprefix("yis-")
    recipe = recipes.get(recipe_name)
    if not recipe:
        return {}, ["missing:" + recipe_name]
    ingredients = recipe.get("ingredients", [])
    scrap_inputs = [x for x in ingredients if x.get("name") == name]
    if len(ingredients) != 1 or len(scrap_inputs) != 1 or scrap_inputs[0].get("amount", 0) <= 0:
        return {}, ["unsupported-inputs:" + recipe_name]
    outputs, gaps = {}, []
    for result in recipe.get("results", []):
        if "shared_probability" in result:
            gaps.append("shared-probability:" + recipe_name)
            continue
        amount = quantity / scrap_inputs[0]["amount"] * expected(result, productivity_for(recipe, productivity))
        target = result["name"]
        if is_scrap(target):
            children, missing = recovery(recipes, target, amount, bonus, productivity, (*seen, name))
            gaps.extend(missing)
        else:
            children = {result.get("type", "item") + ":" + target: amount * bonus}
        for key, value in children.items():
            outputs[key] = outputs.get(key, 0) + value
    return outputs, gaps


def build_report(raw, source_productivity=0, recycle_productivity=0):
    recipes = raw["recipe"]
    curve = []
    for name, scrap, recycle in CURVE:
        quality = raw.get("quality", {}).get(name)
        if quality is None:
            continue
        speed = quality.get("crafting_machine_speed_multiplier", quality.get("default_multiplier", 1 + .3 * quality.get("level", 0)))
        curve.append(dict(quality=name, scrap_factor=scrap, recycle_factor=recycle,
                          default_speed_factor=speed, scrap_per_second_factor=scrap * speed))
    matrix = [dict(source=a["quality"], recycler=b["quality"],
                   direct_recovery_factor=a["scrap_factor"] * b["recycle_factor"],
                   mixed_two_stage_factor=a["scrap_factor"] * b["recycle_factor"],
                   scrap_per_second_factor=a["scrap_per_second_factor"],
                   recovery_per_second_factor=a["scrap_per_second_factor"] * b["recycle_factor"])
              for a in curve for b in curve]
    rows = []
    for name, recipe in recipes.items():
        if name.startswith("yis-") or name.endswith("-recycling"):
            continue
        results = [r for r in recipe.get("results", []) if is_scrap(r.get("name", ""))]
        if not results:
            continue
        if any("shared_probability" in r for r in results):
            rows.append(dict(recipe=name, unsupported="shared_probability"))
            continue
        amounts = [(r, expected(r, productivity_for(recipe, source_productivity))) for r in results]
        scenarios = []
        for a in curve:
            for b in curve:
                output, gaps = {}, []
                for result, amount in amounts:
                    recovered, missing = recovery(recipes, result["name"], amount * a["scrap_factor"], b["recycle_factor"], recycle_productivity)
                    gaps.extend(missing)
                    for key, value in recovered.items():
                        output[key] = output.get(key, 0) + value
                scenarios.append(dict(source=a["quality"], recycler=b["quality"], recovered=output,
                                      recovered_per_second_at_base_speed_one={
                                          k: v * a["default_speed_factor"] / recipe.get("energy_required", .5)
                                          for k, v in output.items()}, gaps=sorted(set(gaps))))
        scrap = sum(value for _, value in amounts)
        rows.append(dict(recipe=name, expected_scrap_per_craft=scrap,
                         scrap_per_second_at_speed_one=scrap / recipe.get("energy_required", .5),
                         ingredients=recipe.get("ingredients", []), scenarios=scenarios))
    rows.sort(key=lambda row: (-row.get("scrap_per_second_at_speed_one", 0), row["recipe"]))
    return dict(schema="ingredient-scrap-quality-proposal/v1", active=False,
                source_productivity=source_productivity, recycle_productivity=recycle_productivity,
                assumptions=["Expected values, no proposed rounding or active recipe changes.",
                             "Throughput uses crafting speed 1; actual machine, beacon and module speeds are not simulated.",
                             "Uses canonical solid recycle recipes; alternatives and additional ingredients are not simulated.",
                             "Only terminal material recovery receives the quality bonus; scrap sorting does not.",
                             "Recovery per second assumes enough recycling capacity; recycler speed is not an extra yield multiplier.",
                             "This is not a full resource or closed-loop profitability proof."],
                curve=curve, matrix=matrix, recipes=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump", type=Path, help="Factorio --dump-data JSON")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--source-productivity", type=float, default=0)
    parser.add_argument("--recycle-productivity", type=float, default=0)
    parser.add_argument("--chain-target", action="append", help="Finished item for full-chain analysis (repeatable)")
    parser.add_argument("--producer", action="append", default=[], metavar="TYPE:ITEM=RECIPE")
    args = parser.parse_args()
    if min(args.source_productivity, args.recycle_productivity) < 0:
        parser.error("productivity must be non-negative (1 = +100%)")
    raw = json.loads(args.dump.read_text(encoding="utf-8"))
    report = build_report(raw, args.source_productivity, args.recycle_productivity)
    if args.chain_target:
        from quality_chain import chain_report
        routes = {}
        for route in args.producer:
            product, separator, recipe = route.partition("=")
            if not separator or ":" not in product or not recipe:
                parser.error("producer must be TYPE:ITEM=RECIPE")
            routes[product] = recipe
        report["chains"] = chain_report(raw, args.chain_target, args.source_productivity, args.recycle_productivity, routes)
        for chain in report["chains"]["targets"]:
            print("\nCHAIN", chain["target"], "raw inputs:", chain["resources"])
            for scenario in chain["scenarios"]:
                print(scenario["source"], "->", scenario["recycler"],
                      "scrap:", round(scenario["expected_scrap"], 3),
                      "recovery:", {k: f"{v:.2%}" for k, v in scenario["recovery_ratios"].items()},
                      "gaps:", scenario["gaps"], "unvalued:", list(scenario["unvalued_recovery"]))
    print("EXPERIMENTAL PROPOSAL - NOT ACTIVE")
    print("Quality       scrap/craft  recovery  scrap/s (default quality speed)")
    for row in report["curve"]:
        print(f"{row['quality']:12} {row['scrap_factor']:11.1%} {row['recycle_factor']:9.1%} {row['scrap_per_second_factor']:9.1%}")
    print("\nSource -> recycler      recovery/craft  scrap/s  recovery/s (sufficient recycling capacity)")
    for row in report["matrix"]:
        if row["source"] in {"normal", "legendary"} and row["recycler"] in {"normal", "legendary"}:
            label = row["source"] + " -> " + row["recycler"]
            print(f"{label:23} {row['direct_recovery_factor']:14.1%} {row['scrap_per_second_factor']:8.1%} {row['recovery_per_second_factor']:11.1%}")
    print("\nRecipe                         scrap/craft  scrap/s at speed 1")
    focus = {"nuclear-reactor", "rocket-silo", "artillery-turret", "artillery-wagon"}
    for row in report["recipes"]:
        if row["recipe"] in focus and "unsupported" not in row:
            print(f"{row['recipe']:30} {row['expected_scrap_per_craft']:11.3f} {row['scrap_per_second_at_speed_one']:10.3f}")
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("Report:", args.output)


if __name__ == "__main__":
    main()
