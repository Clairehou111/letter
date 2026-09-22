# Privacy-Safe Operational Analytics Plan

Status: validated (typed, consent-gated operational analytics; production
project configuration and release review pending)

1. [x] Define the allowlisted operational event taxonomy and retention policy.
2. [x] Add schema validation that rejects health fields and free-form properties.
3. [x] Implement consent, opt-out, buffering, retry, and deletion behavior.
4. [x] Add synthetic payload tests and inspect crash/analytics integrations.
5. [x] Review the taxonomy against local-first and Care anti-addiction rules.

Production PostHog project configuration and final release review remain
pending. No health records, Care choices, free-form text, or inferred states
are sent by the implemented event boundary.
