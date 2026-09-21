import importlib.util
import pathlib
import shutil
import sys
import tempfile
import unittest

import numpy as np


MODULE_PATH = pathlib.Path(__file__).with_name("generate_audio_variants.py")
sys.path.insert(0, str(MODULE_PATH.parent))
SPEC = importlib.util.spec_from_file_location("care_audio_variants", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CareAudioVariantTest(unittest.TestCase):
    def test_circular_crossfade_reduces_length_by_one_fade(self):
        samples = np.linspace(-1, 1, 1000, dtype=np.float32)

        result = MODULE.circular_crossfade(samples, 100)

        self.assertEqual(len(result), 900)
        self.assertTrue(np.isfinite(result).all())

    def test_circular_crossfade_preserves_stereo_channels(self):
        samples = np.column_stack(
            (
                np.linspace(-1, 1, 1000, dtype=np.float32),
                np.linspace(1, -1, 1000, dtype=np.float32),
            )
        )

        result = MODULE.circular_crossfade(samples, 100)

        self.assertEqual(result.shape, (900, 2))
        self.assertFalse(np.allclose(result[:, 0], result[:, 1]))

    def test_onset_softening_limits_gain_only_near_largest_rise(self):
        sample_rate = 1000
        samples = np.concatenate(
            [
                np.full(500, 0.01, dtype=np.float32),
                np.full(500, 0.5, dtype=np.float32),
                np.full(500, 0.1, dtype=np.float32),
            ]
        )

        result, details = MODULE.soften_abrupt_onsets(samples, sample_rate)

        self.assertEqual(len(details), 1)
        self.assertGreater(details[0]["reduction_db"], 0)
        self.assertLess(abs(result[500]), abs(samples[500]))
        self.assertAlmostEqual(result[-1], samples[-1])

        window = round(sample_rate * 0.05)
        chunks = result[: len(result) // window * window].reshape((-1, window))
        rms = np.sqrt(np.mean(np.square(chunks), axis=1) + 1e-12)
        rises = np.diff(20 * np.log10(rms))
        self.assertLessEqual(float(np.max(rises)), 13.0)

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "ffmpeg required")
    def test_mp3_round_trip_preserves_stereo_layout(self):
        sample_rate = 8000
        seconds = np.arange(sample_rate, dtype=np.float32) / sample_rate
        samples = np.column_stack(
            (
                np.sin(2 * np.pi * 220 * seconds),
                np.sin(2 * np.pi * 330 * seconds),
            )
        ).astype(np.float32)

        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory) / "stereo.mp3"
            MODULE._encode_mp3(samples, sample_rate, 2, output)
            decoded = MODULE._decode(output, sample_rate, 2)

        self.assertEqual(decoded.shape[1], 2)
        self.assertFalse(np.allclose(decoded[:, 0], decoded[:, 1], atol=1e-3))

    def test_candidate_gate_rejects_channel_and_loudness_drift(self):
        source = {"channels": 2, "integrated_lufs": -28.0}

        channel_gate, _ = MODULE._candidate_gate(
            source,
            {"channels": 1, "integrated_lufs": -28.0},
            "PASS",
        )
        loudness_gate, _ = MODULE._candidate_gate(
            source,
            {"channels": 2, "integrated_lufs": -40.0},
            "PASS",
        )
        eligible_gate, _ = MODULE._candidate_gate(
            source,
            {"channels": 2, "integrated_lufs": -29.0},
            "PASS",
        )

        self.assertEqual(channel_gate, "REJECT_CHANNEL_LAYOUT")
        self.assertEqual(loudness_gate, "REJECT_METRIC_DRIFT")
        self.assertEqual(eligible_gate, "ELIGIBLE_FOR_LISTENING")


if __name__ == "__main__":
    unittest.main()
