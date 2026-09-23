# Letter Within Pricing And Entitlement Strategy

Status: approved product direction; bounded payment implementation complete;
external store release and price validation pending
Date: 2026-08-07
Supersedes the price points and upfront-paywall placement recorded in
`features/2026-07-29-paid-split-and-paywall/`. The safety and data-access
guarantees in that specification remain in force.

The research-backed premium-loop plan, including helpfulness versus willingness
to pay evidence, is documented in
`premium-companion-loop-evidence-and-plan.md`.

## Decision Summary

Letter Within will use a generous free product and one paid tier, `Letter Within Plus`.
The free product helps a person track their cycle and get through a difficult
moment. Plus helps Letter Within remember, compare, and prepare with the person over
time.

Letter Within offers monthly, annual, and one-time purchase options through the
bounded RevenueCat slice. The value-first boundary remains: the first real
free preview precedes the Plus explanation and plan selector.

Historical timing note: the earlier decision deferred billing until after loop
validation. The user's later instruction to finish payment explicitly
superseded that timing decision; it did not erase the earlier rationale or the
remaining external release gates.

Independent development and local-first privacy are trust reasons, not a
donation pitch. Optional tips may exist in About, but `buy us a coffee` is not
the primary commercial framing.

## Product Character

Letter Within is not only a period tracker and not only a mindfulness app. Its
distinctive loop is:

1. See a potentially difficult window coming.
2. Have something gentle and low-effort to do while it is happening.
3. Preserve what happened and what helped.
4. Learn a personal pattern across cycles.
5. Bring useful preparation into the next cycle or evidence into a clinical
   conversation.

The natural retention unit is a cycle, not a daily streak. Letter Within should not
manufacture daily duties to imitate habit apps.

Positioning line:

> A private cycle companion for the days that feel heavier.

Supporting promise:

> Letter Within helps you notice what may be coming, move through difficult moments,
> and understand your personal pattern over time, with your data kept locally.

Avoid `an exit from awful moments` in North American marketing. In an emotional
health context, `an exit` can unintentionally suggest suicide. Prefer `a softer
way through`, `a place to land`, or `something to hold onto while the moment
passes`.

## Commercial Principles

1. Users pay for compounding understanding, preparation, and personalization,
   not for access to their own health data.
2. Acute Care and urgent safety are never paywalled.
3. Privacy, local backup, raw export, correction, and deletion are product
   rights rather than premium benefits.
4. Current-cycle visualizations must demonstrate Letter Within's differentiation for
   free. Plus may add longitudinal comparison and interpretation.
5. A paywall appears after demonstrated value, never during Care, safety,
   logging, backup, or export.
6. Losing Plus pauses new premium computation but does not delete data or hide
   previously generated local material.
7. Store prices and renewal terms are displayed using store-provided metadata.

## Launch Price Architecture

| Plan | Proposed US price | Role |
| --- | ---: | --- |
| Letter Within Free | $0 forever | Complete tracking and immediate Care |
| Letter Within Plus Monthly | $6.99/month | Flexible option |
| Letter Within Plus Annual | $29.99/year | Primary recommended option |
| Letter Within Plus One-time | $79.99 once | Ownership-friendly local-first option |
| Founding One-time | $59.99 once | Optional 60-90 day launch offer |

Do not retain the six-month plan or the `$0.99 first month` structure. They add
choice without clarifying value. The old six-month and annual prices were also
almost identical.

`One-time` should be described precisely:

> Permanent access to the offline Letter Within Plus features included in the
> purchase. Optional future services with recurring external costs, such as
> encrypted cloud backup, may be offered separately. Health records remain
> excluded from AI processing.

Do not launch the paid tier merely because entitlement scaffolding exists.
Before payment is enabled, Plus must contain at least one complete compounding
value loop that a user can understand from real data.

## Free And Plus Boundary

### Free Forever

- unlimited period, bleeding, symptom, mood, energy, pain, and impact records
- record review, correction, and deletion
- cycle estimates and the current Gravity Horizon
- current Spectrum Log and useful basic history
- basic Twin Matrix visibility
- every current acute Care activity and all safety routes
- Cycle Letters remain readable
- privacy cover, app lock, and notification privacy controls
- encrypted local backup, restore, raw export, and local deletion
- access to all local records after cancellation or entitlement uncertainty

### Letter Within Plus

- Personal Patterns across multiple cycles
- longitudinal Gravity Horizon comparisons
- full-history Spectrum Log trends and cautious explanations
- symptom and functional-impact relationships across cycles
- Care Memory: favorites, custom sequences or durations, outcomes, and what
  previously helped
- user-approved preparation for an upcoming difficult window
- future-self notes resurfaced in an appropriate context
- cross-Letter comparison, themes, and search
- polished clinician-ready reports and custom report ranges; raw data export
  remains free
- optional future encrypted multi-device sync if recurring infrastructure is
  introduced
- secondary cosmetic personalization such as additional themes or widgets

The current differentiated charts are not wholly premium. Their advanced
history and interpretation are premium.

## Entitlement Behavior

- Never open a purchase surface inside an acute Care or safety flow.
- Never block recording because entitlement cannot be checked.
- Never include cycle dates, symptoms, notes, inferred state, or other health
  information in billing analytics.
- A lapsed user may read existing local records and generated material.
- Plus controls creating or refreshing advanced analysis, not ownership of
  material already generated on the device.
- Provide Restore Purchases and Manage Subscription from You or Settings.
- The free product is the primary demonstration. A short trial alone cannot
  prove value that compounds across cycles.
- After sufficient history exists, offer one honest Personal Patterns preview
  before asking the user to choose a plan.

## Optional Independent Support

An optional `Support Letter Within` section may offer one-time tips such as `$4.99`,
`$9.99`, and `$19.99`. Tips unlock nothing and should live under About rather
than beside the plan selector.

Preferred trust language:

> Independently built. Sustained by people who find Letter Within useful, not by
> advertising or selling health data.

Do not make `coffee money` the product's value proposition. It can make an
intimate health product feel temporary or hobby-like.

## North American Willingness To Pay

There is demonstrated willingness to pay for Health & Fitness apps in North
America, but it is concentrated rather than universal. RevenueCat's 2026
benchmarks report:

- Health & Fitness has a 2.9% median day-35 download-to-paid conversion, with
  the upper quartile above 6.2%.
- North America has a 2.56% median day-35 download-to-paid conversion across
  categories and an 11.3% 90th percentile.
- Health & Fitness trial-to-paid conversion has a 37.7% median, but that metric
  includes only people who already started a trial.
- Trials lasting 17-32 days convert better at the median than trials of four
  days or less.

Source: https://www.revenuecat.com/state-of-subscription-apps-2026-utilities

This proves that the category can monetize. It does not prove that Letter Within can
yet monetize. Most users still do not pay, and the difference between weak and
strong products is large.

Competitor pricing establishes a credible range:

- Clue Plus: approximately `$9.99/month` or `$39.99/year` in the US App Store.
  https://support.helloclue.com/hc/en-us/articles/115005215266-How-much-does-Clue-Plus-cost
- Stardust: approximately `$6.99/month` or `$29.99/year` in the US App Store.
  https://apps.apple.com/us/app/stardust-period-tracker/id1495829322
- Bearable: `$6.99/month` or `$34.99/year`, with a deliberately generous free
  tracker and premium correlations and longer history.
  https://bearable.app/our-pricing-and-principles/
- Privacy-first independent apps commonly combine subscriptions with a
  one-time option around `$99`, so a Letter Within one-time purchase is consistent
  with local-first expectations.

The number of screens is not the deciding factor. Users are more likely to pay
when Letter Within can demonstrate one of these outcomes:

- `This helped me through a moment when I had little capacity.`
- `This showed a repeatable pattern I had not been able to explain.`
- `This brought back my own words or actions at the right time.`
- `This helped me prepare for a clinician conversation.`

If Plus only unlocks one chart or a longer list, the proposed price is not yet
earned. If the remember-and-prepare loop works across real cycles, Letter Within is
not a simple app from the user's perspective even if its interface remains
simple.

## Validation Before Charging

Do not use compliments or download count as willingness-to-pay evidence.
Validate behavior in this order:

1. Can a new user understand `Track -> Care -> Remember -> Prepare` without an
   explanation from the developer?
2. Do users return in a later cycle without a daily-streak mechanism?
3. After two or three complete cycles, does a real Personal Patterns preview
   feel specific and trustworthy?
4. Show the real plan selector without charging and measure `See plans`, plan
   selection, and checkout intent locally without collecting health values.
5. Enable public purchases only after the Plus loop, external store
   configuration, and native store-state validation are complete. The bounded
   payment code is already implemented.

Initial planning assumptions, not promises:

- 2-3% day-35 download-to-paid is a reasonable category benchmark, not a
  launch forecast.
- A result below 1% should trigger investigation of retention and premium value
  before lowering price.
- Keep `$29.99/year` as the initial annual hypothesis. A simple interface is an
  advantage; shallow paid value is not. Implement and validate the compounding
  Plus loop before testing a lower price.
- Low conversion alone is not evidence that price is the problem. First check
  whether users reached, understood, trusted, and wanted the premium outcome.
- Test a lower `$24.99/year` only when qualified users reach the plans surface,
  show clear purchase intent, abandon at checkout, and identify price as the
  reason. Otherwise improve the loop or its explanation.
- Test `$29.99/year` against `$34.99/year` only after enough qualified users
  reach the value moment. Do not begin by discounting an unproven experience.

## Landing Page And Promotion Consequences

The landing page should explain four ideas in this order:

1. See it coming: cycle timing and Gravity Horizon.
2. Move through it: immediate, low-decision Care.
3. Understand the pattern: Spectrum Log, Letters, and Twin Matrix.
4. Private by design: local-first and independently built.

Recommended pricing message:

> The essentials stay free. Plus supports deeper patterns, personal
> preparation, and independent development.

Do not lead with feature quantity, an AI claim, a donation request, or a hard
paywall. Lead with the difficult moment and the cycle-to-cycle outcome.

## Implementation Snapshot On 2026-08-08

The bounded paid product implementation is complete, but public store release
is not yet production-ready.

- The entitlement domain and capability vocabulary exist.
- The Free product includes one real, data-backed preview; Plus gates continuing
  preparation and pattern continuity while preserving local records.
- `LetterApp` defaults to a local development entitlement repository.
- The RevenueCat adapter implements the approved monthly/yearly/lifetime
  catalog, authenticated UUID binding, localized store pricing, purchase,
  restore, pending, lapsed, offline-unknown, and cancellation behavior.
- The plan sheet includes Restore Purchases and visible unavailable/error states.
- Actual public keys, App Store/Play products, the `letter_plus` entitlement and
  offering, store agreements, sandbox accounts, and native lifecycle validation
  remain pending.

Therefore the remaining monetization work is release preparation and evidence:

1. validate that the Plus loop creates compounding value with real multi-cycle
   data;
2. decide the final price from qualified-user evidence;
3. configure store products, the `letter_plus` entitlement/offering, and public
   RevenueCat keys;
4. complete agreements, sandbox accounts, and native purchase/restore/grace/
   expiry/offline validation before public enablement.

## Research Basis For The Premium Loop

### What makes a digital companion helpful

The strongest interpretation of `helpful and honest companion` is not that
Letter Within should pretend to be a person. It is that Letter Within should reliably do
three humanly meaningful things: recognize the user's state without
overclaiming, collaborate on a small next step, and remember user-approved
learning over time.

This maps closely to the three parts of a working alliance:

- bond: the user feels respected, understood, and safe enough to continue;
- goal: the app and user are oriented toward the same immediate aim;
- task: the next action is clear, acceptable, and chosen by the user.

The following evidence supports that model, with important limits:

| Evidence | Main finding | Limitation and Letter Within implication |
| --- | --- | --- |
| Shoshani et al., *JAMA Network Open* 2026, 3-arm RCT, n=995 | A conversational AI intervention improved anxiety, depression, well-being, and life satisfaction relative to controls; perceived therapeutic alliance was associated with engagement and symptom improvement. [PubMed](https://pubmed.ncbi.nlm.nih.gov/41979879/) | University students in Israel, 12 weeks, unblinded, and the alliance analysis is associative rather than proof that alliance caused the outcome. We can use alliance as a design target, not claim Letter Within is therapy. |
| Schläpfer et al., *Internet Interventions* 2026, secondary RCT analysis, n=117 | In a conversational mindfulness/relaxation app, goal and task agreement had small associations with later distress; bond alone was not significant in the overall sample. [PubMed](https://pubmed.ncbi.nlm.nih.gov/41868778/) | Cancer population and correlational analysis. The practical lesson is that warmth without a useful, chosen action is insufficient. |
| Darcy et al., *JMIR Formative Research* 2021, n=36,070 Woebot users | Users reported early bond scores comparable to published face-to-face CBT and group-CBT comparisons. [Full article](https://formative.jmir.org/2021/5/e27868/) | Retrospective, self-selected users; comparison values came from other studies; most authors were employed by Woebot or had relevant interests. This shows digital bond is possible, not that it is equivalent to therapy. |
| Fitzpatrick et al., *JMIR Mental Health* 2017, RCT, n=70 | Two weeks of a CBT conversational agent reduced depression symptoms more than an information-only control; acceptability depended strongly on interaction process. [Article](https://mental.jmir.org/2017/2/e19/) | Small, young, mostly university sample and short follow-up. Letter Within should borrow the process qualities—low friction, responsive guidance, specific next steps—not market itself as treating depression. |
| Fulmer et al., *JMIR Mental Health* 2018, RCT, n=74 | A personalized conversational AI intervention reduced anxiety and depression symptoms relative to an information control in college students. [Article](https://mental.jmir.org/2018/4/e64/) | Small formative study, retrospective registration, and company conflicts of interest. Personalization is promising but not sufficient evidence of a PMS effect. |
| Brand and user research in the digital alliance literature, including a 2025 qualitative study | Users describe alliance as genuineness, progress toward a personally meaningful goal, meaningful interaction, and the app doing what it claims. [PubMed](https://pubmed.ncbi.nlm.nih.gov/40660205/) | Qualitative, small samples and a paranoia-focused app. Treat `honest` as observable behavior: calibrated language, clear limits, no invented feelings, and no false certainty. |

For PMS specifically, an 8-week randomized study of smartphone mindfulness
training in 80 women with PMS found lower symptom scores and better quality of
life than a no-intervention control. [PubMed](https://pubmed.ncbi.nlm.nih.gov/35782413/)
This supports making Care useful and accessible; it does not establish that
Letter Within's particular animations, charts, or premium memory features are
effective.

### Personalization helps only when its cost is low

Personalization is valuable when it reduces decision effort and makes the
next step feel relevant. It becomes harmful when the user must complete a
questionnaire before receiving help or when the app sounds overconfident.

- A 2025 sequential multiple-assignment study of a very large US mental-health
  website sample found that demographic tailoring reduced disengagement and
  increased clicks, but adding questions to support tailoring itself increased
  disengagement by 14%. [PubMed](https://pubmed.ncbi.nlm.nih.gov/41187311/)
- JITAI design research recommends adapting eligibility, timing, frequency, and
  content using momentary and historical context, while updating from the
  person's response to prior interventions. [PubMed](https://pubmed.ncbi.nlm.nih.gov/30590757/)
- A systematic review of mobile health engagement components found that
  personalized feedback, visualization, reminders, self-monitoring, and goals
  often support engagement, while poor navigation and technical difficulty
  reduce it. [PubMed](https://pubmed.ncbi.nlm.nih.gov/34637651/)

The design rule for Letter Within is therefore `personalize from what the user has
already chosen and recorded`. Do not create a daily intake ritual. Ask for one
small confirmation after Care, and make every inference dismissible and
editable.

### Just-in-time support versus notification burden

Timing matters, but more notifications are not the same as more care:

- A microrandomized trial found that a tailored push notification produced a
  small increase in next-day self-monitoring, but the effect attenuated over
  time. [PubMed](https://pubmed.ncbi.nlm.nih.gov/30497999/)
- Another microrandomized trial found a strong immediate opening effect but no
  improvement in time to disengagement across notification policies. [PubMed](https://pubmed.ncbi.nlm.nih.gov/37294612/)

For Letter Within, the default should remain the previously chosen low-burden Cycle
Check-in and a quiet period-logging reminder. Care preparation should appear
in-app in its relevant Cycle, Letters, or Care context; optional reminders can
be explicitly enabled, scheduled, paused, or dismissed. A premium loop must
not turn suffering into a notification obligation.

### Privacy and trust are part of perceived value

Privacy is not merely a compliance feature for an intimate PMS product. It is
part of the user's willingness to disclose and to trust pattern feedback:

- An empirical review of 61 prominent mental-health apps found that 41% had no
  privacy policy and that apps frequently requested broad device permissions.
  [PubMed](https://pubmed.ncbi.nlm.nih.gov/31122630/)
- A survey of 539 people found that privacy concerns about information being
  accessible to others were negatively associated with digital mental-health
  app use. [PubMed](https://pubmed.ncbi.nlm.nih.gov/38637866/)
- Interviews with DMHI users identified nonresponse, deterioration, and data
  privacy as central safety concerns; users asked for easy access to limits,
  real-time feedback, responsible access management, and genuine crisis
  support. [PubMed](https://pubmed.ncbi.nlm.nih.gov/39919292/)

Local-first gives Letter Within a real trust advantage only if it is legible in the
product: account data stays separate from health records, no health data enters
analytics, local backup/export/delete remain visible, notification previews are
clear, and estimate limits use plain language. Privacy should never be a
premium gate.

### What the evidence says about paying

The evidence for helpfulness is materially stronger than the evidence for
consumer willingness to pay for a PMS companion. Most willingness-to-pay
research uses stated preferences, broad health-app categories, or samples
outside North America.

- A 2024 survey of 577 Hong Kong adults found that 58.9% stated a positive WTP
  for health apps, with a median of HK$50 (about US$6.50). Prior health-app
  installation and prior payment were associated with greater WTP; common
  reasons for paying nothing were distrust, not seeing benefits, and expecting
  free provision. [Full article](https://journals.sagepub.com/doi/10.1177/20552076241248925)
- A US survey of 423 adults found high willingness to try unguided digital
  mental-health interventions for free, but about 65.2% were unwilling when
  asked about a US$13 monthly fee. The authors caution that these are stated
  intentions, not observed purchases. [Full article](https://pmc.ncbi.nlm.nih.gov/articles/PMC11046394/)
- A 2023 discrete-choice experiment with 593 adults found that cost had the
  largest effect on health-app choice, followed by security/privacy and
  usefulness; ease of use and professional support also mattered. [PubMed](https://pubmed.ncbi.nlm.nih.gov/37707310/)
- Current RevenueCat 2026 subscription benchmarks show that monetization is
  real but concentrated: Health & Fitness has a 2.9% median day-35
  download-to-paid rate, North America has a 2.56% median across categories,
  annual plans are common in Health & Fitness, and the common annual price
  anchor is around $30-$40. [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps-2026-utilities)

These findings support $29.99/year as a testable price, not as a guaranteed
market truth. A lower price may reduce friction, but it will not compensate
for a premium feature that feels like a longer log or a decorative chart.
Evidence of actual value should come first.

## Research-Informed Premium Loop Plan

The first Plus release should implement one coherent loop rather than many
isolated locked features:

1. **Notice:** free cycle timing, Gravity Horizon, Spectrum Log, and symptom
   records remain useful on their own.
2. **Care:** the user opens an immediate Care activity. No paywall,
   re-authentication prompt, or required reflection interrupts this moment.
3. **Remember:** after Care, Letter Within offers one optional, low-effort question:
   `Did this help enough to remember?` The user can choose `helped`, `not much`,
   or `not now`, then select `remember this` or `don't save`.
4. **Learn:** after enough comparable records—initially two or three cycles or
   another clearly disclosed threshold—Plus presents one cautious pattern with
   evidence counts, dates/range, and uncertainty. Example: `Racing thoughts
   appeared in 2 of your last 3 late-cycle windows. Taking space was marked
   helpful twice.`
5. **Confirm:** the user can save, edit, dismiss, or correct the pattern. Letter Within
   never turns a correlation into a diagnosis or claims that a phase caused a
   feeling.
6. **Prepare:** before the next estimated difficult window, Letter Within offers a
   personal preparation card containing the user's selected Care options,
   words, and practical preferences. The user chooses whether to use it; no
   streak or compliance language is used.
7. **Return:** during the window, the card opens directly to the chosen Care
   activity. Afterward, the user can update what helped. The next cycle gets
   better because the user taught Letter Within something, not because Letter Within demanded
   more data.

The Plus value moment is step 4 or 6. The paywall should appear only after the
user has seen a real, specific preview from their own data, and it should say
what Plus adds: remembered patterns, preparation, and deeper comparisons. It
should never imply that payment is required to be safe, cared for, or allowed
to access one's records.

### Measures for the first validation build

Measure outcomes, not only engagement:

- immediate Care helpfulness and whether the user felt pressured;
- whether a user accepts, edits, or dismisses a generated pattern;
- whether a preparation card is opened and used in the next window;
- whether the user reports that the next difficult window felt more manageable;
- return in the next cycle without a daily streak;
- after the value preview: plan-page view, annual/lifetime selection, checkout
  start, and stated reason for abandonment.

Do not interpret app opens, notification clicks, or time spent alone as proof
that Letter Within helped. Engagement can be efficient: the Woebot engagement-cluster
study found a subgroup with lower behavioral usage but higher alliance,
greater enactment of skills, and larger symptom declines. [PubMed](https://pubmed.ncbi.nlm.nih.gov/37831490/)

This evidence-informed plan is the basis for the next product/design phase.
It is not a clinical efficacy claim, a diagnosis engine, or a promise that any
particular user will benefit. The implementation-ready requirements and test
matrix are in `features/2026-08-07-premium-companion-loop/`.
