# Letter Brand And Experience System

Status: approved
Date: 2026-07-28

## Brand Thesis

`Letter` is not a decorative name. It is the product's model of time:

- the body produces recurring signals
- a difficult moment may leave an urgent note
- the user decides later what the note means
- a steadier past self can prepare a reply for a future difficult self
- each cycle becomes an owned, editable record

The metaphor creates continuity. It does not explain physiology.

Primary brand promise:

> Your body writes in patterns. Letter helps you through hard moments,
> remembers what helped, and brings your own wisdom back when you need it.

## Three-Layer Design

Letter must preserve three different visual responsibilities.

### Ritual Layer

Used for emotional meaning:

- envelopes
- ink
- margins
- seals
- letter numbers
- opening and closing transitions
- restrained moonlight

### Utility Layer

Used for repeated action:

- period calendar
- cycle date and confidence
- symptom selection
- severity rating
- Care entry
- privacy controls
- editing and deletion

Controls remain familiar, labeled, fast, and accessible. A user must never need
to understand a metaphor to perform a health task.

### Clinical Layer

Used for doctor-facing evidence:

- tables
- timelines
- heatmaps
- scale legends
- missingness
- data provenance
- medication events
- export controls

The clinical layer can carry Letter typography and restrained color, but it
must not hide evidence inside poetic narrative or a simulated object.

## Metaphor Budget

Use one strong metaphor per screen, not one per component.

Good:

- one envelope representing the current cycle
- an ink bloom after a symptom is saved
- one seal representing a deliberate 24-hour cooldown
- a folio cover representing a completed cycle
- a margin note representing a user-authored interpretation

Avoid:

- wooden controls, quill buttons, scroll-shaped forms, wax toggles, or leather
  cards throughout the UI
- forcing gestures such as circling or crossing when a normal tap is more
  accessible
- hiding dates, scores, or buttons in decorative objects
- turning every transition into a slow ceremony

Ritual moments can be slower. Everyday recording must remain fast.

## Visual Direction

The visual language is `contemporary private correspondence`, not antique
Chinese décor, dark academia, or a fantasy occult interface.

### Color Roles

Use a balanced palette:

- `ink`: `#20252A`
- `mist`: `#F3F5F2`
- `paper`: `#FAFAF7`
- `teal`: `#176B67`
- `coral`: `#C85D62`
- `amber`: `#A86A16`
- `clinical blue`: `#3E6F9C`
- `safety red`: `#B42318`
- `night`: `#121517`
- `moon metal`: `#C4A66A`

Paper and moon-metal colors are accents, not a beige or brown theme. Care modes
can change local emphasis while navigation and safety colors remain stable.

### Typography

- `Newsreader` for product name, cycle letters, and short ritual statements
- platform sans-serif for controls, body copy, ratings, and clinical data
- no strict all-lowercase rule
- no negative letter spacing
- no thin text for safety, small labels, or low-contrast screens

### Texture

- subtle bitmap paper grain in ritual surfaces
- no full-screen wood or leather texture as the default app background
- texture opacity remains low enough to preserve text contrast
- clinical exports use a clean solid background

### Shape

- cards and panels use an 8-pixel radius or less
- envelopes and folio covers may use their natural geometry
- avoid rounded text pills when an icon, checkbox, segmented control, or
  standard button is clearer

## Motion And Haptics

Motion roles:

- `instant`: 80-120 ms for tap response
- `responsive`: 160-220 ms for normal navigation
- `ritual`: 400-700 ms for sealing or opening a letter
- `ambient`: slow and optional, never required to understand state

Rules:

- first meaningful feedback occurs after the first gesture
- only the focal object moves during high-energy scenes
- reduce-motion mode replaces spatial movement with opacity and state changes
- sound and haptics are optional and respect system settings
- no flash, strobe, or movement behind headache/migraine Care

## Today: The Current Letter

Today is not a literal desk simulation. It is a modern work surface with one
current-cycle letter as the focal object.

First viewport:

1. direct cycle state: observed period date or estimated cycle day
2. prediction range and confidence
3. current letter state
4. `Record` and `Care` actions
5. one relevant preparation or future-self note

The current letter may look:

- unopened when no event is recorded
- annotated after logging
- sealed when a private draft is cooling down
- ready for reply when the user has chosen a later review

Envelope color can represent product state. It must not present an estimated
cycle phase as certainty.

## Logging: Put It In Writing

Logging remains one tap, text, or voice.

Visual feedback:

- selected symptoms receive an ink mark
- severity produces visibly different marks plus explicit labels
- saved text receives a brief ink-settle animation
- structured extraction appears as an editable margin summary

The metaphor never replaces:

- visible symptom names
- accessible controls
- per-item severity
- edit and delete
- report inclusion controls

## Cycle Rhythm And Moonlight

Moonlight is a brand rhythm, not a biological scale.

Do not hard-map:

- follicular phase to new moon
- ovulation to full moon
- luteal phase to waning moon
- anger to blood moon as a clinical state

Research on menstrual and lunar synchrony is mixed and any observed association
is weak, intermittent, or not clinically meaningful for an individual
prediction. Cycle lengths also vary and do not remain aligned to a 29.5-day
lunar cycle.

Allowed:

- an abstract light disc that grows or recedes over the user's own cycle
- a subtle seal chosen from a moon-inspired set
- optional display of the actual astronomical moon phase, clearly separate
  from menstrual prediction
- brand language about rhythm, return, light, and time

The UI always labels health state directly:

> Estimated luteal phase

not:

> The waning moon is causing your symptoms.

## Care: Urgent Marks, Not Typos

Do not describe rage, depression, or pain as the body's `typos`. A typo suggests
the body made an error, while `hormone tsunami` claims a cause the product may
not know.

Preferred metaphors:

- an urgent line
- a sentence written too loudly
- a heavy underline
- a margin alarm
- a sealed note that deserves later attention

Example:

> Something was written very loudly tonight. You do not have to decide what it
> means yet.

Care-mode names stay experiential and direct. Moon-inspired art may appear
inside a scene, but `blood moon`, `waning moon`, and `dark moon` do not replace
accessible labels such as `I want to explode` or `I feel heavy`.

## Reply Ritual

The Reply Ritual connects a past hard moment with a present steadier moment.

### Trigger

Do not assume every user becomes happy and rational on cycle day 4 or 5.

A reply becomes available when:

- a sealed draft cooldown has ended
- a Care event has not been reviewed
- the user has indicated they feel steadier
- or the user opens `Letters` and chooses to review

Notification:

> A sealed note is ready when you are.

Do not expose note content on the lock screen.

### Opening

The envelope opens only after the user chooses. The first screen asks:

> Do you want to look back, turn it into a note for next time, or leave it
> closed?

Choices:

- `Look back`
- `Write to next time`
- `Keep it closed`
- `Delete unopened`

### Interpretation

Local rules or optional NLP may underline candidate words. Letter asks:

> Some words came up more than once. Do any of them matter to you now?

The user confirms, edits, or ignores every suggestion. The app does not state
that an unfiltered thought was the body's truth.

### Reply

The output can contain:

- a message for next time
- one practical comfort action
- one boundary to prepare
- one topic to revisit outside the acute window
- nothing; closing without a reply is valid

The note can surface in a future similar context only after the user approves
its trigger.

## Letters: The Archive

The archive should feel collectible and private without becoming difficult to
scan on a phone.

### Browse View

Use a vertical folio list rather than a literal 3D wooden shelf:

- `Letter No. 112`
- cycle date range
- observed period dates
- coverage indicator
- one user-approved title or short summary
- clear state: open, sealed, incomplete, or ready for review

Folio materials and cover colors provide visual variety. The list still
supports search, filters, and accessibility.

### Cycle Detail

Each Letter has three views:

1. `Story`
2. `Pattern`
3. `Clinical`

`Story` contains the user-authored narrative and Care memories.

`Pattern` contains cautious trends, action history, and confidence.

`Clinical` contains confirmed ratings, functional impact, medication events,
provenance, and export.

The app may create an optional warm narrative:

> You asked for space twice and used heat on three pain days.

It must not write praise around inferred hormone causality or claim that the app
prevented a resignation unless the user explicitly confirms that outcome.

## Clinical Export

PDF and CSV exports use the clinical layer:

- direct title
- date coverage
- prospective versus recalled data
- confirmed symptom heatmap
- functional impact
- medication and Care action history
- missingness and provenance legend
- optional user-selected notes

Envelope, seal, and Letter number may appear in the header. The evidence remains
plain and clinician-readable.

## Commercial Expression

Brand depth can support trust and willingness to pay, but it does not create
clinical value or validate a premium price by itself.

Subscription value remains:

> period tracking + personal Care + remembered actions and words + trustworthy
> patterns + doctor-ready evidence + local-first privacy

### Physical Letter

Physical products are not P0.

A future physical test should begin with non-ingestible, non-personalized items:

- a printed future-self card
- a reusable envelope or folio
- a general comfort-planning card

Do not begin with app-selected vitamin B6 or another supplement. Supplements
introduce dosage, contraindication, manufacturing, labeling, advertising, and
cross-border regulatory work. In Canada, vitamins and minerals can be regulated
as natural health products with product and site licensing requirements.

Do not describe cycle-timed shipping as anonymous. Fulfillment requires an
address and delivery timing can reveal sensitive health information. Any future
physical subscription requires:

- separate opt-in
- user-selected shipping schedule
- clear fulfillment-provider disclosure
- minimal data sharing
- neutral packaging
- deletion and cancellation behavior
- U.S. and Canadian regulatory and privacy review

The independent-developer roadmap should validate the software loop before
taking on inventory, fulfillment, returns, and product liability.

## Concept Validation

Test three visual directions with North American target users:

1. modern correspondence
2. moon-forward ritual
3. warm clinical

Measure:

- product comprehension
- perceived trust
- perceived medical credibility
- emotional resonance
- ability to find Record and Care
- ability to distinguish prediction from observation
- ability to locate clinical evidence
- willingness to pay after seeing actual product value

Do not select a direction from `premium`, `mystical`, or `Eastern` language
alone.

## Sources

- Menstrual onset and lunar-phase study with no overall association:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC8003924/
- Large 2024 analysis finding a small, uncertain circalunar association:
  https://doi.org/10.1016/j.fertnstert.2023.12.009
- FDA dietary supplement information:
  https://www.fda.gov/food/dietary-supplements
- Health Canada natural health product regulation:
  https://www.canada.ca/en/health-canada/services/drugs-health-products/natural-non-prescription/regulation.html
- FTC Health Breach Notification Rule and health apps:
  https://www.ftc.gov/news-events/news/press-releases/2024/04/ftc-finalizes-changes-health-breach-notification-rule
