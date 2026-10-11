# Care scene behavior

Status: current implemented scene contract. [Care and memory](requirements.md)
owns shared behavior; [2.0 Care relief](../release-2.0/care-relief.md) defines
the planned Body and Everyday care extension.

Care opens five text-labeled modes: Release, Heavy, Focus, Space, and Body.
Each is a paced sequence with one primary action per step, a persistent exit,
and a quiet safety route. Motion preference changes presentation, not copy or
available controls. An interruption preserves the named step so the person
can continue, check in, or leave. Only pressing the final step's completion
action can hand a completed action to the optional outcome flow. Merely
viewing a step, backgrounding, using safety, or leaving records no completion.

## Release / feeling overloaded

The five steps are arrive, locate bodily pressure, breathe out at one's own
pace, press and release gently, and land. Stop if pressing hurts; exit remains
available. The scene has no tapping quota, timed Shatter object, message
draft, or 24-hour seal.

## Heavy / low energy

The four steps make the moment smaller, notice where heaviness sits, borrow
support from the surface holding the person, and land softly. There is no
required hold, timer, typing, or sound. The prior dim-light and two-minute
presence sequence is historical and is not a current feature requirement.

## Focus / racing thoughts

The five steps arrive, let thoughts pass, choose one thing, hold it gently,
and land. Choosing can remain entirely in the person's mind; the current
scene does not collect or save thought text, create a task, or set a deadline.

## Space / needing distance

The four steps invite a pause from answering, imagine a soft edge, rest in
that space, and land. The current scene does not close a curtain, create a
boundary card, use the clipboard, read contacts, or send messages.

## Body / physical discomfort

The five steps arrive, find a comfortable position, consider safe warmth and
a slow breath, read the medical boundary, and land. New, unusual, or severe
symptoms have a visible medical route. The scene offers comfort, not a pain
assessment or a claim of treatment effect. The [2.0 Care relief
spec](../release-2.0/care-relief.md) defines further self-paced practices and
companion art; those are release targets until validated in the app.

All primary controls must work with Reduced Motion, screen readers, 200% text,
320 logical pixels, and at least 44-pixel targets. The final optional
Better/Same/Worse check-back remains governed by [Care and
memory](requirements.md).
