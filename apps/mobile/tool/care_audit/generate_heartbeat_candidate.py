#!/usr/bin/env python3
"""Generate a deterministic, seamless simulated-heartbeat Care candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
from pathlib import Path

import numpy as np


def _command(name: str) -> str:
    value = shutil.which(name)
    if value is None:
        raise RuntimeError(f"Required command not found: {name}")
    return value


def _pulse(
    time: np.ndarray,
    onset: float,
    *,
    amplitude: float,
    fundamental_hz: float,
    decay_seconds: float,
) -> np.ndarray:
    age = time - onset
    active = (age >= 0) & (age <= decay_seconds * 6)
    local = np.maximum(age, 0)
    attack = 1 - np.exp(-local / 0.008)
    decay = np.exp(-local / decay_seconds)
    body = (
        np.sin(2 * math.pi * fundamental_hz * local)
        + 0.46 * np.sin(2 * math.pi * fundamental_hz * 2 * local)
        + 0.18 * np.sin(2 * math.pi * fundamental_hz * 3 * local)
        + 0.10 * np.sin(2 * math.pi * fundamental_hz * 4 * local)
        + 0.06 * np.sin(2 * math.pi * fundamental_hz * 5 * local)
    )
    return np.where(active, amplitude * attack * decay * body, 0).astype(
        np.float32
    )


def generate_heartbeat(
    *,
    sample_rate: int = 44100,
    duration_seconds: float = 20.0,
    bpm: float = 60.0,
) -> tuple[np.ndarray, dict[str, float | int]]:
    period = 60 / bpm
    beat_count_float = duration_seconds / period
    beat_count = round(beat_count_float)
    if not math.isclose(beat_count_float, beat_count, abs_tol=1e-6):
        raise ValueError("Duration must contain a whole number of heartbeat periods.")

    frame_count = round(sample_rate * duration_seconds)
    time = np.arange(frame_count, dtype=np.float64) / sample_rate
    # Put the boundary in the quiet remainder after the prior dub and before
    # the next lub rather than cutting through either pulse.
    first_beat = period / 4
    heartbeat = np.zeros(frame_count, dtype=np.float32)
    organic_cycle = (1.0, 0.96, 1.025, 0.985, 1.01)
    for index in range(beat_count):
        onset = first_beat + index * period
        variation = organic_cycle[index % len(organic_cycle)]
        heartbeat += _pulse(
            time,
            onset,
            amplitude=0.72 * variation,
            fundamental_hz=62,
            decay_seconds=0.075,
        )
        heartbeat += _pulse(
            time,
            onset + 0.23,
            amplitude=0.46 * variation,
            fundamental_hz=78,
            decay_seconds=0.06,
        )

    # Integer-cycle body tones provide a continuous, center-panned floor and
    # enough low-mid harmonic information to survive a phone speaker better
    # than sub-bass alone.
    body_tone = (
        0.012 * np.sin(2 * math.pi * 60 * time)
        + 0.009 * np.sin(2 * math.pi * 120 * time + 0.4)
        + 0.004 * np.sin(2 * math.pi * 180 * time + 1.1)
        + 0.003 * np.sin(2 * math.pi * 240 * time + 0.7)
        + 0.0015 * np.sin(2 * math.pi * 360 * time + 1.4)
    ).astype(np.float32)
    samples = heartbeat + body_tone
    target_peak = 10 ** (-12 / 20)
    samples *= target_peak / max(float(np.max(np.abs(samples))), 1e-9)
    return samples.astype(np.float32), {
        "sample_rate": sample_rate,
        "duration_seconds": duration_seconds,
        "bpm": bpm,
        "beat_count": beat_count,
        "lub_dub_offset_seconds": 0.23,
        "target_peak_dbfs": -12.0,
    }


def _encode_mp3(samples: np.ndarray, sample_rate: int, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            _command("ffmpeg"),
            "-v",
            "error",
            "-y",
            "-f",
            "f32le",
            "-ac",
            "1",
            "-ar",
            str(sample_rate),
            "-i",
            "pipe:0",
            "-codec:a",
            "libmp3lame",
            "-b:a",
            "192k",
            str(output),
        ],
        input=np.asarray(samples, dtype="<f4").tobytes(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Could not encode {output.name}: "
            f"{result.stderr.decode(errors='replace')[:500]}"
        )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--bpm", type=float, default=60.0)
    parser.add_argument("--duration", type=float, default=20.0)
    args = parser.parse_args()
    try:
        samples, manifest = generate_heartbeat(
            duration_seconds=args.duration,
            bpm=args.bpm,
        )
        _encode_mp3(samples, int(manifest["sample_rate"]), args.output)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"Heartbeat generation failed: {error}")
        return 2
    manifest.update(
        {
            "path": str(args.output.resolve()),
            "sha256": _sha256(args.output),
            "intent": "simulated internal heartbeat; not user biometric data",
            "production_assets_changed": False,
        }
    )
    manifest_path = args.output.with_suffix(".json")
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"audio": str(args.output), "manifest": str(manifest_path)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
