import importlib.util
import pathlib
import unittest

import numpy as np


MODULE_PATH = pathlib.Path(__file__).with_name("analyze_media.py")
SPEC = importlib.util.spec_from_file_location("care_audit_analyzer", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CareAuditAnalyzerTest(unittest.TestCase):
    def test_opposing_flash_counter_counts_direction_changes(self):
        flashes, per_second, maximum = MODULE._count_opposing_flashes(
            np.asarray([0.1, 0.3, 0.1, 0.3, 0.1], dtype=np.float32),
            fps=30,
        )

        self.assertEqual(flashes, 3)
        self.assertEqual(per_second, 3)
        self.assertAlmostEqual(maximum, 0.2)

    def test_flat_sequence_has_no_flash(self):
        flashes, per_second, maximum = MODULE._count_opposing_flashes(
            np.asarray([0.2, 0.21, 0.2, 0.205], dtype=np.float32),
            fps=30,
        )

        self.assertEqual(flashes, 0)
        self.assertEqual(per_second, 0)
        self.assertLess(maximum, 0.1)

    def test_flash_recommendation_is_a_failure(self):
        recommendations = MODULE._recommendations(
            "explode",
            {
                "opposing_flash_count": 4,
                "max_opposing_flashes_per_second": 4,
                "red_flash_frame_count": 0,
                "max_red_flash_events_per_second": 0,
                "max_frame_luminance_step": 0.05,
                "p95_frame_difference": 0.02,
            },
            None,
        )

        self.assertEqual(recommendations[0]["status"], "FAIL")
        self.assertEqual(recommendations[0]["review"], "AUTO")

    def test_emotional_effect_remains_manual(self):
        recommendations = MODULE._recommendations(
            "heavy",
            {
                "opposing_flash_count": 0,
                "max_opposing_flashes_per_second": 0,
                "red_flash_frame_count": 0,
                "max_red_flash_events_per_second": 0,
                "max_frame_luminance_step": 0.01,
                "p95_frame_difference": 0.2,
            },
            None,
        )

        self.assertEqual(recommendations[0]["status"], "MANUAL_REQUIRED")
        self.assertEqual(recommendations[0]["review"], "MANUAL")

    def test_detects_slow_motion_period(self):
        fps = 20
        times = np.arange(0, 25, 1 / fps)
        period, correlation = MODULE._strongest_period(
            np.sin(times * 2 * np.pi / 5).astype(np.float32),
            samples_per_second=fps,
        )

        self.assertIsNotNone(period)
        self.assertIsNotNone(correlation)
        self.assertAlmostEqual(period, 5, delta=0.1)
        self.assertGreater(correlation, 0.95)

    def test_optical_flow_is_normalized_to_30_fps(self):
        self.assertAlmostEqual(MODULE._flow_at_30_fps(3.0, 60), 6.0)
        self.assertAlmostEqual(MODULE._flow_at_30_fps(6.0, 2), 0.4)

    def test_box_counting_dimension_of_line_is_near_one(self):
        mask = np.zeros((128, 128), dtype=bool)
        np.fill_diagonal(mask, True)

        dimension, fit = MODULE._box_counting_dimension(mask)

        self.assertIsNotNone(dimension)
        self.assertIsNotNone(fit)
        self.assertAlmostEqual(dimension, 1.0, delta=0.15)
        self.assertGreater(fit, 0.95)

    def test_saliency_proxy_centers_a_single_focus(self):
        yy, xx = np.mgrid[0:192, 0:128]
        image = np.exp(-((xx - 64) ** 2 + (yy - 96) ** 2) / 180).astype(np.float32)

        center_x, center_y, _, focus_count, concentration, _ = MODULE._saliency_proxy(
            image,
            None,
        )

        self.assertAlmostEqual(center_x, 0.5, delta=0.08)
        self.assertAlmostEqual(center_y, 0.5, delta=0.08)
        self.assertGreater(focus_count, 0)
        self.assertGreater(concentration, 0.1)

    def test_cross_modal_correlation_finds_known_lag(self):
        rate = 20
        time = np.arange(200) / rate
        visual = np.sin(2 * np.pi * time / 2.5)
        audio = np.roll(visual, 3)

        result = MODULE._cross_modal_correlation(
            visual,
            audio,
            samples_per_second=rate,
        )

        self.assertGreater(result["correlation"], 0.95)
        self.assertAlmostEqual(result["lag_ms"], 150, delta=1)

    def test_dominant_palette_reports_weights(self):
        pixels = np.asarray(
            [[255, 0, 0]] * 75 + [[0, 0, 255]] * 25,
            dtype=np.uint8,
        )

        palette = MODULE._dominant_colors([pixels], clusters=2)

        self.assertEqual(palette[0]["hex"], "#FF0000")
        self.assertAlmostEqual(palette[0]["weight"], 0.75)
        self.assertAlmostEqual(sum(item["weight"] for item in palette), 1)

    def test_local_flash_detects_one_flashing_tile(self):
        tiles = np.full((12, 64), 0.2, dtype=np.float32)
        tiles[:, 0] = np.resize(np.asarray([0.1, 0.4], dtype=np.float32), 12)

        metrics = MODULE._local_flash_metrics(tiles, fps=12)

        self.assertGreater(metrics["max_local_opposing_flashes_per_second"], 3)
        self.assertGreater(metrics["max_local_luminance_step"], 0.1)

    def test_audio_spectrum_reports_tone_without_clipping(self):
        sample_rate = 16000
        times = np.arange(sample_rate, dtype=np.float32) / sample_rate
        samples = 0.2 * np.sin(2 * np.pi * 440 * times)

        metrics = MODULE._audio_spectral_metrics(samples, sample_rate)

        self.assertAlmostEqual(metrics["spectral_centroid_mean_hz"], 440, delta=25)
        self.assertEqual(metrics["clipped_sample_fraction"], 0)

    def test_pulse_proxy_finds_regular_sixty_bpm_envelope(self):
        sample_rate = 1000
        samples = np.zeros(sample_rate * 20, dtype=np.float32)
        pulse = np.exp(-np.arange(200, dtype=np.float32) / 35)
        for second in range(20):
            onset = second * sample_rate + 250
            samples[onset : onset + len(pulse)] += pulse

        metrics = MODULE._pulse_cadence_metrics(samples, sample_rate)

        self.assertAlmostEqual(metrics["pulse_periodicity_bpm"], 60, delta=1)
        self.assertGreater(metrics["pulse_periodicity_correlation"], 0.8)
        self.assertLess(metrics["pulse_proxy_interval_cv"], 0.05)


if __name__ == "__main__":
    unittest.main()
