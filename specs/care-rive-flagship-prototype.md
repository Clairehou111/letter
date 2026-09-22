# Care Rive Flagship Prototype — After the Storm

Status: prototype only; not connected to production Flutter
Date: 2026-09-04

## Purpose

Validate whether one short interactive scene can help a person who feels
heavy, tearful, empty, or overwhelmed feel accompanied and regain a small
sense of agency. This is not a treatment claim and it is not the crisis route.

Entry: `CareMode.heavy` (`I feel heavy`).

The scene must preserve the existing Care journey, deterministic safety
route, interruption recovery, completion flow, Better/Same/Worse outcome,
and Care Memory. Rive will eventually replace rendering only through
`CareAnimationPort`.

## Emotional arc

```text
HEAVY RAIN
  -> MY SMALLEST TOUCH IS NOTICED
  -> THE WORLD RESPONDS WITHOUT TESTING ME
  -> THE STORM SOFTENS
  -> WARM LIGHT AND A QUIET RAINBOW REMAIN
```

The person may interact, pause, or do nothing. There is no failure, score,
streak, collection count, or requirement to catch enough drops. The scene
must still reach a finite resting state when there is little or no input.

## Visual direction

- Phone portrait artboard: 390 x 844.
- Immersive adult editorial atmosphere, not childish, clinical, gamified, or
  paper-cut/cartoon-like.
- Deep plum, ink blue, charcoal, and desaturated violet at arrival.
- Rain has depth: at least three spatial layers, varied blur/opacity/speed,
  soft reflected light, and organic timing rather than uniform stripes.
- A warm coral/amber light appears where the person first touches.
- As the scene settles, the darkness lifts gradually; it does not flash into
  cheerful daylight.
- The final rainbow is subtle, atmospheric, and earned by the transition. It
  must not look like a reward badge or children's sticker.
- No text, navigation, safety controls, or outcome controls inside the Rive
  asset. Flutter owns those for accessibility and localization.

## Interaction

- A tap or slow drag catches nearby rain into a warm pool or light held near
  the fingertip.
- Contact creates one soft ripple and briefly warms adjacent droplets.
- Additional interaction gently advances clearing, but rapid tapping gives
  no extra reward and never intensifies the scene.
- If the person stops touching, the scene continues breathing and very slowly
  eases on its own.
- Pointer interaction stays in the lower two-thirds so Flutter can reserve a
  persistent top/back area and bottom control shelf.

## Prototype state machine

State machine name: `AfterTheStorm`

States:

1. `arrival` — layered heavy rain, almost-dark environment, dim warm point.
2. `receiving` — touch attracts nearby drops; soft ripples and light respond.
3. `clearing` — rain density and speed fall; background opens; warmth spreads.
4. `rest` — sparse rain, quiet reflected light, subtle rainbow, finite calm.

Preferred inputs:

- `progress` (number, 0–100): app- or interaction-driven scene progress.
- `touching` (boolean): whether gentle contact is active.
- `touchX` and `touchY` (number): normalized pointer position if supported.
- `settle` (trigger): transition to `clearing` without requiring success.
- `reset` (trigger): deterministic prototype restart.
- `reducedMotion` (boolean): replaces moving rain with low-frequency opacity
  changes and tap-to-advance composed states.

Preferred events:

- `sceneReady`
- `firstResponse`
- `restReached`

The editor preview may implement its own listeners. These names are the
desired future Flutter boundary, not permission to change persistence or
navigation contracts.

## Timing

- Visible response to first touch: under 100 ms.
- Arrival can be understood without copy: under 2 seconds.
- First meaningful softening: about 6–12 seconds after interaction.
- Rest state: about 30–60 seconds, and never later than 90 seconds.
- The person can exit at every point; exiting is never presented as failure.

## Prototype acceptance

- The storm feels dimensional and alive on a phone-sized canvas.
- One touch produces an unmistakable but gentle response.
- Doing nothing does not strand or punish the person.
- The transformation reads as emotional release, not weather entertainment.
- The final state is calmer without becoming falsely cheerful.
- Reduced motion preserves the same emotional sequence.
- The prototype contains no production health data and writes no app data.

