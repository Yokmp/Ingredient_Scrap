"""Expected full-chain scrap accounting with explicit producer selection."""
from collections import defaultdict
from quality_balance import expected, is_scrap, productivity_for, recovery


def key(entry):
    return entry.get("type", "item") + ":" + entry["name"]


class Chain:
    def __init__(self, raw, productivity=0, producers=None, recipe_productivity=None):
        self.raw = raw
        self.recipes = raw["recipe"]
        self.productivity = productivity
        self.producers = producers or {}
        self.recipe_productivity = recipe_productivity or {}
        self.roots = set()
        for resource in raw.get("resource", {}).values():
            mining = resource.get("minable", {})
            self.roots.update(key(r) for r in mining.get("results", []))
            if mining.get("result"):
                self.roots.add("item:" + mining["result"])
        for tile in raw.get("tile", {}).values():
            if tile.get("fluid"):
                self.roots.add("fluid:" + tile["fluid"])
        self.index = defaultdict(list)
        for name, recipe in self.recipes.items():
            categories = recipe.get("categories", [recipe.get("category", "crafting")])
            if name.startswith("yis-") or name.endswith("-recycling") or "recycling" in categories:
                continue
            for result in recipe.get("results", []):
                if not is_scrap(result["name"]) and expected(result) > 0:
                    self.index[key(result)].append(name)

    def expand(self, target, amount=1):
        resources, scraps, crafts = defaultdict(float), defaultdict(float), defaultdict(float)
        contributions = defaultdict(lambda: defaultdict(float))
        selected, alternatives, gaps = {}, {}, set()

        def visit(product, quantity, path):
            if quantity <= 0:
                return
            if product in self.roots and product not in self.producers:
                resources[product] += quantity
                return
            if product in path or len(path) >= 100:
                gaps.add("cycle-or-depth:" + product)
                return
            choices = sorted(set(self.index.get(product, [])))
            name = self.producers.get(product)
            if name is None:
                canonical = product.split(":", 1)[1]
                name = canonical if canonical in choices else (choices[0] if len(choices) == 1 else None)
            if not name or name not in choices:
                gaps.add("ambiguous-or-missing:" + product)
                alternatives[product] = choices
                return
            recipe = self.recipes[name]
            if any("shared_probability" in r for r in recipe.get("results", [])):
                gaps.add("shared-probability:" + name)
                return
            productivity = productivity_for(recipe, self.productivity)
            if name in self.recipe_productivity:
                # Explicit totals include inherent/research bonuses, not only modules.
                productivity = min(self.recipe_productivity[name], recipe.get("maximum_productivity", 3))
            output = sum(expected(r, productivity) for r in recipe["results"] if key(r) == product)
            if output <= 0:
                gaps.add("zero-output:" + name)
                return
            count = quantity / output
            selected[product] = name
            if len(choices) > 1:
                alternatives[product] = choices
            crafts[name] += count
            for result in recipe["results"]:
                if is_scrap(result["name"]):
                    value = count * expected(result, productivity)
                    scraps[result["name"]] += value
                    contributions[name][result["name"]] += value
            for ingredient in recipe.get("ingredients", []):
                if "amount" not in ingredient:
                    gaps.add("unsupported-ingredient:" + name)
                    continue
                visit(key(ingredient), ingredient["amount"] * count, (*path, product))

        visit(target, amount, ())
        return dict(resources=dict(resources), scrap=dict(scraps), crafts=dict(crafts),
                    contributors=[dict(recipe=n, scrap=dict(s), total=sum(s.values()))
                                  for n, s in sorted(contributions.items(), key=lambda x: (-sum(x[1].values()), x[0]))],
                    selected_producers=selected, alternatives=alternatives, gaps=sorted(gaps))


def chain_report(raw, targets, source_productivity=0, recycle_productivity=0, producers=None):
    # Explicit conventional oil routes; surplus coproducts receive no credit.
    routes = {"fluid:petroleum-gas": "basic-oil-processing", "fluid:heavy-oil": "advanced-oil-processing",
              "fluid:sulfuric-acid": "sulfuric-acid", "fluid:molten-iron": "iron-ore-melting"}
    routes = {k: v for k, v in routes.items() if v in raw["recipe"]}
    routes.update(producers or {})
    chain = Chain(raw, source_productivity, routes)
    output = []
    for target in targets:
        base = chain.expand("item:" + target)
        scenarios = []
        for source, scrap_factor in (("normal", 1), ("legendary", .2)):
            for recycler, bonus in (("normal", 1), ("legendary", 1.12)):
                if source not in raw.get("quality", {}) or recycler not in raw.get("quality", {}):
                    continue
                recovered, equivalent = defaultdict(float), defaultdict(float)
                unvalued = {}
                gaps = set(base["gaps"])
                for name, quantity in base["scrap"].items():
                    materials, missing = recovery(raw["recipe"], name, quantity * scrap_factor, bonus, recycle_productivity)
                    gaps.update(missing)
                    for material, amount in materials.items():
                        recovered[material] += amount
                for material, amount in recovered.items():
                    value = chain.expand(material, amount)
                    if value["gaps"]:
                        unvalued[material] = dict(amount=amount, gaps=value["gaps"])
                        continue
                    for resource, quantity in value["resources"].items():
                        equivalent[resource] += quantity
                ratios = ({r: equivalent.get(r, 0) / quantity for r, quantity in base["resources"].items() if quantity > 0}
                          if not base["gaps"] else {})
                scenarios.append(dict(source=source, recycler=recycler, recovered=dict(recovered),
                                      recovered_resource_equivalent=dict(equivalent), recovery_ratios=ratios,
                                      unvalued_recovery=unvalued,
                                      complete=not gaps and not unvalued,
                                      off_chain_resources={r: v for r, v in equivalent.items() if r not in base["resources"]},
                                      expected_scrap=sum(base["scrap"].values()) * scrap_factor, gaps=sorted(gaps)))
        output.append(dict(target=target, **base, scenarios=scenarios))
    return dict(source_productivity=source_productivity, recycle_productivity=recycle_productivity,
                assumptions=["One finished target, fractional expected crafts; all upstream machines use the selected production quality.",
                             "Raw resource extraction is a boundary; mining productivity, fuel, energy and research costs are excluded.",
                             "Canonical same-name producers preferred; other ambiguous producers require an explicit route.",
                             "Oil routes discard surplus coproducts; this can overestimate oil input.",
                             "Recovered materials valued by replacement raw inputs at the same production productivity.",
                             "Scrap from recycling or replacement valuation is not credited again; no recursive reinvestment.",
                             "No summed ratio across different raw resources or fluid/item units.",
                             "Productivity is a recipe-level bound, not proof of attainable machine/module configurations."], targets=output)
