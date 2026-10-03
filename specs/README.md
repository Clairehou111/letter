# Letter Within specifications

**Target: Release 2.0.** This directory describes the intended 2.0 product,
not a released build. The iPhone 1.0 Build 17 review submission is documented
under `validation/1.0/`. The 2.0 acceptance state is in
[`features/release-2.0/validation.md`](features/release-2.0/validation.md); open gates there
must not be described as complete.

| Question | Source of truth |
| --- | --- |
| Product promise, audience, boundaries | [product.md](product.md) |
| Delivery order and open work | [roadmap.md](roadmap.md) |
| Applications, storage, auth, network | [architecture.md](architecture.md) |
| Navigation, Care, visual and accessibility rules | [experience.md](experience.md) |
| Cycle, record, pattern and clinical evidence | [data-and-reports.md](data-and-reports.md) |
| Free, Plus, pricing and access | [entitlements.md](entitlements.md) |
| Detailed feature behavior and acceptance | [features/](features/) |
| Release 2.0 additions and gates | [features/release-2.0/](features/release-2.0/) |
| Durable architecture decisions | [adr/](adr/) |

This README is a map of the specifications, while the repository
[README](../README.md) covers setup and release status. The root
[PRODUCT.md](../PRODUCT.md) is a product and brand brief; this directory's
[product.md](product.md) is the release contract. Keep
[data-and-reports.md](data-and-reports.md) here because its provenance,
estimate, and reporting rules span multiple feature contracts. The
[architecture decision records](adr/) stay here too: they preserve durable
technical decisions across releases. Detailed editing and acceptance rules
belong under [features/](features/).

The 2026 dated feature plans were reconciled into the current feature
contracts rather than restored unchanged. Git history preserves the originals.
Validation records document what was tested at a particular time and do not
override these current product contracts.
