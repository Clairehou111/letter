# Letter Within Plus: Evidence And Premium Companion Loop

Status: research-backed plan; bounded payment implementation complete; external
store release pending
Date: 2026-08-07
Related decision: `pricing-and-entitlement-strategy.md`

## Decision

Keep the initial annual price hypothesis at `$29.99/year`. Do not lower it
before the product has demonstrated the outcome that Plus is meant to sell.

The premium promise is not “more tracking” and not “access to Care when a user
is suffering.” It is:

> Letter Within remembers what has helped this person, shows a trustworthy pattern
> across cycles, and offers a small, user-controlled preparation for the next
> difficult window.

This is a hypothesis about willingness to pay, not an established fact. The
research supports helpfulness mechanisms more strongly than it supports a
specific price or subscription model.

## What “honest companion” should mean

Letter Within may feel companion-like without pretending to be a person, therapist, or
medical authority. The experience should have five properties:

1. **Recognition:** acknowledge the user's recorded experience without claiming
   to know more than was recorded.
2. **Contingency:** respond to the current state and the user's chosen goal;
   avoid generic wellness copy that could appear at any time.
3. **Memory:** bring back user-authored words, previous choices, and outcomes
   only when relevant and with an easy correction or deletion path.
4. **Autonomy:** offer choices, previews, snooze, skip, and “not for me.” The
   app should never turn self-care into a compliance duty.
5. **Honesty:** distinguish recorded, estimated, and inferred information;
   state uncertainty; never imply diagnosis, hormonal measurement, human
   attention, or guaranteed relief.

The emotional target is not attachment to an artificial person. It is a feeling
of being understood enough to make the next small step easier, while retaining
agency and privacy.

## Evidence synthesis

### PMS and PMDD lived experience

| Evidence | Finding | Limitation | Letter Within implication |
| --- | --- | --- | --- |
| Gledhill et al., 2024, systematic review and thematic synthesis of 17 qualitative studies | Premenstrual disorders were described as life-changing or life-controlling, with burdens of understanding, managing, and repeatedly explaining the experience. | Included studies were small and heterogeneous, with differing diagnostic methods. | Reduce interpretation and explanation burden. Do not make a user act as their own clinician to receive value. [Source](https://doi.org/10.3389/fpsyt.2024.1440690) |
| Osborn et al., 2020, interviews with 17 people with diagnosed PMDD | Participants described identity disruption, not being heard, misdiagnosis, and long delays. Seeing a recurring pattern could be validating and support care-seeking. | UK specialist and self-selected sample; findings do not generalize to all PMS experiences. | Show the user's specific evidence while avoiding diagnosis or a claim that the cycle explains every difficult feeling. [Source](https://doi.org/10.1186/s12905-020-01100-8) |
| Chan et al., 2023, qualitative US study with 32 participants | Participants described dismissal, repeated self-advocacy, poor care continuity, and symptom records being ignored. Diagnosis could validate an experience but did not guarantee useful treatment. | Online PMDD-community recruitment may overrepresent severe experiences and people already seeking answers. | Make clinician summaries editable, concise, and provenance-aware so users do not have to repeatedly reconstruct their history. [Source](https://doi.org/10.1186/s12905-023-02334-y) |
| Hardy & Hardie, 2017, workplace interviews | Difficulty concentrating, self-doubt, sensitivity, fatigue, and social difficulty affected work; guilt and overcompensation could follow after symptoms changed. | Fifteen UK participants; workplace-specific and not a prevalence estimate. | Never frame the clearer phase as a productivity debt or ask the user to compensate for a difficult window. [Source](https://pubmed.ncbi.nlm.nih.gov/28635534/) |
| Park et al., 2023, qualitative occupational study | Symptoms disrupted self-care, productivity, leisure, routine, and relationships; self-awareness supported management. | Four participants, so themes require cautious interpretation. | Help the user reduce demands and choose support; do not introduce streaks or optimization pressure. [Source](https://doi.org/10.1177/03080226231174792) |
| Levy & Romo-Avilés, 2019, qualitative menstrual-app study | Tracking helped people prepare, understand their bodies, verify experiences, and communicate with clinicians; privacy concerns, distress, and tracking effort also caused disengagement. | European sample and general menstrual tracking rather than a Letter Within-like intervention. | Follow `record less, learn more`; incomplete data is ordinary and must never be presented as failure. [Source](https://doi.org/10.1186/s12889-019-7549-8) |

These findings support the user's idea of a helpful and honest companion, with
one refinement: Letter Within should create **trustworthy continuity**, not simulated
intimacy. It can say `you recorded`, `you chose`, and `this helped before`. It
must not say `I know how you feel`, `your hormones made you do this`, or `this
is the real you`.

### Helpfulness and relational quality

| Evidence | Finding | Limitation | Letter Within implication |
| --- | --- | --- | --- |
| van Lotringen et al., 2021, systematic scoping review of 23 studies on text-based digital psychotherapy | Working alliance was generally high (combined mean 5.66/7); most reported alliance-outcome relationships were positive. Text can support reflection and openness. | Mostly therapist-guided ICBT for anxiety/depression; not an automated PMS companion. Alliance was often measured once, and empathy/compassion were under-measured. | Use collaborative goals and tasks, not a fake therapist persona. Measure whether Letter Within feels useful, respectful, and collaborative. [Source](https://www.frontiersin.org/journals/digital-health/articles/10.3389/fdgth.2021.689750/full) |
| Park et al., 2022, narrative review of digital therapeutic alliance in fully automated apps | Automated apps may be experienced as flexible and nonjudgmental; empathy and the “bond” component are difficult and the evidence base is still small. | Narrative review; few fully automated app studies; traditional alliance measures do not map cleanly to apps. | “Always available, private, and nonjudgmental” is credible. “I understand exactly how you feel” is not. [Source](https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2022.819623/full) |
| 2025 systematic review/meta-analysis of communication competence in health conversational agents | Empathy, contingent responses, explanation, and related communication strategies improved evaluations and psychological outcomes with small-to-medium effects. Effects did not reliably extend to agent use or health outcomes. | Mixed health domains and experimental studies; not evidence that a companion increases retention or payment. | Use brief, context-specific acknowledgment and explanation. Treat felt support as an outcome to test, not proof of clinical efficacy. [Source](https://pmc.ncbi.nlm.nih.gov/articles/PMC12582511/) |
| Borghouts et al., 2021, systematic review of 208 DMHI engagement studies | Engagement was helped by perceived utility, personalization, insight, control, social connectedness, and appropriate guidance. Common barriers included technical friction, severity of distress, and lack of personalization; real-world engagement is usually lower than trial engagement. | Heterogeneous interventions and engagement definitions; mostly not menstrual-cycle apps. | The loop must be useful in under a minute, low-effort during PMS, and specific to the person's own records. |

### Personalization, autonomy, and timing

| Evidence | Finding | Limitation | Letter Within implication |
| --- | --- | --- | --- |
| Cheng et al., 2026, TPB-informed systematic review of adult DMHT initiation and early engagement | Perceived fit, practical relevance, ease of use, autonomy, and perceived control shaped initiation. Distress itself can make starting any support effortful and overwhelming. | Focuses on initiation/early engagement, not payment or long-term PMS use; qualitative evidence is heterogeneous. | “Here are three options” is better than a required routine. The first Care action should be immediately available without onboarding or paywall. [Source](https://mental.jmir.org/2026/1/e88731/) |
| Thomas et al., 2024, scoping review of personalization and recommendation in mental-health apps | Personalization is promising but evidence is mixed; useful personalization needs to remain relevant and adapt over time rather than merely insert a name. | Scoping review; varied definitions and outcomes; not a definitive causal estimate. | Personalization should be grounded in recorded symptoms, chosen Care actions, and user feedback—not decorative labels or unsupported predictions. [Source](https://www.tandfonline.com/doi/pdf/10.1080/0144929X.2024.2356630) |
| von Lützow et al., 2025, systematic review/meta-analysis of 23 JITAI/EMI studies (2,563 participants) | JITAI/EMI interventions showed short-term and follow-up improvements in mental-health/well-being outcomes; reported pooled effects included g=0.92 at one month and g=0.45 at 3–6 months in follow-up subsets. | Only nine studies contributed follow-up data; many interventions were CBT-based, and “just-in-time” triggering was inconsistently specified in earlier work. | Use timing sparingly and based on a meaningful cycle window or an explicit user action. Do not turn Letter Within into an always-on notification coach. [Source](https://pubmed.ncbi.nlm.nih.gov/41027677/) |
| D'Cruz et al., 2020, systematic review of uptake and engagement with health/well-being smartphone apps | Tailored notifications produced a small engagement increase in a microrandomized trial; reminders helped some users but annoyed or stigmatized others when mistimed or too revealing. | Notification terms were inconsistently defined; evidence was mixed across behaviors and populations. | Default to the user's Cycle Check-in, neutral lock-screen copy, quiet hours, snooze, and a strict notification budget. “No reminder” must be a successful state. [Source](https://pmc.ncbi.nlm.nih.gov/articles/PMC7293059/) |

### Trust and local-first privacy

| Evidence | Finding | Limitation | Letter Within implication |
| --- | --- | --- | --- |
| Mohan & Jenkins, 2025, qualitative study of 25 menstrual-app users | Participants valued accurate predictions, good interface design, ownership/access to their data, and clearer privacy statements. | Small, self-selected UK sample; qualitative findings do not estimate market size or payment. | Make local storage, export, deletion, and the separation between account data and health records visible before a user records sensitive data. Privacy is a product benefit, not a hidden policy page. [Source](https://pubmed.ncbi.nlm.nih.gov/40463855/) |
| Punzi et al., 2023, privacy/medical scoring of 18 menstrual-cycle apps | Average privacy score was 0.40 and medical score 0.11; 89% had unnecessary permissions in the evaluated sample. | Scoring framework and app sample are time- and region-specific; scores do not measure user outcomes. | “Local-first” can be a concrete trust differentiator if Letter Within minimizes permissions and explains exactly what stays on-device. [Source](https://pubmed.ncbi.nlm.nih.gov/37697855/) |
| 2024 quantitative study of trust and privacy in contact-tracing apps | Trust and perceived privacy were modeled as drivers of adoption, disclosure, and continued use. | Contact tracing is a different, more surveillance-oriented context; not a pricing study. | Trust is a prerequisite for the memory loop: users will not supply the data needed for personalization if data handling is opaque. [Source](https://www.sciencedirect.com/org/science/article/pii/S2291522224000172) |

### Willingness to pay: what is actually known

| Evidence | Finding | Limitation | Decision relevance |
| --- | --- | --- | --- |
| 2024 survey of 577 adults on WTP for health apps | 58.9% said they were willing to pay; median stated WTP was HK$50. Previous maximum payment for a health app predicted higher WTP. Common reasons for not paying were distrust, believing health apps should be publicly provided, and not understanding the benefit. | Hong Kong sample, broad “health apps” category, self-reported hypothetical payment, and not a North American PMS sample. | There is a paying segment, but perceived benefit and trust must precede price. It does not validate `$29.99/year` by itself. [Source](https://pubmed.ncbi.nlm.nih.gov/38698831/) |
| 2022 systematic review/meta-analysis of WTP for eHealth | Across 16 one-time-payment studies, mean WTP for health apps was reported around US$35.86, with substantial heterogeneity. | Studies used different countries, app types, time periods, and elicitation methods; this is not subscription conversion evidence. | A `$79.99` lifetime option is plausible as a test, but the annual price must be justified by continuing value. [Source](https://pmc.ncbi.nlm.nih.gov/articles/PMC9520394/) |
| 2023 discrete-choice experiment on health-app purchase preferences | Usefulness, ease of use, security/privacy, professional attitude, device/data burden, and price were treated as purchase-relevant attributes. | Stated preferences are not completed purchases; general health-app context. | The plan surface must show the outcome, effort, privacy model, and price together. A feature list alone will underperform. [Source](https://pmc.ncbi.nlm.nih.gov/articles/PMC10364011/) |
| 2024 US digital-mental-health technology review | Willingness to pay varied; some users preferred free apps because of financial constraints or uncertainty about effectiveness. | Review summarized varied studies rather than estimating a single market price. | Keep the Free product genuinely useful and show a real Plus preview before charging. [Source](https://mental.jmir.org/2024/1/e57401/) |

## Premium loop plan

The first Plus release should implement one coherent loop rather than many
independent locks.

The implementation-ready requirements, delivery batches, and test matrix live
in `features/2026-08-07-premium-companion-loop/`.

### 1. Notice

Letter Within continues to show free, useful cycle context: bleeding days, estimates,
the current Gravity Horizon, Spectrum Log, and basic records. A user should be
able to understand why Letter Within is different before paying.

### 2. Care now

Every current Care activity remains free and immediately reachable. At the end
of an activity, offer one optional, one-tap reflection:

- Helped
- Helped a little
- Not for me
- Skip

No streak, score, guilt copy, or required journal entry. The user can correct or
delete the response later.

### 3. Remember

After enough data exists—initially two completed cycles with sufficient records,
with three as the stronger threshold—Plus creates a compact personal pattern:

- what tended to appear;
- when it appeared in relation to the cycle;
- which Care options the user tried;
- what the user said helped;
- what remains uncertain or has insufficient data.

Every claim must link to the underlying records. Do not infer a clinical cause
from a correlation, and do not call an inferred pattern a diagnosis.

### 4. Prepare

Before a user-approved difficult window, Letter Within offers a preparation card:

> Your last two late-cycle windows included racing thoughts. You marked
> convergence breathing as “helped a little” and taking space as “helped.”
> Would you like to place either in this window's plan?

The user chooses zero, one, or several options. The plan is editable and can be
ignored without consequence. The default reminder remains the existing Cycle
Check-in, with neutral copy, quiet hours, snooze, and an easy off switch.

### 5. Reflect and repair

After the window, ask only when context makes it useful and allow “not now.”
Letter Within should show whether the prediction felt relevant and whether the plan
helped. If the user says a pattern was wrong, the app should visibly repair the
next summary rather than defend the inference.

This repair behavior is part of honesty. A companion that never admits
uncertainty will lose trust faster than one that occasionally says “we do not
have enough evidence yet.”

## What belongs in Plus

Plus should unlock depth and continuity:

- multi-cycle Personal Patterns and comparisons;
- extended Spectrum Log and Gravity Horizon history;
- Care Memory and user-approved preparation plans;
- future-self notes resurfaced by explicit relevance rules;
- cross-Letter search and themes;
- polished clinician-ready reports and custom ranges.

Free must retain immediate Care, period and symptom logging, basic charts,
privacy controls, local backup/restore, raw export, deletion, and access to
existing local data after lapse. Do not put a paywall in the moment of acute
distress.

## Validation plan before public store release

### Evidence of helpfulness

Test with people who have used Letter Within across at least two cycles. Ask about
specific recent episodes rather than general enthusiasm:

- Did Letter Within help you do something easier during a difficult moment?
- Did the app's memory feel accurate, useful, intrusive, or irrelevant?
- Did you feel more prepared, or did it create another duty?
- Did you feel in control of reminders and choices?
- Did the Care activity change the next few minutes, even if it did not change
  the whole day?

Use brief, non-diagnostic measures of perceived usefulness, fit, autonomy,
trust, burden, and felt support. Treat “helped me get through the moment” as a
meaningful user outcome, but do not call it clinical treatment efficacy.

### Evidence of willingness to pay

Do not infer payment from compliments, downloads, or stated agreement with the
mission. After a user sees a real, data-backed pattern and preparation preview,
measure behavior:

1. opens the Plus explanation;
2. selects annual, monthly, lifetime, or “not now”;
3. reaches the store sheet;
4. completes or abandons checkout;
5. optionally states the reason for not purchasing.

Keep health values out of billing analytics. The key diagnostic question is
whether users fail to pay because Plus is not useful, not trusted, not
understood, or simply too expensive.

### Success signals for the first loop

- Users can accurately explain what Plus remembers and prepares.
- Users voluntarily reuse a previously helpful Care option.
- Users correct inaccurate summaries rather than abandoning the feature.
- Users report more preparation and control without reporting duty or guilt.
- Users return in a later cycle because the loop was useful, not because of a
  streak.
- Qualified users reach the plan surface after the value moment; only then is
  price testing interpretable.

## Explicit non-goals

- No AI therapist or human impersonation.
- No diagnosis, hormone measurement, ovulation claim, or certainty beyond the
  existing estimate logic.
- No daily check-in program.
- No notification campaign designed to maximize opens.
- No paywall on safety, acute Care, personal health-data ownership, or export.
- No lowering of the annual price until qualified users demonstrate the Plus
  value and identify price as the main checkout barrier.

## Bottom line

The research supports Letter Within as potentially helpful when it is specific,
contingent, autonomy-preserving, easy to use under distress, and transparent
about uncertainty. It does not support claiming that a warm tone alone creates
an honest companion, nor that empathy features alone make people pay.

People are most likely to pay when they have experienced a concrete benefit and
trust the app with sensitive data. For Letter Within, that benefit should be a small,
accurate, user-controlled cycle-to-cycle memory: “this is what tends to happen
to me, and this is what I chose that helped last time.”
