# Privacy-Safe Operational Analytics Validation

Status: validated (typed, consent-gated implementation; production project
configuration and final release review pending)

- [x] An allowlist rejects cycle, symptom, Care, text, report, and inferred-state
  fields.
- [x] No free-form analytics property is accepted.
- [x] Opt-out prevents collection and does not impair local features.
- [x] Retention and deletion behavior are documented and tested.
- [x] Ordinary analytics contains no distress-state or clinical usefulness
  claim.
- [x] Safety studies use a separate consented protocol and data store.

The current repository-wide Flutter suite passes 611 tests, including the
analytics contract tests. This does not validate a configured production
PostHog project or real-user outcomes.
