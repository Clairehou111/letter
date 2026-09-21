import importlib.util
import json
import pathlib
import tempfile
import unittest

import numpy as np


MODULE_PATH = pathlib.Path(__file__).with_name("llm_review.py")
SPEC = importlib.util.spec_from_file_location("care_llm_review", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CareLlmReviewTest(unittest.TestCase):
    def test_keyframe_selection_keeps_endpoints_and_motion_peak(self):
        frames = [pathlib.Path(f"frame_{index:04d}.png") for index in range(100)]
        differences = [0.0] * 99
        differences[48] = 1.0

        selected = MODULE.select_keyframes(
            frames,
            {"time_series": {"frame_difference": differences}},
            8,
        )

        indexes = [item["index"] for item in selected]
        self.assertEqual(indexes[0], 0)
        self.assertEqual(indexes[-1], 99)
        self.assertTrue(any(45 <= index <= 55 for index in indexes))
        self.assertEqual(len(indexes), 8)
        self.assertTrue(any(15 <= index <= 25 for index in indexes))
        self.assertTrue(any(75 <= index <= 85 for index in indexes))

    def test_cache_key_changes_when_evidence_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            evidence = pathlib.Path(directory) / "evidence.jpg"
            evidence.write_bytes(b"first")
            schema = {"type": "object"}
            first = MODULE._cache_key({}, evidence, "user", "system", schema, "model")
            evidence.write_bytes(b"second")
            second = MODULE._cache_key({}, evidence, "user", "system", schema, "model")

        self.assertNotEqual(first, second)

    def test_api_payload_uses_image_and_strict_schema(self):
        with tempfile.TemporaryDirectory() as directory:
            evidence = pathlib.Path(directory) / "evidence.jpg"
            evidence.write_bytes(b"jpeg")
            payload = MODULE._api_payload(
                "gpt-5.6-luna",
                "system",
                "user",
                evidence,
                {"type": "object", "additionalProperties": False},
            )

        content = payload["input"][1]["content"]
        self.assertEqual(content[1]["type"], "input_image")
        self.assertTrue(content[1]["image_url"].startswith("data:image/jpeg;base64,"))
        self.assertTrue(payload["text"]["format"]["strict"])
        self.assertFalse(payload["store"])

    def test_extracts_structured_output_text(self):
        expected = {"subject_id": "heavy-full-low"}
        response = {
            "output": [
                {
                    "type": "message",
                    "content": [{"type": "output_text", "text": json.dumps(expected)}],
                }
            ]
        }

        self.assertEqual(json.loads(MODULE._extract_output_text(response)), expected)

    def test_schema_disallows_extra_properties_at_root(self):
        schema = json.loads(MODULE.SCHEMA_PATH.read_text(encoding="utf-8"))

        self.assertFalse(schema["additionalProperties"])
        self.assertIn("recommendations", schema["required"])

    def test_series_peak_positions_finds_focus_shift(self):
        positions = MODULE._series_peak_positions(
            {
                "time_series": {
                    "saliency_center_x": [0.1, 0.1, 0.9, 0.9],
                    "saliency_center_y": [0.5, 0.5, 0.5, 0.5],
                }
            }
        )

        focus = [item for item in positions if item[1] == "focus shift"]
        self.assertEqual(len(focus), 1)
        self.assertGreater(focus[0][2], 0.7)


if __name__ == "__main__":
    unittest.main()
