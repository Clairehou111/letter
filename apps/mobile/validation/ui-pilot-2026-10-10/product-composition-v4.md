# Product recording refinement after owner review

Owner screenshot: `Screenshot 2026-10-10 at 20.16.05.png`, reviewed from the supplied local path. Owner requested Medication, Supplement and Birth control optimization after identifying ambiguous additional-use, end-date and archive buttons and an unattractive multi-episode layout. They also requested better use of taste, Finesse UI and GSAP skills, and explicitly authorized rejecting unsuitable proposals instead of adopting them.

## Product truth

- The daily shortcut updates one selected-date source per use period. Its displayed selected status must derive only from `dailyShortcut == true`.
- An additional use is a distinct source with `dailyShortcut: false`. Emergency birth-control recording keeps its existing distinct-event semantics.
- End/change-end modifies the actual end date; existing use records remain. A stopped, unarchived period is still recordable for a historical date inside its actual interval.
- Archive sets `archived: true`, leaves dates unchanged, retains all versions/use records and prevents new use recording. There is no restore API; the UI must not imply one.
- Product details are versioned. Saved uses keep their original `versionId`, exact name/dose/unit/route, date and metadata. Presentation does not merge periods or rewrite history.

## Intended composition

The page serves a brief personal recording task. Keep Build17 canvas, type, accent and native components. Use a compact selected-date context and family-specific Add action; remove public episode jargon. Products appear as flat, concise rows with actual use-period dates, applicable dose/detail preview and truthful selected-date status. Expand one row at a time to expose primary daily recording; the other rows remain compact.

Additional entries belong with the selected-date record details. Their focused sheet names the product/day, shows existing entries, and explicitly saves an additional entry. Product management lives in a labeled, accessible action sheet: Edit details, End use / Change end date, Archive use period. Confirmations state the actual consequence. Other periods and archived history use a separate collapsed disclosure; all original dated version snapshots remain reachable, including guarded per-source deletion.

Create/edit forms prioritize product identity, then actual dates or version-effective date, then optional typed details. Preserve family-specific categories, precise dose input, nullable fields, dirty draft guards and durable Save/error behavior.

Motion has a job: immediate touch response; about 220 ms expansion/chevron continuity to retain the user's place; native focused sheets; truthful selected/saving/error feedback. Reduce Motion reaches the same complete state immediately. Do not animate health numbers or block interaction for choreography.

## Skill applicability

- Local `design-taste-frontend` and `gpt-taste` were inspected. Their landing-page, AIDA, random layout and mandatory JavaScript/GSAP rules are unsuitable for this native recording flow and are not applied. Existing Letter Within identity has priority.
- The user-named [Finesse UI source](https://github.com/mouse-lin/finesse-skill/blob/main/skills/finesse-ui/SKILL.md) and its [phone daily-desk guidance](https://github.com/mouse-lin/finesse-skill/blob/main/skills/finesse-ui/references/h5-mobile.md) were fetched and read as design references. Applicable principles: recording is a personal recurring task rather than an administrative object list; low entry cost, deliberate empty state, thumb-accessible primary actions, progressive disclosure, native sheet furniture and consistent press feedback. Its HTML frame/CSS/status-bar recipes are not copied into Flutter. No new bitmap assets are needed for this scope, and no generation/provider upload was performed.
- Official [GSAP Core](https://github.com/greensock/gsap-skills/blob/main/skills/gsap-core/SKILL.md) and [Timeline](https://github.com/greensock/gsap-skills/blob/main/skills/gsap-timeline/SKILL.md) were inspected for coordinated, interruptible state transitions and reduced motion. GSAP remains a JavaScript implementation reference. Flutter SDK animation/controllers implement the actual interface without a web bridge or new animation dependency.
- Impeccable Operate, Clarify and Craft Floor guide the native consistency and action hierarchy. Its existing session context remains in force; no repeated context launcher or new approval gate is introduced.

No global skill installation is claimed. Owner-approved implementation continues; no separate approval question is needed for these already authorized presentation changes.

## Verification plan

Meaningful manager tests verify daily-source identity versus additional events, archived read-only behavior, actual end-date correction, original-version history, busy/error states and narrow/large-text layout. Run analyzer and full regression after the production revision freezes; compare protected source hashes against the integrated pre-pilot baseline.

The separate V4 native fixture retains V3 primary-form/source checks and adds actual multi-period managers, selected-date status, management sheets, additional-entry drafts and archived snapshots for all three families. Synthetic review device only; cancel previews and compare exact repository collections before/after. Preserve V3 evidence, captured at its own source fingerprint. Inspect the actual V4 states/recording once, correct material blockers in one bounded pass if necessary, then update the resident owner preview without replacing its database.
