#!/usr/bin/env python3
"""Local, conservative audit for Care animation captures and audio assets.

This tool deliberately reports engineering signals and review prompts. It does
not infer calmness, reduced anxiety, depression, or any other clinical outcome.
It uses ffmpeg/ffprobe for decoding and numpy for deterministic calculations.
OpenCV is optional; when installed, the report includes Farneback optical-flow
statistics in addition to the dependency-free frame-difference proxy.
"""

from __future__ import annotations

import argparse
import colorsys
import functools
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import numpy as np


MODES = {"explode", "heavy", "racing", "space", "physical", "breath"}

MODE_GUIDANCE = {
    "explode": {
        "goal": "high activation -> pause -> protect a consequential decision",
        "suggestions": [
            "Reduce accelerating particles, rapid impact feedback, and rising haptic frequency if activation keeps increasing.",
            "Keep the compression-and-seal transformation, then hand off to a quiet pause before sending, posting, buying, quitting, or ending a relationship.",
            "Review whether the scene makes people want to keep hitting the screen; this requires manual review.",
        ],
    },
    "heavy": {
        "goal": "heavy rain -> gradual thinning -> visual stillness, with no action required",
        "suggestions": [
            "Verify across the full sequence that rain density, speed, and streak length decrease gradually to stillness without an abrupt cut or bright flash.",
            "Keep the rain self-resolving; breathing and every other interaction must remain optional rather than becoming a task the person must complete.",
            "Treat the stopped rain as a visual ending only: the settled copy must not claim that crying, sadness, or depression has ended or that recovery is guaranteed.",
        ],
    },
    "racing": {
        "goal": "many simultaneous inputs -> one place to rest attention",
        "suggestions": [
            "Reduce line count, speed, and visual entropy after the gesture without implying that every problem is solved.",
            "Keep naming, writing, and breathing optional; verify that one-tap completion remains available.",
        ],
    },
    "space": {
        "goal": "too much incoming input -> a bounded pause without isolation",
        "suggestions": [
            "Make the closing action short and finite, then show a quiet cocoon with an always-available safety route.",
            "State that the app cannot block calls, notifications, or other apps; do not frame solitude as guaranteed safety.",
        ],
    },
    "physical": {
        "goal": "physical discomfort -> optional simulated heartbeat as a low-stimulation internal anchor",
        "suggestions": [
            "Keep headache presentation still, dim, silent, and without haptics or flashing.",
            "For other physical contexts, verify that the clearly simulated heartbeat stays optional, soft, regular, and distinguishable from measured personal heart-rate data.",
            "Avoid camera movement, tilt, and large parallax for nausea; retain the new/unusual/severe medical boundary.",
            "Do not describe the animation or sound as treating pain, nausea, migraine, or fatigue.",
        ],
    },
    "breath": {
        "goal": "one visible breathing cycle with optional sound and no performance pressure",
        "suggestions": [
            "Keep each selected pattern periodic and visually legible without requiring the user to match it perfectly.",
            "Verify coherent, long-exhale, and box patterns separately; holds must remain clearly distinguishable from stalled animation.",
            "Keep sound optional and verify that Reduce Motion leaves phase words usable without a resizing ring.",
        ],
    },
}


def _command(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise RuntimeError(f"Required command not found: {name}")
    return path


def _run(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)


def _ffprobe_json(path: Path) -> dict[str, Any]:
    result = _run(
        [
            _command("ffprobe"),
            "-v",
            "error",
            "-show_streams",
            "-show_format",
            "-of",
            "json",
            str(path),
        ]
    )
    return json.loads(result.stdout.decode("utf-8"))


def _parse_fraction(value: str | None) -> float | None:
    if not value or value in {"0/0", "N/A"}:
        return None
    numerator, denominator = value.split("/", 1)
    return float(numerator) / float(denominator)


def _relative_luminance(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.float32) / 255.0
    linear = np.where(values <= 0.04045, values / 12.92, ((values + 0.055) / 1.055) ** 2.4)
    return 0.2126 * linear[..., 0] + 0.7152 * linear[..., 1] + 0.0722 * linear[..., 2]


def _red_ratio(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.float32)
    denominator = values.sum(axis=-1)
    return np.divide(values[..., 0], denominator, out=np.zeros_like(denominator), where=denominator > 0)


def _count_opposing_flashes(
    luminance: np.ndarray,
    *,
    fps: float = 30.0,
    threshold: float = 0.10,
) -> tuple[int, int, float]:
    if len(luminance) < 3:
        return 0, 0, 0.0
    delta = np.diff(luminance)
    transitions = np.abs(delta) >= threshold
    signs = np.sign(delta)
    opposing = transitions[1:] & transitions[:-1] & (signs[1:] != signs[:-1])
    window = max(1, round(fps))
    counts = np.convolve(opposing.astype(np.int16), np.ones(window, dtype=np.int16), mode="full")
    maximum_per_second = int(counts[: len(opposing) + window - 1].max()) if len(opposing) else 0
    return int(opposing.sum()), maximum_per_second, float(np.max(np.abs(delta)))


def _optional_optical_flow(previous: np.ndarray, current: np.ndarray) -> float | None:
    try:
        import cv2  # type: ignore
    except ImportError:
        return None
    previous_gray = cv2.cvtColor(previous, cv2.COLOR_RGB2GRAY)
    current_gray = cv2.cvtColor(current, cv2.COLOR_RGB2GRAY)
    flow = cv2.calcOpticalFlowFarneback(
        previous_gray,
        current_gray,
        None,
        0.5,
        3,
        15,
        3,
        5,
        1.2,
        0,
    )
    return float(np.linalg.norm(flow, axis=2).mean())


def _strongest_period(
    values: np.ndarray,
    *,
    samples_per_second: float,
    minimum_seconds: float = 2.0,
    maximum_seconds: float = 30.0,
) -> tuple[float | None, float | None]:
    """Return the strongest slow autocorrelation period and its correlation."""
    if len(values) < 8 or samples_per_second <= 0:
        return None, None
    maximum_seconds = min(maximum_seconds, len(values) / samples_per_second / 2)
    minimum_lag = max(1, round(minimum_seconds * samples_per_second))
    maximum_lag = min(len(values) - 2, round(maximum_seconds * samples_per_second))
    if maximum_lag < minimum_lag:
        return None, None
    x = values.astype(np.float64)
    x -= np.linspace(x[0], x[-1], len(x))
    x -= x.mean()
    variance = float(np.dot(x, x))
    if variance <= 1e-12:
        return None, None
    best_lag: int | None = None
    best_score = -1.0
    for lag in range(minimum_lag, maximum_lag + 1):
        left = x[:-lag]
        right = x[lag:]
        denominator = math.sqrt(float(np.dot(left, left) * np.dot(right, right)))
        if denominator <= 1e-12:
            continue
        score = float(np.dot(left, right) / denominator)
        if score > best_score:
            best_score = score
            best_lag = lag
    if best_lag is None:
        return None, None
    return best_lag / samples_per_second, best_score


def _flow_at_30_fps(flow: float | None, sample_fps: float) -> float | None:
    """Normalize per-sampled-frame displacement to a comparable 30 fps value."""
    if flow is None or sample_fps <= 0:
        return None
    return flow * sample_fps / 30.0


def _dominant_colors(pixel_chunks: list[np.ndarray], clusters: int = 5) -> list[dict[str, Any]]:
    """Deterministic, dependency-free RGB k-means for a compact palette."""
    if not pixel_chunks:
        return []
    pixels = np.concatenate(pixel_chunks).reshape((-1, 3)).astype(np.float32)
    if len(pixels) > 24000:
        indexes = np.linspace(0, len(pixels) - 1, 24000, dtype=np.int64)
        pixels = pixels[indexes]
    unique = np.unique(pixels, axis=0)
    count = min(clusters, len(unique))
    if count == 0:
        return []
    luminance_order = np.argsort(
        unique[:, 0] * 0.2126 + unique[:, 1] * 0.7152 + unique[:, 2] * 0.0722
    )
    initial = np.linspace(0, len(luminance_order) - 1, count, dtype=np.int64)
    centers = unique[luminance_order[initial]].copy()
    labels = np.zeros(len(pixels), dtype=np.int16)
    for _ in range(20):
        distance = ((pixels[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
        new_labels = distance.argmin(axis=1).astype(np.int16)
        new_centers = centers.copy()
        for index in range(count):
            members = pixels[new_labels == index]
            if len(members):
                new_centers[index] = members.mean(axis=0)
        if np.array_equal(labels, new_labels) and np.allclose(centers, new_centers):
            break
        labels = new_labels
        centers = new_centers
    palette: list[dict[str, Any]] = []
    for index, center in enumerate(centers):
        weight = float(np.mean(labels == index))
        rgb = np.clip(np.rint(center), 0, 255).astype(np.uint8)
        hue, saturation, value = colorsys.rgb_to_hsv(*(rgb.astype(np.float64) / 255.0))
        palette.append(
            {
                "hex": "#{:02X}{:02X}{:02X}".format(*rgb),
                "rgb": [int(channel) for channel in rgb],
                "weight": weight,
                "hue_degrees": hue * 360,
                "saturation": saturation,
                "value": value,
            }
        )
    return sorted(palette, key=lambda item: item["weight"], reverse=True)


def _local_flash_metrics(tile_luminance: np.ndarray, fps: float) -> dict[str, Any]:
    if tile_luminance.shape[0] < 3:
        return {
            "max_local_opposing_flashes_per_second": 0,
            "max_local_luminance_step": 0.0,
            "max_flashing_tile_fraction": 0.0,
        }
    delta = np.diff(tile_luminance, axis=0)
    transitions = np.abs(delta) >= 0.10
    opposing = transitions[1:] & transitions[:-1] & (np.sign(delta[1:]) != np.sign(delta[:-1]))
    window = max(1, round(fps))
    tile_counts = np.zeros_like(opposing, dtype=np.int16)
    for tile in range(opposing.shape[1]):
        convolved = np.convolve(
            opposing[:, tile].astype(np.int16),
            np.ones(window, dtype=np.int16),
            mode="full",
        )
        tile_counts[:, tile] = convolved[: opposing.shape[0]]
    return {
        "max_local_opposing_flashes_per_second": int(tile_counts.max()) if tile_counts.size else 0,
        "max_local_luminance_step": float(np.abs(delta).max()) if delta.size else 0.0,
        "max_flashing_tile_fraction": float((tile_counts > 3).mean(axis=1).max()) if tile_counts.size else 0.0,
    }


def _temporal_flicker_frequency(tile_luminance: np.ndarray, fps: float) -> dict[str, Any]:
    maximum_hz = fps / 2
    result: dict[str, Any] = {
        "flicker_frequency_band_hz": [3.0, maximum_hz],
        "strongest_flicker_frequency_hz": None,
        "strongest_flicker_relative_power": None,
        "strongest_flicker_peak_to_peak": None,
    }
    if tile_luminance.shape[0] < max(16, round(fps)) or maximum_hz < 3:
        return result
    frequencies = np.fft.rfftfreq(tile_luminance.shape[0], d=1 / fps)
    band = (frequencies >= 3) & (frequencies <= maximum_hz)
    if not np.any(band):
        return result
    best: tuple[float, float, float] | None = None
    window = np.hanning(tile_luminance.shape[0])
    for tile in range(tile_luminance.shape[1]):
        series = tile_luminance[:, tile].astype(np.float64)
        peak_to_peak = float(np.ptp(series))
        centered = (series - series.mean()) * window
        power = np.abs(np.fft.rfft(centered)) ** 2
        total = float(power[1:].sum())
        if total <= 1e-12:
            continue
        band_indexes = np.flatnonzero(band)
        peak_index = int(band_indexes[np.argmax(power[band])])
        relative = float(power[peak_index] / total)
        candidate = (relative, float(frequencies[peak_index]), peak_to_peak)
        if best is None or candidate[0] > best[0]:
            best = candidate
    if best is not None:
        result.update(
            {
                "strongest_flicker_frequency_hz": best[1],
                "strongest_flicker_relative_power": best[0],
                "strongest_flicker_peak_to_peak": best[2],
            }
        )
    return result


def _spatial_pattern_proxy(luminance: np.ndarray) -> tuple[float, float, float]:
    """Return edge density, orientation coherence, and a stripe/grid proxy."""
    gy, gx = np.gradient(luminance.astype(np.float32))
    magnitude = np.hypot(gx, gy)
    threshold = max(0.08, float(np.percentile(magnitude, 90)))
    edges = magnitude >= threshold
    density = float(edges.mean())
    if not np.any(edges):
        return density, 0.0, 0.0
    angles = np.arctan2(gy[edges], gx[edges])
    coherence = float(np.abs(np.mean(np.exp(2j * angles))))
    contrast = float(np.percentile(luminance, 95) - np.percentile(luminance, 5))
    return density, coherence, density * coherence * contrast


def _box_counting_dimension(mask: np.ndarray) -> tuple[float | None, float | None]:
    """Estimate edge-set box-counting dimension and log-log fit quality."""
    binary = np.asarray(mask, dtype=bool)
    if binary.ndim != 2 or min(binary.shape) < 16:
        return None, None
    occupied = float(binary.mean())
    if occupied <= 0.001 or occupied >= 0.999:
        return None, None
    maximum_power = int(math.floor(math.log2(min(binary.shape))))
    sizes = [2**power for power in range(1, maximum_power) if 2**power <= min(binary.shape) // 2]
    counts: list[float] = []
    valid_sizes: list[float] = []
    for size in sizes:
        height = binary.shape[0] // size * size
        width = binary.shape[1] // size * size
        if height == 0 or width == 0:
            continue
        blocks = binary[:height, :width].reshape(
            height // size,
            size,
            width // size,
            size,
        )
        count = int(np.any(blocks, axis=(1, 3)).sum())
        if count > 0:
            valid_sizes.append(float(size))
            counts.append(float(count))
    if len(counts) < 3:
        return None, None
    x = np.log(1 / np.asarray(valid_sizes, dtype=np.float64))
    y = np.log(np.asarray(counts, dtype=np.float64))
    slope, intercept = np.polyfit(x, y, 1)
    predicted = slope * x + intercept
    residual = float(np.sum((y - predicted) ** 2))
    total = float(np.sum((y - y.mean()) ** 2))
    fit = 1 - residual / total if total > 1e-12 else 0.0
    return float(slope), float(fit)


def _edge_fractal_proxy(luminance: np.ndarray) -> tuple[float | None, float | None]:
    gy, gx = np.gradient(luminance.astype(np.float32))
    magnitude = np.hypot(gx, gy)
    threshold = max(0.025, float(np.percentile(magnitude, 82)))
    return _box_counting_dimension(magnitude >= threshold)


def _saliency_proxy(
    luminance: np.ndarray,
    cv2: Any | None,
) -> tuple[float, float, float, int, float, np.ndarray]:
    """Return deterministic center-surround saliency engineering proxies."""
    source = luminance.astype(np.float32)
    if cv2 is not None:
        small = cv2.resize(source, (64, 96), interpolation=cv2.INTER_AREA)
        blurred = cv2.GaussianBlur(small, (0, 0), sigmaX=4.0, sigmaY=4.0)
    else:
        row_indexes = np.linspace(0, source.shape[0] - 1, 96, dtype=np.int64)
        column_indexes = np.linspace(0, source.shape[1] - 1, 64, dtype=np.int64)
        small = source[np.ix_(row_indexes, column_indexes)]
        padded = np.pad(small, 2, mode="edge")
        blurred = sum(
            padded[row : row + 96, column : column + 64]
            for row in range(5)
            for column in range(5)
        ) / 25
    gy, gx = np.gradient(small)
    saliency = np.abs(small - blurred) + 0.5 * np.hypot(gx, gy)
    saliency = np.maximum(saliency, 0)
    total = float(saliency.sum())
    if total <= 1e-12:
        probability = np.full_like(saliency, 1 / saliency.size)
    else:
        probability = saliency / total
    yy, xx = np.mgrid[0 : probability.shape[0], 0 : probability.shape[1]]
    center_x = float((probability * xx).sum() / max(probability.shape[1] - 1, 1))
    center_y = float((probability * yy).sum() / max(probability.shape[0] - 1, 1))
    entropy = float(
        -np.sum(probability * np.log(np.maximum(probability, 1e-12)))
        / math.log(probability.size)
    )
    threshold = float(np.percentile(saliency, 97))
    if cv2 is not None and threshold > 0:
        peaks = (saliency >= threshold) & (
            saliency >= cv2.dilate(saliency, np.ones((9, 9), dtype=np.uint8))
        )
        focus_count = int(peaks.sum())
    else:
        focus_count = int(np.sum(saliency >= threshold)) if threshold > 0 else 0
    top_count = max(1, round(saliency.size * 0.10))
    concentration = float(np.partition(probability.ravel(), -top_count)[-top_count:].sum())
    return center_x, center_y, entropy, focus_count, concentration, probability


def _cross_modal_correlation(
    visual: np.ndarray,
    audio: np.ndarray,
    *,
    samples_per_second: float,
    maximum_lag_seconds: float = 1.0,
) -> dict[str, float | None]:
    """Compare standardized visual-motion and audio-energy envelopes."""
    count = min(len(visual), len(audio))
    if count < 12 or samples_per_second <= 0:
        return {"correlation": None, "lag_ms": None, "zero_lag_correlation": None}
    visual_values = visual[:count].astype(np.float64)
    audio_values = audio[:count].astype(np.float64)
    visual_values -= np.linspace(visual_values[0], visual_values[-1], count)
    audio_values -= np.linspace(audio_values[0], audio_values[-1], count)
    visual_std = float(visual_values.std())
    audio_std = float(audio_values.std())
    if visual_std <= 1e-9 or audio_std <= 1e-9:
        return {"correlation": None, "lag_ms": None, "zero_lag_correlation": None}
    visual_values = (visual_values - visual_values.mean()) / visual_std
    audio_values = (audio_values - audio_values.mean()) / audio_std
    maximum_lag = min(count // 3, max(1, round(maximum_lag_seconds * samples_per_second)))
    candidates: list[tuple[float, int]] = []
    for lag in range(-maximum_lag, maximum_lag + 1):
        if lag < 0:
            left, right = visual_values[-lag:], audio_values[: count + lag]
        elif lag > 0:
            left, right = visual_values[: count - lag], audio_values[lag:]
        else:
            left, right = visual_values, audio_values
        if len(left) >= 8:
            candidates.append((float(np.mean(left * right)), lag))
    best_correlation, best_lag = max(candidates, key=lambda item: item[0])
    zero_lag = next(value for value, lag in candidates if lag == 0)
    return {
        "correlation": best_correlation,
        "lag_ms": best_lag / samples_per_second * 1000,
        "zero_lag_correlation": zero_lag,
    }


def _downsample(values: list[float], maximum: int = 240) -> list[float]:
    if len(values) <= maximum:
        return values
    indexes = np.linspace(0, len(values) - 1, maximum, dtype=np.int64)
    return [values[int(index)] for index in indexes]


def analyze_video(path: Path, *, max_width: int = 320, sample_fps: float = 30.0) -> dict[str, Any]:
    metadata = _ffprobe_json(path)
    streams = metadata.get("streams", [])
    video = next((stream for stream in streams if stream.get("codec_type") == "video"), None)
    if video is None:
        raise ValueError(f"No video stream found in {path}")
    width = int(video["width"])
    height = int(video["height"])
    source_fps = _parse_fraction(video.get("avg_frame_rate")) or _parse_fraction(video.get("r_frame_rate")) or sample_fps
    duration = float(video.get("duration") or metadata.get("format", {}).get("duration") or 0)
    scaled_height = max(2, round(height * max_width / width))
    if scaled_height % 2:
        scaled_height += 1

    process = subprocess.Popen(
        [
            _command("ffmpeg"),
            "-v",
            "error",
            "-i",
            str(path),
            "-vf",
            f"scale={max_width}:{scaled_height}:flags=bilinear,fps={sample_fps}",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "-",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    frame_size = max_width * scaled_height * 3
    means: list[float] = []
    focus_luminances: list[float] = []
    saturations: list[float] = []
    values_mean: list[float] = []
    lab_lightness: list[float] = []
    lab_chroma: list[float] = []
    cool_fractions: list[float] = []
    warm_fractions: list[float] = []
    neutral_fractions: list[float] = []
    high_saturation_fractions: list[float] = []
    dark_fractions: list[float] = []
    bright_fractions: list[float] = []
    contrast_ranges: list[float] = []
    red_ratios: list[float] = []
    deltas: list[float] = []
    changed_area_fractions: list[float] = []
    histogram_steps: list[float] = []
    flow_values: list[float] = []
    red_flash_events: list[int] = []
    tile_luminances: list[np.ndarray] = []
    palette_pixels: list[np.ndarray] = []
    pattern_edge_density: list[float] = []
    pattern_orientation_coherence: list[float] = []
    pattern_scores: list[float] = []
    fractal_dimensions: list[float] = []
    fractal_fit_scores: list[float] = []
    saliency_centroids: list[tuple[float, float]] = []
    saliency_entropies: list[float] = []
    saliency_focus_counts: list[int] = []
    saliency_concentrations: list[float] = []
    saliency_maps: list[np.ndarray] = []
    previous_luminance: float | None = None
    previous: np.ndarray | None = None
    previous_histogram: np.ndarray | None = None
    try:
        import cv2  # type: ignore
    except ImportError:
        cv2 = None
    frames = 0
    while process.stdout is not None:
        payload = process.stdout.read(frame_size)
        if len(payload) != frame_size:
            break
        frame = np.frombuffer(payload, dtype=np.uint8).reshape((scaled_height, max_width, 3))
        luminance = _relative_luminance(frame)
        mean_luminance = float(luminance.mean())
        means.append(mean_luminance)
        focus_luminances.append(
            float(
                luminance[
                    round(scaled_height * 0.35) : round(scaled_height * 0.70),
                    round(max_width * 0.20) : round(max_width * 0.80),
                ].mean()
            )
        )
        contrast_ranges.append(float(np.percentile(luminance, 95) - np.percentile(luminance, 5)))
        dark_fractions.append(float((luminance <= 0.05).mean()))
        bright_fractions.append(float((luminance >= 0.80).mean()))
        values = frame.astype(np.float32) / 255.0
        maximum = values.max(axis=-1)
        minimum = values.min(axis=-1)
        saturation = np.divide(
            maximum - minimum,
            maximum,
            out=np.zeros_like(maximum),
            where=maximum > 0,
        )
        saturations.append(float(saturation.mean()))
        values_mean.append(float(maximum.mean()))
        high_saturation_fractions.append(float(((saturation >= 0.75) & (maximum >= 0.2)).mean()))
        if cv2 is not None:
            hsv = cv2.cvtColor(frame, cv2.COLOR_RGB2HSV)
            hue = hsv[..., 0].astype(np.float32) * 2
            hsv_saturation = hsv[..., 1].astype(np.float32) / 255
            chromatic = hsv_saturation >= 0.15
            neutral_fractions.append(float((~chromatic).mean()))
            cool_fractions.append(float((chromatic & (hue >= 150) & (hue <= 300)).mean()))
            warm_fractions.append(float((chromatic & ((hue <= 75) | (hue >= 330))).mean()))
            lab = cv2.cvtColor(frame, cv2.COLOR_RGB2LAB).astype(np.float32)
            lab_lightness.append(float((lab[..., 0] * (100 / 255)).mean()))
            a = lab[..., 1] - 128
            b = lab[..., 2] - 128
            lab_chroma.append(float(np.hypot(a, b).mean()))
        red_ratios.append(float(_red_ratio(frame).mean()))
        row_tiles = np.array_split(luminance, 8, axis=0)
        tile_luminances.append(
            np.asarray(
                [float(tile.mean()) for row in row_tiles for tile in np.array_split(row, 8, axis=1)],
                dtype=np.float32,
            )
        )
        palette_interval = max(1, round(sample_fps / 2))
        if frames % palette_interval == 0:
            palette_pixels.append(frame[::8, ::8].reshape((-1, 3)))
            edge_density, coherence, pattern_score = _spatial_pattern_proxy(luminance)
            pattern_edge_density.append(edge_density)
            pattern_orientation_coherence.append(coherence)
            pattern_scores.append(pattern_score)
            fractal_dimension, fractal_fit = _edge_fractal_proxy(luminance)
            if fractal_dimension is not None and fractal_fit is not None:
                fractal_dimensions.append(fractal_dimension)
                fractal_fit_scores.append(fractal_fit)
        saliency_interval = max(1, round(sample_fps / 5))
        if frames % saliency_interval == 0:
            center_x, center_y, entropy, focus_count, concentration, saliency_map = (
                _saliency_proxy(luminance, cv2)
            )
            saliency_centroids.append((center_x, center_y))
            saliency_entropies.append(entropy)
            saliency_focus_counts.append(focus_count)
            saliency_concentrations.append(concentration)
            saliency_maps.append(saliency_map)
        histogram, _ = np.histogram(luminance, bins=32, range=(0, 1))
        histogram = histogram.astype(np.float32)
        histogram /= max(float(histogram.sum()), 1.0)
        if previous is not None:
            luminance_delta = np.abs(luminance - _relative_luminance(previous))
            deltas.append(float(luminance_delta.mean()))
            changed_area_fractions.append(float((luminance_delta >= 0.10).mean()))
            if previous_histogram is not None:
                histogram_steps.append(float(np.abs(histogram - previous_histogram).sum() / 2))
            flow = _optional_optical_flow(previous, frame)
            if flow is not None:
                flow_values.append(flow)
        red_event = 0
        if previous_luminance is not None and abs(mean_luminance - previous_luminance) >= 0.10:
            red_change = np.abs(_red_ratio(frame) - _red_ratio(previous)) >= 0.20
            red_event = int(red_change.mean() >= 0.25)
        red_flash_events.append(red_event)
        previous_luminance = mean_luminance
        previous = frame.copy()
        previous_histogram = histogram
        frames += 1
    stderr = process.stderr.read().decode("utf-8") if process.stderr else ""
    return_code = process.wait()
    if return_code != 0:
        raise RuntimeError(f"ffmpeg video decode failed: {stderr.strip()}")

    luminance_array = np.asarray(means, dtype=np.float32)
    saturation_array = np.asarray(saturations, dtype=np.float32)
    red_ratio_array = np.asarray(red_ratios, dtype=np.float32)
    delta_array = np.asarray(deltas, dtype=np.float32)
    tile_luminance_array = np.asarray(tile_luminances, dtype=np.float32)
    flashes, max_flashes_per_second, max_step = _count_opposing_flashes(
        luminance_array,
        fps=sample_fps,
    )
    red_array = np.asarray(red_flash_events, dtype=np.int16)
    red_window = max(1, round(sample_fps))
    red_counts = np.convolve(red_array, np.ones(red_window, dtype=np.int16), mode="full")
    max_red_per_second = int(red_counts.max()) if len(red_counts) else 0
    motion_steps = np.abs(np.diff(delta_array)) if len(delta_array) > 1 else np.asarray([], dtype=np.float32)
    quarter_length = max(1, len(delta_array) // 4)
    motion_first_quarter = float(delta_array[:quarter_length].mean()) if len(delta_array) else None
    motion_last_quarter = float(delta_array[-quarter_length:].mean()) if len(delta_array) else None
    motion_end_start_ratio = (
        motion_last_quarter / motion_first_quarter
        if motion_first_quarter is not None and motion_first_quarter > 1e-9
        else None
    )
    frame_difference_period, frame_difference_period_strength = _strongest_period(
        delta_array,
        samples_per_second=sample_fps,
    )
    luminance_period, luminance_period_strength = _strongest_period(
        luminance_array,
        samples_per_second=sample_fps,
    )
    focus_luminance_period, focus_luminance_period_strength = _strongest_period(
        np.asarray(focus_luminances, dtype=np.float32),
        samples_per_second=sample_fps,
    )
    optical_flow_period, optical_flow_period_strength = _strongest_period(
        np.asarray(flow_values, dtype=np.float32),
        samples_per_second=sample_fps,
    )
    strongest_period = optical_flow_period or frame_difference_period
    period_strength = (
        optical_flow_period_strength
        if optical_flow_period is not None
        else frame_difference_period_strength
    )
    local_flash = _local_flash_metrics(tile_luminance_array, sample_fps)
    frequency_metrics = _temporal_flicker_frequency(tile_luminance_array, sample_fps)
    saliency_jumps = [
        math.hypot(current[0] - previous_point[0], current[1] - previous_point[1])
        / math.sqrt(2)
        for previous_point, current in zip(saliency_centroids, saliency_centroids[1:])
    ]
    saliency_correlations: list[float] = []
    for previous_map, current_map in zip(saliency_maps, saliency_maps[1:]):
        previous_flat = previous_map.ravel().astype(np.float64)
        current_flat = current_map.ravel().astype(np.float64)
        denominator = float(previous_flat.std() * current_flat.std())
        if denominator > 1e-12:
            saliency_correlations.append(
                float(
                    np.mean(
                        (previous_flat - previous_flat.mean())
                        * (current_flat - current_flat.mean())
                    )
                    / denominator
                )
            )
    histogram_array = np.asarray(histogram_steps, dtype=np.float32)
    changed_area_array = np.asarray(changed_area_fractions, dtype=np.float32)
    scene_cut_count = int(
        np.sum((histogram_array >= 0.55) & (changed_area_array >= 0.50))
    ) if len(histogram_array) else 0
    return {
        "path": str(path),
        "source_width": width,
        "source_height": height,
        "source_fps": source_fps,
        "duration_seconds": duration,
        "sample_fps": sample_fps,
        "frames_analyzed": frames,
        "mean_luminance": float(luminance_array.mean()) if frames else None,
        "luminance_p95": float(np.percentile(luminance_array, 95)) if frames else None,
        "mean_saturation": float(saturation_array.mean()) if frames else None,
        "saturation_p95": float(np.percentile(saturation_array, 95)) if frames else None,
        "mean_value": float(np.mean(values_mean)) if values_mean else None,
        "mean_lab_lightness": float(np.mean(lab_lightness)) if lab_lightness else None,
        "mean_lab_chroma": float(np.mean(lab_chroma)) if lab_chroma else None,
        "mean_cool_color_fraction": float(np.mean(cool_fractions)) if cool_fractions else None,
        "mean_warm_color_fraction": float(np.mean(warm_fractions)) if warm_fractions else None,
        "mean_neutral_color_fraction": float(np.mean(neutral_fractions)) if neutral_fractions else None,
        "mean_high_saturation_fraction": float(np.mean(high_saturation_fractions))
        if high_saturation_fractions
        else None,
        "mean_dark_fraction": float(np.mean(dark_fractions)) if dark_fractions else None,
        "mean_bright_fraction": float(np.mean(bright_fractions)) if bright_fractions else None,
        "mean_luminance_contrast_range": float(np.mean(contrast_ranges)) if contrast_ranges else None,
        "max_luminance_contrast_range": float(np.max(contrast_ranges)) if contrast_ranges else None,
        "dominant_colors": _dominant_colors(palette_pixels),
        "mean_red_ratio": float(red_ratio_array.mean()) if frames else None,
        "max_frame_luminance_step": max_step,
        "mean_frame_difference": float(delta_array.mean()) if len(delta_array) else None,
        "p95_frame_difference": float(np.percentile(delta_array, 95)) if len(delta_array) else None,
        "motion_first_quarter": motion_first_quarter,
        "motion_last_quarter": motion_last_quarter,
        "motion_end_start_ratio": motion_end_start_ratio,
        "max_motion_step": float(motion_steps.max()) if len(motion_steps) else None,
        "motion_jerk_p95": float(np.percentile(motion_steps, 95)) if len(motion_steps) else None,
        "strongest_motion_period_seconds": strongest_period,
        "strongest_motion_period_correlation": period_strength,
        "strongest_frame_difference_period_seconds": frame_difference_period,
        "strongest_frame_difference_period_correlation": frame_difference_period_strength,
        "strongest_luminance_period_seconds": luminance_period,
        "strongest_luminance_period_correlation": luminance_period_strength,
        "strongest_focus_luminance_period_seconds": focus_luminance_period,
        "strongest_focus_luminance_period_correlation": focus_luminance_period_strength,
        "strongest_optical_flow_period_seconds": optical_flow_period,
        "strongest_optical_flow_period_correlation": optical_flow_period_strength,
        "scene_cut_count": scene_cut_count,
        "max_changed_area_fraction": float(changed_area_array.max()) if len(changed_area_array) else 0.0,
        "max_histogram_step": float(histogram_array.max()) if len(histogram_array) else 0.0,
        "opposing_flash_count": flashes,
        "max_opposing_flashes_per_second": max_flashes_per_second,
        "red_flash_frame_count": int(red_array.sum()),
        "max_red_flash_events_per_second": max_red_per_second,
        "optical_flow_mean": float(np.mean(flow_values)) if flow_values else None,
        "optical_flow_p95": float(np.percentile(flow_values, 95)) if flow_values else None,
        "optical_flow_mean_at_30fps": _flow_at_30_fps(
            float(np.mean(flow_values)) if flow_values else None,
            sample_fps,
        ),
        "optical_flow_p95_at_30fps": _flow_at_30_fps(
            float(np.percentile(flow_values, 95)) if flow_values else None,
            sample_fps,
        ),
        "optical_flow_available": bool(flow_values),
        "spatial_edge_density_p95": float(np.percentile(pattern_edge_density, 95))
        if pattern_edge_density
        else None,
        "spatial_orientation_coherence_p95": float(np.percentile(pattern_orientation_coherence, 95))
        if pattern_orientation_coherence
        else None,
        "spatial_pattern_score_max": float(np.max(pattern_scores)) if pattern_scores else None,
        "edge_fractal_dimension_mean": float(np.mean(fractal_dimensions))
        if fractal_dimensions
        else None,
        "edge_fractal_dimension_p10": float(np.percentile(fractal_dimensions, 10))
        if fractal_dimensions
        else None,
        "edge_fractal_dimension_p90": float(np.percentile(fractal_dimensions, 90))
        if fractal_dimensions
        else None,
        "edge_fractal_loglog_fit_mean": float(np.mean(fractal_fit_scores))
        if fractal_fit_scores
        else None,
        "saliency_focus_count_mean": float(np.mean(saliency_focus_counts))
        if saliency_focus_counts
        else None,
        "saliency_focus_count_p95": float(np.percentile(saliency_focus_counts, 95))
        if saliency_focus_counts
        else None,
        "saliency_entropy_mean": float(np.mean(saliency_entropies))
        if saliency_entropies
        else None,
        "saliency_top10_concentration_mean": float(np.mean(saliency_concentrations))
        if saliency_concentrations
        else None,
        "saliency_centroid_jump_p95": float(np.percentile(saliency_jumps, 95))
        if saliency_jumps
        else None,
        "saliency_map_correlation_p10": float(np.percentile(saliency_correlations, 10))
        if saliency_correlations
        else None,
        "saliency_proxy_sample_fps": min(sample_fps, 5.0),
        "time_series": {
            "luminance": _downsample(means),
            "focus_luminance": _downsample(focus_luminances),
            "saturation": _downsample(saturations),
            "frame_difference": _downsample(deltas, maximum=1200),
            "optical_flow": _downsample(flow_values),
            "saliency_center_x": _downsample([point[0] for point in saliency_centroids]),
            "saliency_center_y": _downsample([point[1] for point in saliency_centroids]),
        },
        **local_flash,
        **frequency_metrics,
    }


def _parse_metric(text: str, label: str) -> float | None:
    match = re.search(rf"{re.escape(label)}:\s*(-?[0-9.]+)", text)
    return float(match.group(1)) if match else None


@functools.lru_cache(maxsize=32)
def _decode_audio(path: Path, sample_rate: int = 16000) -> np.ndarray:
    result = _run(
        [
            _command("ffmpeg"),
            "-v",
            "error",
            "-i",
            str(path),
            "-ac",
            "1",
            "-ar",
            str(sample_rate),
            "-f",
            "f32le",
            "-",
        ]
    )
    return np.frombuffer(result.stdout, dtype=np.float32)


def analyze_audio_visual_alignment(
    video_metrics: dict[str, Any],
    audio_path: Path,
    *,
    sample_rate: int = 16000,
) -> dict[str, Any]:
    """Measure source-level envelope coupling; runtime DSP is not represented."""
    visual = np.asarray(
        video_metrics.get("time_series", {}).get("frame_difference", []),
        dtype=np.float64,
    )
    duration = float(video_metrics.get("duration_seconds") or 0)
    if len(visual) < 12 or duration < 2:
        return {
            "audio_visual_source_asset": audio_path.name,
            "audio_visual_alignment_available": False,
        }
    decoded = _decode_audio(audio_path, sample_rate)
    if not len(decoded):
        return {
            "audio_visual_source_asset": audio_path.name,
            "audio_visual_alignment_available": False,
        }
    envelope_rate = len(visual) / duration
    window_samples = max(1, round(sample_rate / envelope_rate))
    audio_energy: list[float] = []
    for index in range(len(visual)):
        start = round(index / envelope_rate * sample_rate)
        sample_indexes = (start + np.arange(window_samples)) % len(decoded)
        window = decoded[sample_indexes].astype(np.float64)
        rms = math.sqrt(float(np.mean(window * window)))
        audio_energy.append(20 * math.log10(max(rms, 1e-9)))
    audio_array = np.asarray(audio_energy, dtype=np.float64)
    correlation = _cross_modal_correlation(
        visual,
        audio_array,
        samples_per_second=envelope_rate,
    )

    def peaks(values: np.ndarray) -> np.ndarray:
        if len(values) < 3 or float(values.std()) <= 1e-9:
            return np.asarray([], dtype=np.int64)
        threshold = float(np.percentile(values, 80))
        return np.flatnonzero(
            (values[1:-1] >= values[:-2])
            & (values[1:-1] > values[2:])
            & (values[1:-1] >= threshold)
        ) + 1

    visual_peaks = peaks(visual)
    audio_peaks = peaks(audio_array)
    peak_mismatch_ms = None
    if len(visual_peaks) and len(audio_peaks):
        distances = [float(np.min(np.abs(audio_peaks - peak))) for peak in visual_peaks]
        peak_mismatch_ms = float(np.median(distances) / envelope_rate * 1000)
    return {
        "audio_visual_source_asset": audio_path.name,
        "audio_visual_alignment_available": correlation["correlation"] is not None,
        "audio_visual_best_correlation": correlation["correlation"],
        "audio_visual_best_lag_ms": correlation["lag_ms"],
        "audio_visual_zero_lag_correlation": correlation["zero_lag_correlation"],
        "audio_visual_peak_median_mismatch_ms": peak_mismatch_ms,
        "audio_visual_envelope_sample_fps": envelope_rate,
        "audio_visual_scope": "raw source loop versus captured visual motion; runtime gain, filters, fades, route latency, and haptics excluded",
    }


def _pulse_cadence_metrics(samples: np.ndarray, sample_rate: int) -> dict[str, Any]:
    """Estimate a slow pulse cadence from a smoothed short-time RMS envelope."""
    hop = max(1, round(sample_rate * 0.01))
    count = len(samples) // hop
    if count < 200:
        return {}
    frames = samples[: count * hop].reshape((count, hop))
    envelope = np.sqrt(np.mean(frames.astype(np.float64) ** 2, axis=1) + 1e-12)
    envelope = np.convolve(envelope, np.ones(10) / 10, mode="same")
    deviation = float(np.std(envelope))
    if deviation <= 1e-12:
        return {}
    normalized = (envelope - float(np.mean(envelope))) / deviation

    minimum_lag = round(0.55 / 0.01)
    maximum_lag = round(1.5 / 0.01)
    correlations: list[tuple[float, int]] = []
    for lag in range(minimum_lag, maximum_lag + 1):
        left = normalized[:-lag]
        right = normalized[lag:]
        correlation = float(np.dot(left, right) / max(len(left), 1))
        correlations.append((correlation, lag))
    best_correlation, best_lag = max(correlations)

    threshold = float(np.percentile(envelope, 75))
    candidates = [
        index
        for index in range(1, len(envelope) - 1)
        if envelope[index] >= threshold
        and envelope[index] >= envelope[index - 1]
        and envelope[index] > envelope[index + 1]
    ]
    selected: list[int] = []
    minimum_distance = round(0.55 / 0.01)
    for index in sorted(candidates, key=lambda item: envelope[item], reverse=True):
        if all(abs(index - prior) >= minimum_distance for prior in selected):
            selected.append(index)
    selected.sort()
    intervals = np.diff(np.asarray(selected, dtype=np.float64)) * 0.01
    intervals = intervals[(intervals >= 0.55) & (intervals <= 1.5)]
    median_interval = float(np.median(intervals)) if len(intervals) else None
    interval_cv = (
        float(np.std(intervals) / np.mean(intervals))
        if len(intervals) >= 2 and float(np.mean(intervals)) > 0
        else None
    )
    return {
        "pulse_proxy_peak_count": len(selected),
        "pulse_proxy_bpm_median": (
            60 / median_interval if median_interval is not None else None
        ),
        "pulse_proxy_interval_cv": interval_cv,
        "pulse_periodicity_bpm": 60 / (best_lag * 0.01),
        "pulse_periodicity_correlation": best_correlation,
        "pulse_proxy_scope": (
            "energy-envelope proxy; does not establish a human heartbeat or biometric measurement"
        ),
    }


def _audio_spectral_metrics(samples: np.ndarray, sample_rate: int) -> dict[str, Any]:
    if len(samples) < 1024:
        return {}
    frame_size = 1024
    hop = 512
    frame_count = 1 + (len(samples) - frame_size) // hop
    indexes = np.arange(frame_size)[None, :] + hop * np.arange(frame_count)[:, None]
    frames = samples[indexes].astype(np.float64)
    windowed = frames * np.hanning(frame_size)
    magnitudes = np.abs(np.fft.rfft(windowed, axis=1))
    power = magnitudes**2
    frequencies = np.fft.rfftfreq(frame_size, d=1 / sample_rate)
    energy = power.sum(axis=1)
    centroid = np.divide(
        (power * frequencies).sum(axis=1),
        energy,
        out=np.zeros_like(energy),
        where=energy > 1e-18,
    )
    cumulative = np.cumsum(power, axis=1)
    rolloff_indexes = np.argmax(cumulative >= cumulative[:, -1:] * 0.85, axis=1)
    rolloff = frequencies[rolloff_indexes]

    def band_fraction(low: float, high: float) -> float:
        selection = (frequencies >= low) & (frequencies < high)
        selected = power[:, selection].sum()
        return float(selected / max(float(power.sum()), 1e-18))

    short_window = max(1, round(sample_rate * 0.05))
    usable = len(samples) // short_window * short_window
    short_frames = samples[:usable].reshape((-1, short_window))
    short_rms = np.sqrt(np.mean(short_frames.astype(np.float64) ** 2, axis=1))
    short_db = 20 * np.log10(np.maximum(short_rms, 1e-9))
    increases = np.diff(short_db)
    return {
        "analysis_sample_rate": sample_rate,
        "spectral_centroid_mean_hz": float(np.mean(centroid)),
        "spectral_centroid_p95_hz": float(np.percentile(centroid, 95)),
        "spectral_rolloff_85_mean_hz": float(np.mean(rolloff)),
        "low_band_fraction_below_250hz": band_fraction(0, 250),
        "presence_band_fraction_2k_5khz": band_fraction(2000, 5000),
        "high_band_fraction_above_5khz": band_fraction(5000, sample_rate / 2 + 1),
        "max_50ms_rms_increase_db": float(np.max(increases)) if len(increases) else 0.0,
        "p95_50ms_rms_dbfs": float(np.percentile(short_db, 95)),
        "silence_fraction_below_minus_60_dbfs": float(np.mean(short_db <= -60)),
        "zero_crossing_rate": float(np.mean(np.signbit(samples[1:]) != np.signbit(samples[:-1]))),
        "dc_offset": float(np.mean(samples)),
        "clipped_sample_fraction": float(np.mean(np.abs(samples) >= 0.999)),
        **_pulse_cadence_metrics(samples, sample_rate),
    }


def analyze_audio(path: Path) -> dict[str, Any]:
    metadata = _ffprobe_json(path)
    stream = next((item for item in metadata.get("streams", []) if item.get("codec_type") == "audio"), None)
    if stream is None:
        raise ValueError(f"No audio stream found in {path}")
    decoded = _decode_audio(path)
    text = ""
    for filter_name in ("ebur128=framelog=verbose", "volumedetect"):
        result = _run(
            [_command("ffmpeg"), "-v", "info", "-i", str(path), "-af", filter_name, "-f", "null", "-"],
            check=False,
        )
        text += result.stderr.decode("utf-8", errors="replace")
    sample_rate = int(stream.get("sample_rate") or 44100)
    quarter_second = max(1, round(0.25 * 16000))
    seam_rms_db = None
    seam_correlation = None
    if len(decoded) > quarter_second * 2:
        first = decoded[:quarter_second]
        last = decoded[-quarter_second:]
        first_rms = math.sqrt(float(np.mean(first * first)))
        last_rms = math.sqrt(float(np.mean(last * last)))
        seam_rms_db = 20 * math.log10(max(first_rms, 1e-9) / max(last_rms, 1e-9))
        if np.std(first) > 1e-8 and np.std(last) > 1e-8:
            seam_correlation = float(np.corrcoef(first, last)[0, 1])
    return {
        "path": str(path),
        "duration_seconds": float(stream.get("duration") or metadata.get("format", {}).get("duration") or 0),
        "codec": stream.get("codec_name"),
        "sample_rate": sample_rate,
        "channels": int(stream.get("channels") or 0),
        "decoded_samples": int(len(decoded)),
        "mean_rms_dbfs": 20 * math.log10(max(math.sqrt(float(np.mean(decoded * decoded))), 1e-9)) if len(decoded) else None,
        "sample_peak_dbfs": 20 * math.log10(max(float(np.max(np.abs(decoded))), 1e-9)) if len(decoded) else None,
        "integrated_lufs": _parse_metric(text, "I"),
        "loudness_range_lu": _parse_metric(text, "LRA"),
        "true_peak_dbfs": _parse_metric(text, "Peak"),
        "volumedetect_max_dbfs": _parse_metric(text, "max_volume"),
        "loop_seam_rms_difference_db": seam_rms_db,
        "loop_seam_correlation": seam_correlation,
        "loop_boundary_sample_step": float(abs(decoded[0] - decoded[-1])) if len(decoded) else None,
        **_audio_spectral_metrics(decoded, 16000),
    }


def _recommendations(mode: str, video: dict[str, Any] | None, audio: dict[str, Any] | None) -> list[dict[str, str]]:
    recommendations: list[dict[str, str]] = []
    if video is not None:
        max_general = max(
            video.get("max_opposing_flashes_per_second", video["opposing_flash_count"]),
            video.get("max_local_opposing_flashes_per_second", 0),
        )
        max_red = video.get("max_red_flash_events_per_second", video["red_flash_frame_count"])
        if max_general > 3 or max_red > 3:
            recommendations.append({
                "status": "FAIL",
                "observation": "More than three opposing or red flash events were detected in the sampled sequence.",
                "risk": "Potential photosensitivity and visual discomfort risk.",
                "suggestion": "Remove the flash pattern or reduce contrast, area, and transition frequency; repeat the capture.",
                "review": "AUTO",
                "acceptance": "No one-second window exceeds three flash events.",
            })
        elif video["max_frame_luminance_step"] > 0.20:
            recommendations.append({
                "status": "WARN",
                "observation": f"Maximum normalized frame luminance step is {video['max_frame_luminance_step']:.3f}.",
                "risk": "A large transition may feel startling even when it is not a flash failure.",
                "suggestion": "Review the transition and soften the fade or reduce the changed area.",
                "review": "AUTO + MANUAL",
                "acceptance": "No unexplained abrupt transition remains in the final capture.",
            })
        flicker_power = video.get("strongest_flicker_relative_power")
        flicker_range = video.get("strongest_flicker_peak_to_peak")
        if (
            flicker_power is not None
            and flicker_range is not None
            and flicker_power >= 0.50
            and flicker_range >= 0.10
        ):
            recommendations.append({
                "status": "WARN",
                "observation": (
                    f"A {video['strongest_flicker_frequency_hz']:.2f} Hz local luminance component "
                    f"has {flicker_power:.0%} relative power and {flicker_range:.2f} peak-to-peak range."
                ),
                "risk": "A repeated local luminance modulation may be visually tiring or missed by whole-frame averages.",
                "suggestion": "Inspect the flagged region, then reduce modulation depth or remove repeated high-contrast alternation.",
                "review": "AUTO + MANUAL",
                "acceptance": "No strong 3 Hz-to-Nyquist component remains with at least 0.10 local peak-to-peak luminance range.",
            })
        if video["p95_frame_difference"] is not None and video["p95_frame_difference"] > 0.12:
            recommendations.append({
                "status": "MANUAL_REQUIRED",
                "observation": f"P95 frame difference is {video['p95_frame_difference']:.3f}.",
                "risk": "The scene may be visually activating or may contain a transition that needs context.",
                "suggestion": MODE_GUIDANCE[mode]["suggestions"][0],
                "review": "MANUAL",
                "acceptance": "A reviewer confirms that movement matches the intended finite transformation.",
            })
        flow_p95 = video.get("optical_flow_p95_at_30fps")
        if flow_p95 is None:
            flow_p95 = video.get("optical_flow_p95")
        if flow_p95 is not None and flow_p95 > 6:
            recommendations.append({
                "status": "MANUAL_REQUIRED",
                "observation": f"P95 optical flow is {flow_p95:.2f} pixels per frame, normalized to 30 fps.",
                "risk": "Sustained large-area movement may feel activating or cognitively busy.",
                "suggestion": MODE_GUIDANCE[mode]["suggestions"][0],
                "review": "MANUAL",
                "acceptance": "A reviewer confirms that the motion supports the intended state change without increasing distress.",
            })
        high_saturation = video.get("mean_high_saturation_fraction")
        if high_saturation is not None and high_saturation > 0.35:
            recommendations.append({
                "status": "MANUAL_REQUIRED",
                "observation": f"Highly saturated pixels occupy {high_saturation:.0%} of the sampled image on average.",
                "risk": "Large saturated areas can dominate attention, especially at high brightness.",
                "suggestion": "Review at maximum scene intensity and lower chroma or occupied area if it overwhelms the intended focal point.",
                "review": "MANUAL + DEVICE",
                "acceptance": "A dark-room iPhone review confirms that saturated areas do not feel glaring or obscure controls.",
            })
        pattern_score = video.get("spatial_pattern_score_max")
        if pattern_score is not None and pattern_score > 0.035:
            recommendations.append({
                "status": "MANUAL_REQUIRED",
                "observation": f"Maximum high-contrast oriented-pattern proxy is {pattern_score:.3f}.",
                "risk": "Repeated aligned edges may behave like stripes or dense line patterns and increase visual fatigue.",
                "suggestion": "Inspect full-screen line density; vary spacing, lower contrast, or reduce the number of parallel elements.",
                "review": "AUTO + MANUAL",
                "acceptance": "The final scene has no uncomfortable high-contrast stripe, grid, or tightly repeated line field on iPhone.",
            })
    if audio is not None:
        peak = audio.get("sample_peak_dbfs")
        if peak is not None and peak >= -1:
            recommendations.append({
                "status": "WARN",
                "observation": f"Decoded sample peak is {peak:.2f} dBFS.",
                "risk": "Runtime filtering or device conversion could produce audible clipping.",
                "suggestion": "Leave headroom and verify the runtime SoLoud chain on an iPhone with speaker and headphones.",
                "review": "AUTO + DEVICE",
                "acceptance": "No clipping or harsh transient is heard at supported volume levels.",
            })
        seam = audio.get("loop_seam_rms_difference_db")
        if (audio.get("duration_seconds") or 0) >= 8 and seam is not None and abs(seam) > 3:
            recommendations.append({
                "status": "WARN",
                "observation": f"Loop start/end RMS differs by {seam:.2f} dB.",
                "risk": "The loop may reveal a boundary during a long Care session.",
                "suggestion": "Use a crossfade or revise the source loop; inspect the first and last second manually.",
                "review": "AUTO + MANUAL",
                "acceptance": "The loop boundary is not noticeable at normal listening volume.",
            })
        clipped = audio.get("clipped_sample_fraction")
        if clipped is not None and clipped > 0:
            recommendations.append({
                "status": "FAIL",
                "observation": f"Clipped samples occupy {clipped:.5%} of the decoded waveform.",
                "risk": "Clipping can produce harsh distortion, especially after runtime processing.",
                "suggestion": "Lower or remaster the source and preserve peak headroom before applying runtime filters.",
                "review": "AUTO + DEVICE",
                "acceptance": "Decoded clipped-sample fraction is zero and no clipping is heard through the runtime chain.",
            })
        transient = audio.get("max_50ms_rms_increase_db")
        # Short spoken and one-shot cues normally begin after digital silence.
        # Keep that onset measurement in the report, but reserve automatic
        # transient warnings for long-form or looping material.
        pulse_interval_cv = audio.get("pulse_proxy_interval_cv")
        heartbeat_like = (
            mode == "physical"
            and audio.get("pulse_periodicity_bpm") is not None
            and 50 <= audio["pulse_periodicity_bpm"] <= 80
            and (audio.get("pulse_periodicity_correlation") or 0) >= 0.35
            and pulse_interval_cv is not None
            and pulse_interval_cv <= 0.20
        )
        if (
            transient is not None
            and transient > 15
            and (audio.get("duration_seconds") or 0) >= 8
            and not heartbeat_like
        ):
            recommendations.append({
                "status": "WARN",
                "observation": f"Maximum 50 ms RMS increase is {transient:.1f} dB.",
                "risk": "A sudden onset or transient may feel startling even when the overall LUFS value is low.",
                "suggestion": "Inspect the timestamp and add a short fade or soften the transient if it is not intentional speech articulation.",
                "review": "AUTO + MANUAL + DEVICE",
                "acceptance": "No unintended abrupt onset remains at normal listening level on speaker and headphones.",
            })
        if mode == "physical" and heartbeat_like:
            recommendations.append({
                "status": "MANUAL_REQUIRED",
                "observation": (
                    f"A heartbeat-like energy cadence was detected near "
                    f"{audio['pulse_periodicity_bpm']:.1f} BPM."
                ),
                "risk": "A simulated pulse may feel artificial, alarming, or confused with biometric feedback even when technically regular.",
                "suggestion": "Label it as a soft simulated heartbeat, keep it optional, and verify cadence, lub-dub character, comfort, and phone-speaker audibility on device.",
                "review": "MANUAL + DEVICE",
                "acceptance": "Reviewers perceive a soft simulated heartbeat without mistaking it for measured personal heart-rate data.",
            })
        dc_offset = audio.get("dc_offset")
        if dc_offset is not None and abs(dc_offset) > 0.01:
            recommendations.append({
                "status": "WARN",
                "observation": f"Waveform DC offset is {dc_offset:.4f}.",
                "risk": "A material DC offset can reduce headroom or reveal a click at edits and loops.",
                "suggestion": "Remove DC offset during mastering and recheck the loop boundary.",
                "review": "AUTO",
                "acceptance": "Absolute decoded DC offset is at or below 0.01.",
            })
    return recommendations


def build_report(mode: str, video: dict[str, Any] | None, audio: dict[str, Any] | None) -> dict[str, Any]:
    recommendations = _recommendations(mode, video, audio)
    return {
        "schema_version": 1,
        "mode": mode,
        "scope": "local engineering and experience review; not a clinical efficacy assessment",
        "goal": MODE_GUIDANCE[mode]["goal"],
        "video": video,
        "audio": audio,
        "recommendations": recommendations,
        "manual_review": MODE_GUIDANCE[mode]["suggestions"],
    }


def markdown(report: dict[str, Any]) -> str:
    lines = [
        f"# Care audit: {report['mode']}",
        "",
        "> Local engineering and experience review. This report does not diagnose, treat, or prove emotional benefit.",
        "",
        f"**Intended transformation:** {report['goal']}",
        "",
        "## Measurements",
        "",
        "```json",
        json.dumps({"video": report["video"], "audio": report["audio"]}, indent=2, sort_keys=True),
        "```",
        "",
        "## Recommendations",
        "",
    ]
    if not report["recommendations"]:
        lines.append("No automatic warning was triggered. Manual review is still required for emotional experience.")
    for item in report["recommendations"]:
        lines.extend(
            [
                f"### {item['status']}: {item['observation']}",
                f"- Risk: {item['risk']}",
                f"- Suggestion: {item['suggestion']}",
                f"- Review: {item['review']}",
                f"- Acceptance: {item['acceptance']}",
                "",
            ]
        )
    lines.extend(["## Manual review prompts", ""])
    lines.extend(f"- {item}" for item in report["manual_review"])
    lines.extend(
        [
            "",
            "## Safety boundary",
            "",
            "Expressions of self-harm, harm to others, imminent danger, or inability to stay safe must exit ordinary Care and show regional crisis resources.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=sorted(MODES), required=True)
    parser.add_argument("--video", type=Path)
    parser.add_argument("--audio", type=Path)
    parser.add_argument("--output", type=Path, required=True, help="Output JSON path; Markdown is written beside it.")
    args = parser.parse_args()
    if args.video is None and args.audio is None:
        parser.error("at least one of --video or --audio is required")
    try:
        video = analyze_video(args.video) if args.video else None
        audio = analyze_audio(args.audio) if args.audio else None
        report = build_report(args.mode, video, audio)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"care audit failed: {error}", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.output.with_suffix(".md").write_text(markdown(report), encoding="utf-8")
    print(json.dumps({"json": str(args.output), "markdown": str(args.output.with_suffix('.md'))}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
