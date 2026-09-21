import importlib.util
import pathlib
import unittest

import numpy as np


MODULE_PATH = pathlib.Path(__file__).with_name("generate_heartbeat_candidate.py")
SPEC = importlib.util.spec_from_file_location("care_heartbeat_candidate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CareHeartbeatCandidateTest(unittest.TestCase):
    def test_generation_is_finite_centered_and_has_exact_period_count(self):
        samples, manifest = MODULE.generate_heartbeat(
            sample_rate=8000,
            duration_seconds=20,
            bpm=60,
        )

        self.assertEqual(samples.shape, (160000,))
        self.assertTrue(np.isfinite(samples).all())
        self.assertEqual(manifest["beat_count"], 20)
        self.assertAlmostEqual(float(np.max(np.abs(samples))), 10 ** (-12 / 20))

    def test_loop_boundary_is_quiet_and_balanced(self):
        samples, _ = MODULE.generate_heartbeat(
            sample_rate=8000,
            duration_seconds=20,
            bpm=60,
        )
        window = 2000
        first_rms = float(np.sqrt(np.mean(samples[:window] ** 2)))
        last_rms = float(np.sqrt(np.mean(samples[-window:] ** 2)))
        difference_db = 20 * np.log10(max(first_rms, 1e-9) / max(last_rms, 1e-9))

        self.assertLess(abs(difference_db), 1.0)
        self.assertLess(abs(float(samples[0] - samples[-1])), 0.01)

    def test_requires_a_whole_number_of_periods(self):
        with self.assertRaises(ValueError):
            MODULE.generate_heartbeat(duration_seconds=20, bpm=64)


if __name__ == "__main__":
    unittest.main()
