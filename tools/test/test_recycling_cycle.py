import unittest

from recycling_cycle import cycle_report
from test_quality_chain import fixture


class CycleTests(unittest.TestCase):
    def raw(self):
        raw = fixture()
        raw["recipe"]["machine-recycling"] = dict(
            ingredients=[dict(name="machine", amount=1)],
            results=[dict(name="gear", amount=0, extra_count_fraction=.5)])
        return raw

    def test_product_and_scrap_are_separate_and_not_double_counted(self):
        result = cycle_report(self.raw(), "machine")
        self.assertTrue(result["complete"])
        self.assertEqual(result["ratios"]["item:iron-ore"], dict(product=.25, scrap=.25, total=.5))

    def test_explicit_inherent_bonus_works_without_module_permission(self):
        result = cycle_report(self.raw(), "machine", productivity={"machine": 1})
        self.assertEqual(result["production"]["crafts"]["machine"], .5)
        self.assertEqual(result["ratios"]["item:iron-ore"]["product"], .5)

    def test_explicit_bonus_respects_zero_cap(self):
        raw = self.raw()
        raw["recipe"]["machine"]["maximum_productivity"] = 0
        result = cycle_report(raw, "machine", productivity={"machine": 3})
        self.assertEqual(result["production"]["crafts"]["machine"], 1)

    def test_missing_recycling_suppresses_ratios(self):
        result = cycle_report(fixture(), "machine")
        self.assertFalse(result["complete"])
        self.assertFalse(result["ratios"])

    def test_self_recycling_is_only_counted_once(self):
        raw = self.raw()
        raw["recipe"]["machine-recycling"]["results"] = [dict(name="machine", amount=1, probability=.25)]
        self.assertEqual(cycle_report(raw, "machine")["ratios"]["item:iron-ore"]["product"], .25)

    def test_unknown_recovered_material_is_reported(self):
        raw = self.raw()
        raw["recipe"]["machine-recycling"]["results"] = [dict(name="unknown", amount=1)]
        result = cycle_report(raw, "machine")
        self.assertFalse(result["complete"])
        self.assertIn("product/item:unknown", result["unvalued"])

    def test_casting_returns_solid_valued_on_same_fluid_route(self):
        raw = self.raw()
        raw["recipe"]["machine"]["ingredients"] = [dict(type="fluid", name="molten", amount=10)]
        raw["recipe"]["machine"]["results"] = [dict(name="machine", amount=1)]
        raw["recipe"]["molten"] = dict(ingredients=[dict(name="iron-ore", amount=1)],
                                         results=[dict(type="fluid", name="molten", amount=10)])
        raw["recipe"]["iron-plate"]["ingredients"] = [dict(type="fluid", name="molten", amount=10)]
        raw["recipe"]["machine-recycling"]["results"] = [dict(name="iron-plate", amount=0, extra_count_fraction=.25)]
        result = cycle_report(raw, "machine", productivity={"machine": .5, "iron-plate": .5})
        self.assertTrue(result["complete"])
        self.assertAlmostEqual(result["ratios"]["item:iron-ore"]["total"], .25)


if __name__ == "__main__":
    unittest.main()
