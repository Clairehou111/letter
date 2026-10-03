# Health-record maintenance plan

Status: implemented foundation; 2.0 integration checks remain.

1. Keep catalog migration and record identity stable while changing capture
   surfaces. Preserve older stored symptom codes and original timestamps.
2. Reconcile Today, Cycle, Care receipt, Patterns, and report consumers against
   confirmed-only provenance and the same-day uniqueness rule.
3. Verify safety-signal interruption and candidate confirmation independently
   of routine symptom saving.
4. Complete the cases in [validation](validation.md) on the release build.
