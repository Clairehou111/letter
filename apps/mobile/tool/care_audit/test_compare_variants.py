import importlib.util
import pathlib
import unittest


MODULE_PATH = pathlib.Path(__file__).with_name("compare_variants.py")
SPEC = importlib.util.spec_from_file_location("care_compare_variants", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CareVariantComparisonTest(unittest.TestCase):
    def test_groups_suffix_variants_with_baseline(self):
        animations = [
            {"id": "heavy-high", "mode": "heavy", "status": "MANUAL_REQUIRED", "metrics": {}},
            {"id": "heavy-high-b", "mode": "heavy", "variant": "bConservative", "status": "PASS", "metrics": {}},
            {"id": "heavy-high-c", "mode": "heavy", "variant": "cSimplified", "status": "PASS", "metrics": {}},
        ]

        groups = MODULE.comparison_groups(animations)

        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]["group"], "heavy-high")
        self.assertEqual(len(groups[0]["candidates"]), 3)

    def test_rejects_candidate_with_deterministic_failure(self):
        groups = [
            {
                "candidates": [
                    {"variant": "bConservative", "scenario_id": "x-b", "status": "FAIL", "metrics": {}},
                    {"variant": "cSimplified", "scenario_id": "x-c", "status": "PASS", "metrics": {}},
                ]
            }
        ]

        decisions = MODULE.visual_eligibility(groups)

        self.assertEqual(decisions[0]["decision"], "REJECT")
        self.assertEqual(decisions[1]["decision"], "ELIGIBLE_FOR_BLINDED_REVIEW")


if __name__ == "__main__":
    unittest.main()
