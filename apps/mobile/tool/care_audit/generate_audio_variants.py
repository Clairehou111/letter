#!/usr/bin/env python3
"""Generate reversible A/B/C audio candidates for warned Care assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import numpy as np

from analyze_media import _recommendations, analyze_audio


SCRIPT_DIR = Path(__file__).resolve().parent
MOBILE_ROOT = SCRIPT_DIR.parents[1]
AUDIO_ROOT = MOBILE_ROOT / "assets/audio/care/prototype"


def _command(name: str) -> str:
    value = shutil.which(name)
    if value is None:
        raise RuntimeError(f"Required command not found: {name}")
    return value


def _decode(path: Path, sample_rate: int, channels: int) -> np.ndarray:
    result = subprocess.run(
        [
            _command("ffmpeg"),
            "-v",
            "error",
            "-i",
            str(path),
            "-f",
            "f32le",
            "-ac",
            str(channels),
            "-ar",
            str(sample_rate),
            "pipe:1",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Could not decode {path.name}: {result.stderr.decode(errors='replace')[:500]}")
    decoded = np.frombuffer(result.stdout, dtype="<f4").copy()
    if len(decoded) % channels:
        raise RuntimeError(
            f"Decoded sample count for {path.name} is not divisible by {channels} channels."
        )
    return decoded.reshape((-1, channels))


def _encode_mp3(
    samples: np.ndarray,
    sample_rate: int,
    channels: int,
    output: Path,
) -> None:
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
            str(channels),
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
        raise RuntimeError(f"Could not encode {output.name}: {result.stderr.decode(errors='replace')[:500]}")


def circular_crossfade(samples: np.ndarray, fade_samples: int) -> np.ndarray:
    """Join the tail to the head with an equal-power wrap crossfade."""
    fade_samples = min(fade_samples, max(1, len(samples) // 4))
    if fade_samples <= 1:
        return samples.copy()
    phase = np.linspace(0, math.pi / 2, fade_samples, dtype=np.float32)
    gain_shape = (fade_samples,) + (1,) * (samples.ndim - 1)
    tail_gain = np.cos(phase).reshape(gain_shape)
    head_gain = np.sin(phase).reshape(gain_shape)
    seam = samples[-fade_samples:] * tail_gain + samples[:fade_samples] * head_gain
    return np.concatenate([seam, samples[fade_samples:-fade_samples]]).astype(np.float32)


def soften_abrupt_onsets(
    samples: np.ndarray,
    sample_rate: int,
    *,
    warning_rise_db: float = 15.0,
    target_rise_db: float = 12.0,
    maximum_reduction_db: float = 30.0,
    recovery_seconds: float = 0.75,
    maximum_events: int = 8,
) -> tuple[np.ndarray, list[dict[str, float]]]:
    """Fade into isolated abrupt 50 ms rises, then recover smoothly.

    Each edit begins at its detected event rather than fading down the
    preceding ambience. This avoids creating a new pre-event dip and keeps
    every channel under the same envelope so stereo placement remains intact.
    """
    window = max(1, round(sample_rate * 0.05))
    count = len(samples) // window
    if count < 3:
        return samples.copy(), []
    chunks = samples[: count * window].reshape(
        (count, window) + samples.shape[1:]
    )
    rms_axes = tuple(range(1, chunks.ndim))
    rms = np.sqrt(np.mean(np.square(chunks), axis=rms_axes) + 1e-12)
    levels = 20 * np.log10(rms)
    rises = np.diff(levels)
    indexes = np.flatnonzero(rises > warning_rise_db)
    if not len(indexes):
        return samples.copy(), []

    result = samples.copy()
    envelope = np.ones(len(samples), dtype=np.float32)
    details: list[dict[str, float]] = []
    prior_recovery_end = -1
    for index in indexes[:maximum_events]:
        rise = float(rises[index])
        onset = (int(index) + 1) * window
        if onset < prior_recovery_end:
            continue
        reduction_db = min(maximum_reduction_db, rise - target_rise_db)
        recovery = min(
            round(sample_rate * recovery_seconds),
            len(samples) - onset,
        )
        if not recovery:
            continue
        recovery_db = np.linspace(
            -reduction_db,
            0,
            recovery,
            dtype=np.float32,
        )
        envelope[onset : onset + recovery] = np.power(10, recovery_db / 20)
        prior_recovery_end = onset + recovery
        details.append(
            {
                "onset_seconds": onset / sample_rate,
                "rise_db": rise,
                "reduction_db": reduction_db,
                "target_rise_db": target_rise_db,
                "recovery_seconds": recovery_seconds,
            }
        )
    envelope_shape = (len(envelope),) + (1,) * (samples.ndim - 1)
    result *= envelope.reshape(envelope_shape)
    return result, details


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _status(recommendations: list[dict[str, str]]) -> str:
    if any(item["status"] == "FAIL" for item in recommendations):
        return "FAIL"
    if any(item["status"] == "WARN" for item in recommendations):
        return "WARN"
    if any(item["status"] == "MANUAL_REQUIRED" for item in recommendations):
        return "MANUAL_REQUIRED"
    return "PASS"


def _audit_candidate(path: Path) -> dict[str, Any]:
    metrics = analyze_audio(path)
    recommendations = _recommendations("physical", None, metrics)
    return {
        "path": str(path),
        "sha256": _sha256(path),
        "status": _status(recommendations),
        "metrics": metrics,
        "recommendations": recommendations,
    }


def _candidate_gate(
    source_metrics: dict[str, Any],
    candidate_metrics: dict[str, Any],
    status: str,
) -> tuple[str, str]:
    source_channels = int(source_metrics.get("channels") or 0)
    candidate_channels = int(candidate_metrics.get("channels") or 0)
    if source_channels != candidate_channels:
        return (
            "REJECT_CHANNEL_LAYOUT",
            f"channel count changed from {source_channels} to {candidate_channels}",
        )
    source_lufs = source_metrics.get("integrated_lufs")
    candidate_lufs = candidate_metrics.get("integrated_lufs")
    if source_lufs is not None and candidate_lufs is not None:
        drift = float(candidate_lufs) - float(source_lufs)
        if abs(drift) > 3:
            return (
                "REJECT_METRIC_DRIFT",
                f"integrated loudness changed by {drift:+.1f} LU",
            )
    if status == "PASS":
        return (
            "ELIGIBLE_FOR_LISTENING",
            "deterministic warnings cleared without material channel or loudness drift",
        )
    return (
        "MANUAL_REVIEW_REQUIRED",
        "one or more deterministic warnings remain",
    )


def _markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Care audio A/B/C candidates",
        "",
        "> Reversible research derivatives for deterministic comparison. App assets are unchanged.",
        "",
        "| Asset | Variant | Status | Candidate gate | Channels | Duration | LUFS | Loop seam delta | Max 50 ms rise | Processing |",
        "|---|---|---:|---|---:|---:|---:|---:|---:|---|",
    ]
    for asset in report["assets"]:
        for variant in asset["variants"]:
            metrics = variant["metrics"]
            lines.append(
                "| {asset} | {variant} | {status} | {gate} | {channels} | {duration:.2f}s | {lufs:.1f} | {seam:.2f} dB | {rise:.1f} dB | {processing} |".format(
                    asset=asset["asset"],
                    variant=variant["variant"],
                    status=variant["status"],
                    gate=variant["candidate_gate"],
                    channels=metrics.get("channels", 0),
                    duration=metrics.get("duration_seconds", 0),
                    lufs=metrics.get("integrated_lufs", 0),
                    seam=metrics.get("loop_seam_rms_difference_db", 0),
                    rise=metrics.get("max_50ms_rms_increase_db", 0),
                    processing=variant["processing"],
                )
            )
    lines.extend(
        [
            "",
            "A is the untouched runtime asset. B uses a 500 ms equal-power circular crossfade. C uses the same seam repair and, only when detected, a channel-preserving 750 ms recovery envelope that targets the largest abrupt 50 ms energy rise.",
            "",
            "Candidate gates reject channel-layout changes and integrated-loudness drift above 3 LU even when a derivative clears the deterministic warning thresholds.",
            "",
            "These transformations are candidates, not production replacements. Listen on iPhone speaker and headphones before selecting one.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    audit = json.loads(args.audit.read_text(encoding="utf-8"))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    warned = [item for item in audit.get("audio", []) if item.get("status") == "WARN"]
    assets: list[dict[str, Any]] = []
    try:
        for item in warned:
            source = AUDIO_ROOT / item["asset"]
            sample_rate = int(item.get("metrics", {}).get("sample_rate") or 44100)
            channels = int(item.get("metrics", {}).get("channels") or 1)
            samples = _decode(source, sample_rate, channels)
            source_candidate = _audit_candidate(source)
            variants = [
                {
                    "variant": "A",
                    "processing": "untouched runtime asset",
                    "candidate_gate": "SOURCE_REFERENCE",
                    "candidate_gate_reason": "untouched runtime source",
                    **source_candidate,
                }
            ]
            for name, fade_seconds, soften in (("B", 0.5, False), ("C", 0.5, True)):
                candidate = circular_crossfade(samples, round(sample_rate * fade_seconds))
                onsets: list[dict[str, float]] = []
                if soften:
                    candidate, onsets = soften_abrupt_onsets(candidate, sample_rate)
                target = output / item["asset"].removesuffix(".mp3") / f"{name}.mp3"
                _encode_mp3(candidate, sample_rate, channels, target)
                processing = f"{fade_seconds * 1000:.0f} ms equal-power circular crossfade"
                if onsets:
                    timestamps = ", ".join(
                        f"{onset['onset_seconds']:.2f}s" for onset in onsets
                    )
                    maximum_reduction = max(
                        onset["reduction_db"] for onset in onsets
                    )
                    processing += (
                        f"; softened {len(onsets)} abrupt rise(s) at {timestamps}; "
                        f"maximum {maximum_reduction:.1f} dB reduction with "
                        f"{onsets[0]['recovery_seconds'] * 1000:.0f} ms recovery"
                    )
                audited = _audit_candidate(target)
                gate, gate_reason = _candidate_gate(
                    source_candidate["metrics"],
                    audited["metrics"],
                    audited["status"],
                )
                variants.append(
                    {
                        "variant": name,
                        "processing": processing,
                        "onset_processing": onsets,
                        "candidate_gate": gate,
                        "candidate_gate_reason": gate_reason,
                        **audited,
                    }
                )
            assets.append(
                {
                    "asset": item["asset"],
                    "source_status": item["status"],
                    "variants": variants,
                }
            )
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"Audio variant generation failed: {error}", file=sys.stderr)
        return 2
    report = {
        "schema_version": 1,
        "source_audit": str(args.audit.resolve()),
        "scope": "runtime-referenced Care audio assets with deterministic WARN status only",
        "production_assets_changed": False,
        "assets": assets,
    }
    json_path = output / "care-audio-variants.json"
    markdown_path = output / "care-audio-variants.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown_path.write_text(_markdown(report), encoding="utf-8")
    print(json.dumps({"json": str(json_path), "markdown": str(markdown_path), "assets": len(assets)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
