# ADR 0001: Local-First Health Storage

Status: accepted; current scope reconciled on 2026-10-03.

## Context

Letter Within needs several cycles of sensitive PMS/PMDD records to personalize
predictions, Care plans, and reports. Server-first storage improves recovery and
multi-device access but increases privacy, breach, deletion, and operational
risk.

## Decision

The device is the source of truth for readable health records. The server
supports operational account and entitlement services only. No AI reads,
rewrites, summarizes, suggests from, or interprets health records, and health
records are never sent to an AI service. Predictions, personal patterns, and
reports are computed deterministically on-device from local data.

## Consequences

- Local encrypted export/import is the recovery path; explain uninstall and
  device-loss consequences.
- Operational analytics cannot include health values or inferred state.
- Automatic cloud health sync is outside the current release contract.
- Any future cloud backup must encrypt on the client and store only ciphertext.
