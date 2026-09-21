#!/usr/bin/env python3
"""Prepare or execute an advisory multimodal review of a Care audit report.

The deterministic Care audit remains the safety gate. This layer prepares
timestamped visual evidence and engineering context for a vision-language model.
It never changes PASS/FAIL results and does not assess clinical efficacy.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import numpy as np


SCRIPT_DIR = Path(__file__).resolve().parent
MOBILE_ROOT = SCRIPT_DIR.parents[1]
SCHEMA_PATH = SCRIPT_DIR / "llm_review_schema.json"
PROMPT_PATH = SCRIPT_DIR / "prompts/care_review_v1.md"
AUDIO_ROOT = MOBILE_ROOT / "assets/audio/care/prototype"
RESPONSES_ENDPOINT = "https://api.openai.com/v1/responses"
PROMPT_VERSION = "care_review_v1"
DEFAULT_MODEL = "gpt-5.6-luna"
MODE_AUDIO = {
    "explode": "explode.mp3",
    "heavy": "heavy.mp3",
    "racing": "racing.mp3",
    "space": "space.mp3",
    "physical": "physical.mp3",
    "breath": "breath.mp3",
}
MODE_INTENTS = {
    "explode": "High activation becomes a contained pause before a consequential decision.",
    "heavy": "Heavy rain gradually thins and stops, with no action required and no promise that sadness or depression has ended.",
    "racing": "Many simultaneous inputs become less visually entropic and leave one place to rest attention.",
    "space": "Incoming stimulation becomes a finite bounded pause without implying guaranteed safety or isolation.",
    "physical": "Physical discomfort is met with a low-stimulation, familiar comfort scene without treatment claims.",
    "breath": "One optional breathing pattern remains legible without performance pressure, including during holds and Reduce Motion.",
}

ANIMATION_METRICS = (
    "duration_seconds",
    "mean_luminance",
    "luminance_p95",
    "mean_saturation",
    "mean_lab_lightness",
    "mean_lab_chroma",
    "mean_cool_color_fraction",
    "mean_warm_color_fraction",
    "mean_neutral_color_fraction",
    "mean_frame_difference",
    "p95_frame_difference",
    "optical_flow_mean_at_30fps",
    "optical_flow_p95_at_30fps",
    "motion_jerk_p95",
    "motion_end_start_ratio",
    "max_frame_luminance_step",
    "max_local_luminance_step",
    "max_opposing_flashes_per_second",
    "max_local_opposing_flashes_per_second",
    "scene_cut_count",
    "spatial_pattern_score_max",
    "edge_fractal_dimension_mean",
    "edge_fractal_loglog_fit_mean",
    "saliency_focus_count_mean",
    "saliency_focus_count_p95",
    "saliency_centroid_jump_p95",
    "saliency_map_correlation_p10",
    "audio_visual_best_correlation",
    "audio_visual_best_lag_ms",
    "audio_visual_peak_median_mismatch_ms",
)


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _compact_metrics(metrics: dict[str, Any], names: tuple[str, ...] | None = None) -> dict[str, Any]:
    if names is None:
        return {
            key: value
            for key, value in metrics.items()
            if key not in {"path", "time_series"}
        }
    return {key: metrics[key] for key in names if key in metrics}


def _series_peak_positions(metrics: dict[str, Any]) -> list[tuple[float, str, float]]:
    """Return normalized positions of important engineering events."""
    series = metrics.get("time_series", {})
    candidates: list[tuple[float, str, float]] = []
    frame_difference = np.asarray(series.get("frame_difference", []), dtype=np.float64)
    if frame_difference.size:
        for index in np.argsort(frame_difference)[-2:]:
            position = (int(index) + 1) / max(1, frame_difference.size)
            candidates.append((position, "motion peak", float(frame_difference[index])))
    luminance = np.asarray(series.get("luminance", []), dtype=np.float64)
    if luminance.size > 1:
        steps = np.abs(np.diff(luminance))
        index = int(np.argmax(steps)) + 1
        candidates.append((index / max(1, luminance.size - 1), "luminance change", float(steps[index - 1])))
    optical_flow = np.asarray(series.get("optical_flow", []), dtype=np.float64)
    if optical_flow.size:
        index = int(np.argmax(optical_flow))
        candidates.append((index / max(1, optical_flow.size - 1), "optical-flow peak", float(optical_flow[index])))
    center_x = np.asarray(series.get("saliency_center_x", []), dtype=np.float64)
    center_y = np.asarray(series.get("saliency_center_y", []), dtype=np.float64)
    count = min(center_x.size, center_y.size)
    if count > 1:
        jumps = np.hypot(np.diff(center_x[:count]), np.diff(center_y[:count]))
        index = int(np.argmax(jumps)) + 1
        candidates.append((index / max(1, count - 1), "focus shift", float(jumps[index - 1])))
    return candidates


def select_keyframes(
    frame_paths: list[Path],
    metrics: dict[str, Any],
    count: int,
) -> list[dict[str, Any]]:
    """Select endpoints, timeline anchors, and measured peaks deterministically."""
    if not frame_paths:
        raise ValueError("No animation frames were found.")
    count = max(2, min(count, len(frame_paths)))
    ranked = sorted(_series_peak_positions(metrics), key=lambda item: item[2], reverse=True)
    timeline_count = min(count, max(6, count - min(4, len(ranked))))
    selected: dict[int, str] = {}
    for position in np.linspace(0.0, 1.0, timeline_count):
        index = round(float(position) * (len(frame_paths) - 1))
        if index == 0:
            label = "start"
        elif index == len(frame_paths) - 1:
            label = "end"
        else:
            label = "timeline anchor"
        selected.setdefault(index, label)
    for position, label, _ in ranked:
        index = round(position * (len(frame_paths) - 1))
        selected.setdefault(index, label)
        if len(selected) >= count:
            break
    while len(selected) < count:
        remaining = [index for index in range(len(frame_paths)) if index not in selected]
        if not remaining:
            break
        index = max(remaining, key=lambda candidate: min(abs(candidate - used) for used in selected))
        selected[index] = "timeline anchor"
    return [
        {"index": index, "path": frame_paths[index], "reason": selected[index]}
        for index in sorted(selected)[:count]
    ]


def _cv2() -> Any:
    try:
        import cv2  # type: ignore
    except ImportError as error:
        raise RuntimeError(
            "OpenCV is required. Install tool/care_audit/requirements.txt in the audit environment."
        ) from error
    return cv2


def _put_text(image: np.ndarray, text: str, origin: tuple[int, int], scale: float = 0.55) -> None:
    cv2 = _cv2()
    cv2.putText(
        image,
        text,
        origin,
        cv2.FONT_HERSHEY_SIMPLEX,
        scale,
        (238, 238, 238),
        1,
        cv2.LINE_AA,
    )


def create_contact_sheet(
    selections: list[dict[str, Any]],
    output: Path,
    duration_seconds: float,
) -> list[dict[str, Any]]:
    cv2 = _cv2()
    columns = 5 if len(selections) > 8 else 4
    cell_width = 340
    header_height = 38
    images: list[np.ndarray] = []
    evidence: list[dict[str, Any]] = []
    source_last_index = int(selections[-1]["index"])
    for order, item in enumerate(selections, start=1):
        source = cv2.imread(str(item["path"]), cv2.IMREAD_COLOR)
        if source is None:
            raise RuntimeError(f"Could not read frame: {item['path']}")
        height = round(source.shape[0] * cell_width / source.shape[1])
        resized = cv2.resize(source, (cell_width, height), interpolation=cv2.INTER_AREA)
        position = item["index"] / max(1, source_last_index)
        timestamp = position * duration_seconds
        header = np.full((header_height, cell_width, 3), 18, dtype=np.uint8)
        label = f"{order:02d}  {timestamp:6.2f}s  {item['reason']}"
        _put_text(header, label, (8, 25), 0.48)
        images.append(np.vstack([header, resized]))
        evidence.append(
            {
                "tile": order,
                "frame_index": int(item["index"]),
                "timestamp_seconds": round(timestamp, 3),
                "selection_reason": item["reason"],
            }
        )
    cell_height = max(image.shape[0] for image in images)
    rows = math.ceil(len(images) / columns)
    sheet = np.full((rows * cell_height, columns * cell_width, 3), 12, dtype=np.uint8)
    for index, image in enumerate(images):
        row, column = divmod(index, columns)
        y = row * cell_height
        x = column * cell_width
        sheet[y : y + image.shape[0], x : x + image.shape[1]] = image
    output.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(output), sheet, [cv2.IMWRITE_JPEG_QUALITY, 90]):
        raise RuntimeError(f"Could not write contact sheet: {output}")
    return evidence


def _decode_audio(path: Path, sample_rate: int = 16000) -> np.ndarray:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg is required to prepare audio evidence.")
    result = subprocess.run(
        [
            ffmpeg,
            "-v",
            "error",
            "-i",
            str(path),
            "-f",
            "f32le",
            "-ac",
            "1",
            "-ar",
            str(sample_rate),
            "pipe:1",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Could not decode audio evidence for {path.name}.")
    return np.frombuffer(result.stdout, dtype="<f4")


def create_audio_evidence(
    audio_path: Path,
    metrics: dict[str, Any],
    output: Path,
    sample_rate: int = 16000,
) -> None:
    """Render a waveform and spectrogram as engineering evidence, not listening."""
    cv2 = _cv2()
    samples = _decode_audio(audio_path, sample_rate)
    if samples.size == 0:
        raise RuntimeError(f"Decoded audio is empty: {audio_path.name}")
    width, height = 1600, 900
    canvas = np.full((height, width, 3), 13, dtype=np.uint8)
    summary = (
        f"{audio_path.name} | {metrics.get('duration_seconds', 0):.2f}s | "
        f"{metrics.get('integrated_lufs', 0):.1f} LUFS | "
        f"peak {metrics.get('sample_peak_dbfs', 0):.1f} dBFS | "
        f"loop delta {metrics.get('loop_seam_rms_difference_db', 0):.2f} dB"
    )
    _put_text(canvas, summary, (40, 42), 0.72)
    _put_text(canvas, "Waveform (engineering evidence only)", (40, 82), 0.55)
    left, right = 45, width - 45
    wave_top, wave_bottom = 100, 350
    center = (wave_top + wave_bottom) // 2
    bins = right - left
    boundaries = np.linspace(0, samples.size, bins + 1, dtype=np.int64)
    for column in range(bins):
        chunk = samples[boundaries[column] : boundaries[column + 1]]
        if chunk.size == 0:
            continue
        low = int(center - float(np.max(chunk)) * (wave_bottom - wave_top) * 0.45)
        high = int(center - float(np.min(chunk)) * (wave_bottom - wave_top) * 0.45)
        cv2.line(canvas, (left + column, low), (left + column, high), (198, 177, 116), 1)
    cv2.line(canvas, (left, center), (right, center), (75, 75, 75), 1)

    window = 1024
    hop = max(256, (samples.size - window) // 900)
    starts = np.arange(0, max(1, samples.size - window + 1), hop, dtype=np.int64)
    if starts.size > 900:
        starts = starts[np.linspace(0, starts.size - 1, 900, dtype=np.int64)]
    hann = np.hanning(window).astype(np.float32)
    columns: list[np.ndarray] = []
    for start in starts:
        chunk = samples[start : start + window]
        if chunk.size < window:
            chunk = np.pad(chunk, (0, window - chunk.size))
        columns.append(np.abs(np.fft.rfft(chunk * hann)))
    spectrum = np.asarray(columns, dtype=np.float32).T
    spectrum = 20 * np.log10(np.maximum(spectrum, 1e-7))
    floor = float(np.percentile(spectrum, 10))
    ceiling = float(np.percentile(spectrum, 99.5))
    normalized = np.clip((spectrum - floor) / max(1e-6, ceiling - floor), 0, 1)
    gray = np.rint(normalized[::-1] * 255).astype(np.uint8)
    colored = cv2.applyColorMap(gray, cv2.COLORMAP_MAGMA)
    spec_top, spec_bottom = 410, 840
    colored = cv2.resize(colored, (right - left, spec_bottom - spec_top), interpolation=cv2.INTER_AREA)
    canvas[spec_top:spec_bottom, left:right] = colored
    _put_text(canvas, "Spectrogram 0-8 kHz (engineering evidence only; the model cannot hear this image)", (40, 392), 0.55)
    _put_text(canvas, "8 kHz", (right - 70, spec_top + 20), 0.45)
    _put_text(canvas, "0 Hz", (right - 60, spec_bottom - 10), 0.45)
    output.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(output), canvas, [cv2.IMWRITE_JPEG_QUALITY, 92]):
        raise RuntimeError(f"Could not write audio evidence: {output}")


def _subject_prompt(subject: dict[str, Any]) -> str:
    context = {
        key: value
        for key, value in subject.items()
        if key not in {"evidence_path", "request_path", "cache_key"}
    }
    return (
        "Review this Care subject using the attached timestamped evidence image and the "
        "following deterministic context. Treat the deterministic status as immutable.\n\n"
        + json.dumps(context, indent=2, sort_keys=True)
    )


def _cache_key(
    subject: dict[str, Any],
    evidence_path: Path,
    prompt: str,
    system_prompt: str,
    schema: dict[str, Any],
    model: str,
) -> str:
    canonical = {
        "model": model,
        "prompt_version": PROMPT_VERSION,
        "system_prompt": system_prompt,
        "user_prompt": prompt,
        "schema": schema,
        "evidence_sha256": _sha256_file(evidence_path),
    }
    return _sha256_bytes(json.dumps(canonical, sort_keys=True).encode("utf-8"))


def _request_descriptor(
    subject: dict[str, Any],
    evidence_path: Path,
    prompt: str,
    cache_key: str,
    model: str,
) -> dict[str, Any]:
    return {
        "endpoint": RESPONSES_ENDPOINT,
        "model": model,
        "prompt_version": PROMPT_VERSION,
        "subject_id": subject["subject_id"],
        "subject_kind": subject["subject_kind"],
        "cache_key": cache_key,
        "evidence_image": str(evidence_path),
        "evidence_sha256": _sha256_file(evidence_path),
        "user_prompt": prompt,
        "structured_output_schema": str(SCHEMA_PATH),
        "note": "This offline descriptor omits the base64 image. --execute builds the API payload in memory.",
    }


def _data_url(path: Path) -> str:
    mime = "image/jpeg" if path.suffix.lower() in {".jpg", ".jpeg"} else "image/png"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"


def _api_payload(
    model: str,
    system_prompt: str,
    user_prompt: str,
    evidence_path: Path,
    schema: dict[str, Any],
    *,
    schema_name: str = "care_experience_review",
    max_output_tokens: int = 3500,
) -> dict[str, Any]:
    return {
        "model": model,
        "store": False,
        "input": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": user_prompt},
                    {
                        "type": "input_image",
                        "image_url": _data_url(evidence_path),
                        "detail": "high",
                    },
                ],
            },
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": schema_name,
                "strict": True,
                "schema": schema,
            }
        },
        "max_output_tokens": max_output_tokens,
    }


def _extract_output_text(response: dict[str, Any]) -> str:
    for output in response.get("output", []):
        if output.get("type") != "message":
            continue
        for content in output.get("content", []):
            if content.get("type") == "output_text" and isinstance(content.get("text"), str):
                return content["text"]
            if content.get("type") == "refusal":
                raise RuntimeError(f"Model refused the review: {content.get('refusal', 'unknown reason')}")
    raise RuntimeError("The Responses API returned no output_text content.")


def _call_responses(payload: dict[str, Any], api_key: str, timeout: float) -> tuple[dict[str, Any], dict[str, Any]]:
    request = urllib.request.Request(
        RESPONSES_ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "letter-care-audit/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Responses API HTTP {error.code}: {detail[:1000]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Responses API request failed: {error.reason}") from error
    parsed = json.loads(_extract_output_text(raw))
    if not isinstance(parsed, dict):
        raise RuntimeError("Structured output was not a JSON object.")
    return parsed, raw


def _animation_subject(
    item: dict[str, Any],
    audio_lookup: dict[str, dict[str, Any]],
    frames_root: Path,
    packages_root: Path,
    keyframe_count: int,
) -> dict[str, Any]:
    scenario_id = item["id"]
    frame_paths = sorted((frames_root / scenario_id).glob("frame_*.png"))
    selections = select_keyframes(frame_paths, item.get("metrics", {}), keyframe_count)
    evidence_path = packages_root / scenario_id / "contact-sheet.jpg"
    duration = float(item.get("timeline_seconds") or item.get("metrics", {}).get("duration_seconds") or 0)
    evidence_tiles = create_contact_sheet(selections, evidence_path, duration)
    audio_name = MODE_AUDIO.get(item["mode"])
    audio_item = audio_lookup.get(audio_name or "")
    return {
        "subject_id": scenario_id,
        "subject_kind": "animation_audio_pair",
        "deterministic_status": item["status"],
        "mode": item["mode"],
        "variant": item.get("variant", "aBaseline"),
        "context": item.get("context"),
        "interaction": item.get("interaction"),
        "intensity": item.get("intensity"),
        "reduced_motion": bool(item.get("reduced_motion")),
        "timeline_seconds": duration,
        "intended_experience": MODE_INTENTS[item["mode"]],
        "deterministic_metrics": _compact_metrics(item.get("metrics", {}), ANIMATION_METRICS),
        "triggered_recommendations": item.get("recommendations", []),
        "paired_source_audio": (
            {
                "asset": audio_name,
                "deterministic_status": audio_item.get("status"),
                "metrics": _compact_metrics(audio_item.get("metrics", {})),
            }
            if audio_item
            else None
        ),
        "evidence_tiles": evidence_tiles,
        "evidence_limitations": [
            "The contact sheet samples a complete deterministic capture but is not continuous video playback.",
            "Paired audio is represented by engineering metrics here; the vision-language model does not hear it.",
            "Runtime DSP, iPhone display behavior, device audio route, haptics, and felt emotional effect require human review.",
        ],
        "evidence_path": evidence_path,
    }


def _audio_subject(item: dict[str, Any], packages_root: Path) -> dict[str, Any]:
    asset = item["asset"]
    source = AUDIO_ROOT / asset
    evidence_path = packages_root / f"audio-{source.stem}" / "audio-evidence.jpg"
    if source.exists():
        create_audio_evidence(source, item.get("metrics", {}), evidence_path)
    else:
        raise RuntimeError(f"Runtime-referenced audio asset is missing: {source}")
    return {
        "subject_id": asset,
        "subject_kind": "audio_asset",
        "deterministic_status": item["status"],
        "intended_experience": "Support the associated Care interaction without startling starts, tiring high-frequency energy, clipping, or an audible loop discontinuity.",
        "deterministic_metrics": _compact_metrics(item.get("metrics", {})),
        "triggered_recommendations": item.get("recommendations", []),
        "evidence_limitations": [
            "The evidence image is a waveform and spectrogram; the vision-language model cannot hear the original audio.",
            "Do not infer timbre, spoken-word accuracy, emotional valence, listener comfort, or audio quality from the image alone.",
            "Speaker, wired/USB, and Bluetooth listening checks on an iPhone remain required.",
        ],
        "evidence_path": evidence_path,
    }


def _markdown(bundle: dict[str, Any]) -> str:
    lines = [
        "# Care LLM advisory review",
        "",
        "> This semantic review is non-clinical and advisory. It does not change the deterministic audit status.",
        "",
        f"Mode: **{bundle['mode']}**",
        f"Model: `{bundle['model']}`",
        f"Prepared animation scenarios: **{bundle['coverage']['animations']}**",
        f"Prepared runtime-referenced audio assets: **{bundle['coverage']['audio']}**",
        "",
    ]
    if bundle["mode"] == "dry_run":
        lines.extend(
            [
                "No API calls were made. Each subject has an English prompt, evidence image, request descriptor, and stable cache key.",
                "",
                "## Prepared subjects",
                "",
                "| Subject | Kind | Deterministic status | Evidence |",
                "|---|---|---:|---|",
            ]
        )
        for subject in bundle["subjects"]:
            lines.append(
                f"| {subject['subject_id']} | {subject['subject_kind']} | {subject['deterministic_status']} | [{Path(subject['evidence_path']).name}]({subject['evidence_path']}) |"
            )
        return "\n".join(lines) + "\n"
    lines.extend(["## Model reviews", ""])
    for entry in bundle["results"]:
        subject_id = entry["subject_id"]
        if entry.get("error"):
            lines.extend([f"### {subject_id}", "", f"API error: {entry['error']}", ""])
            continue
        review = entry["review"]
        lines.extend(
            [
                f"### {subject_id}",
                "",
                f"Intent achieved: **{review['intent_achieved']}**  ",
                f"Overall experience: **{review['overall_experience']}**",
                "",
            ]
        )
        for recommendation in review.get("recommendations", []):
            lines.append(
                f"- {recommendation['priority']} — `{recommendation['parameter']}`: {recommendation['proposed_change']} Acceptance: {recommendation['acceptance_check']}"
            )
        if not review.get("recommendations"):
            lines.append("- No parameter change was proposed.")
        lines.append("")
    return "\n".join(lines) + "\n"


def _validate_keyframe_count(value: str) -> int:
    count = int(value)
    if not 8 <= count <= 16:
        raise argparse.ArgumentTypeError("--keyframes must be between 8 and 16.")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True, help="Path to care-audit-summary.json.")
    parser.add_argument("--output", type=Path, required=True, help="Dedicated LLM review output directory.")
    parser.add_argument("--execute", action="store_true", help="Call the Responses API. Without this flag, only offline packages are generated.")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--keyframes", type=_validate_keyframe_count, default=10)
    parser.add_argument("--subject", action="append", help="Prepare only a matching scenario ID or audio filename. Repeatable.")
    parser.add_argument("--force", action="store_true", help="Ignore local cached model responses.")
    parser.add_argument("--timeout", type=float, default=120.0)
    args = parser.parse_args()

    audit_path = args.audit.resolve()
    output = args.output.resolve()
    report = _read_json(audit_path)
    schema = _read_json(SCHEMA_PATH)
    schema_for_api = {key: value for key, value in schema.items() if key not in {"$schema", "title"}}
    system_prompt = PROMPT_PATH.read_text(encoding="utf-8").strip()
    output.mkdir(parents=True, exist_ok=True)
    packages_root = output / "packages"
    requests_root = output / "requests"
    cache_root = output / "cache"
    results_root = output / "results"
    requests_root.mkdir(parents=True, exist_ok=True)
    cache_root.mkdir(parents=True, exist_ok=True)
    if args.execute:
        results_root.mkdir(parents=True, exist_ok=True)

    selected = set(args.subject or [])
    audio_lookup = {item["asset"]: item for item in report.get("audio", [])}
    subjects: list[dict[str, Any]] = []
    try:
        for item in report.get("animations", []):
            if selected and item["id"] not in selected:
                continue
            subjects.append(
                _animation_subject(
                    item,
                    audio_lookup,
                    audit_path.parent / "frames",
                    packages_root,
                    args.keyframes,
                )
            )
        for item in report.get("audio", []):
            if selected and item["asset"] not in selected:
                continue
            subjects.append(_audio_subject(item, packages_root))
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"Care LLM review preparation failed: {error}", file=sys.stderr)
        return 2

    prepared: list[dict[str, Any]] = []
    for subject in subjects:
        evidence_path = Path(subject.pop("evidence_path"))
        prompt = _subject_prompt(subject)
        cache_key = _cache_key(subject, evidence_path, prompt, system_prompt, schema_for_api, args.model)
        safe_name = subject["subject_id"].replace("/", "-")
        request_path = requests_root / f"{safe_name}.json"
        descriptor = _request_descriptor(subject, evidence_path, prompt, cache_key, args.model)
        request_path.write_text(json.dumps(descriptor, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        subject.update(
            {
                "evidence_path": str(evidence_path),
                "request_path": str(request_path),
                "cache_key": cache_key,
            }
        )
        prepared.append(subject)

    bundle: dict[str, Any] = {
        "schema_version": 1,
        "prompt_version": PROMPT_VERSION,
        "mode": "execute" if args.execute else "dry_run",
        "model": args.model,
        "deterministic_audit": str(audit_path),
        "deterministic_status_unchanged": True,
        "coverage": {
            "animations": sum(item["subject_kind"] == "animation_audio_pair" for item in prepared),
            "audio": sum(item["subject_kind"] == "audio_asset" for item in prepared),
        },
        "unused_audio_not_reviewed": report.get("unused_audio", []),
        "subjects": prepared,
        "results": [],
        "limitations": [
            "Model output is advisory and cannot change deterministic PASS/FAIL results.",
            "Contact sheets do not reproduce continuous playback.",
            "Audio evidence images cannot substitute for listening.",
            "No result establishes emotional or clinical efficacy.",
        ],
    }

    if args.execute:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            print("--execute requires OPENAI_API_KEY in the environment.", file=sys.stderr)
            return 2
        for subject in prepared:
            cache_path = cache_root / f"{subject['cache_key']}.json"
            result_path = results_root / f"{subject['subject_id'].replace('/', '-')}.json"
            if cache_path.exists() and not args.force:
                cached = _read_json(cache_path)
                entry = {
                    "subject_id": subject["subject_id"],
                    "cache": "hit",
                    "review": cached["review"],
                    "response_id": cached.get("response_id"),
                }
            else:
                descriptor = _read_json(Path(subject["request_path"]))
                payload = _api_payload(
                    args.model,
                    system_prompt,
                    descriptor["user_prompt"],
                    Path(subject["evidence_path"]),
                    schema_for_api,
                )
                try:
                    review, raw = _call_responses(payload, api_key, args.timeout)
                    if review.get("subject_id") != subject["subject_id"]:
                        raise RuntimeError(
                            f"Structured output subject_id mismatch: {review.get('subject_id')!r}"
                        )
                    cached = {
                        "cache_key": subject["cache_key"],
                        "model": args.model,
                        "response_id": raw.get("id"),
                        "review": review,
                    }
                    cache_path.write_text(json.dumps(cached, indent=2, sort_keys=True) + "\n", encoding="utf-8")
                    entry = {
                        "subject_id": subject["subject_id"],
                        "cache": "miss",
                        "review": review,
                        "response_id": raw.get("id"),
                    }
                except (RuntimeError, ValueError, json.JSONDecodeError) as error:
                    entry = {"subject_id": subject["subject_id"], "error": str(error)}
            result_path.write_text(json.dumps(entry, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            bundle["results"].append(entry)

    manifest_path = output / "care-llm-review.json"
    markdown_path = output / "care-llm-review.md"
    manifest_path.write_text(json.dumps(bundle, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown_path.write_text(_markdown(bundle), encoding="utf-8")
    print(
        json.dumps(
            {
                "mode": bundle["mode"],
                "manifest": str(manifest_path),
                "markdown": str(markdown_path),
                "coverage": bundle["coverage"],
            },
            indent=2,
        )
    )
    return 1 if any(item.get("error") for item in bundle["results"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
