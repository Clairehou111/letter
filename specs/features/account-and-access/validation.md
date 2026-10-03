# Account and access acceptance

Status: final physical StoreKit, auth-provider, and declaration checks open.

| Case | Required result |
| --- | --- |
| First entry/offline | New user signs in once; returning user can read local history and enter acute Care offline or after session expiry. |
| Deletion | Account and local health deletion are separate, explained, and independently testable; a new account can connect without destroying local history. |
| Purchase | Store catalog/localized prices, pending, purchase, Restore, grace, expiry, and network failure produce accurate access and errors. |
| Preview/lapse | No-card preview never creates files; expiry retains local records and previously generated files; transient refresh error retains confirmed access. |
| Privacy | Default-off analytics, revoke/clear, random ID, exact event payload, no health leakage, live policy and App Store declaration alignment. |
| Accessibility | Paywall, account error, recovery, deletion, and consent controls remain usable with large text and screen reader. |

The 1.0 Build 17 review record in [`validation/1.0/`](../../../validation/1.0/)
does not prove 2.0 StoreKit purchase/Restore or its final privacy declaration.
Use synthetic records and disposable test accounts for release evidence.
