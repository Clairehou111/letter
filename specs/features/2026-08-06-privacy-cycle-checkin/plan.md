# Implementation plan

1. Add a versioned secure preference store with app lock off and Cycle Check-in on
   by default.
2. Add a root lifecycle privacy shell and a device-authentication adapter.
3. Add a testable notification port and coordinator that derives its date only
   from the existing prediction engine.
4. Recalculate after initial load and all cycle-data mutations while keeping one
   pending notification maximum.
5. Add minimal controls and permission status to Privacy in You.
6. Route notification taps to Cycle only after any configured lock succeeds.
7. Add domain, widget, accessibility, lifecycle, and scheduling tests; then run
   analyzer, the full Flutter suite, and native builds where the environment permits.

