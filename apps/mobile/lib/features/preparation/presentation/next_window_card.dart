import 'package:flutter/material.dart';

import '../../../design_system/lovable/health_record_kit.dart';
import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/lovable/letter_theme.dart';
import '../../care/domain/care_mode.dart';
import '../../cycle/domain/cycle_prediction.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/preparation_loop_state.dart';
import '../domain/preparation_plan.dart';
import '../domain/preparation_snapshot.dart';

/// Lovable's compact Today entry, adapted only to consume production evidence.
class NextWindowCard extends StatelessWidget {
  const NextWindowCard({
    required this.snapshot,
    required this.onOpenDetails,
    super.key,
  });

  final PreparationSnapshot snapshot;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final observation = snapshot.observation;
    final careLine = _careCardLine(snapshot.care);
    final observationLine = observation == null
        ? null
        : 'You recorded ${observation.symptom.label.toLowerCase()} in '
              '${observation.distinctCompletedCycles} of '
              '${observation.totalCompletedCycles} completed cycles.';
    final headline = observationLine ?? careLine;
    assert(headline != null);

    return Padding(
      padding: const EdgeInsets.only(top: LetterTokens.s28),
      child: Semantics(
        button: true,
        label: 'Your next window, ${headline!}, opens details',
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('next-window-card'),
            onTap: onOpenDetails,
            borderRadius: LetterTokens.brSurface,
            child: LetterCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR NEXT WINDOW · PLUS', style: letterEyebrow()),
                  const SizedBox(height: LetterTokens.s8),
                  Text(
                    headline,
                    key: const Key('next-window-headline'),
                    style: letterSerif(size: context.isLovableNarrow ? 20 : 22),
                  ),
                  const SizedBox(height: LetterTokens.s8),
                  Text(
                    'For the estimated support window ahead.',
                    key: const Key('next-window-timing-context'),
                    style: letterHelper(size: 13),
                  ),
                  if (observationLine != null && careLine != null) ...[
                    const SizedBox(height: LetterTokens.s8),
                    Text(
                      careLine,
                      key: const Key('next-window-care'),
                      style: letterHelper(size: 13),
                    ),
                  ],
                  const SizedBox(height: LetterTokens.s16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Details',
                        style: letterBody(size: 14, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: LetterTokens.s4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: LetterTokens.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A confirmed memory returned in context. It never creates a new outcome
/// path; opening Care still ends in the existing Better/Same/Worse flow.
class PreparationReturnCard extends StatelessWidget {
  const PreparationReturnCard({
    required this.plan,
    required this.onOpenCare,
    required this.onNotNow,
    super.key,
  });

  final PreparationPlan plan;
  final ValueChanged<CareMode> onOpenCare;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) => LetterCard(
    key: const Key('prep_return_card'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOU SAVED THIS FOR NOW', style: letterEyebrow()),
        if (plan.personalText case final text?) ...[
          const SizedBox(height: LetterTokens.s8),
          Text(
            '“$text”',
            key: const Key('prep_return_personal_text'),
            style: letterSerif(size: 17),
          ),
        ],
        if (plan.includeCare) ...[
          const SizedBox(height: LetterTokens.s8),
          Text(
            _savedCareLine(plan),
            style: letterBody(size: 15, weight: FontWeight.w600),
          ),
        ],
        if (plan.noteText case final note?) ...[
          const SizedBox(height: LetterTokens.s8),
          Text('“$note”', style: letterSerif(size: 17)),
        ],
        const SizedBox(height: LetterTokens.s16),
        if (plan.includeCare) ...[
          PrimaryButton(
            key: const Key('prep_return_open_care'),
            label: 'Open Care: ${plan.careMode.label}',
            onPressed: () => onOpenCare(plan.careMode),
            expand: true,
          ),
          const SizedBox(height: LetterTokens.s8),
        ],
        QuietButton(
          key: const Key('prep_return_not_now'),
          label: 'Not now',
          onPressed: onNotNow,
          expand: true,
        ),
        const SizedBox(height: LetterTokens.s8),
        Text(
          'Letter Within did not send you this. You saved it.',
          style: letterHelper(size: 12),
        ),
      ],
    ),
  );
}

class YourNextWindowScreen extends StatefulWidget {
  const YourNextWindowScreen({
    required this.snapshot,
    required this.onReviewRecords,
    required this.onOpenCare,
    this.loopState,
    this.repository,
    this.loopLoadFailed = false,
    super.key,
  });

  final PreparationSnapshot snapshot;
  final VoidCallback onReviewRecords;
  final ValueChanged<CareMode> onOpenCare;
  final PreparationLoopState? loopState;
  final PreparationRepository? repository;
  final bool loopLoadFailed;

  @override
  State<YourNextWindowScreen> createState() => _YourNextWindowScreenState();
}

class _YourNextWindowScreenState extends State<YourNextWindowScreen> {
  bool _timingExpanded = true;
  bool _observationExpanded = true;
  bool _careExpanded = true;
  bool _noteExpanded = true;
  late PreparationLoopState? _loopState;
  bool _proposalHiddenForVisit = false;
  bool _restoredNotice = false;
  late bool _loopLoadFailed;
  bool _loopLoading = false;

  @override
  void initState() {
    super.initState();
    _loopState = widget.loopState;
    _loopLoadFailed = widget.loopLoadFailed;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final care = snapshot.care;
    final note = snapshot.futureNote;

    return Scaffold(
      backgroundColor: LetterTokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const _PageTopBar(
              eyebrow: 'Today',
              title: 'Your next window',
              backLabel: 'Back to Today',
            ),
            Expanded(
              child: ListView(
                key: const Key('next-window-details'),
                padding: const EdgeInsets.only(bottom: LetterTokens.s28),
                children: [
                  _section(
                    child: _CollapsibleCard(
                      eyebrow: 'Estimated next period',
                      title: _range(
                        context,
                        snapshot.timing.periodRangeStart,
                        snapshot.timing.periodRangeEnd,
                      ),
                      expanded: _timingExpanded,
                      onToggle: () =>
                          setState(() => _timingExpanded = !_timingExpanded),
                      summaryLines: [
                        _confidenceLabel(snapshot.timing.confidence),
                        _precisionLine(snapshot.timing),
                      ],
                      trailing: const ProvenanceTag(observed: false),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WindowRangeBar(timing: snapshot.timing),
                          const SizedBox(height: LetterTokens.s12),
                          Text(
                            _confidenceLabel(snapshot.timing.confidence),
                            key: const Key('next-window-detail-confidence'),
                            style: letterBody(size: 14),
                          ),
                          const SizedBox(height: LetterTokens.s4),
                          Text(
                            _precisionLine(snapshot.timing),
                            style: letterHelper(size: 12.5),
                          ),
                          const SizedBox(height: LetterTokens.s8),
                          Text(
                            'Letter Within is showing this preparation before your '
                            'estimated next period. The date range comes from your '
                            'recorded starts; it does not predict how you will feel.',
                            style: letterHelper(size: 12.5),
                          ),
                          if (snapshot.timing.hasWideVariation) ...[
                            const SizedBox(height: LetterTokens.s8),
                            Text(
                              'A range this wide is a rough guide only. Recording '
                              'your next period start will update this estimate.',
                              style: letterHelper(size: 12.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.observation case final observation?)
                    _section(
                      top: LetterTokens.s16,
                      child: _CollapsibleCard(
                        eyebrow: 'What you recorded before',
                        title:
                            'You recorded ${observation.symptom.label.toLowerCase()} in '
                            '${observation.distinctCompletedCycles} of '
                            '${observation.totalCompletedCycles} completed cycles.',
                        expanded: _observationExpanded,
                        onToggle: () => setState(
                          () => _observationExpanded = !_observationExpanded,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _strengthLine(observation),
                              key: const Key('next-window-strength'),
                              style: letterBody(size: 14),
                            ),
                            const SizedBox(height: LetterTokens.s8),
                            Text(
                              _recordsLine(context, observation),
                              key: const Key('next-window-detail-observation'),
                              style: letterBody(size: 14),
                            ),
                            const SizedBox(height: LetterTokens.s8),
                            Text(
                              'A cycle without a matching record is missing evidence, '
                              'not proof that nothing happened.',
                              style: letterHelper(size: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (care != null)
                    _section(
                      top: LetterTokens.s16,
                      child: _CollapsibleCard(
                        eyebrow: 'What you have reached for before',
                        title: care.actionLabel,
                        expanded: _careExpanded,
                        onToggle: () =>
                            setState(() => _careExpanded = !_careExpanded),
                        summaryLines: [_careMetaLine(context, care)],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${care.actionLabel} · Better ${care.betterCount} · '
                              'Same ${care.sameCount} · Worse ${care.worseCount}',
                              key: const Key('next-window-detail-care'),
                              style: letterBody(size: 14),
                            ),
                            const SizedBox(height: LetterTokens.s4),
                            Text(
                              _careMetaLine(context, care),
                              style: letterHelper(size: 12.5),
                            ),
                            const SizedBox(height: LetterTokens.s8),
                            Text(
                              'This is your Care history, kept separately. Letter Within '
                              'does not link it to any symptom.',
                              style: letterHelper(size: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (care != null && note != null && note.mode == care.mode)
                    _section(
                      top: LetterTokens.s16,
                      child: _CollapsibleCard(
                        eyebrow: 'Your note to yourself',
                        title: 'You left yourself a note',
                        expanded: _noteExpanded,
                        onToggle: () =>
                            setState(() => _noteExpanded = !_noteExpanded),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.only(
                                left: LetterTokens.s12,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: LetterTokens.teal,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                '“${note.text}”',
                                key: const Key('next-window-note'),
                                style: letterSerif(size: 17),
                              ),
                            ),
                            const SizedBox(height: LetterTokens.s8),
                            Text(
                              'You wrote this. Letter Within shows it back unchanged.',
                              style: letterHelper(size: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_loopLoading)
                    _section(
                      top: LetterTokens.s16,
                      child: const LetterCard(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LetterTokens.teal,
                              ),
                            ),
                            SizedBox(width: LetterTokens.s12),
                            Expanded(
                              child: Text(
                                'Reading your saved preparation from this device.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_loopLoadFailed)
                    _section(
                      top: LetterTokens.s16,
                      child: LetterCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your preparation could not be read',
                              style: letterSerif(size: 19),
                            ),
                            const SizedBox(height: LetterTokens.s8),
                            Text(
                              'Nothing is lost. Your records and anything you saved are still on this device.',
                              style: letterHelper(size: 12.5),
                            ),
                            const SizedBox(height: LetterTokens.s12),
                            QuietButton(
                              label: 'Try again',
                              onPressed: _retryLoop,
                              expand: true,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_loopState case final loop?)
                    _section(
                      top: LetterTokens.s16,
                      child: _PreparationBlock(
                        state: loop,
                        hiddenForVisit: _proposalHiddenForVisit,
                        restoredNotice: _restoredNotice,
                        onRemember: care == null ? null : _openSavePreparation,
                        onEdit: _openEditPreparation,
                        onNotNow: () =>
                            setState(() => _proposalHiddenForVisit = true),
                        onDismiss: _dismissProposal,
                        onUndoDismiss: _undoDismiss,
                        onReview: widget.onReviewRecords,
                        onKeepReference: _keepAsReference,
                        onWithdraw: _withdrawPreparation,
                      ),
                    ),
                  if (_loopState case final loop?
                      when loop.dismissals.isNotEmpty &&
                          loop.kind != PreparationLoopKind.dismissed)
                    _section(
                      top: LetterTokens.s8,
                      child: QuietButton(
                        key: const Key('prep_restore_entry'),
                        label: 'Restore a dismissed suggestion',
                        onPressed: _openRestoreList,
                        expand: true,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      LetterTokens.gutter,
                      LetterTokens.s28,
                      LetterTokens.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (care != null) ...[
                          PrimaryButton(
                            key: const Key('next-window-open-care'),
                            label: 'Open Care: ${care.mode.label}',
                            onPressed: () => widget.onOpenCare(care.mode),
                            expand: true,
                          ),
                          const SizedBox(height: LetterTokens.s12),
                        ],
                        QuietButton(
                          key: const Key('next-window-review-records'),
                          label: 'Review these records',
                          onPressed: widget.onReviewRecords,
                          expand: true,
                        ),
                        const SizedBox(height: LetterTokens.s12),
                        Text(
                          'Read only. Nothing here changes your records.',
                          style: letterHelper(size: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSavePreparation() async {
    final repository = widget.repository;
    final loop = _loopState;
    if (repository == null || loop == null || loop.snapshot.care == null) {
      return;
    }
    final plan = await Navigator.of(context).push<PreparationPlan>(
      MaterialPageRoute(
        builder: (context) => _SavePreparationScreen(
          snapshot: loop.snapshot,
          repository: repository,
        ),
      ),
    );
    if (!mounted || plan == null) return;
    setState(() {
      _loopState = _withLoop(loop, kind: PreparationLoopKind.saved, plan: plan);
      _proposalHiddenForVisit = false;
    });
  }

  Future<void> _retryLoop() async {
    final repository = widget.repository;
    if (repository == null) return;
    setState(() => _loopLoading = true);
    try {
      final state = await PreparationLoopState.load(
        snapshot: widget.snapshot,
        repository: repository,
        currentSourceIds: PreparationFingerprint.sourceIds(
          widget.snapshot,
        ).toSet(),
      );
      if (!mounted) return;
      setState(() {
        _loopState = state;
        _loopLoadFailed = false;
        _loopLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loopLoadFailed = true;
        _loopLoading = false;
      });
    }
  }

  Future<void> _openEditPreparation() async {
    final repository = widget.repository;
    final loop = _loopState;
    final plan = loop?.plan;
    if (repository == null || loop == null || plan == null) return;
    var withdrawn = false;
    final updated = await Navigator.of(context).push<PreparationPlan?>(
      MaterialPageRoute(
        builder: (context) => _SavePreparationScreen(
          snapshot: loop.snapshot,
          repository: repository,
          initialPlan: plan,
          onWithdrawn: () => withdrawn = true,
        ),
      ),
    );
    if (!mounted) return;
    if (withdrawn) {
      setState(() {
        _loopState = _withLoop(
          loop,
          kind: PreparationLoopKind.proposed,
          clearPlan: true,
        );
        _proposalHiddenForVisit = false;
      });
      return;
    }
    if (updated == null) return;
    setState(() {
      _loopState = _withLoop(
        loop,
        kind: PreparationLoopKind.saved,
        plan: updated,
      );
    });
  }

  Future<void> _dismissProposal() async {
    final repository = widget.repository;
    final loop = _loopState;
    if (repository == null || loop == null) return;
    final dismissal = PreparationDismissal(
      fingerprint: loop.proposalFingerprint,
      evidenceLine: _proposalEvidenceLine(loop.snapshot),
      dismissedAt: DateTime.now().toUtc(),
    );
    await repository.dismiss(dismissal);
    if (!mounted) return;
    setState(() {
      _loopState = _withLoop(
        loop,
        kind: PreparationLoopKind.dismissed,
        dismissals: [...loop.dismissals, dismissal],
      );
      _restoredNotice = false;
    });
  }

  Future<void> _undoDismiss() async {
    final repository = widget.repository;
    final loop = _loopState;
    if (repository == null || loop == null) return;
    await repository.restoreDismissal(loop.proposalFingerprint);
    if (!mounted) return;
    setState(() {
      _loopState = _withLoop(
        loop,
        kind: PreparationLoopKind.proposed,
        dismissals: loop.dismissals
            .where((item) => item.fingerprint != loop.proposalFingerprint)
            .toList(growable: false),
      );
      _restoredNotice = true;
    });
  }

  Future<void> _keepAsReference() async {
    final repository = widget.repository;
    final loop = _loopState;
    final plan = loop?.plan;
    if (repository == null || loop == null || plan == null) return;
    final updated = plan.copyWith(
      status: PreparationPlanStatus.privateReference,
      updatedAt: DateTime.now().toUtc(),
    );
    await repository.savePlan(updated);
    if (!mounted) return;
    setState(() {
      _loopState = _withLoop(
        loop,
        kind: PreparationLoopKind.privateReference,
        plan: updated,
      );
    });
  }

  Future<void> _withdrawPreparation() async {
    final repository = widget.repository;
    final loop = _loopState;
    if (repository == null || loop == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw this preparation?'),
        content: const Text(
          'The records it came from stay exactly as they are. Only this saved '
          'preparation is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.removeActivePlan();
    if (!mounted) return;
    setState(() {
      _loopState = _withLoop(
        loop,
        kind: PreparationLoopKind.proposed,
        clearPlan: true,
      );
      _proposalHiddenForVisit = false;
    });
  }

  Future<void> _openRestoreList() async {
    final repository = widget.repository;
    final loop = _loopState;
    if (repository == null || loop == null) return;
    final restored = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (context) => RestoreDismissedPreparationScreen(
          repository: repository,
          dismissals: loop.dismissals,
        ),
      ),
    );
    if (!mounted || restored == null || restored.isEmpty) return;
    final restoredCurrent = restored.contains(loop.proposalFingerprint);
    setState(() {
      _loopState = _withLoop(
        loop,
        kind: restoredCurrent ? PreparationLoopKind.proposed : loop.kind,
        dismissals: loop.dismissals
            .where((item) => !restored.contains(item.fingerprint))
            .toList(growable: false),
      );
      _restoredNotice = restoredCurrent;
    });
  }

  Widget _section({required Widget child, double top = LetterTokens.s20}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(
          LetterTokens.gutter,
          top,
          LetterTokens.gutter,
          0,
        ),
        child: child,
      );
}

class _PreparationBlock extends StatelessWidget {
  const _PreparationBlock({
    required this.state,
    required this.hiddenForVisit,
    required this.restoredNotice,
    required this.onRemember,
    required this.onEdit,
    required this.onNotNow,
    required this.onDismiss,
    required this.onUndoDismiss,
    required this.onReview,
    required this.onKeepReference,
    required this.onWithdraw,
  });

  final PreparationLoopState state;
  final bool hiddenForVisit;
  final bool restoredNotice;
  final VoidCallback? onRemember;
  final VoidCallback onEdit;
  final VoidCallback onNotNow;
  final VoidCallback onDismiss;
  final VoidCallback onUndoDismiss;
  final VoidCallback onReview;
  final VoidCallback onKeepReference;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    if (hiddenForVisit && state.kind == PreparationLoopKind.proposed) {
      return const SizedBox.shrink();
    }
    if (state.kind == PreparationLoopKind.dismissed) {
      return LetterCard(
        key: const Key('prep_block'),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This suggestion is hidden.', style: letterBody(size: 15)),
              const SizedBox(height: LetterTokens.s8),
              Text(
                'Only this suggestion is hidden. Your records are unchanged.',
                style: letterHelper(size: 12.5),
              ),
              const SizedBox(height: LetterTokens.s12),
              QuietButton(
                key: const Key('prep_undo'),
                label: 'Undo',
                onPressed: onUndoDismiss,
                expand: true,
              ),
            ],
          ),
        ),
      );
    }

    final plan = state.plan;
    final proposed = state.kind == PreparationLoopKind.proposed;
    final title = switch (state.kind) {
      PreparationLoopKind.proposed => 'Remember this for next time?',
      PreparationLoopKind.saved => 'Saved for next time',
      PreparationLoopKind.privateReference => 'Kept as a private reference',
      PreparationLoopKind.stale =>
        'This preparation is based on records that changed.',
      PreparationLoopKind.withdrawn =>
        'The records behind this preparation are no longer there.',
      PreparationLoopKind.dismissed => '',
    };
    final eyebrow = switch (state.kind) {
      PreparationLoopKind.proposed => 'PREPARATION',
      PreparationLoopKind.privateReference ||
      PreparationLoopKind.withdrawn => 'NO LONGER CURRENT',
      _ => 'SAVED FOR NEXT TIME',
    };

    return LetterCard(
      key: const Key('prep_block'),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow, style: letterEyebrow()),
            const SizedBox(height: LetterTokens.s4),
            Text(title, style: letterSerif(size: 19)),
            const SizedBox(height: LetterTokens.s8),
            if (restoredNotice && proposed) ...[
              Text(
                'Restored. Nothing was saved while it was hidden.',
                style: letterHelper(size: 12.5),
              ),
              const SizedBox(height: LetterTokens.s8),
            ],
            if (proposed) ...[
              Text(
                _proposalEvidenceLine(state.snapshot),
                style: letterBody(size: 14),
              ),
              const SizedBox(height: LetterTokens.s8),
              Text(
                state.snapshot.care == null
                    ? 'There is no Care memory attached to this yet, so there '
                          'is nothing to save.'
                    : 'Nothing is saved until you confirm it.',
                style: letterHelper(size: 12.5),
              ),
            ] else if (plan != null) ...[
              _SavedPreparationSummary(plan: plan),
              const SizedBox(height: LetterTokens.s8),
              Text(switch (state.kind) {
                PreparationLoopKind.saved =>
                  'Saved ${MaterialLocalizations.of(context).formatMediumDate(plan.createdAt.toLocal())}.',
                PreparationLoopKind.stale =>
                  'Letter Within has not changed what you saved.',
                PreparationLoopKind.withdrawn =>
                  'It is kept here so you can still read it. It is not shown anywhere else.',
                PreparationLoopKind.privateReference =>
                  'This is readable here, but is not presented as current.',
                _ => '',
              }, style: letterHelper(size: 12.5)),
              if (state.kind == PreparationLoopKind.saved) ...[
                const SizedBox(height: LetterTokens.s4),
                Text(
                  'Saving this does not send you anything. Nothing here is a reminder or a promise.',
                  style: letterHelper(size: 12.5),
                ),
              ],
            ],
            const SizedBox(height: LetterTokens.s16),
            if (proposed && onRemember != null) ...[
              PrimaryButton(
                key: const Key('prep_primary'),
                label: 'Remember for next time',
                onPressed: onRemember,
                expand: true,
              ),
              const SizedBox(height: LetterTokens.s8),
              QuietButton(
                key: const Key('prep_not_now'),
                label: 'Not now',
                onPressed: onNotNow,
                expand: true,
              ),
              const SizedBox(height: LetterTokens.s8),
            ],
            if (proposed) ...[
              QuietButton(
                key: const Key('prep_not_for_me'),
                label: 'Not for me',
                onPressed: onDismiss,
                expand: true,
              ),
            ] else if (state.kind == PreparationLoopKind.saved) ...[
              QuietButton(
                key: const Key('prep_edit_open'),
                label: 'Edit preparation',
                onPressed: onEdit,
                expand: true,
              ),
              const SizedBox(height: LetterTokens.s8),
              QuietButton(
                key: const Key('prep_withdraw'),
                label: 'Withdraw preparation',
                onPressed: onWithdraw,
                expand: true,
              ),
            ] else if (state.kind == PreparationLoopKind.stale) ...[
              PrimaryButton(
                key: const Key('prep_stale_review'),
                label: 'Review updated evidence',
                onPressed: onReview,
                expand: true,
              ),
              const SizedBox(height: LetterTokens.s8),
              QuietButton(
                key: const Key('prep_stale_keep'),
                label: 'Keep as a private reference',
                onPressed: onKeepReference,
                expand: true,
              ),
              const SizedBox(height: LetterTokens.s8),
              QuietButton(
                key: const Key('prep_withdraw'),
                label: 'Withdraw preparation',
                onPressed: onWithdraw,
                expand: true,
              ),
            ] else ...[
              QuietButton(
                key: const Key('prep_withdraw'),
                label: state.kind == PreparationLoopKind.withdrawn
                    ? 'Remove this text'
                    : 'Remove preparation',
                onPressed: onWithdraw,
                expand: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedPreparationSummary extends StatelessWidget {
  const _SavedPreparationSummary({required this.plan});

  final PreparationPlan plan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (plan.personalText case final text?) ...[
        Container(
          key: const Key('prep_saved_personal_text'),
          padding: const EdgeInsets.only(left: LetterTokens.s12),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: LetterTokens.teal, width: 2),
            ),
          ),
          child: Text('“$text”', style: letterSerif(size: 17)),
        ),
        if (plan.includeCare || plan.noteText != null)
          const SizedBox(height: LetterTokens.s12),
      ],
      if (plan.includeCare)
        Text(
          'Return with Care: ${plan.careMode.label}',
          key: const Key('prep_saved_care'),
          style: letterBody(size: 14),
        ),
      if (plan.noteText != null) ...[
        if (plan.includeCare) const SizedBox(height: LetterTokens.s4),
        Text('Your earlier note is included.', style: letterHelper(size: 12.5)),
      ],
    ],
  );
}

class _SavePreparationScreen extends StatefulWidget {
  const _SavePreparationScreen({
    required this.snapshot,
    required this.repository,
    this.initialPlan,
    this.onWithdrawn,
  });

  final PreparationSnapshot snapshot;
  final PreparationRepository repository;
  final PreparationPlan? initialPlan;
  final VoidCallback? onWithdrawn;

  @override
  State<_SavePreparationScreen> createState() => _SavePreparationScreenState();
}

class _SavePreparationScreenState extends State<_SavePreparationScreen> {
  late bool _includeCare;
  late bool _includeNote;
  late final TextEditingController _personalTextController;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _includeCare = widget.initialPlan?.includeCare ?? true;
    _includeNote =
        widget.initialPlan?.noteText != null ||
        (widget.initialPlan == null && widget.snapshot.futureNote != null);
    _personalTextController = TextEditingController(
      text: widget.initialPlan?.personalText ?? '',
    );
  }

  @override
  void dispose() {
    _personalTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final care = widget.snapshot.care!;
    final note = widget.snapshot.futureNote;
    final editing = widget.initialPlan != null;
    final canSave =
        _includeCare ||
        _includeNote ||
        _personalTextController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: LetterTokens.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _PageTopBar(
              title: editing ? 'Edit preparation' : 'Save this preparation',
              backLabel: 'Close',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(LetterTokens.gutter),
                children: [
                  Text(
                    editing
                        ? 'Change your own preparation or which existing support returns with it.'
                        : 'Write what you want to remember, then choose whether existing support should return with it.',
                    style: letterBody(size: 15),
                  ),
                  const SizedBox(height: LetterTokens.s20),
                  TextField(
                    key: const Key('prep_personal_text'),
                    controller: _personalTextController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 280,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Your preparation (optional)',
                      hintText:
                          'What would you like ready or remembered next time?',
                      helperText:
                          'Your words stay exactly as you write them on this device.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: LetterTokens.s16),
                  LetterCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _PreparationTickRow(
                          key: const Key('prep_confirm_care_row'),
                          value: _includeCare,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _includeCare = value),
                          label:
                              '${care.actionLabel} — Better ${care.betterCount} · '
                              'Same ${care.sameCount} · Worse ${care.worseCount}',
                          detail: 'Opens Care: ${care.mode.label}',
                          last: note == null || note.mode != care.mode,
                        ),
                        if (note != null && note.mode == care.mode) ...[
                          _PreparationTickRow(
                            key: const Key('prep_confirm_note_row'),
                            value: _includeNote,
                            onChanged: _saving
                                ? null
                                : (value) =>
                                      setState(() => _includeNote = value),
                            label: 'Your note to yourself',
                            detail:
                                'You wrote this. Letter Within shows it back unchanged.',
                            note: note.text,
                            last: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!canSave) ...[
                    const SizedBox(height: LetterTokens.s8),
                    Text(
                      'Write a preparation or include at least one item to save.',
                      style: letterHelper(size: 12.5),
                    ),
                  ],
                  if (_failed) ...[
                    const SizedBox(height: LetterTokens.s8),
                    Text(
                      'This preparation could not be saved. Nothing else changed.',
                      style: letterHelper(size: 12.5),
                    ),
                  ],
                  const SizedBox(height: LetterTokens.s20),
                  PrimaryButton(
                    key: const Key('prep_confirm_save'),
                    label: _saving
                        ? 'Saving…'
                        : editing
                        ? 'Save changes'
                        : 'Save for next time',
                    onPressed: canSave && !_saving ? _save : null,
                    expand: true,
                  ),
                  const SizedBox(height: LetterTokens.s8),
                  QuietButton(
                    label: 'Cancel',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    expand: true,
                  ),
                  if (editing) ...[
                    const SizedBox(height: LetterTokens.s12),
                    QuietButton(
                      key: const Key('prep_withdraw'),
                      label: 'Withdraw preparation',
                      onPressed: _saving ? null : _withdraw,
                      expand: true,
                    ),
                  ],
                  const SizedBox(height: LetterTokens.s16),
                  Text(
                    'Saving this does not send you anything. Nothing here is a reminder or a promise.',
                    style: letterHelper(size: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final care = widget.snapshot.care!;
      final now = DateTime.now().toUtc();
      final fingerprint = await PreparationFingerprint.forSelection(
        widget.snapshot,
        includeCare: _includeCare,
        includeNote: _includeNote,
      );
      final plan = PreparationPlan(
        id: PreparationPlan.activeId,
        status: PreparationPlanStatus.current,
        evidenceFingerprint: fingerprint,
        sourceRecordIds: PreparationFingerprint.selectionSourceIds(
          widget.snapshot,
          includeCare: _includeCare,
          includeNote: _includeNote,
        ),
        includeCare: _includeCare,
        careActionId: care.actionId,
        careActionLabel: care.actionLabel,
        careMode: care.mode,
        betterCount: care.betterCount,
        sameCount: care.sameCount,
        worseCount: care.worseCount,
        noteText: _includeNote ? widget.snapshot.futureNote?.text : null,
        personalText: _personalTextController.text.trim().isEmpty
            ? null
            : _personalTextController.text.trim(),
        createdAt: widget.initialPlan?.createdAt ?? now,
        updatedAt: now,
      );
      await widget.repository.savePlan(plan);
      if (mounted) Navigator.of(context).pop(plan);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  Future<void> _withdraw() async {
    final confirmed = await showLetterConfirm(
      context: context,
      title: 'Withdraw this preparation?',
      body:
          'The records it came from stay exactly as they are. Only this saved '
          'preparation is removed.',
      confirmLabel: 'Withdraw',
    );
    if (!confirmed) return;
    await widget.repository.removeActivePlan();
    if (!mounted) return;
    widget.onWithdrawn?.call();
    Navigator.of(context).pop();
  }
}

class _PreparationTickRow extends StatelessWidget {
  const _PreparationTickRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.last,
    this.detail,
    this.note,
    super.key,
  });

  final String label;
  final String? detail;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    button: true,
    child: InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
        padding: const EdgeInsets.all(LetterTokens.s16),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: LetterTokens.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                value
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 22,
                color: value ? LetterTokens.teal : LetterTokens.muted,
              ),
            ),
            const SizedBox(width: LetterTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value ? 'Included' : 'Left out', style: letterEyebrow()),
                  const SizedBox(height: LetterTokens.s4),
                  Text(
                    label,
                    style: letterBody(size: 14.5, weight: FontWeight.w500),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: LetterTokens.s8),
                    Container(
                      padding: const EdgeInsets.only(left: LetterTokens.s12),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: LetterTokens.teal, width: 2),
                        ),
                      ),
                      child: Text('“$note”', style: letterSerif(size: 17)),
                    ),
                  ],
                  if (detail != null) ...[
                    const SizedBox(height: LetterTokens.s4),
                    Text(detail!, style: letterHelper(size: 12.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RestoreDismissedPreparationScreen extends StatefulWidget {
  const RestoreDismissedPreparationScreen({
    required this.repository,
    required this.dismissals,
    super.key,
  });

  final PreparationRepository repository;
  final List<PreparationDismissal> dismissals;

  @override
  State<RestoreDismissedPreparationScreen> createState() =>
      _RestoreDismissedScreenState();
}

class _RestoreDismissedScreenState
    extends State<RestoreDismissedPreparationScreen> {
  late final List<PreparationDismissal> _remaining = [...widget.dismissals];
  final Set<String> _restored = {};

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LetterTokens.canvas,
    body: PopScope<Set<String>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_restored);
      },
      child: SafeArea(
        child: Column(
          children: [
            _PageTopBar(
              eyebrow: 'Your next window',
              title: 'Hidden suggestions',
              backLabel: 'Back',
              onBack: () => Navigator.of(context).pop(_restored),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(LetterTokens.gutter),
                children: [
                  Text(
                    'Hiding a suggestion only hides the suggestion. Every record '
                    'behind it is untouched.',
                    style: letterHelper(size: 12.5),
                  ),
                  const SizedBox(height: LetterTokens.s16),
                  if (_remaining.isEmpty)
                    LetterCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nothing is hidden right now',
                            style: letterSerif(size: 19),
                          ),
                          const SizedBox(height: LetterTokens.s4),
                          Text(
                            'When you choose “Not for me” on a suggestion, it '
                            'appears here so you can bring it back.',
                            style: letterHelper(size: 12.5),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final item in _remaining) ...[
                      LetterCard(
                        key: Key('prep_dismissed_${item.fingerprint}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.evidenceLine,
                              style: letterBody(
                                size: 14.5,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: LetterTokens.s4),
                            Text(
                              'Hidden ${MaterialLocalizations.of(context).formatMediumDate(item.dismissedAt.toLocal())}.',
                              style: letterHelper(size: 12.5),
                            ),
                            const SizedBox(height: LetterTokens.s12),
                            QuietButton(
                              key: Key('prep_restore_${item.fingerprint}'),
                              label: 'Restore',
                              onPressed: () => _restore(item),
                              expand: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LetterTokens.s12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _restore(PreparationDismissal item) async {
    await widget.repository.restoreDismissal(item.fingerprint);
    if (!mounted) return;
    setState(() {
      _remaining.remove(item);
      _restored.add(item.fingerprint);
    });
  }
}

PreparationLoopState _withLoop(
  PreparationLoopState state, {
  required PreparationLoopKind kind,
  PreparationPlan? plan,
  bool clearPlan = false,
  List<PreparationDismissal>? dismissals,
}) => PreparationLoopState(
  kind: kind,
  snapshot: state.snapshot,
  proposalFingerprint: state.proposalFingerprint,
  plan: clearPlan ? null : plan ?? state.plan,
  dismissals: dismissals ?? state.dismissals,
);

String _proposalEvidenceLine(PreparationSnapshot snapshot) {
  final care = snapshot.care;
  if (care != null) {
    final better = switch (care.betterCount) {
      0 => 'You recorded ${care.actionLabel} before.',
      1 => 'You marked ${care.actionLabel} Better once.',
      2 => 'You marked ${care.actionLabel} Better twice.',
      final count => 'You marked ${care.actionLabel} Better $count times.',
    };
    return snapshot.futureNote != null
        ? '$better You also left yourself a note.'
        : better;
  }
  final observation = snapshot.observation!;
  return 'You recorded ${observation.symptom.label.toLowerCase()} in '
      '${observation.distinctCompletedCycles} of '
      '${observation.totalCompletedCycles} completed cycles.';
}

String _savedCareLine(PreparationPlan plan) => switch (plan.betterCount) {
  0 => plan.careActionLabel,
  1 => '${plan.careActionLabel} — you marked this Better once.',
  2 => '${plan.careActionLabel} — you marked this Better twice.',
  final count =>
    '${plan.careActionLabel} — you marked this Better $count times.',
};

class _PageTopBar extends StatelessWidget {
  const _PageTopBar({
    required this.title,
    required this.backLabel,
    this.eyebrow,
    this.onBack,
  });

  final String title;
  final String backLabel;
  final String? eyebrow;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: LetterTokens.hairline),
    ),
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.s8,
      LetterTokens.s4,
      LetterTokens.gutter,
      LetterTokens.s8,
    ),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: backLabel,
          child: InkWell(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            borderRadius: LetterTokens.brControl,
            child: const SizedBox(
              width: LetterTokens.tapTarget,
              height: LetterTokens.tapTarget,
              child: Icon(Icons.arrow_back, size: 20),
            ),
          ),
        ),
        const SizedBox(width: LetterTokens.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(), style: letterEyebrow()),
                const SizedBox(height: 2),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: letterBody(size: 15, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.eyebrow,
    this.summaryLines = const [],
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final List<String> summaryLines;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final stacked = context.isLovableNarrow || context.isLovableLargeText;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: letterEyebrow()),
          const SizedBox(height: LetterTokens.s4),
        ],
        Text(
          title,
          style: letterBody(size: 15, weight: FontWeight.w600, height: 1.3),
        ),
        for (final line in summaryLines) ...[
          const SizedBox(height: LetterTokens.s4),
          Text(line, style: letterHelper(size: 12.5)),
        ],
      ],
    );

    return LetterCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              borderRadius: LetterTokens.brSurface,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: LetterTokens.tapTarget,
                ),
                padding: const EdgeInsets.all(LetterTokens.s16),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          if (trailing != null) ...[
                            const SizedBox(height: LetterTokens.s8),
                            trailing!,
                          ],
                          const SizedBox(height: LetterTokens.s8),
                          _expandLabel(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: header),
                          if (trailing != null) ...[
                            const SizedBox(width: LetterTokens.s8),
                            trailing!,
                          ],
                          const SizedBox(width: LetterTokens.s8),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: LetterTokens.muted,
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: LetterTokens.line),
            Padding(
              padding: const EdgeInsets.all(LetterTokens.s16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _expandLabel() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Icon(
        expanded ? Icons.expand_less : Icons.expand_more,
        size: 20,
        color: LetterTokens.muted,
      ),
      const SizedBox(width: LetterTokens.s4),
      Text(
        expanded ? 'Hide details' : 'Show details',
        style: letterHelper(size: 12.5),
      ),
    ],
  );
}

class _WindowRangeBar extends StatelessWidget {
  const _WindowRangeBar({required this.timing});

  final PreparationTimingEvidence timing;

  @override
  Widget build(BuildContext context) => Semantics(
    label: timing.hasWideVariation
        ? 'Wide estimated range, shown at reduced precision'
        : 'Estimated range',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: CustomPaint(
            painter: _RangePainter(wide: timing.hasWideVariation),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: LetterTokens.s4),
        Row(
          children: [
            Expanded(
              child: Text(
                _date(context, timing.periodRangeStart),
                style: letterHelper(size: 11.5),
              ),
            ),
            const SizedBox(width: LetterTokens.s8),
            Expanded(
              child: Text(
                _date(context, timing.periodRangeEnd),
                textAlign: TextAlign.end,
                style: letterHelper(size: 11.5),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RangePainter extends CustomPainter {
  const _RangePainter({required this.wide});

  final bool wide;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, size.width, size.height - 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = LetterColors.clinicalBlue.withValues(alpha: 0.08),
    );
    canvas.save();
    canvas.clipRRect(rect);
    final hatch = Paint()
      ..color = LetterColors.clinicalBlue.withValues(alpha: wide ? 0.35 : 0.5)
      ..strokeWidth = 1;
    final step = wide ? 10.0 : 6.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        hatch,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = LetterColors.clinicalBlue.withValues(alpha: 0.7),
    );
    if (!wide) {
      final middle = size.width / 2;
      canvas.drawLine(
        Offset(middle, 0),
        Offset(middle, size.height),
        Paint()
          ..strokeWidth = 1.5
          ..color = LetterColors.clinicalBlue,
      );
    }
  }

  @override
  bool shouldRepaint(_RangePainter oldDelegate) => oldDelegate.wide != wide;
}

String _strengthLine(PreparationObservationEvidence observation) =>
    observation.strength == PreparationPatternStrength.early
    ? 'Early pattern based on ${observation.distinctCompletedCycles} completed cycles.'
    : 'Repeated pattern';

String _recordsLine(
  BuildContext context,
  PreparationObservationEvidence observation,
) =>
    '${observation.recordCount} ${observation.recordCount == 1 ? 'record' : 'records'}, '
    'on ${observation.sources.map((item) => _date(context, item.date)).join(', ')}.';

String _precisionLine(PreparationTimingEvidence timing) {
  if (timing.hasWideVariation) {
    return 'Your recorded intervals vary by ${timing.observedSpreadDays} days, '
        'so this range is wide.';
  }
  if (timing.observedSpreadDays <= 0) {
    return 'Based on ${timing.observedIntervalCount} recorded '
        '${timing.observedIntervalCount == 1 ? 'interval' : 'intervals'}.';
  }
  return 'Based on ${timing.observedIntervalCount} recorded '
      '${timing.observedIntervalCount == 1 ? 'interval' : 'intervals'}, '
      '${timing.observedSpreadDays} days apart at the widest.';
}

String _careMetaLine(BuildContext context, PreparationCareEvidence care) =>
    '${care.pinned ? 'Pinned. ' : ''}Last used '
    '${_date(context, care.lastRecordedDate)}.';

String? _careCardLine(PreparationCareEvidence? care) {
  if (care == null || care.betterCount == 0) return null;
  final count = switch (care.betterCount) {
    1 => 'once',
    2 => 'twice',
    final value => '$value times',
  };
  return 'You have marked ${care.actionLabel} Better $count.';
}

String _confidenceLabel(PredictionConfidence confidence) =>
    switch (confidence) {
      PredictionConfidence.low => 'Low confidence',
      PredictionConfidence.medium => 'Medium confidence',
      PredictionConfidence.higher => 'Higher confidence',
    };

String _range(BuildContext context, LocalDate start, LocalDate end) =>
    '${_date(context, start)}–${_date(context, end)}';

String _date(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.asLocalDateTime);
