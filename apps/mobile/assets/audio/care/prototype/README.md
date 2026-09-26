The five Care ambience loops retain stable runtime filenames. Heavy and Racing
remain copied directly from the user's Lovable prototype,
`Clairehou111/scene-mind-soothe`, commit
`125937df9ad205e471a2a404b02a7761eedabaaa`. Explode and Space are conservative
derivatives of those prototype sources. Physical is a deterministic simulated
heartbeat generated locally for pre-TestFlight device review.

Mapping:

- `explode.mp3` → prototype `explode.mp3.asset.json`, then a 500 ms
  channel-preserving equal-power loop crossfade
- `heavy.mp3` → `heavy.mp3.asset.json`
- `racing.mp3` → `racing.mp3.asset.json`
- `space.mp3` → prototype `away-street-crowd-v2.mp3.asset.json`, then a 500 ms
  stereo-preserving loop crossfade and localized softening of one abrupt rise
- `physical.mp3` → `tool/care_audit/generate_heartbeat_candidate.py`, 54 BPM,
  20 seconds, 18 centered `lub-dub` cycles; simulated rather than biometric

Selected bundled hashes:

- `explode.mp3`: `fd7005aaddc4594420e43d0182badfe2b7ee3d7aeb43982c1c366937b1a4567b`
- `space.mp3`: `555ec0f8d7bacc53daf5a424c71b29c2ae19b529b6a918ad150027afe7e8340a`
- `physical.mp3`: `d2ada87d5cc88c7b9b8ae2b63649824e992a069257bd4bdb6adc0c8745754dad`

Candidate labels, rejected ElevenLabs outputs, and audit reports are not bundled.

At runtime, `CareSoundEngine` applies the scene-specific low-pass, high-shelf,
compressor, playback-rate, and intensity shaping directly to these loops. The
door scene uses `space.mp3` with its continuous `outside^1.7` gain envelope;
pre-rendered shaped loops and crowd crossfade variants are no longer bundled.
Physical plays at `1.0x` to retain its authored 54 BPM cadence and remains
silent for headache/migraine.

The `voice-*.mp3` and `hum-*.mp3` cues belong to the separate guided breathing
flow and are loaded directly at runtime. The breathing flow has no looping
background track.
