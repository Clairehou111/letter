# ADR 0001: Local-First Health Storage

Status: accepted

## Context

Letter needs several cycles of sensitive PMS/PMDD records to personalize
predictions, Care plans, and reports. Server-first storage improves recovery and
multi-device access but increases privacy, breach, deletion, and operational
risk.

## Decision

The device is the source of truth for readable health records in P0. The server
stores only operational account information. Cloud LLM use is explicit,
minimized, transient processing rather than health-record storage.

## Consequences

- P0 must provide encrypted export/import and warn about uninstall/device loss.
- Operational analytics cannot include health values or inferred state.
- Automatic cloud sync is not available in P0.
- A future backup must encrypt on the client and store only ciphertext.

