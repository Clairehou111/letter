# Care media audit

This is a local, non-clinical audit for the Flutter Care scenes. It checks
rendered captures and bundled audio for engineering risks, then produces
experience-review prompts. It does not determine whether a person is calm,
whether anger was relieved, or whether depression was treated.

## Requirements

- `ffmpeg` and `ffprobe` on `PATH`;
- Python 3 with the packages in `requirements.txt`. OpenCV provides the
  Farneback optical-flow statistics; without it, the report explicitly falls
  back to frame-difference motion metrics.

Install them into a local virtual environment rather than the app runtime:

```bash
python3 -m venv /tmp/care-audit-venv
/tmp/care-audit-venv/bin/pip install -r tool/care_audit/requirements.txt
```

The current app renders Care scenes at runtime with `CustomPainter`; the input
must therefore be a capture of the running scene, not a screenshot of a static
asset. The `scenarios.json` file is the capture matrix and keeps the random
seeds and interaction steps reproducible.

## Run the complete audit

One command captures all deterministic Flutter animation scenarios, encodes
them as review videos, discovers the MP3 files referenced by Care runtime Dart
code, audits those files, and lists bundled-but-unreferenced files separately:

```bash
cd product/letter/apps/mobile
python3 tool/care_audit/run_full_audit.py --output /tmp/care-audit-full
```

Outputs:

- `care-audit-summary.json` and `care-audit-summary.md`;
- `care-optimization-report.md` with prioritized changes and acceptance checks;
- the complete animation matrix under `frames/`, covering all modes, Physical
  contexts, principal interactions, intensity boundaries, complete natural
  timelines, all three guided-breathing patterns, and reduced motion;
- matching review videos under `videos/` and per-scenario SVG metric charts under
  `charts/`;
- metrics for every runtime-referenced Care MP3;
- filenames and sizes for bundled MP3s that Care code does not reference.

Use `--skip-capture` to re-analyze existing frames after changing only the
analysis rules.

When only scenario acceptance metadata changed and the frame captures are known
to be unchanged, add `--reuse-analysis` with `--skip-capture`. It reuses metrics
for existing scenario IDs and analyzes only newly added captures. Never use it
after changing painter output.

For a focused implementation pass, repeat `--scenario-id` to capture and
analyze only the affected scenarios while leaving the complete matrix intact.

## Run one media audit

```bash
cd product/letter/apps/mobile
python3 tool/care_audit/analyze_media.py \
  --mode explode \
  --video /tmp/care-audit/explode.mp4 \
  --audio assets/audio/care/prototype/explode.mp3 \
  --output /tmp/care-audit/explode.json
```

The single-media command writes JSON and a Markdown report next to the requested output.
The complete command analyzes only MP3 files referenced by Care runtime code;
unreferenced files are listed without effect analysis. The report still
requires device listening because SoLoud applies runtime filters, gain fades,
and the Space outside envelope.

## Prepare the optional LLM review

After the deterministic audit, prepare English-only multimodal evidence and
request descriptors without making a network call:

```bash
python3 tool/care_audit/llm_review.py \
  --audit /tmp/care-audit-full/care-audit-summary.json \
  --output /tmp/care-audit-full/llm-review
```

Add `--execute` only when an API call is intended. The optional layer never
changes deterministic statuses and does not analyze unused MP3 files. See
[`LLM_REVIEW.md`](LLM_REVIEW.md) for the evidence, cache, cost, and interpretation
rules.

## Generate A/B/C candidates before LLM review

`scenarios.json` keeps `aBaseline` as the original visual reference and adds
controlled B/C captures only for findings that need visual revision:

- `bConservative`: moderately lower Heavy rain density/velocity and Racing
  line density/speed/contrast;
- `cSimplified`: a stronger reduction of the same parameters;
- both B and C render a genuinely static sealed Explode frame under Reduce
  Motion.

Production now defaults to `productionHybrid`, which applies the selected
path-specific findings: dense but slower Heavy rain with a complete monotonic
fade, C-like Racing at default intensity, B/C midpoint Racing at high
intensity, and a genuinely static Reduce Motion frame. Seeds, interactions,
copy, and complete scene timelines remain identical across comparisons.

Heavy and Racing MP3 sources remain unchanged ambient loops. Because playback
starts at a randomized loop offset, they are not beat-locked to frames.
Runtime low-pass and gain envelopes now follow visual settling slowly; this
provides coarse audio-visual congruency without regenerating audio or inventing
frame-accurate synchronization.

Generate reversible audio candidates for runtime-referenced assets currently
carrying a deterministic warning:

```bash
python3 tool/care_audit/generate_audio_variants.py \
  --audit /tmp/care-audit-full/care-audit-summary.json \
  --output /tmp/care-audit-abc/audio-variants
```

A is the untouched app asset. B applies a 500 ms equal-power loop repair. C
adds localized recovery envelopes for abrupt rises detected in long-form
ambience. Derived files preserve the source channel count and sample rate and
remain under the requested audit directory; the app bundle is not modified.
The candidate gate rejects channel-layout changes and loudness drift above
3 LU even if a derivative clears the warning thresholds. Run deterministic
comparison first, then listen only to surviving candidates on an iPhone.

Generate the deterministic Physical heartbeat research candidate separately:

```bash
python3 tool/care_audit/generate_heartbeat_candidate.py \
  --output /tmp/care-heartbeat/E-procedural-heartbeat.mp3 \
  --bpm 60 \
  --duration 20
```

This produces a centered simulated `lub-dub` loop, not biometric audio. Its
cadence, loop seam, loudness, and phone-oriented harmonics still require the
normal deterministic audit and physical-iPhone listening gate.

When the blinded sheets are reviewed by direct multimodal subagents rather than
the external API helper, preserve each reviewer's JSON and unblind only after
both reviews finish:

```bash
python3 tool/care_audit/compile_direct_luna_review.py \
  --heavy-review /tmp/care-audit-abc/blind-review/direct-luna-heavy.json \
  --racing-review /tmp/care-audit-abc/blind-review/direct-luna-racing.json \
  --mappings /tmp/care-audit-abc/blind-review/blind-mappings.json \
  --output /tmp/care-audit-abc/blind-review
```

This consolidation step records that no external API key was used and keeps
the model's visual judgment separate from the audio listening gate. Luna can
inspect the evidence images, but this workflow does not claim that it heard the
MP3 candidates or watched continuous video.

## Implemented measurements

- Farneback optical-flow mean/P95 normalized to a comparable 30 fps value,
  frame-difference motion, jerk, trend, and per-series slow-period
  autocorrelation;
- deterministic RGB k-means dominant palette, HSV cool/warm/neutral fractions,
  LAB lightness/chroma, saturation, brightness, and contrast;
- whole-frame and 8×8 local flash-event checks, temporal frequency proxy from
  3 Hz to the capture Nyquist limit, scene-cut proxy, and spatial
  stripe/grid-risk proxy;
- LUFS, peak/headroom, loop seam, clipping, 50 ms transients, spectral centroid,
  rolloff, and low/presence/high frequency-band balance;
- stillness checks for Reduce Motion and headache presentation.
- exploratory edge-set box-counting dimension, deterministic center-surround
  saliency focus/continuity, and raw-source audio/visual envelope correlation.

These are reproducible engineering proxies, not a Harding certification. A
60 fps capture can only inspect temporal components up to 30 Hz; TestFlight
review on physical iPhones remains required.

The fractal, saliency, and cross-modal values are intended for comparing two
revisions of the same scene. They have no automatic "therapeutic" threshold:
box-counting an arbitrary edge map does not prove natural self-similarity,
saliency prediction is not eye tracking, and source-level audio correlation
does not include runtime DSP or device latency. CLIP/VLM emotion similarity is
deliberately excluded from pass/fail because prompt similarity cannot establish
felt valence or efficacy.

## Optional iOS Simulator capture

Run the app in Profile mode, open one scenario, and record only that scene:

```bash
xcrun simctl io booted recordVideo --codec=h264 /tmp/care-audit/explode.mp4
```

Stop the recording after the settle state is visible. Repeat for the matrix in
`scenarios.json`. TestFlight acceptance still requires an iPhone after the
build is available; Simulator and Android do not validate the physical iOS
screen, speaker, headphone route, or GPU timing.

## Interpreting results

- `FAIL`: fix or re-capture before release review;
- `WARN`: inspect the exact segment and decide whether to revise it;
- `MANUAL_REQUIRED`: an automated metric cannot determine emotional effect;
- no warning: no tested engineering rule triggered, not evidence of efficacy.

For emotional review, use the format:

```text
observation -> potential experience risk -> proposed change -> review type -> acceptance condition
```

Do not use this tool to diagnose, score, or infer a user's mental-health state.
