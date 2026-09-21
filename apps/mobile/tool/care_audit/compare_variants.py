#!/usr/bin/env python3
"""Compare deterministic A/B/C Care candidates without inventing an efficacy score."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


VARIANTS = ("aBaseline", "bConservative", "cSimplified")
METRICS = (
    "optical_flow_p95_at_30fps",
    "motion_jerk_p95",
    "motion_end_start_ratio",
    "spatial_pattern_score_max",
    "max_frame_luminance_step",
    "max_local_opposing_flashes_per_second",
    "mean_frame_difference",
)


def _base_id(item: dict[str, Any]) -> str:
    variant = item.get("variant", "aBaseline")
    if variant == "bConservative" and item["id"].endswith("-b"):
        return item["id"][:-2]
    if variant == "cSimplified" and item["id"].endswith("-c"):
        return item["id"][:-2]
    return item["id"]


def comparison_groups(animations: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, dict[str, dict[str, Any]]] = {}
    for item in animations:
        variant = item.get("variant", "aBaseline")
        if variant not in VARIANTS:
            continue
        grouped.setdefault(_base_id(item), {})[variant] = item
    results: list[dict[str, Any]] = []
    for base_id, candidates in sorted(grouped.items()):
        if len(candidates) < 2:
            continue
        rows = []
        for variant in VARIANTS:
            item = candidates.get(variant)
            if item is None:
                continue
            rows.append(
                {
                    "variant": variant,
                    "scenario_id": item["id"],
                    "status": item["status"],
                    "metrics": {
                        key: item.get("metrics", {}).get(key)
                        for key in METRICS
                        if key in item.get("metrics", {})
                    },
                    "recommendations": item.get("recommendations", []),
                }
            )
        results.append(
            {
                "group": base_id,
                "mode": next(iter(candidates.values()))["mode"],
                "candidates": rows,
            }
        )
    return results


def visual_eligibility(groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    decisions = []
    for variant in VARIANTS[1:]:
        rows = [
            candidate
            for group in groups
            for candidate in group["candidates"]
            if candidate["variant"] == variant
        ]
        failures = [row["scenario_id"] for row in rows if row["status"] == "FAIL"]
        flash_findings = [
            row["scenario_id"]
            for row in rows
            if row["metrics"].get("max_local_opposing_flashes_per_second", 0) > 0
        ]
        decisions.append(
            {
                "variant": variant,
                "decision": "REJECT" if failures or flash_findings else "ELIGIBLE_FOR_BLINDED_REVIEW",
                "scenario_count": len(rows),
                "failures": failures,
                "new_flash_findings": flash_findings,
                "manual_or_warn": [
                    row["scenario_id"]
                    for row in rows
                    if row["status"] in {"WARN", "MANUAL_REQUIRED"}
                ],
            }
        )
    return decisions


def _number(value: Any, digits: int = 3) -> str:
    return "—" if value is None else f"{value:.{digits}f}"


def _markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Care A/B/C deterministic comparison",
        "",
        "> Engineering comparison only. No therapeutic, emotional-effect, or aggregate efficacy score is calculated.",
        "",
        "## Visual eligibility",
        "",
    ]
    for decision in report["visual_eligibility"]:
        lines.append(
            f"- **{decision['variant']} — {decision['decision']}** across {decision['scenario_count']} controlled captures."
        )
        if decision["failures"]:
            lines.append(f"  Failures: {', '.join(decision['failures'])}.")
        if decision["manual_or_warn"]:
            lines.append(
                f"  Still needs interpretation: {', '.join(decision['manual_or_warn'])}."
            )
    lines.extend(
        [
            "",
            "## Visual scenario groups",
            "",
            "| Group | Variant | Status | P95 flow @30fps | Jerk P95 | End/start | Pattern proxy | Luminance step | Local flashes/s | Mean frame difference |",
            "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for group in report["visual_groups"]:
        for candidate in group["candidates"]:
            metrics = candidate["metrics"]
            lines.append(
                "| {group} | {variant} | {status} | {flow} | {jerk} | {ratio} | {pattern} | {light} | {flash} | {difference} |".format(
                    group=group["group"],
                    variant=candidate["variant"],
                    status=candidate["status"],
                    flow=_number(metrics.get("optical_flow_p95_at_30fps")),
                    jerk=_number(metrics.get("motion_jerk_p95")),
                    ratio=_number(metrics.get("motion_end_start_ratio")),
                    pattern=_number(metrics.get("spatial_pattern_score_max")),
                    light=_number(metrics.get("max_frame_luminance_step"), 4),
                    flash=_number(metrics.get("max_local_opposing_flashes_per_second"), 0),
                    difference=_number(metrics.get("mean_frame_difference"), 5),
                )
            )
    audio = report.get("audio")
    if audio:
        lines.extend(
            [
                "",
                "## Audio candidates",
                "",
                "Audio candidates remain a listening decision. A vision-language model cannot hear the waveform/spectrogram evidence.",
                "",
                "| Asset | Variant | Status | Loop seam delta | Max 50 ms rise |",
                "|---|---|---:|---:|---:|",
            ]
        )
        for asset in audio.get("assets", []):
            for candidate in asset["variants"]:
                metrics = candidate["metrics"]
                lines.append(
                    f"| {asset['asset']} | {candidate['variant']} | {candidate['status']} | "
                    f"{_number(metrics.get('loop_seam_rms_difference_db'), 2)} dB | "
                    f"{_number(metrics.get('max_50ms_rms_increase_db'), 1)} dB |"
                )
    lines.extend(
        [
            "",
            "## Next gate",
            "",
            "Only visual candidates marked `ELIGIBLE_FOR_BLINDED_REVIEW` should be packaged with anonymous labels for LLM comparison. Audio B/C must be listened to before any app-asset replacement.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--visual-audit", required=True, type=Path)
    parser.add_argument("--audio-variants", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    visual = json.loads(args.visual_audit.read_text(encoding="utf-8"))
    groups = comparison_groups(visual.get("animations", []))
    report: dict[str, Any] = {
        "schema_version": 1,
        "visual_audit": str(args.visual_audit.resolve()),
        "visual_groups": groups,
        "visual_eligibility": visual_eligibility(groups),
    }
    if args.audio_variants:
        report["audio"] = json.loads(args.audio_variants.read_text(encoding="utf-8"))
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    json_path = output / "care-abc-comparison.json"
    markdown_path = output / "care-abc-comparison.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown_path.write_text(_markdown(report), encoding="utf-8")
    print(json.dumps({"json": str(json_path), "markdown": str(markdown_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
