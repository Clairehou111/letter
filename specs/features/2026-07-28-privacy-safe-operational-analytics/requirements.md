# Privacy-Safe Operational Analytics Requirements

Status: proposed
Dependencies: authentication, explicit privacy settings, and product event review

## Goal

Measure product reliability and workflow usability without collecting health
values or distress states as analytics.

## Requirements

REQ-001: Analytics events are limited to non-health operational facts such as
app version, platform, crash-free startup, route load failure, and purchase
flow outcome.

REQ-002: Events must not contain cycle dates, symptom codes, Care mode labels,
Better/Same/Worse outcomes, text, transcripts, drafts, reports, predictions,
or inferred health state.

REQ-003: Analytics is disabled until the user understands and chooses the
applicable privacy setting. The local app remains fully usable when disabled.

REQ-004: Event schemas are allowlisted, versioned, reviewed, and tested for
health-data leakage. Free-form properties are prohibited.

REQ-005: Operational analytics is never used to rank distress, target users
with Care notifications, or optimize session length.

REQ-006: Safety and clinical usefulness metrics are collected only through an
explicit research or usability study protocol, not ordinary analytics.

## Non-Goals

- emotional sentiment tracking
- symptom funnel analysis
- behavioral severity inference
- targeted distress advertising
- health-data server storage
