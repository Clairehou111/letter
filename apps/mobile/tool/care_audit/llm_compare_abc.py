#!/usr/bin/env python3
"""Prepare and optionally execute blinded LLM comparisons of Care A/B/C visuals."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import sys
from pathlib import Path
from typing import Any

import numpy as np

from llm_review import _api_payload, _call_responses, _read_json, _sha256_file


SCRIPT_DIR = Path(__file__).resolve().parent
SCHEMA_PATH = SCRIPT_DIR / "llm_compare_abc_schema.json"
PROMPT_PATH = SCRIPT_DIR / "prompts/care_compare_abc_v1.md"
MODEL = "gpt-5.6-luna"
PROMPT_VERSION = "care_compare_abc_v1"
MODEL_INPUT_USD_PER_MILLION = 0.20
MODEL_OUTPUT_USD_PER_MILLION = 1.20
INTENTS = {
    "heavy": "Heavy rain gradually thins and stops without requiring interaction; the ending does not promise emotional recovery. Guided breathing is a separate Care experience.",
    "racing": "Many simultaneous inputs become less visually entropic and leave one place to rest attention without implying every problem is solved.",
}


def _cv2() -> Any:
    try:
        import cv2  # type: ignore
    except ImportError as error:
        raise RuntimeError("OpenCV is required for blinded comparison sheets.") from error
    return cv2


def blind_mapping(group_id: str) -> dict[str, str]:
    variants = ["aBaseline", "bConservative", "cSimplified"]
    seed = int(hashlib.sha256(f"{PROMPT_VERSION}:{group_id}".encode()).hexdigest()[:16], 16)
    random.Random(seed).shuffle(variants)
    return dict(zip(("X", "Y", "Z"), variants, strict=True))


def _put_text(image: np.ndarray, text: str, origin: tuple[int, int], scale: float = 0.55) -> None:
    cv2 = _cv2()
    cv2.putText(image, text, origin, cv2.FONT_HERSHEY_SIMPLEX, scale, (238, 238, 238), 1, cv2.LINE_AA)


def create_blind_sheet(
    group: dict[str, Any],
    mapping: dict[str, str],
    frames_root: Path,
    output: Path,
    frame_count: int = 6,
) -> list[dict[str, Any]]:
    cv2 = _cv2()
    by_variant = {item["variant"]: item for item in group["candidates"]}
    baseline_paths = sorted((frames_root / by_variant["aBaseline"]["scenario_id"]).glob("frame_*.png"))
    if not baseline_paths:
        raise RuntimeError(f"Missing frames for {group['group']}")
    indexes = [round(value) for value in np.linspace(0, len(baseline_paths) - 1, frame_count)]
    cell_width = 280
    header_height = 38
    rows: list[np.ndarray] = []
    evidence: list[dict[str, Any]] = []
    duration = float(group.get("timeline_seconds") or 0)
    for label in ("X", "Y", "Z"):
        item = by_variant[mapping[label]]
        paths = sorted((frames_root / item["scenario_id"]).glob("frame_*.png"))
        cells: list[np.ndarray] = []
        for index in indexes:
            source = cv2.imread(str(paths[index]), cv2.IMREAD_COLOR)
            if source is None:
                raise RuntimeError(f"Could not read {paths[index]}")
            height = round(source.shape[0] * cell_width / source.shape[1])
            image = cv2.resize(source, (cell_width, height), interpolation=cv2.INTER_AREA)
            timestamp = index / max(1, len(paths) - 1) * duration
            header = np.full((header_height, cell_width, 3), 18, dtype=np.uint8)
            _put_text(header, f"Candidate {label}  {timestamp:6.2f}s", (8, 25), 0.48)
            cells.append(np.vstack([header, image]))
        rows.append(np.hstack(cells))
        evidence.append(
            {
                "candidate": label,
                "timestamps_seconds": [
                    round(index / max(1, len(paths) - 1) * duration, 3) for index in indexes
                ],
            }
        )
    width = max(row.shape[1] for row in rows)
    separator = np.full((16, width, 3), 4, dtype=np.uint8)
    sheet_parts: list[np.ndarray] = []
    for row_index, row in enumerate(rows):
        if row_index:
            sheet_parts.append(separator)
        sheet_parts.append(row)
    sheet = np.vstack(sheet_parts)
    output.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(output), sheet, [cv2.IMWRITE_JPEG_QUALITY, 90]):
        raise RuntimeError(f"Could not write {output}")
    return evidence


def _anonymous_metrics(group: dict[str, Any], mapping: dict[str, str]) -> dict[str, Any]:
    by_variant = {item["variant"]: item for item in group["candidates"]}
    return {
        label: {
            "optical_flow_p95_at_30fps": by_variant[variant]["metrics"].get("optical_flow_p95_at_30fps"),
            "motion_jerk_p95": by_variant[variant]["metrics"].get("motion_jerk_p95"),
            "motion_end_start_ratio": by_variant[variant]["metrics"].get("motion_end_start_ratio"),
            "spatial_pattern_score_max": by_variant[variant]["metrics"].get("spatial_pattern_score_max"),
            "max_frame_luminance_step": by_variant[variant]["metrics"].get("max_frame_luminance_step"),
            "local_flashes_per_second": by_variant[variant]["metrics"].get("max_local_opposing_flashes_per_second"),
        }
        for label, variant in mapping.items()
    }


def _prompt(group: dict[str, Any], mapping: dict[str, str], evidence: list[dict[str, Any]]) -> str:
    context = {
        "group_id": group["group"],
        "mode": group["mode"],
        "timeline_seconds": group.get("timeline_seconds"),
        "intended_experience": INTENTS[group["mode"]],
        "evidence_rows": evidence,
        "anonymous_metrics": _anonymous_metrics(group, mapping),
    }
    return "Compare Candidate X, Y, and Z using this context and the attached evidence sheet.\n\n" + json.dumps(context, indent=2, sort_keys=True)


def _cache_key(model: str, prompt: str, system_prompt: str, schema: dict[str, Any], evidence: Path) -> str:
    value = {
        "model": model,
        "prompt": prompt,
        "system_prompt": system_prompt,
        "schema": schema,
        "evidence_sha256": _sha256_file(evidence),
    }
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def _validate_review(review: dict[str, Any], group_id: str) -> None:
    if review.get("group_id") != group_id:
        raise RuntimeError(f"group_id mismatch: {review.get('group_id')!r}")
    if set(review.get("ranking", [])) != {"X", "Y", "Z"} or len(review["ranking"]) != 3:
        raise RuntimeError("ranking must contain X, Y, and Z exactly once")


def _usage(raw: dict[str, Any]) -> dict[str, Any]:
    usage = raw.get("usage", {})
    input_tokens = int(usage.get("input_tokens") or 0)
    output_tokens = int(usage.get("output_tokens") or 0)
    estimate = (
        input_tokens * MODEL_INPUT_USD_PER_MILLION / 1_000_000
        + output_tokens * MODEL_OUTPUT_USD_PER_MILLION / 1_000_000
    )
    return {
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "estimated_token_cost_usd": round(estimate, 6),
    }


def _markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Care blinded A/B/C LLM comparison",
        "",
        "> Advisory visual review only. Deterministic results remain authoritative; no clinical effect is established.",
        "",
        f"Model: `{report['model']}`  ",
        f"Estimated token cost: **${report['estimated_token_cost_usd']:.4f}**",
        "",
    ]
    for result in report["results"]:
        lines.extend([f"## {result['group_id']}", ""])
        if result.get("error"):
            lines.extend([f"Error: {result['error']}", ""])
            continue
        review = result["review"]
        unblinded = result["unblinded_ranking"]
        lines.extend(
            [
                f"Blind ranking: **{' > '.join(review['ranking'])}**  ",
                f"Unblinded ranking: **{' > '.join(unblinded)}**  ",
                f"Preferred: **{result['preferred_variant']}** ({review['confidence']} confidence)",
                "",
                review["selection_rationale"],
                "",
            ]
        )
        for recommendation in review.get("revision_recommendations", []):
            lines.append(
                f"- {recommendation['candidate']} / {result['mapping'][recommendation['candidate']]} — `{recommendation['parameter']}`: {recommendation['proposed_change']}"
            )
        lines.append("")
    lines.extend(
        [
            "## Interpretation",
            "",
            "Use recurring preferences as design evidence, not as an efficacy claim. Review the selected candidate on iPhone and keep the TestFlight comparison blinded where practical.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--comparison", required=True, type=Path)
    parser.add_argument("--visual-audit", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--model", default=MODEL)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    comparison = _read_json(args.comparison)
    visual = _read_json(args.visual_audit)
    animation_lookup = {item["id"]: item for item in visual["animations"]}
    output = args.output.resolve()
    evidence_root = output / "evidence"
    request_root = output / "requests"
    cache_root = output / "cache"
    result_root = output / "results"
    for directory in (evidence_root, request_root, cache_root):
        directory.mkdir(parents=True, exist_ok=True)
    if args.execute:
        result_root.mkdir(parents=True, exist_ok=True)
    schema = _read_json(SCHEMA_PATH)
    schema_for_api = {key: value for key, value in schema.items() if key not in {"$schema", "title"}}
    system_prompt = PROMPT_PATH.read_text(encoding="utf-8").strip()
    prepared = []
    mappings: dict[str, dict[str, str]] = {}
    for group in comparison["visual_groups"]:
        if group["group"] == "explode-reduced-motion":
            continue
        enriched = dict(group)
        enriched["timeline_seconds"] = animation_lookup[group["group"]].get("timeline_seconds")
        mapping = blind_mapping(group["group"])
        mappings[group["group"]] = mapping
        evidence_path = evidence_root / f"{group['group']}.jpg"
        evidence = create_blind_sheet(
            enriched,
            mapping,
            args.visual_audit.parent / "frames",
            evidence_path,
        )
        user_prompt = _prompt(enriched, mapping, evidence)
        cache_key = _cache_key(args.model, user_prompt, system_prompt, schema_for_api, evidence_path)
        descriptor = {
            "group_id": group["group"],
            "model": args.model,
            "prompt_version": PROMPT_VERSION,
            "evidence_image": str(evidence_path),
            "evidence_sha256": _sha256_file(evidence_path),
            "cache_key": cache_key,
            "user_prompt": user_prompt,
            "mapping_is_intentionally_omitted": True,
        }
        request_path = request_root / f"{group['group']}.json"
        request_path.write_text(json.dumps(descriptor, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        prepared.append(descriptor)
    (output / "blind-mappings.json").write_text(
        json.dumps(mappings, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    report: dict[str, Any] = {
        "schema_version": 1,
        "mode": "execute" if args.execute else "dry_run",
        "model": args.model,
        "prepared_groups": len(prepared),
        "skipped_objective_group": "explode-reduced-motion",
        "results": [],
        "estimated_token_cost_usd": 0.0,
    }
    if args.execute:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            print("--execute requires OPENAI_API_KEY in the environment.", file=sys.stderr)
            return 2
        for descriptor in prepared:
            group_id = descriptor["group_id"]
            cache_path = cache_root / f"{descriptor['cache_key']}.json"
            try:
                if cache_path.exists() and not args.force:
                    cached = _read_json(cache_path)
                    review = cached["review"]
                    usage = cached.get("usage", {})
                    cache_state = "hit"
                else:
                    payload = _api_payload(
                        args.model,
                        system_prompt,
                        descriptor["user_prompt"],
                        Path(descriptor["evidence_image"]),
                        schema_for_api,
                        schema_name="care_abc_comparison",
                        max_output_tokens=2200,
                    )
                    review, raw = _call_responses(payload, api_key, 120)
                    _validate_review(review, group_id)
                    usage = _usage(raw)
                    cached = {
                        "model": args.model,
                        "response_id": raw.get("id"),
                        "usage": usage,
                        "review": review,
                    }
                    cache_path.write_text(json.dumps(cached, indent=2, sort_keys=True) + "\n", encoding="utf-8")
                    cache_state = "miss"
                mapping = mappings[group_id]
                preferred = review["preferred_candidate"]
                result = {
                    "group_id": group_id,
                    "cache": cache_state,
                    "mapping": mapping,
                    "review": review,
                    "unblinded_ranking": [mapping[label] for label in review["ranking"]],
                    "preferred_variant": mapping.get(preferred, "no_clear_winner"),
                    "usage": usage,
                }
                report["estimated_token_cost_usd"] += float(usage.get("estimated_token_cost_usd", 0))
            except (RuntimeError, ValueError, json.JSONDecodeError) as error:
                result = {"group_id": group_id, "error": str(error)}
            (result_root / f"{group_id}.json").write_text(
                json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
            report["results"].append(result)
    report["estimated_token_cost_usd"] = round(report["estimated_token_cost_usd"], 6)
    json_path = output / "care-abc-llm-review.json"
    markdown_path = output / "care-abc-llm-review.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    markdown_path.write_text(_markdown(report), encoding="utf-8")
    print(
        json.dumps(
            {
                "mode": report["mode"],
                "prepared_groups": report["prepared_groups"],
                "estimated_token_cost_usd": report["estimated_token_cost_usd"],
                "json": str(json_path),
                "markdown": str(markdown_path),
            },
            indent=2,
        )
    )
    return 1 if any(item.get("error") for item in report["results"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
