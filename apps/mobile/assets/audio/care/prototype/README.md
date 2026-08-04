These five loop files are copied directly from the user's Lovable prototype,
`Clairehou111/scene-mind-soothe`, commit
`125937df9ad205e471a2a404b02a7761eedabaaa`.

Mapping:

- `explode.mp3` → `explode.mp3.asset.json`
- `heavy.mp3` → `heavy.mp3.asset.json`
- `racing.mp3` → `racing.mp3.asset.json`
- `space.mp3` → `away-street-crowd-v2.mp3.asset.json`
- `physical.mp3` → `care.mp3.asset.json`

They are the prototype's post-processed seamless ambience tracks; Letter does
not synthesize or substitute audio for these scenes.

The five `*-shaped.mp3` runtime files apply the prototype's Web Audio output
chain at its default intensity: the per-scene Q=0.3 low-pass, -24 dB high
shelf at 1400 Hz, 26 Hz high-pass, and the prototype limiter settings. The
original files above remain alongside them as source-of-truth. The door's
`space-shaped.mp3` uses its prototype-open 4200 Hz cutoff; Letter applies the
prototype's continuous `outside^1.7` gain envelope as the door closes.
