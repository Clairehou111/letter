# Multimodal LLM Review

This document defines the optional semantic and experience-review layer for the Care media audit. It is an advisory research tool for pre-TestFlight optimization. It is not a clinical report, a medical device evaluation, or evidence that a scene treats anger, depression, anxiety, pain, or any other condition.

## Audit boundary

The existing deterministic audit is the hard gate. Its engineering checks remain authoritative for `PASS`, `WARN`, `MANUAL_REQUIRED`, and `FAIL`, including motion, reduced-motion behavior, luminance and flash proxies, color and contrast, audio loudness, clipping, transients, loop seams, and other reproducible media checks.

`llm_review.py` must never change those statuses. It adds observations and revision suggestions alongside the deterministic report. A multimodal model cannot override a deterministic failure, and a favorable model response cannot turn a failed or unreviewed scene into a release approval.

## Scope of one LLM review run

The review reads `care-audit-summary.json` and covers the complete report scope:

- every animation scenario in `animations`, including all Care modes, physical contexts, interaction branches, intensity boundaries, full timelines, Breath modes, and reduced-motion variants;
- every audio item in `audio`, which is the set of MP3 files referenced by Care runtime code;
- `unused_audio` is listed for cleanup context but is not analyzed as an active Care experience;
- deterministic metrics and charts already produced by the audit.

The tool must not silently sample only a representative four-second clip or one typical path. If a summary is missing an animation or a runtime-referenced audio item, the run should report an input error or an incomplete manifest rather than implying full coverage.

## `llm_review.py` behavior

`llm_review.py` is dry-run by default. A dry run performs no network call and does not require an API key. It should:

1. read `care-audit-summary.json`;
2. enumerate all animation and active-audio records;
3. collect deterministic evidence referenced by the summary;
4. generate keyframes for each animation: start, motion peak, major transition, settle state, end, and any additional detected motion or luminance jump;
5. generate an animation contact sheet and an audio evidence image for each referenced MP3, such as waveform, spectrogram, and level timeline;
6. write a manifest containing scenario IDs, media paths, evidence paths, SHA256 hashes, deterministic statuses, and metric excerpts;
7. write model-ready request payloads or prompt files without calling a model.

The output directory remains separate from the deterministic report and contains:

```text
llm-review/
  care-llm-review.json
  care-llm-review.md
  packages/
  requests/
  cache/
  results/               # created only by --execute
```

The manifest makes coverage auditable. It identifies every reviewed animation and every runtime-referenced audio file, plus explicitly lists unused audio without analyzing it.

## OpenAI execution mode

Only `--execute` may call the OpenAI Responses API. The default model is `gpt-5.6-luna`; a different model may be selected explicitly for comparison or escalation. `OPENAI_API_KEY` must be read only from the process environment. Do not read it from source files, checked-in configuration, the report, command-line arguments, or generated manifests.

The image-capable model receives contact sheets, evidence images, the scenario intent, and deterministic metric excerpts. The image model does not directly listen to raw MP3 audio. Audio review therefore uses the generated waveform, spectrogram, loudness, clipping, transient, loop-seam, and frequency metrics. If audio semantics are needed later, use an explicitly audio-capable service and record that as a separate review path; do not claim that an image-only request heard the audio.

The LLM request requires structured output containing:

- `subject_id` and `subject_kind`;
- observations tied to an evidence image or timestamp;
- whether the intended visual transition is understandable: `yes`, `no`, or `uncertain`;
- possible experience risks, such as overload, ambiguity, excessive repetition, coercive pacing, or an unsupported promise of recovery;
- concrete parameter-level suggestions, such as reducing rain density, extending a fade, lowering contrast, or clarifying a Breath phase;
- evidence type: `IMAGE`, `METRIC`, `CONTEXT`, or `INFERENCE`;
- confidence and whether physical-device review is required.

The model must not diagnose the user, infer a user's mental-health state, or claim that an animation is therapeutic. Suggestions must preserve user agency and must describe changes to the media or interaction, not treatment instructions.

## SHA256 cache

The tool must cache results by a SHA256 key derived from the complete review input, including:

- the relevant media and evidence hashes;
- the deterministic metric excerpt;
- the scenario intent and prompt version;
- the selected model and review configuration.

If none of those inputs change, a later run must reuse the cached LLM result and avoid another API request. Changing a scene should invalidate only that scene. Changing the shared prompt or model should invalidate the affected review set. Cache metadata must not contain the API key.

## Recommended review rubric

Use Calm-inspired product principles as design references, not as proprietary algorithm claims:

- clear immediate intent with low decision burden;
- one understandable emotional or sensory transition per mode;
- visual rhythm that guides attention without demanding performance;
- audio and animation that support the same direction without requiring artificial beat matching;
- a visible end state and an optional next action;
- controls for skip, sound, and reduced motion;
- wording that supports hope or relief without promising recovery.

Mode-specific prompts must respect the actual Care intent. For example, Heavy is a heavy-rain scene that gradually stops. The review should ask whether the rain visibly and credibly stops, whether the transition is too abrupt or overstimulating, and whether the ending offers a small amount of agency or orientation without claiming that the user's problem is solved. It should not ask the scene to remain calm throughout or reinterpret the rain as a promise of recovery.

## Dry-run example

Run from `product/letter/apps/mobile` after the deterministic audit has produced its summary:

```bash
python3 tool/care_audit/llm_review.py \
  --audit /tmp/care-audit-full/care-audit-summary.json \
  --output /tmp/care-audit-full/llm-review
```

This command must not call OpenAI. It creates the complete manifest, contact sheets, audio evidence, and model-ready request files for all animations and all runtime-referenced audio.

## Execute example

Set the key in the shell environment, then explicitly opt into network execution:

```bash
export OPENAI_API_KEY="your-key"
python3 tool/care_audit/llm_review.py \
  --audit /tmp/care-audit-full/care-audit-summary.json \
  --output /tmp/care-audit-full/llm-review \
  --execute \
  --model gpt-5.6-luna
```

Without `--execute`, the key must not be used. The execution report should record the model, prompt version, cache hits, cache misses, request errors, and covered items, while never recording the secret value.

## Interpretation and release use

LLM results are suggestions for animation, audio, copy, and interaction revisions only. They do not change deterministic `PASS`/`FAIL` results, do not replace physical iPhone review, and do not establish clinical efficacy. A practical loop is:

```text
deterministic hard gate
        -> multimodal evidence package
        -> LLM observations and parameter suggestions
        -> artist/developer revision
        -> deterministic re-audit
        -> targeted device review
        -> TestFlight feedback
```

For cost control, generate all evidence in dry-run mode first, execute the low-cost model once for the full matrix, and escalate only failed, warned, manually required, or changed scenarios. Keep blind A/B comparisons where possible and treat TestFlight user feedback as the final product-learning signal rather than treating model similarity scores as proof of emotional benefit.
