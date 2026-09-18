import unittest
from quality_balance import expected, recovery, build_report


class QualityBalanceTests(unittest.TestCase):
    def test_productivity_exclusion_with_range(self):
        result = dict(amount_min=1, amount_max=3, independent_probability=.25, ignored_by_productivity=2)
        self.assertAlmostEqual(expected(result, 3), .75)
        self.assertAlmostEqual(expected(dict(amount=.5), 1), 1)

    def test_mixed_bonus_only_applies_to_material_recovery(self):
        recipes = {
            "yis-recycle-mixed-scrap": dict(ingredients=[dict(name="yis-mixed-scrap", amount=5)],
                                          results=[dict(name="yis-iron-scrap", amount=1, independent_probability=.6)]),
            "yis-recycle-iron-scrap": dict(ingredients=[dict(name="yis-iron-scrap", amount=2)],
                                         results=[dict(name="iron-plate", amount=1)]),
        }
        recovered, gaps = recovery(recipes, "yis-mixed-scrap", 5, 1.12, 3)
        self.assertFalse(gaps)
        # Recipes do not allow productivity; only proposed quality bonuses apply.
        self.assertAlmostEqual(recovered["item:iron-plate"], .3 * 1.12)

    def test_recursive_fallback_is_reported(self):
        recipes = {"yis-recycle-mixed-scrap": dict(ingredients=[dict(name="yis-mixed-scrap", amount=1)],
                                                results=[dict(name="yis-mixed-scrap", amount=1)])}
        _, gaps = recovery(recipes, "yis-mixed-scrap", 1, 1, 0)
        self.assertEqual(gaps, ["cycle:yis-mixed-scrap"])

    def test_legendary_uses_level_five_speed_but_fourth_step_curve(self):
        report = build_report(dict(recipe={}, quality={"normal": {"level": 0}, "legendary": {"level": 5}}))
        self.assertEqual(report["curve"][1]["default_speed_factor"], 2.5)
        self.assertEqual(report["curve"][1]["scrap_per_second_factor"], .5)
        self.assertAlmostEqual(report["matrix"][-1]["mixed_two_stage_factor"], .224)

    def test_four_extremes_recover_actual_material_amounts(self):
        raw = dict(quality={"normal": {"level": 0}, "legendary": {"level": 5}}, recipe={
            "machine": dict(energy_required=2, results=[dict(name="yis-iron-scrap", amount=10)]),
            "yis-recycle-iron-scrap": dict(ingredients=[dict(name="yis-iron-scrap", amount=2)],
                                         results=[dict(name="iron-plate", amount=1)]),
        })
        scenarios = build_report(raw)["recipes"][0]["scenarios"]
        for row, per_craft, per_second in zip(scenarios, [5, 5.6, 1, 1.12], [2.5, 2.8, 1.25, 1.4]):
            self.assertAlmostEqual(row["recovered"]["item:iron-plate"], per_craft)
            self.assertAlmostEqual(row["recovered_per_second_at_base_speed_one"]["item:iron-plate"], per_second)


if __name__ == "__main__":
    unittest.main()
