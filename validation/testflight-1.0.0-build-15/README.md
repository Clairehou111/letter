# TestFlight 1.0.0 (15) — release and device validation

## Build and upload

- Source: local `letter-main` `main` commit `4ec9f74`; `pubspec.yaml` is
  `1.0.0+15`. No tracked source changes were present during archive creation.
- Release wrapper: `apps/mobile/tool/build_ios_release.sh --build-number=15`.
  The ignored release config passed nonempty public Supabase, Apple RevenueCat
  `appl_...`, and PostHog `phc_...`/US-host checks. No key values are recorded
  here. Build 14 used an empty PostHog token; Build 15 uses the configured
  project, still behind the default-off analytics control.
- Source preflight before the version-only bump: `flutter analyze --no-pub`
  found no issues; full `flutter test --no-pub` finished with **688 passed,
  1 existing skip, 0 failures**. `git diff --check` passed after the bump.
- Xcode archive and IPA: `1.0.0 (15)`, bundle `app.letterwithin`, iOS deployment
  target 15.0. Archive code signature passed `codesign --verify --deep --strict`.
  IPA: `apps/mobile/build/ios/ipa/Letter Within.ipa`; SHA-256
  `97e4098de80b23008d14c967b979c99889a1feebbc720add3ab71a0a5ff1df6f`.
- Xcode Organizer reported **Letter Within 1.0.0 (15) uploaded**. App Store
  Connect received it at Oct 2, 2026 02:08 local time, then completed
  processing. The TestFlight build is **Ready to Submit** and assigned to the
  existing **Internal Testers** group (2 testers). There are no reported
  installs, sessions, crashes, or feedback yet. This is a TestFlight upload,
  not an App Review submission.

## Physical iPhone run

Status: **not started**. Internal testers had not begun Build 14 testing when
Build 15 was requested. Use synthetic local records and a disposable app
account. Record device model, iOS version, TestFlight build number, tester and
app-account aliases, local time, Pass/Fail/Blocked, and redacted evidence.

Run D01–D12 in
[`physical-iphone-build-14-checklist.md`](../../specs/features/2026-09-25-release-2-0/physical-iphone-build-14-checklist.md),
substituting **Build 15** for Build 14 throughout. Add these Build 15 checks:

1. **B15-01 — Plus catalog on first load.** With a fresh account without Plus,
   open Plus immediately after sign-in, then after relaunch. Confirm monthly,
   annual, and lifetime products and localized Apple prices load. Repeat once
   after a temporary network loss and recovery. If the catalog is missing,
   capture the fixed local `plan_catalog_load` reason and exact action order;
   do not copy raw account or health information into the report.
2. **B15-02 — Purchase and restore.** On a physical iPhone TestFlight install,
   use a sandbox tester for one purchase, confirm Plus unlocks, relaunch, and
   restore. Check a separate fresh unpaid account/tester so an existing Apple
   entitlement does not make the initial-offer test inconclusive.
3. **B15-03 — Optional analytics.** Check analytics is off before consent and
   no PostHog event is sent. Turn it on, trigger a Plus catalog refresh, and
   inspect the `plan_catalog_load` event in the Letter Within project: result
   and fixed reason only, with no account ID, error string, dates, symptoms,
   notes, or Care details. Review SDK-added fields and IP/region handling
   against the published App Store Connect declaration. Turn the control off,
   trigger another refresh, and confirm no new event appears. If the off-state
   cannot be observed reliably, mark it Blocked rather than Pass.
4. **B15-04 — Website and clinical gates.** Before App Review, verify the live
   privacy page reflects optional PostHog analytics and the App Store Connect
   label remains aligned with the actual Build 15 event. SP6/LV3 image,
   wording, pressure guidance, and safety still lack qualified clinical
   sign-off; retain this as an open release gate while the feature remains.

Do not submit Build 15 for App Review based on upload or automated tests alone.
