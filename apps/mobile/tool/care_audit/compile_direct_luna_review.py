#!/usr/bin/env python3
"""Unblind and consolidate direct multimodal Luna A/B/C reviews."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


VARIANT_LABELS = {
    "aBaseline": "A — baseline",
    "bConservative": "B — conservative",
    "cSimplified": "C — simplified",
}


def _load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def unblind_reviews(
    reviews: list[dict[str, Any]], mappings: dict[str, dict[str, str]]
) -> list[dict[str, Any]]:
    unblinded: list[dict[str, Any]] = []
    for review in reviews:
        group_id = review["group_id"]
        mapping = mappings[group_id]
        ranking = review["ranking"]
        if sorted(ranking) != ["X", "Y", "Z"]:
            raise ValueError(f"Invalid ranking for {group_id}: {ranking}")
        observations = []
        for observation in review.get("observations", []):
            blind_candidate = observation["candidate"]
            observations.append(
                {
                    **observation,
                    "blind_candidate": blind_candidate,
                    "variant": mapping[blind_candidate],
                }
            )
            observations[-1].pop("candidate", None)
        unblinded.append(
            {
                **review,
                "preferred_blind_candidate": review["preferred"],
                "preferred_variant": mapping[review["preferred"]],
                "ranking_blind": ranking,
                "ranking_variants": [mapping[candidate] for candidate in ranking],
                "observations": observations,
            }
        )
        unblinded[-1].pop("preferred", None)
        unblinded[-1].pop("ranking", None)
    return unblinded


def build_report(
    heavy: list[dict[str, Any]],
    racing: list[dict[str, Any]],
    mappings: dict[str, dict[str, str]],
) -> dict[str, Any]:
    reviews = unblind_reviews(heavy + racing, mappings)
    preferred_counts = Counter(item["preferred_variant"] for item in reviews)
    return {
        "schema_version": 1,
        "review_method": "Direct multimodal gpt-5.6-luna subagents over blinded evidence sheets",
        "external_api_key_used": False,
        "clinical_report": False,
        "summary": {
            "reviewed_groups": len(reviews),
            "preferred_variant_counts": {
                variant: preferred_counts.get(variant, 0) for variant in VARIANT_LABELS
            },
            "single_global_winner": False,
            "decision": "Use path-specific tuning targets; do not replace every scene with one global variant.",
        },
        "reviews": reviews,
        "reduced_motion_gate": {
            "group_id": "explode-reduced-motion",
            "llm_reviewed": False,
            "decision": "Use B or C behavior; both deterministic captures are static and pass, while A fails reduced-motion acceptance.",
        },
        "audio_gate": {
            "llm_reviewed": False,
            "decision": "Do not promote audio automatically. Listen to referenced A/B/C assets on an iPhone before selection.",
        },
    }


def _variant(value: str) -> str:
    return VARIANT_LABELS.get(value, value)


def markdown(report: dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [
        "# Care A/B/C direct multimodal review",
        "",
        "> Non-clinical pre-TestFlight engineering and product-design review. The model inspected blinded still-sheet evidence plus anonymous deterministic metrics. It did not watch continuous video or hear audio.",
        "",
        "## Decision",
        "",
        "There is **no single global winner**. Use path-specific tuning targets:",
        "",
        "| Path | Preferred target | Ranking | Confidence |",
        "|---|---|---|---:|",
    ]
    for review in report["reviews"]:
        ranking = " > ".join(_variant(value) for value in review["ranking_variants"])
        lines.append(
            f"| `{review['group_id']}` | {_variant(review['preferred_variant'])} | {ranking} | {review['confidence']:.0%} |"
        )
    lines.extend(
        [
            "",
            "Preference count is descriptive, not a score: "
            + ", ".join(
                f"{_variant(variant)} {count}"
                for variant, count in summary["preferred_variant_counts"].items()
            )
            + ".",
            "",
            "## What to change next",
            "",
            "### Heavy",
            "",
            "- Keep A's clearly heavy opening and readable rain-stopping narrative for the long default/full paths.",
            "- For real-time high intensity, tune toward B: preserve visible response while adding a monotonic density/opacity decay that reaches a clearly sparse or stopped endpoint within the interaction window.",
            "- Do not use C's sparse Heavy opening as the general target; the review found that it weakens the overwhelmed-to-agency transition.",
            "- Keep rain reduction independent from optional breathing. Cap endpoint halo growth so it reads as a quiet anchor, not proof of emotional recovery.",
            "",
            "### Racing",
            "",
            "- Use C as the default-intensity target: it retained the progression while reducing flow, jerk, luminance change, and stripe-pattern load.",
            "- Use B as the full tap/sweep target: it best preserved visible intermediate organization without A's higher interference burden.",
            "- Do not leave a perfectly unchanged single line for most of a 90-second path. Add very low-amplitude localized evolution or a restrained tap acknowledgment.",
            "- Reduce final horizontal-line crowding so the focus state does not become a fine-stripe block.",
            "",
            "### Reduced motion",
            "",
            report["reduced_motion_gate"]["decision"],
            "",
            "## Per-path findings",
            "",
        ]
    )
    for review in report["reviews"]:
        blind_map = {
            observation["blind_candidate"]: observation["variant"]
            for observation in review.get("observations", [])
        }
        blind_key = ", ".join(
            f"{candidate} = {_variant(blind_map[candidate])}"
            for candidate in ("X", "Y", "Z")
            if candidate in blind_map
        )
        lines.extend(
            [
                f"### `{review['group_id']}` — {_variant(review['preferred_variant'])}",
                "",
                f"Unblinded key: {blind_key}.",
                "",
                "Original blinded rationale:",
                "",
                review["rationale"],
                "",
                "Recommended adjustments:",
                "",
            ]
        )
        lines.extend(
            f"- {recommendation}"
            for recommendation in review.get("specific_parameter_recommendations", [])
        )
        lines.extend(["", "TestFlight questions:", ""])
        lines.extend(
            f"- {question}" for question in review.get("human_validation_questions", [])
        )
        lines.append("")
    lines.extend(
        [
            "## Audio remains a separate gate",
            "",
            report["audio_gate"]["decision"],
            "The deterministic pass found B fixed the `explode.mp3` seam warning, but `physical.mp3` and `space.mp3` still require listening and further onset/loop work. A vision-only review cannot select them responsibly.",
            "",
            "## Review limitations",
            "",
            "- Still sheets can compare composition and sampled progression, but not frame-perfect easing, short transient peaks, touch latency, or full playback cadence.",
            "- Deterministic metrics are screening proxies, not evidence that an animation changes mood or physiology.",
            "- Validate brightness, perceived motion, audio comfort, and emotional interpretation on an actual iPhone in dim and normal viewing conditions.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--heavy-review", required=True, type=Path)
    parser.add_argument("--racing-review", required=True, type=Path)
    parser.add_argument("--mappings", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    report = build_report(
        _load(args.heavy_review), _load(args.racing_review), _load(args.mappings)
    )
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    json_path = output / "care-abc-direct-luna-review.json"
    markdown_path = output / "care-abc-direct-luna-review.md"
    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    markdown_path.write_text(markdown(report), encoding="utf-8")
    print(json.dumps({"json": str(json_path), "markdown": str(markdown_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
