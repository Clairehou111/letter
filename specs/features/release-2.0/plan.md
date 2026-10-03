# Release 2.0 delivery plan

Status: target release; implementation evidence exists, final release gates
are open. The [requirements](requirements.md) and [Care relief](care-relief.md)
are the behavior contracts. This plan does not mark a gate complete by itself.

1. Reconcile the current app, API, and store configuration against every
   requirement. Fix deviations in focused changes while preserving local
   records and existing Care safety/exit behavior.
2. Complete the native clinical, accessibility, privacy, and commercial checks
   listed in [validation](validation.md). Keep synthetic test data in evidence.
3. Record the tested commit, device/build, exact result, unresolved defect,
   reviewer, and date for each gate in `validation/2.0/`.
4. Update release assets and public copy to match the tested binary and
   privacy declaration. Submit only after all blocking gates pass.

The earlier implementation and simulator evidence was retained in
[`validation/2.0/`](../../../validation/2.0/). It does not substitute for
the remaining physical-device, clinician, or purchase checks.
