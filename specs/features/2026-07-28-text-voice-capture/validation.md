# Text And On-Device Voice Capture Validation

Status: proposed

- Text works when voice permission is denied or unavailable.
- No raw audio is persisted after cancellation.
- Transcript save requires explicit confirmation.
- The app never sends audio, transcript, or note content to the API by
  default.
- Capture does not create a clinical value without user confirmation.
- Permission denial, interruption, partial transcript, and retry states are
  recoverable.
- 320px, reduced motion, screen reader, and large-text paths pass.
