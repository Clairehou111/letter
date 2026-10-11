# Onboarding and safety routes

Status: current 2.0 feature contract. Earlier cloud-AI and five-tab onboarding
requirements are retired.

OS-01. A new installation presents the product promise, accurate privacy
boundary, and optional goals before the main experience. Progress, Back, and
Continue are clear; goals can be skipped. A completed installation returns to
the app without flashing the wrong screen. Loading or save failure is
recoverable and cannot silently mark onboarding complete.

OS-02. Explain that readable health records are encrypted on this device,
account/purchase services are operationally separate, and no AI interprets
health records. There is no cloud-AI opt-in or health-processing preference.
Legacy onboarding profiles containing a retired `cloud_tools` field still
decode; new saves omit it. Goal identifiers are local, stored securely, and
never sent to analytics or account metadata. A concise “See how privacy
works” explanation returns to the same step without changing preferences.

OS-03. Care's emotional safety route uses deterministic device-region
selection. For the US it shows the [988 Suicide & Crisis Lifeline](https://988lifeline.org/)
for call or text and 911 for immediate danger. For Canada it shows the
[9-8-8 Suicide Crisis Helpline](https://988.ca/) for call or text and 911
for immediate danger. Other or unknown regions get an honest local-emergency
fallback; never guess another country's number. Display the number in text
and make it tappable, so failure to open the dialer does not hide it. A
non-US/CA launch requires reviewed localized content.

OS-04. State plainly that Letter Within cannot provide emergency help.
Safety copy must be short, direct, non-diagnostic, and free of shame, promises,
or an invented recovery timeline. Opening the route stops the ordinary Care
scene; returning or leaving needs no explanation. The same route is available
throughout each emotional Care scene. It does not call on a contact, send a
message, determine risk from text, or log that a route was opened.

OS-05. Physical Care's boundary distinguishes urgent new or severe symptoms
from non-urgent assessment needs without diagnosing, recommending medication,
or claiming the app can assess severity. Fainting, chest pain/palpitations,
sudden severe pain, or heavy bleeding with weakness/dizziness route toward
urgent medical care; new, unusual, changing, severe, or function-limiting
symptoms prompt medical assessment. User-selected palpitations in the health
record picker open this boundary instead of a routine rating.

OS-06. No safety-route use becomes a record, candidate, report item,
analytics event, log, or notification. Region mapping requires no network,
AI, random source, or device permission. Safety and onboarding remain usable
at 320 logical pixels with 200% text, screen readers, Reduced Motion, and
44-pixel targets.
