# Release Acceptance Gates Validation

Status: in_progress

- [x] Native Android API 37 and iPhone 17 iOS 26.5 simulator evidence covers
      the real `sqlite3mc` encrypted database, encrypted file header,
      plaintext-sentinel absence, wrong-key failure, correct-key reopening,
      and mobile secure-storage fail-closed behavior.
- [x] Native backup acceptance covers wrong-key and tampered packages leaving
      the destination unchanged and valid encrypted backup restoration.
- [x] The same installed app launched twice without reinstall preserves the
      secure key and encrypted data across process restart.
- [x] Real schema 10-to-11 migration preserves period data and cycle-reflection
      `startingPeriodId` on Android API 37 and iPhone 17 iOS 26.5 simulator.
- [ ] Manual Files/share UX is exercised on both platforms.
- [ ] Care usability and adverse-response findings are reviewed by the product
      owner before release.
- [ ] Clinical report review confirms traceability and missingness.
- [ ] Accessibility and store-readiness checks pass on both platforms.
- [ ] Privacy, billing, payment dashboards, and release configuration are
      validated in the live native environments.
- [ ] All unsupported clinical, medication, contact, and cloud-storage claims
      are absent from release copy.

The native checks above are automated acceptance evidence, not a claim that
manual UX, accessibility, clinical, user, store, or payment-dashboard gates
are complete.
