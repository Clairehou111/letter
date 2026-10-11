# Patterns and reports acceptance

Status: final release-configuration and clinician-comprehension checks open.

| Case | Required result |
| --- | --- |
| Pattern evidence | Two-record threshold, source counts, cycle/date coverage, missingness, and edit/delete recomputation. |
| What helped | Better, Same, and Worse remain factual; no causal or treatment wording. |
| Cycle story | Stable period ownership, incomplete current cycle, authored reflection and nested Care notes, no fabricated history. |
| Free/Plus | Recent three-month on-screen factual view free; longer ranges and PDF/CSV files require paid access; preview cannot generate. |
| Report contents | Confirmed-only values and selected notes; separate observed/predicted dates; provenance and missingness visible; excluded content absent. |
| File behavior | Exact selected range, complete preview, local save path, explicit share, file retained after entitlement lapse, recoverable failure. |
| Clinical reading | A reviewer can understand source, uncertainty, missingness, and limits; no DRSP or diagnosis claim. |

Use synthetic multi-cycle fixtures and compare generated PDF/CSV output with
the underlying local rows. Dated output and reviewer evidence belongs under
[`validation/2.0/`](../../../validation/2.0/).
