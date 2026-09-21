import importlib.util
import pathlib
import sys
import unittest


MODULE_PATH = pathlib.Path(__file__).with_name("llm_compare_abc.py")
sys.path.insert(0, str(MODULE_PATH.parent))
SPEC = importlib.util.spec_from_file_location("care_llm_compare_abc", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CareLlmCompareAbcTest(unittest.TestCase):
    def test_blind_mapping_is_stable_and_complete(self):
        first = MODULE.blind_mapping("heavy-full-high")
        second = MODULE.blind_mapping("heavy-full-high")

        self.assertEqual(first, second)
        self.assertEqual(set(first), {"X", "Y", "Z"})
        self.assertEqual(set(first.values()), {"aBaseline", "bConservative", "cSimplified"})

    def test_rejects_duplicate_ranking(self):
        with self.assertRaises(RuntimeError):
            MODULE._validate_review(
                {"group_id": "x", "ranking": ["X", "X", "Y"]},
                "x",
            )


if __name__ == "__main__":
    unittest.main()
