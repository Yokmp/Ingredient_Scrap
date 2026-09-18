import unittest
from quality_chain import Chain, chain_report


def fixture():
    return dict(quality={"normal": {"level": 0}, "legendary": {"level": 5}},
                resource={"ore": {"minable": {"result": "iron-ore"}}}, recipe={
        "machine": dict(ingredients=[dict(name="gear", amount=2)],
                        results=[dict(name="machine", amount=1), dict(name="yis-iron-scrap", amount=1)]),
        "gear": dict(allow_productivity=True, ingredients=[dict(name="iron-plate", amount=4)],
                     results=[dict(name="gear", amount=2), dict(name="yis-iron-scrap", amount=1)]),
        "iron-plate": dict(allow_productivity=True, ingredients=[dict(name="iron-ore", amount=1)],
                           results=[dict(name="iron-plate", amount=1)]),
        "yis-recycle-iron-scrap": dict(allow_productivity=True,
                                      ingredients=[dict(name="yis-iron-scrap", amount=2)],
                                      results=[dict(name="iron-plate", amount=1)]),
    })


class ChainTests(unittest.TestCase):
    def test_batch_output_and_all_upstream_scrap(self):
        report = chain_report(fixture(), ["machine"])["targets"][0]
        self.assertEqual(report["resources"], {"item:iron-ore": 4})
        self.assertEqual(report["scrap"], {"yis-iron-scrap": 2})
        for scenario, ratio in zip(report["scenarios"], [.25, .28, .05, .056]):
            self.assertAlmostEqual(scenario["recovery_ratios"]["item:iron-ore"], ratio)
            self.assertFalse(scenario["gaps"])

    def test_productivity_reduces_upstream_crafts_and_scales_scrap(self):
        report = chain_report(fixture(), ["machine"], 1, 1)["targets"][0]
        self.assertEqual(report["resources"], {"item:iron-ore": 1})
        self.assertEqual(report["crafts"]["gear"], .5)
        self.assertEqual(report["scrap"], {"yis-iron-scrap": 2})
        self.assertEqual(report["scenarios"][0]["recovered"], {"item:iron-plate": 2})
        self.assertEqual(report["scenarios"][0]["recovery_ratios"], {"item:iron-ore": 1})

    def test_shared_intermediate_counts_demands_not_visits(self):
        raw = fixture()
        raw["recipe"]["machine"]["ingredients"] = [dict(name="gear", amount=1), dict(name="component", amount=1)]
        raw["recipe"]["component"] = dict(ingredients=[dict(name="gear", amount=1)], results=[dict(name="component", amount=1)])
        result = Chain(raw).expand("item:machine")
        self.assertEqual(result["crafts"]["gear"], 1)
        self.assertEqual(result["resources"]["item:iron-ore"], 4)
        self.assertEqual(result["scrap"]["yis-iron-scrap"], 2)

    def test_ambiguous_recipe_and_cycles_are_visible(self):
        raw = fixture()
        raw["recipe"]["gear-a"] = raw["recipe"].pop("gear")
        raw["recipe"]["gear-b"] = raw["recipe"]["gear-a"]
        self.assertIn("ambiguous-or-missing:item:gear", Chain(raw).expand("item:machine")["gaps"])
        raw["recipe"]["gear-a"]["ingredients"] = [dict(name="machine", amount=1)]
        result = Chain(raw, producers={"item:gear": "gear-a"}).expand("item:machine")
        self.assertIn("cycle-or-depth:item:machine", result["gaps"])

    def test_explicit_producer_overrides_resource_boundary(self):
        raw = fixture()
        raw["resource"]["plate"] = dict(minable=dict(result="iron-plate"))
        self.assertIn("item:iron-plate", Chain(raw).expand("item:machine")["resources"])
        self.assertIn("item:iron-ore", Chain(raw, producers={"item:iron-plate": "iron-plate"}).expand("item:machine")["resources"])


if __name__ == "__main__":
    unittest.main()
