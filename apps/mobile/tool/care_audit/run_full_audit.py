#!/usr/bin/env python3
"""Capture and audit every Care animation and bundled Care audio asset."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import numpy as np

from analyze_media import (
    MODE_GUIDANCE,
    _command,
    _recommendations,
    analyze_audio,
    analyze_audio_visual_alignment,
    analyze_video,
    _strongest_period,
)


SCRIPT_DIR = Path(__file__).resolve().parent
MOBILE_ROOT = SCRIPT_DIR.parents[1]
SCENARIOS_PATH = SCRIPT_DIR / "scenarios.json"
AUDIO_ROOT = MOBILE_ROOT / "assets/audio/care/prototype"
CARE_SOURCE_ROOT = MOBILE_ROOT / "lib/features/care"
CAPTURE_TEST = "test/care_audit/care_animation_capture_test.dart"
MODE_AUDIO = {
    "explode": "explode.mp3",
    "heavy": "heavy.mp3",
    "racing": "racing.mp3",
    "space": "space.mp3",
    "physical": "physical.mp3",
    "breath": "breath.mp3",
}


def _run_capture(frames_root: Path, scenario_ids: list[str] | None = None) -> None:
    environment = os.environ.copy()
    environment["CARE_AUDIT_OUTPUT_DIR"] = str(frames_root)
    if scenario_ids:
        environment["CARE_AUDIT_SCENARIO_IDS"] = ",".join(scenario_ids)
    result = subprocess.run(
        [_command("flutter"), "test", CAPTURE_TEST],
        cwd=MOBILE_ROOT,
        env=environment,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError("Flutter animation capture failed.")


def _encode_frames(frame_directory: Path, output: Path, fps: int) -> None:
    first = frame_directory / "frame_0000.png"
    if not first.exists():
        raise RuntimeError(f"Missing animation frames: {frame_directory}")
    output.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            _command("ffmpeg"),
            "-v",
            "error",
            "-y",
            "-framerate",
            str(fps),
            "-i",
            str(frame_directory / "frame_%04d.png"),
            "-vf",
            "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "18",
            "-pix_fmt",
            "yuv420p",
            str(output),
        ],
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Could not encode {frame_directory.name}.")


def _runtime_audio_references() -> set[str]:
    pattern = re.compile(r"assets/audio/care/prototype/([A-Za-z0-9_-]+\.mp3)")
    references: set[str] = set()
    for path in CARE_SOURCE_ROOT.rglob("*.dart"):
        references.update(pattern.findall(path.read_text(encoding="utf-8")))
    return references


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _status(recommendations: list[dict[str, str]], *, missing: bool = False) -> str:
    if missing or any(item["status"] == "FAIL" for item in recommendations):
        return "FAIL"
    if any(item["status"] == "WARN" for item in recommendations):
        return "WARN"
    if any(item["status"] == "MANUAL_REQUIRED" for item in recommendations):
        return "MANUAL_REQUIRED"
    return "PASS"


def _audit_animations(
    scenarios: list[dict[str, Any]],
    frames_root: Path,
    videos_root: Path,
    fps: int,
    prior_results: dict[str, dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for scenario in scenarios:
        scenario_id = scenario["id"]
        mode = scenario["mode"]
        frame_directory = frames_root / scenario_id
        video_path = videos_root / f"{scenario_id}.mp4"
        if not frame_directory.exists():
            results.append(
                {
                    "id": scenario_id,
                    "mode": mode,
                    "status": "FAIL",
                    "error": f"Missing frame directory: {frame_directory}",
                    "recommendations": [],
                }
            )
            continue
        scenario_fps = int(scenario.get("capture_fps", fps))
        prior = (prior_results or {}).get(scenario_id)
        if prior is not None and video_path.exists():
            metrics = prior["metrics"]
        else:
            _encode_frames(frame_directory, video_path, scenario_fps)
            metrics = analyze_video(video_path, sample_fps=float(scenario_fps))
            source_audio = AUDIO_ROOT / MODE_AUDIO[mode]
            if source_audio.exists():
                metrics.update(analyze_audio_visual_alignment(metrics, source_audio))
        recommendations = _recommendations(mode, metrics, None)
        if scenario.get("expected_still"):
            difference = metrics.get("mean_frame_difference")
            if difference is not None and difference > 0.001:
                recommendations.append(
                    {
                        "status": "FAIL",
                        "observation": f"Still-mode mean frame difference is {difference:.5f}.",
                        "risk": "Reduced-motion or headache presentation is not visually still.",
                        "suggestion": "Stop the animation controller and remove pulsing, particles, and moving overlays.",
                        "review": "AUTO",
                        "acceptance": "Mean frame difference is at or below 0.001 in a repeated capture.",
                    }
                )
        expected_period = scenario.get("expected_period_seconds")
        if expected_period:
            period_series = scenario.get("period_series", "motion")
            low, high = (float(value) for value in expected_period)
            period_prefix = {
                "frame_difference": "strongest_frame_difference",
                "focus_luminance": "strongest_focus_luminance",
                "luminance": "strongest_luminance",
                "motion": "strongest_motion",
            }.get(period_series)
            if period_prefix is None:
                raise ValueError(
                    f"Unknown period_series for {scenario['id']}: {period_series}"
                )
            period = metrics.get(f"{period_prefix}_period_seconds")
            strength = metrics.get(f"{period_prefix}_period_correlation")
            if period_series == "focus_luminance":
                values = np.asarray(
                    metrics.get("time_series", {}).get("focus_luminance", []),
                    dtype=np.float32,
                )
                duration = float(metrics.get("duration_seconds") or 0)
                if len(values) >= 8 and duration > 0:
                    period, strength = _strongest_period(
                        values,
                        samples_per_second=len(values) / duration,
                        minimum_seconds=low,
                        maximum_seconds=high,
                    )
            metrics["expected_period_series"] = period_series
            metrics["expected_period_range_seconds"] = [low, high]
            metrics["expected_period_evaluation_seconds"] = period
            metrics["expected_period_evaluation_correlation"] = strength
            if period is None or strength is None or strength < 0.45 or not low <= period <= high:
                observation = (
                    "No reliable period was detected."
                    if period is None or strength is None
                    else f"Strongest {period_series.replace('_', ' ')} period is {period:.1f}s with {strength:.2f} correlation."
                )
                recommendations.append(
                    {
                        "status": "WARN",
                        "observation": observation,
                        "risk": "The optional breathing guide may not read as a stable, repeatable slow cycle.",
                        "suggestion": "Make the guide radius follow one smooth waveform and remove competing motion near the guide.",
                        "review": "AUTO + MANUAL",
                        "acceptance": f"Detected period is {low:.0f}-{high:.0f}s with correlation at or above 0.45, then confirmed visually.",
                    }
                )
        if scenario.get("expected_motion_reduction"):
            ratio = metrics.get("motion_end_start_ratio")
            if ratio is None or ratio > 0.50:
                observed = "unavailable" if ratio is None else f"{ratio:.2f}x"
                recommendations.append(
                    {
                        "status": "FAIL",
                        "observation": f"Last-quarter versus first-quarter frame movement is {observed}.",
                        "risk": "The scene's intended settling transformation may not be visible across the full sequence.",
                        "suggestion": MODE_GUIDANCE[mode]["suggestions"][0],
                        "review": "AUTO + MANUAL",
                        "acceptance": "Last-quarter mean frame difference is at most 50% of the first quarter, with no abrupt final cut.",
                    }
                )
        results.append(
            {
                "id": scenario_id,
                "mode": mode,
                "variant": scenario.get("variant", "aBaseline"),
                "context": scenario.get("context"),
                "reduced_motion": bool(scenario.get("reduced_motion")),
                "interaction": scenario.get("interaction", "none"),
                "intensity": scenario.get("intensity"),
                "timeline_seconds": scenario.get("timeline_seconds"),
                "capture_fps": scenario_fps,
                "status": _status(recommendations),
                "video": str(video_path),
                "metrics": metrics,
                "recommendations": recommendations,
                "manual_review": MODE_GUIDANCE[mode]["suggestions"],
            }
        )
    return results


def _audio_recommendations(metrics: dict[str, Any]) -> list[dict[str, str]]:
    return _recommendations("physical", None, metrics)


def _audit_audio() -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    runtime = _runtime_audio_references()
    results: list[dict[str, Any]] = []
    unused: list[dict[str, Any]] = []
    for path in sorted(AUDIO_ROOT.glob("*.mp3")):
        if path.name not in runtime:
            unused.append(
                {
                    "asset": path.name,
                    "bytes": path.stat().st_size,
                    "sha256": _sha256(path),
                }
            )
            continue
        metrics = analyze_audio(path)
        recommendations = _audio_recommendations(metrics)
        results.append(
            {
                "asset": path.name,
                "runtime_referenced": True,
                "status": _status(recommendations),
                "sha256": _sha256(path),
                "metrics": metrics,
                "recommendations": recommendations,
            }
        )
    missing = sorted(runtime - {item["asset"] for item in results})
    for name in missing:
        results.append(
            {
                "asset": name,
                "runtime_referenced": True,
                "status": "FAIL",
                "error": "Runtime-referenced audio asset is missing.",
                "recommendations": [],
            }
        )
    return results, unused


def _format_number(value: Any, digits: int = 3) -> str:
    if value is None:
        return "—"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def _write_svg_chart(metrics: dict[str, Any], output: Path, title: str) -> None:
    series = metrics.get("time_series", {})
    panels = [
        ("Luminance", series.get("luminance", []), "#E7C77A"),
        ("Frame difference", series.get("frame_difference", []), "#8FB3D9"),
        ("Optical flow", series.get("optical_flow", []), "#B7A6F6"),
    ]
    width, height = 960, 480
    left, right, top = 72, 24, 48
    panel_height = 116
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#0B0E14"/>',
        f'<text x="{left}" y="28" fill="#F3EDE5" font-family="sans-serif" font-size="16">{title}</text>',
    ]
    for panel_index, (label, values, color) in enumerate(panels):
        y0 = top + panel_index * 140
        svg.append(
            f'<text x="{left}" y="{y0 + 14}" fill="#B8BCC6" font-family="sans-serif" font-size="12">{label}</text>'
        )
        svg.append(
            f'<rect x="{left}" y="{y0 + 22}" width="{width-left-right}" height="{panel_height}" fill="#121722" stroke="#283142"/>'
        )
        if values:
            low = min(values)
            high = max(values)
            span = max(high - low, 1e-9)
            points = []
            for index, value in enumerate(values):
                x = left + index / max(1, len(values) - 1) * (width - left - right)
                y = y0 + 22 + panel_height - (value - low) / span * panel_height
                points.append(f"{x:.1f},{y:.1f}")
            svg.append(f'<polyline points="{" ".join(points)}" fill="none" stroke="{color}" stroke-width="1.5"/>')
            svg.append(
                f'<text x="{width-right}" y="{y0 + 14}" text-anchor="end" fill="#7F8794" font-family="monospace" font-size="11">{low:.4f}–{high:.4f}</text>'
            )
    svg.append("</svg>")
    output.write_text("\n".join(svg) + "\n", encoding="utf-8")


def _palette_text(metrics: dict[str, Any]) -> str:
    return " ".join(
        f"`{item['hex']}` {item['weight']:.0%}"
        for item in metrics.get("dominant_colors", [])[:3]
    ) or "—"


def _markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Full Care animation and audio audit",
        "",
        "> Pre-TestFlight engineering and experience-risk screening. Not a clinical report, efficacy study, or Harding certification.",
        "",
        f"Overall status: **{report['status']}**",
        "",
        "## Method coverage",
        "",
        "Implemented: Farneback optical flow, frame motion and jerk, slow-period autocorrelation, RGB k-means palette, HSV/LAB summaries, luminance contrast, global and 8×8 local flash checks, 3 Hz-to-Nyquist frequency proxy, spatial-pattern proxy, scene-cut proxy, reduced-motion stillness, LUFS/peaks/loop seams, audio spectrum/transient checks, edge-set box-counting dimension, deterministic saliency continuity proxies, and source-level audio/visual envelope correlation.",
        "",
        "Limitations: the flash and pattern checks are conservative local proxies, not Harding certification. Fractal, saliency, and audio/visual values are comparative design signals without a therapeutic pass threshold. Source-level correlation excludes runtime DSP and device latency. Simulator captures do not validate iPhone display PWM, GPU timing, speaker/headphone response, eye movements, or emotional effect.",
        "",
        "## Scenario and branch coverage",
        "",
        "| Scenario | Variant | Status | Timeline | Capture | Interaction | Intensity | Context | Chart |",
        "|---|---|---:|---:|---:|---|---:|---|---|",
    ]
    for item in report["animations"]:
        lines.append(
            "| {id} | {variant} | {status} | {timeline}s | {fps} fps | {interaction} | {intensity} | {context} | [SVG]({chart}) |".format(
                id=item["id"],
                variant=item.get("variant", "aBaseline"),
                status=item["status"],
                timeline=_format_number(item.get("timeline_seconds"), 1),
                fps=_format_number(item.get("capture_fps"), 0),
                interaction=item.get("interaction") or "none",
                intensity=_format_number(item.get("intensity"), 1),
                context=item.get("context") or ("reduced motion" if item.get("reduced_motion") else "—"),
                chart=item.get("chart", ""),
            )
        )
    lines.extend(
        [
            "",
            "## Exploratory positive-quality metrics",
            "",
            "> Comparative signals only. They do not establish relaxation, valence, safety, cortisol change, or therapeutic efficacy.",
            "",
            "| Scenario | Edge fractal D (fit) | Saliency foci mean/P95 | Focus jump P95 | Saliency continuity P10 | Source AV corr | Best lag | Peak mismatch |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for item in report["animations"]:
        metrics = item.get("metrics", {})
        lines.append(
            "| {id} | {fractal} ({fit}) | {focus}/{focus_p95} | {jump} | {continuity} | {correlation} | {lag} ms | {mismatch} ms |".format(
                id=item["id"],
                fractal=_format_number(metrics.get("edge_fractal_dimension_mean"), 2),
                fit=_format_number(metrics.get("edge_fractal_loglog_fit_mean"), 2),
                focus=_format_number(metrics.get("saliency_focus_count_mean"), 1),
                focus_p95=_format_number(metrics.get("saliency_focus_count_p95"), 1),
                jump=_format_number(metrics.get("saliency_centroid_jump_p95"), 3),
                continuity=_format_number(metrics.get("saliency_map_correlation_p10"), 3),
                correlation=_format_number(metrics.get("audio_visual_best_correlation"), 3),
                lag=_format_number(metrics.get("audio_visual_best_lag_ms"), 0),
                mismatch=_format_number(metrics.get("audio_visual_peak_median_mismatch_ms"), 0),
            )
        )
    lines.extend(
        [
            "",
            "## Animation motion and safety metrics",
            "",
            "| Scenario | Global/local flashes/s | P95 flow @30fps | Motion jerk P95 | End/start | Period | Pattern proxy | Max luminance step |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for item in report["animations"]:
        metrics = item.get("metrics", {})
        lines.append(
            "| {id} | {global_flash}/{local_flash} | {flow} | {jerk} | {ratio} | {period}s ({strength}) | {pattern} | {step} |".format(
                id=item["id"],
                global_flash=_format_number(metrics.get("max_opposing_flashes_per_second"), 0),
                local_flash=_format_number(metrics.get("max_local_opposing_flashes_per_second"), 0),
                flow=_format_number(metrics.get("optical_flow_p95_at_30fps"), 3),
                jerk=_format_number(metrics.get("motion_jerk_p95"), 3),
                ratio=_format_number(metrics.get("motion_end_start_ratio"), 3),
                period=_format_number(metrics.get("strongest_motion_period_seconds"), 1),
                strength=_format_number(metrics.get("strongest_motion_period_correlation"), 2),
                pattern=_format_number(metrics.get("spatial_pattern_score_max"), 3),
                step=_format_number(metrics.get("max_frame_luminance_step"), 4),
            )
        )
    lines.extend(
        [
            "",
            "## Animation color metrics",
            "",
            "| Scenario | Dominant palette | LAB L* | LAB chroma | Saturation | High-sat area | Cool/warm/neutral | Contrast |",
            "|---|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for item in report["animations"]:
        metrics = item.get("metrics", {})
        lines.append(
            "| {id} | {palette} | {lightness} | {chroma} | {saturation} | {high_sat} | {cool}/{warm}/{neutral} | {contrast} |".format(
                id=item["id"],
                palette=_palette_text(metrics),
                lightness=_format_number(metrics.get("mean_lab_lightness"), 1),
                chroma=_format_number(metrics.get("mean_lab_chroma"), 1),
                saturation=_format_number(metrics.get("mean_saturation"), 2),
                high_sat=_format_number(metrics.get("mean_high_saturation_fraction"), 2),
                cool=_format_number(metrics.get("mean_cool_color_fraction"), 2),
                warm=_format_number(metrics.get("mean_warm_color_fraction"), 2),
                neutral=_format_number(metrics.get("mean_neutral_color_fraction"), 2),
                contrast=_format_number(metrics.get("max_luminance_contrast_range"), 2),
            )
        )
    lines.extend(
        [
            "",
            "## Referenced audio coverage",
            "",
            "| Asset | Status | Duration | LUFS | Peak | Loop seam Δ | Centroid | >5 kHz | Max 50 ms rise | Clipped |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for item in report["audio"]:
        metrics = item.get("metrics", {})
        lines.append(
            "| {asset} | {status} | {duration}s | {lufs} | {peak} dBFS | {seam} dB | {centroid} Hz | {high} | {rise} dB | {clipped} |".format(
                asset=item["asset"],
                status=item["status"],
                duration=_format_number(metrics.get("duration_seconds"), 2),
                lufs=_format_number(metrics.get("integrated_lufs"), 1),
                peak=_format_number(metrics.get("sample_peak_dbfs"), 1),
                seam=_format_number(metrics.get("loop_seam_rms_difference_db"), 2),
                centroid=_format_number(metrics.get("spectral_centroid_mean_hz"), 0),
                high=_format_number(metrics.get("high_band_fraction_above_5khz"), 3),
                rise=_format_number(metrics.get("max_50ms_rms_increase_db"), 1),
                clipped=_format_number(metrics.get("clipped_sample_fraction"), 6),
            )
        )
    lines.extend(["", "## Bundled but not referenced by Care runtime code", ""])
    if report["unused_audio"]:
        lines.extend(f"- `{item['asset']}` ({item['bytes']} bytes)" for item in report["unused_audio"])
    else:
        lines.append("None.")
    lines.extend(["", "## Triggered recommendations", ""])
    emitted = False
    for item in [*report["animations"], *report["audio"]]:
        for recommendation in item.get("recommendations", []):
            emitted = True
            label = item.get("id", item.get("asset"))
            lines.extend(
                [
                    f"### {label}: {recommendation['status']}",
                    f"- Observation: {recommendation['observation']}",
                    f"- Risk: {recommendation['risk']}",
                    f"- Suggestion: {recommendation['suggestion']}",
                    f"- Review: {recommendation['review']}",
                    f"- Acceptance: {recommendation['acceptance']}",
                    "",
                ]
            )
    if not emitted:
        lines.append("No automatic rule triggered. iPhone and emotional-experience review remain required.")
    return "\n".join(lines) + "\n"


def _optimization_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Care pre-TestFlight optimization recommendations",
        "",
        "> Technical prioritization derived from deterministic captures and referenced audio only. Not a clinical conclusion.",
        "",
    ]
    ordered = {"FAIL": 0, "WARN": 1, "MANUAL_REQUIRED": 2}
    actions: list[tuple[int, str, dict[str, str]]] = []
    for item in [*report["animations"], *report["audio"]]:
        label = item.get("id", item.get("asset"))
        for recommendation in item.get("recommendations", []):
            actions.append((ordered.get(recommendation["status"], 3), label, recommendation))
    lines.extend(["## Prioritized actions", ""])
    if not actions:
        lines.append("No automatic action was triggered; complete the manual and iPhone checks below.")
    for _, label, recommendation in sorted(actions, key=lambda item: item[0]):
        lines.extend(
            [
                f"### {recommendation['status']} — {label}",
                f"- Why: {recommendation['observation']} {recommendation['risk']}",
                f"- Change: {recommendation['suggestion']}",
                f"- Done when: {recommendation['acceptance']}",
                "",
            ]
        )
    lines.extend(
        [
            "## Exploratory quality-review workflow",
            "",
            "- Use saliency focus count, centroid jump, and map continuity to compare revisions of the same scene. Treat large changes as review timestamps, not eye-tracking results.",
            "- Use box-counting dimension only when the edge log-log fit is strong and the visual intentionally contains scale-repeating structure. Do not force every scene into D=1.3–1.5.",
            "- Use source audio/visual correlation to compare mixes, then repeat on an iPhone because runtime gain, filters, fades, route latency, and haptics are excluded.",
            "- Do not convert CLIP/VLM prompt similarity into a valence or therapeutic score. Collect blinded TestFlight ratings for soothing, safety, hope, agency, overwhelm, boredom, and desire to stop/continue instead.",
            "",
        ]
    )
    lines.extend(["## Per-mode design review", ""])
    for mode, guidance in MODE_GUIDANCE.items():
        mode_items = [item for item in report["animations"] if item["mode"] == mode]
        statuses = ", ".join(f"{item['id']}={item['status']}" for item in mode_items)
        lines.extend([f"### {mode.title()}", f"Measured scenarios: {statuses}.", ""])
        lines.extend(f"- {suggestion}" for suggestion in guidance["suggestions"])
        lines.append("")
    lines.extend(
        [
            "## Required iPhone checks after TestFlight",
            "",
            "- Repeat the highest-intensity scenes at minimum and maximum display brightness in a dark room; record any glare, judder, local flash, or uncomfortable stripe field.",
            "- Test Reduce Motion, 60 Hz and ProMotion hardware where available; simulator timing is not physical display timing.",
            "- Listen to every referenced ambience through speaker, wired/USB headphones, and Bluetooth at low and high supported volume; inspect loop boundaries and sudden starts.",
            "- Run short human experience sessions for anger, crying/heaviness, racing thoughts, need for space, and physical discomfort. Record observation and preference, not treatment claims.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--skip-capture",
        action="store_true",
        help="Analyze an existing <output>/frames directory without running Flutter capture.",
    )
    parser.add_argument(
        "--reuse-analysis",
        action="store_true",
        help="With --skip-capture, reuse metrics already present in the output summary for unchanged scenario IDs.",
    )
    parser.add_argument(
        "--scenario-id",
        action="append",
        dest="scenario_ids",
        help="Capture and analyze only this scenario ID. Repeat for multiple scenarios.",
    )
    args = parser.parse_args()
    output = args.output.resolve()
    frames_root = output / "frames"
    videos_root = output / "videos"
    try:
        if args.reuse_analysis and not args.skip_capture:
            raise ValueError("--reuse-analysis requires --skip-capture.")
        output.mkdir(parents=True, exist_ok=True)
        config = json.loads(SCENARIOS_PATH.read_text(encoding="utf-8"))
        scenarios = config["scenarios"]
        if args.scenario_ids:
            requested = set(args.scenario_ids)
            known = {item["id"] for item in scenarios}
            unknown = sorted(requested - known)
            if unknown:
                raise ValueError(f"Unknown scenario IDs: {', '.join(unknown)}")
            scenarios = [item for item in scenarios if item["id"] in requested]
        prior_results: dict[str, dict[str, Any]] = {}
        prior_path = output / "care-audit-summary.json"
        if args.reuse_analysis and prior_path.exists():
            prior_report = json.loads(prior_path.read_text(encoding="utf-8"))
            prior_results = {item["id"]: item for item in prior_report.get("animations", [])}
        if not args.skip_capture:
            _run_capture(frames_root, args.scenario_ids)
        animations = _audit_animations(
            scenarios,
            frames_root,
            videos_root,
            int(config["capture_fps"]),
            prior_results,
        )
        audio, unused_audio = _audit_audio()
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"full Care audit failed: {error}", file=sys.stderr)
        return 2
    statuses = [item["status"] for item in [*animations, *audio]]
    overall = "FAIL" if "FAIL" in statuses else "WARN" if "WARN" in statuses else "MANUAL_REQUIRED"
    charts_root = output / "charts"
    charts_root.mkdir(parents=True, exist_ok=True)
    for item in animations:
        chart_name = f"{item['id']}.svg"
        _write_svg_chart(item.get("metrics", {}), charts_root / chart_name, item["id"])
        item["chart"] = f"charts/{chart_name}"
    report = {
        "schema_version": 2,
        "status": overall,
        "scope": (
            "focused animation scenarios and every runtime-referenced Care MP3"
            if args.scenario_ids
            else "all discrete Care modes and physical contexts, principal interaction branches, intensity boundaries, full natural timelines, reduced motion, and every runtime-referenced Care MP3"
        ),
        "animations": animations,
        "audio": audio,
        "unused_audio": unused_audio,
    }
    json_path = output / "care-audit-summary.json"
    markdown_path = output / "care-audit-summary.md"
    optimization_path = output / "care-optimization-report.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown_path.write_text(_markdown(report), encoding="utf-8")
    optimization_path.write_text(_optimization_markdown(report), encoding="utf-8")
    print(
        json.dumps(
            {
                "json": str(json_path),
                "markdown": str(markdown_path),
                "optimization": str(optimization_path),
                "charts": str(charts_root),
            },
            indent=2,
        )
    )
    return 1 if overall == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
