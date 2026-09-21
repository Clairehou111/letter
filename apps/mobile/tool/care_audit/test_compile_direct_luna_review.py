import importlib.util
import pathlib
import unittest


MODULE_PATH = pathlib.Path(__file__).with_name("compile_direct_luna_review.py")
SPEC = importlib.util.spec_from_file_location("care_compile_direct_luna_review", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CompileDirectLunaReviewTest(unittest.TestCase):
    def test_unblinds_and_does_not_choose_global_winner(self):
        heavy = [
            {
                "group_id": "heavy-path",
                "preferred": "X",
                "ranking": ["X", "Y", "Z"],
                "confidence": 0.8,
                "rationale": "Clearer transition.",
                "observations": [{"candidate": "X", "strengths": [], "risks": []}],
                "specific_parameter_recommendations": [],
                "human_validation_questions": [],
            }
        ]
        racing = []
        mappings = {
            "heavy-path": {
                "X": "bConservative",
                "Y": "aBaseline",
                "Z": "cSimplified",
            }
        }

        report = MODULE.build_report(heavy, racing, mappings)

        self.assertEqual(report["reviews"][0]["preferred_variant"], "bConservative")
        self.assertEqual(
            report["reviews"][0]["ranking_variants"],
            ["bConservative", "aBaseline", "cSimplified"],
        )
        self.assertEqual(
            report["reviews"][0]["observations"][0]["variant"], "bConservative"
        )
        self.assertFalse(report["summary"]["single_global_winner"])
        self.assertFalse(report["external_api_key_used"])

    def test_rejects_duplicate_ranking(self):
        review = [
            {
                "group_id": "path",
                "preferred": "X",
                "ranking": ["X", "X", "Z"],
                "confidence": 0.5,
                "rationale": "",
            }
        ]
        mappings = {"path": {"X": "aBaseline", "Y": "bConservative", "Z": "cSimplified"}}

        with self.assertRaises(ValueError):
            MODULE.build_report(review, [], mappings)


if __name__ == "__main__":
    unittest.main()
