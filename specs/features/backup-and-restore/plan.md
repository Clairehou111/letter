# Backup maintenance plan

Status: native implementation exists.

1. Keep envelope versioning, KDF parameters, and authenticated encryption
   compatible with existing files; migrations need explicit fixture coverage.
2. Reconcile each new local record collection with snapshot, preview, Merge,
   Replace, and atomic commit behavior before release.
3. Verify files and passphrases never enter operational services or telemetry.
4. Complete [validation](validation.md) on a physical release-configured
   device, including share destination and interrupted restore.
