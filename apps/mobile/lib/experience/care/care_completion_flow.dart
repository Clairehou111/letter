import 'package:flutter/material.dart';

import '../../features/care/domain/care_memory.dart';
import '../../features/care/domain/care_memory_repository.dart';
import '../../features/care/domain/care_mode.dart';
import '../../features/cycle/domain/local_date.dart';
import '../../features/health_records/domain/health_record.dart';
import '../../features/health_records/domain/observation_catalog.dart';
import '../../features/recovery_receipt/domain/recovery_receipt.dart';
import '../degree/degree_graphics.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';
import 'care_scene_foundation.dart';

/// The soft-landing check-back that follows every Care scene.
///
/// Contracts honored here (design authority):
///  * A completion is a **deliberate** [CareActionCompletion] supplied by the
///    scene the person actually performed. Reading a suggestion never counts;
///    nothing persists until the person deliberately saves an outcome.
///  * The outcome is optional. Better / Same / Worse render through the
///    shared outcome arcs in [DegreeGraphics] — shape + word, never color
///    alone. Skipping records nothing and loses nothing.
///  * The RecoveryReceipt is offered **separately**, behind an explicit,
///    plainly worded per-use opt-in, and is independently dismissible.
///    Declining leaves the saved Care completion fully valid.
///  * For [CareMode.space] — where [suggestedSymptomForCare] returns null —
///    the free choice presents the [RecoveryReceiptSignal] list (including
///    "Something else" and "I do not remember"), never the full catalog.
///  * Pain inside the receipt is a severity degree: when the chosen signal
///    is a pain-kind symptom, the shared pain card asks its degree in the
///    same five named SymptomSeverity levels as every other observation —
///    never a numeric score or a location list. Cancelling discards the
///    unfinished degree rather than persisting invalid data.
///  * Provenance derives from [recoveryReceiptProvenance] (same-day vs later
///    recall) and is surfaced honestly after save.
///  * Reflection fields respect the 280-character limit and surface
///    [CareMemoryException.userMessage] verbatim on failure.
///  * Dismiss and later check-in are first-class exits. No reminder is
///    promised anywhere in copy until a notification channel is confirmed.
///  * Errors are visual + textual only — never haptic.
class CareCompletionFlow extends StatefulWidget {
  const CareCompletionFlow({
    super.key,
    required this.mode,
    required this.completion,
    required this.careMemoryRepository,
    required this.onLeaveCare,
    this.saveReceipt,
    this.onResumeScene,
    this.resumeHint,
    this.onLaterCheckIn,
    this.onOpenSafety,
    this.motionPreference = CareSceneMotionPreference.full,
    this.now,
  });

  /// The mode whose scene just ended.
  final CareMode mode;

  /// The deliberate action record produced by the completed scene. Persisted
  /// only when the person deliberately saves an outcome — never on a read.
  final CareActionCompletion completion;

  final CareMemoryRepository careMemoryRepository;

  /// Receipt persistence seam, wired by the shell. When null, the receipt
  /// opt-in is not offered at all.
  final Future<RecoveryReceiptResult> Function(RecoveryReceiptDraft draft)?
  saveReceipt;

  /// Leave the Care world back to daylight (dismiss / done).
  final VoidCallback onLeaveCare;

  /// Continue an interrupted scene (interruption recovery).
  final VoidCallback? onResumeScene;

  /// Named recovery copy for an interrupted scene, e.g. "You were in the
  /// middle of Release. Continue, check in, or leave it here."
  final String? resumeHint;

  /// The later check-in exit. No reminder is scheduled or implied.
  final VoidCallback? onLaterCheckIn;

  /// Routes to the deterministic safety surface.
  final VoidCallback? onOpenSafety;

  final CareSceneMotionPreference motionPreference;

  /// Testable clock.
  final DateTime Function()? now;

  @override
  State<CareCompletionFlow> createState() => _CareCompletionFlowState();
}

enum _LandingStage { checkIn, checkedIn }

class _CareCompletionFlowState extends State<CareCompletionFlow> {
  _LandingStage _stage = _LandingStage.checkIn;

  CareOutcome? _selectedOutcome;
  bool _savingOutcome = false;
  String? _outcomeError;
  bool _skippedOutcome = false;

  CareRecord? _record;
  String? _ackLine;
  bool _showPulse = false;

  bool _receiptDismissed = false;
  RecoveryReceiptResult? _receiptResult;

  bool _reflectionSaved = false;

  // Reflection draft lives here so an interrupted sheet keeps its words.
  final TextEditingController _observationController = TextEditingController();
  final TextEditingController _whatHelpedController = TextEditingController();
  final TextEditingController _futureSelfController = TextEditingController();
  ReflectionNeed? _reflectionNeed;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void dispose() {
    _observationController.dispose();
    _whatHelpedController.dispose();
    _futureSelfController.dispose();
    super.dispose();
  }

  Future<void> _saveOutcome() async {
    final outcome = _selectedOutcome;
    if (outcome == null || _savingOutcome) return;
    setState(() {
      _savingOutcome = true;
      _outcomeError = null;
    });
    try {
      // The completion is validated before it ever becomes a record; an
      // unrecognized action can never persist.
      final valid = validateCareCompletion(widget.completion);
      final record = await widget.careMemoryRepository.saveOutcome(
        valid,
        outcome,
      );
      if (!mounted) return;
      final line = await ExperienceFoundation.savedRhythm(
        SavedRhythmKind.outcome,
        now: _now(),
      );
      if (!mounted) return;
      setState(() {
        _record = record;
        _stage = _LandingStage.checkedIn;
        _ackLine = line;
        _showPulse = true;
      });
    } on CareMemoryException catch (error) {
      // Errors are visual + textual. No haptics — vibration punishes.
      setState(() => _outcomeError = error.userMessage);
    } catch (_) {
      setState(
        () => _outcomeError = const CareMemoryException(
          CareMemoryFailure.storageUnavailable,
        ).userMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _savingOutcome = false);
      }
    }
  }

  void _skipOutcome() {
    ExperienceHaptics.pick();
    setState(() => _skippedOutcome = true);
  }

  Future<void> _openReceipt() async {
    final record = _record;
    final saveReceipt = widget.saveReceipt;
    if (record == null || saveReceipt == null) return;
    ExperienceHaptics.pick();
    final result = await showExperienceSheet<RecoveryReceiptResult>(
      context,
      careWorld: true,
      child: _RecoveryReceiptSheet(
        record: record,
        completion: widget.completion,
        saveReceipt: saveReceipt,
        motionPreference: widget.motionPreference,
        now: widget.now,
      ),
    );
    if (!mounted || result == null) return;
    final line = await ExperienceFoundation.savedRhythm(
      SavedRhythmKind.record,
      now: _now(),
    );
    if (!mounted) return;
    setState(() {
      _receiptResult = result;
      _ackLine = line;
    });
  }

  void _dismissReceipt() {
    ExperienceHaptics.pick();
    setState(() => _receiptDismissed = true);
  }

  Future<void> _openReflection() async {
    final record = _record;
    if (record == null) return;
    ExperienceHaptics.pick();
    final saved = await showExperienceSheet<bool>(
      context,
      careWorld: true,
      child: _ReflectionSheet(
        recordId: record.id,
        careMemoryRepository: widget.careMemoryRepository,
        observationController: _observationController,
        whatHelpedController: _whatHelpedController,
        futureSelfController: _futureSelfController,
        initialNeed: _reflectionNeed,
        onNeedChanged: (need) => _reflectionNeed = need,
      ),
    );
    if (!mounted || saved != true) return;
    final line = await ExperienceFoundation.savedRhythm(
      SavedRhythmKind.reflection,
      now: _now(),
    );
    if (!mounted) return;
    setState(() {
      _reflectionSaved = true;
      _ackLine = line;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Care check-back after ${widget.mode.label}',
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: ExperienceColors.careBackdrop,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ExperienceSpacing.screenMargin,
                ExperienceSpacing.sm,
                ExperienceSpacing.screenMargin,
                ExperienceSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: Semantics(
                      header: true,
                      child: Column(
                        children: <Widget>[
                          Text(
                            widget.mode.label.toUpperCase(),
                            style: ExperienceType.eyebrow(
                              ExperienceColors.careInkSoft,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: ExperienceSpacing.xs),
                          Text(
                            'You stayed with the moment.',
                            style: ExperienceType.title(
                              ExperienceColors.careInk,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ExperienceSpacing.sm),
                  // The held ember — the same luminous ember from the scene,
                  // held closer. Decorative; never in the accessibility tree.
                  Center(
                    child: _HeldEmber(
                      motion: widget.motionPreference,
                      showPulse: _showPulse,
                      onPulseComplete: () {
                        if (mounted) {
                          setState(() => _showPulse = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: ExperienceSpacing.xs),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          bottom: ExperienceSpacing.xl,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                if (widget.resumeHint != null) ...<Widget>[
                                  _ResumeCard(
                                    hint: widget.resumeHint!,
                                    onContinue: widget.onResumeScene,
                                  ),
                                  const SizedBox(height: ExperienceSpacing.md),
                                ],
                                if (_stage == _LandingStage.checkIn &&
                                    !_skippedOutcome)
                                  _buildOutcomeSection()
                                else if (_stage == _LandingStage.checkedIn)
                                  _buildCheckedInSection()
                                else
                                  _buildSkippedSection(),
                                const SizedBox(height: ExperienceSpacing.sm),
                                Center(
                                  child: SavedRhythmAckLine(
                                    line: _ackLine,
                                    careWorld: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ExperienceSpacing.xs),
                  if (_stage == _LandingStage.checkedIn)
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: _EmberAction(
                        label: 'Return to daylight',
                        onPressed: widget.onLeaveCare,
                      ),
                    ),
                  if (_stage == _LandingStage.checkedIn)
                    const SizedBox(height: ExperienceSpacing.xs),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(5),
                    child: _QuietSafetyLine(onTap: widget.onOpenSafety),
                  ),
                  const SizedBox(height: ExperienceSpacing.xs),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: _ExitPill(
                      label: CareSceneFoundation.defaultExitLabel,
                      onPressed: widget.onLeaveCare,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The question leads. Reassurance follows the actions, so nothing
        // competes with Better / Same / Worse before a choice is made.
        Text(
          'How does this moment feel now?',
          style: ExperienceType.title(ExperienceColors.careInk),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ExperienceSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            for (final outcome in DegreeGraphics.outcomes)
              _OutcomeOption(
                outcome: outcome,
                selected: _selectedOutcome == outcome,
                onTap: _savingOutcome
                    ? null
                    : () {
                        ExperienceHaptics.pick();
                        setState(() => _selectedOutcome = outcome);
                      },
              ),
          ],
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'If you like, leave one word about how it landed. '
          'It is optional — skipping records nothing.',
          style: ExperienceType.caption(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _EmberAction(
            label: _savingOutcome ? 'Saving…' : 'Save this check-back',
            onPressed: _selectedOutcome == null || _savingOutcome
                ? null
                : _saveOutcome,
          ),
        ),
        if (_outcomeError != null)
          Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _outcomeError!,
                style: ExperienceType.caption(ExperienceColors.emberSoft),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const SizedBox(height: ExperienceSpacing.sm),
        // Skip is a first-class, fully visible exit from the question —
        // its own quiet row, never tucked under the primary action.
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(
              ExperienceSpacing.minTouchTarget,
            ),
          ),
          onPressed: _savingOutcome ? null : _skipOutcome,
          child: Text(
            'Skip — nothing needs saving',
            style: ExperienceType.label(ExperienceColors.careInkSoft),
            textAlign: TextAlign.center,
          ),
        ),
        if (widget.onLaterCheckIn != null)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(
                ExperienceSpacing.minTouchTarget,
              ),
            ),
            onPressed: widget.onLaterCheckIn,
            child: Text(
              "I'll check back later",
              style: ExperienceType.caption(ExperienceColors.careInkSoft),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: ExperienceSpacing.md),
        Text(
          'However it went, showing up was the whole of '
          'it. Nothing needs fixing now.',
          style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSkippedSection() {
    return Column(
      children: <Widget>[
        Text(
          'Nothing was saved. The moment still counted.',
          style: ExperienceType.body(ExperienceColors.careInk),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'You can leave whenever you like.',
          style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCheckedInSection() {
    final record = _record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Saved state: the chosen outcome settles, read-only, with its word.
        if (record != null)
          Center(
            child: Column(
              children: <Widget>[
                DegreeGraphics.outcome(
                  record.outcome,
                  selected: true,
                  careWorld: true,
                ),
                const SizedBox(height: ExperienceSpacing.xs),
                Text(
                  'You recorded “${record.actionLabel}”.',
                  style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: ExperienceSpacing.lg),
        // The RecoveryReceipt opt-in — separate, explicit, dismissible.
        if (widget.saveReceipt != null &&
            _receiptResult == null &&
            !_receiptDismissed)
          _ReceiptOptInCard(onAccept: _openReceipt, onDecline: _dismissReceipt),
        if (_receiptDismissed && _receiptResult == null)
          Text(
            'Nothing else was added — your check-back stands.',
            style: ExperienceType.caption(ExperienceColors.careInkSoft),
            textAlign: TextAlign.center,
          ),
        if (_receiptResult != null) _ReceiptSavedCard(result: _receiptResult!),
        const SizedBox(height: ExperienceSpacing.md),
        // A few words, optionally, for future you.
        if (!_reflectionSaved)
          _ReflectionOfferCard(onWrite: _openReflection)
        else
          Text(
            'Reflection kept for future you.',
            style: ExperienceType.caption(ExperienceColors.careInkSoft),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Landing pieces
// ---------------------------------------------------------------------------

/// The luminous held ember from the active scene, carried into the landing.
/// Layered warm glow around [EmberOrb] — decorative and motion-aware; the
/// breathing and pulse honour [CareSceneMotionPreference] through the orb
/// itself. Excluded from the accessibility tree.
class _HeldEmber extends StatelessWidget {
  const _HeldEmber({
    required this.motion,
    required this.showPulse,
    required this.onPulseComplete,
  });

  final CareSceneMotionPreference motion;
  final bool showPulse;
  final VoidCallback onPulseComplete;

  @override
  Widget build(BuildContext context) {
    const orbSize = 72.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: orbSize,
        height: orbSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            // Warm halo — the ember's light on the dark, not a flat disc.
            Container(
              width: orbSize * 2.6,
              height: orbSize * 2.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    ExperienceColors.emberGlow.withValues(alpha: 0.34),
                    ExperienceColors.emberGlow.withValues(alpha: 0.10),
                    ExperienceColors.emberGlow.withValues(alpha: 0),
                  ],
                  stops: const <double>[0, 0.45, 1],
                ),
              ),
            ),
            Container(
              width: orbSize * 1.5,
              height: orbSize * 1.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    ExperienceColors.emberSoft.withValues(alpha: 0.30),
                    ExperienceColors.emberSoft.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            EmberOrb(size: orbSize, breathing: true, motion: motion),
            if (showPulse)
              EmberPulse(diameter: 108, onComplete: onPulseComplete),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.hint, required this.onContinue});

  final String hint;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.careGlass,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.careGlassBorder),
      ),
      child: Column(
        children: <Widget>[
          Text(
            hint,
            style: ExperienceType.body(ExperienceColors.careInk),
            textAlign: TextAlign.center,
          ),
          if (onContinue != null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Semantics(
              button: true,
              label: 'Continue where you left off',
              child: TextButton(
                onPressed: onContinue,
                child: Text(
                  'Continue',
                  style: ExperienceType.label(ExperienceColors.emberSoft),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeOption extends StatelessWidget {
  const _OutcomeOption({
    required this.outcome,
    required this.selected,
    required this.onTap,
  });

  final CareOutcome outcome;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = DegreeGraphics.outcomeLabel(outcome);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: 'Outcome: $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minWidth: ExperienceSpacing.degreeTarget,
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: ExperienceSpacing.xs * 2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x29FFFFFF)
                : ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected
                  ? ExperienceColors.emberSoft
                  : ExperienceColors.careGlassBorder,
              width: selected ? 1.5 : 1,
            ),
            // A colored glow only at the focal moment of choosing.
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: ExperienceColors.emberGlow.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ExcludeSemantics(
            child: DegreeGraphics.outcome(
              outcome,
              selected: selected,
              careWorld: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptOptInCard extends StatelessWidget {
  const _ReceiptOptInCard({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.careGlass,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.careGlassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add this moment to your health record?',
            style: ExperienceType.headline(ExperienceColors.careInk),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Optional, and separate from your check-back — that is already '
            'saved either way. With your yes, you name the signal and its '
            'intensity, plus pain only if it was present, so your patterns '
            'can learn from real moments.',
            style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          _EmberAction(label: 'Yes, add the note', onPressed: onAccept),
          TextButton(
            onPressed: onDecline,
            child: Text(
              'Not now',
              style: ExperienceType.caption(ExperienceColors.careInkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSavedCard extends StatelessWidget {
  const _ReceiptSavedCard({required this.result});

  final RecoveryReceiptResult result;

  @override
  Widget build(BuildContext context) {
    final count = result.records.length;
    final provenanceLine = result.provenance == HealthRecordProvenance.sameDay
        ? 'Recorded as a same-day note.'
        : 'Recorded from later recall — it still counts.';
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.careGlass,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.careGlassBorder),
      ),
      child: Column(
        children: <Widget>[
          Text.rich(
            TextSpan(
              style: ExperienceType.body(ExperienceColors.careInk),
              children: <InlineSpan>[
                const TextSpan(text: 'Added '),
                TextSpan(
                  text: '$count',
                  style: ExperienceType.data(ExperienceColors.careInk),
                ),
                TextSpan(
                  text: count == 1
                      ? ' health note to your record.'
                      : ' health notes to your record.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            provenanceLine,
            style: ExperienceType.caption(ExperienceColors.careInkSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReflectionOfferCard extends StatelessWidget {
  const _ReflectionOfferCard({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.careGlass,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.careGlassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Keep a few words for future you?',
            style: ExperienceType.headline(ExperienceColors.careInk),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'What the moment was, what helped — anything you want the next '
            'hard moment to remember. Optional, always.',
            style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Write a reflection',
              child: TextButton(
                onPressed: onWrite,
                child: Text(
                  'Write a reflection',
                  style: ExperienceType.label(ExperienceColors.emberSoft),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietSafetyLine extends StatelessWidget {
  const _QuietSafetyLine({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      CareSceneFoundation.defaultSafetyLine,
      style: ExperienceType.caption(ExperienceColors.careInkSoft),
      textAlign: TextAlign.center,
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
        child: text,
      );
    }
    return Semantics(
      button: true,
      label: CareSceneFoundation.defaultSafetyLine,
      child: InkWell(
        borderRadius: ExperienceRadius.chipRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: ExperienceSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.favorite_border,
                size: 14,
                color: ExperienceColors.careInkSoft,
              ),
              const SizedBox(width: ExperienceSpacing.xs),
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmberAction extends StatelessWidget {
  const _EmberAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.degreeTarget,
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ExperienceColors.emberGradient,
              borderRadius: ExperienceRadius.heroRadius,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: ExperienceColors.emberGlow.withValues(alpha: 0.55),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: ExperienceRadius.heroRadius,
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.lg,
                    vertical: ExperienceSpacing.sm,
                  ),
                  child: Text(
                    label,
                    style: ExperienceType.label(Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitPill extends StatelessWidget {
  const _ExitPill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. Exit is always available.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: Material(
          color: ExperienceColors.careInk,
          borderRadius: ExperienceRadius.heroRadius,
          child: InkWell(
            borderRadius: ExperienceRadius.heroRadius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.lg,
                vertical: ExperienceSpacing.sm,
              ),
              child: Text(
                label,
                style: ExperienceType.label(ExperienceColors.careSkyBottom),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RecoveryReceipt sheet — the explicit, per-use opt-in health note.
// ---------------------------------------------------------------------------

class _RecoveryReceiptSheet extends StatefulWidget {
  const _RecoveryReceiptSheet({
    required this.record,
    required this.completion,
    required this.saveReceipt,
    required this.motionPreference,
    this.now,
  });

  final CareRecord record;
  final CareActionCompletion completion;
  final Future<RecoveryReceiptResult> Function(RecoveryReceiptDraft draft)
  saveReceipt;
  final CareSceneMotionPreference motionPreference;
  final DateTime Function()? now;

  @override
  State<_RecoveryReceiptSheet> createState() => _RecoveryReceiptSheetState();
}

class _RecoveryReceiptSheetState extends State<_RecoveryReceiptSheet> {
  RecoveryReceiptSignal? _signal;
  SymptomSeverity? _severity;
  final Set<SymptomType> _additionalSignals = <SymptomType>{};
  final Set<FunctionalImpact> _impacts = <FunctionalImpact>{};

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Modes with a suggested signal start there; space starts with the free
    // signal list and nothing preselected.
    _signal = _suggestedSignal();
  }

  RecoveryReceiptSignal? _suggestedSignal() {
    final symptom = suggestedSymptomForCare(widget.record);
    if (symptom == null) return null;
    for (final signal in RecoveryReceiptSignal.values) {
      if (signal.symptom == symptom) return signal;
    }
    return null;
  }

  bool get _suggestionAvailable =>
      suggestedSymptomForCare(widget.record) != null;

  /// Whether the chosen signal is a pain-kind symptom. Its degree is then
  /// asked through the shared pain card — pain is a severity degree, never
  /// a numeric score or a location list.
  bool get _isPainSignal {
    final symptom = _signal?.symptom;
    if (symptom == null) return false;
    return ObservationCatalog.definitionFor(symptom).recordingKind ==
        ObservationRecordingKind.pain;
  }

  List<SymptomType> get _physicalOptions {
    final main = _signal?.symptom;
    return SymptomType.values
        .where(
          (type) =>
              type.category == SymptomCategory.physical &&
              type.availableForNewRecords &&
              type != main,
        )
        .toList(growable: false);
  }

  String get _provenanceHint {
    final recordedAt = (widget.now ?? DateTime.now)();
    final experienced = LocalDate.fromDateTime(
      widget.completion.occurredAt.toLocal(),
    );
    final provenance = recoveryReceiptProvenance(
      experiencedDate: experienced,
      recordedAt: recordedAt,
    );
    return provenance == HealthRecordProvenance.sameDay
        ? 'This will be marked as a same-day record.'
        : 'This will be marked as a later recollection — it still counts.';
  }

  Future<void> _save() async {
    final signal = _signal;
    if (signal == null) {
      setState(
        () => _error = const RecoveryReceiptException(
          RecoveryReceiptFailure.signalRequired,
        ).userMessage,
      );
      return;
    }
    final symptom = signal.symptom;
    if (symptom == null) return; // graceful no-record branches render instead
    final severity = _severity;
    if (severity == null) {
      setState(
        () => _error = const RecoveryReceiptException(
          RecoveryReceiptFailure.severityRequired,
        ).userMessage,
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = validateRecoveryReceiptDraft(
        RecoveryReceiptDraft(
          careRecordId: widget.record.id,
          symptom: symptom,
          severity: severity,
          functionalImpacts: _impacts,
          additionalPhysicalSignals: _additionalSignals,
        ),
      );
      final result = await widget.saveReceipt(draft);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on RecoveryReceiptException catch (error) {
      // Verbatim contract copy.
      setState(() => _error = error.userMessage);
    } on HealthRecordException catch (error) {
      setState(() => _error = error.userMessage);
    } catch (_) {
      setState(
        () => _error = const RecoveryReceiptException(
          RecoveryReceiptFailure.storageUnavailable,
        ).userMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _cancel() {
    // Cancelling discards everything local — including an unfinished pain
    // degree — rather than persisting invalid data. The Care completion
    // already saved stays fully valid.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final signal = _signal;
    final symptom = signal?.symptom;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'What was this moment?',
              style: ExperienceType.title(ExperienceColors.careInk),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'Kept light on purpose — a signal, its intensity, and pain only '
            'if it was present.',
            style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.lg),

          // --- Signal: suggested for mapped modes, the receipt signal list
          // (never the full catalog) for space and for changing. -----------
          Text(
            'The signal',
            style: ExperienceType.bodyStrong(ExperienceColors.careInk),
          ),
          if (_suggestionAvailable)
            Padding(
              padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
              child: Text(
                'Suggested from this moment — change it if another fits '
                'better.',
                style: ExperienceType.caption(ExperienceColors.careInkSoft),
              ),
            ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              for (final option in RecoveryReceiptSignal.values)
                _CareChoiceChip(
                  label: option.label,
                  semanticsLabel: 'Signal: ${option.label}',
                  selected: _signal == option,
                  onTap: _saving
                      ? null
                      : () {
                          ExperienceHaptics.pick();
                          setState(() {
                            _signal = option;
                            _error = null;
                            if (option.symptom != _signal?.symptom) {
                              _additionalSignals.remove(option.symptom);
                            }
                          });
                          // Changing the main signal can never leave it
                          // duplicated in the additional physical step.
                          final main = option.symptom;
                          if (main != null &&
                              _additionalSignals.contains(main)) {
                            setState(() => _additionalSignals.remove(main));
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.md),

          if (signal == null)
            Text(
              'Choose a signal above to continue — or “I do not remember” if '
              'none fit.',
              style: ExperienceType.caption(ExperienceColors.careInkSoft),
            )
          else if (symptom == null)
            _GracefulSignalNote(signal: signal, onClose: _cancel)
          else ...<Widget>[
            // --- Degree: exactly five named degrees, never "not at all".
            // For a pain-kind signal the shared pain card asks the same
            // question — pain is a severity degree, never a score. ------
            if (_isPainSignal)
              DegreeGraphics.painEntry(
                severity: _severity,
                careWorld: true,
                enabled: !_saving,
                onSeverityChanged: (degree) {
                  setState(() {
                    // Choosing the same degree again removes it —
                    // absence, never "not at all".
                    _severity = _severity == degree ? null : degree;
                    _error = null;
                  });
                },
                onCleared: () {
                  ExperienceHaptics.pick();
                  setState(() {
                    _severity = null;
                    _error = null;
                  });
                },
              )
            else ...<Widget>[
              Text(
                'Its intensity',
                style: ExperienceType.bodyStrong(ExperienceColors.careInk),
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              for (final severity in SymptomSeverity.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs),
                  child: _SeverityRow(
                    severity: severity,
                    selected: _severity == severity,
                    onTap: _saving
                        ? null
                        : () {
                            ExperienceHaptics.pick();
                            setState(() {
                              _severity = severity;
                              _error = null;
                            });
                          },
                  ),
                ),
            ],
            const SizedBox(height: ExperienceSpacing.sm),

            // --- Optional additional physical signals (physical only). ---
            Text(
              'Any other physical signals? (optional)',
              style: ExperienceType.bodyStrong(ExperienceColors.careInk),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            Wrap(
              spacing: ExperienceSpacing.xs * 2,
              runSpacing: ExperienceSpacing.xs * 2,
              children: <Widget>[
                for (final type in _physicalOptions)
                  _CareChoiceChip(
                    label: type.label,
                    semanticsLabel: 'Additional physical signal: ${type.label}',
                    selected: _additionalSignals.contains(type),
                    onTap: _saving
                        ? null
                        : () {
                            ExperienceHaptics.pick();
                            setState(() {
                              if (_additionalSignals.contains(type)) {
                                _additionalSignals.remove(type);
                              } else {
                                _additionalSignals.add(type);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: ExperienceSpacing.md),

            // --- Functional impact, optional. ----------------------------
            Text(
              'Did it get in the way of anything? (optional)',
              style: ExperienceType.bodyStrong(ExperienceColors.careInk),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            Wrap(
              spacing: ExperienceSpacing.xs * 2,
              runSpacing: ExperienceSpacing.xs * 2,
              children: <Widget>[
                for (final impact in FunctionalImpact.values)
                  _CareChoiceChip(
                    label: impact.label,
                    semanticsLabel: 'Functional impact: ${impact.label}',
                    selected: _impacts.contains(impact),
                    onTap: _saving
                        ? null
                        : () {
                            ExperienceHaptics.pick();
                            setState(() {
                              if (_impacts.contains(impact)) {
                                _impacts.remove(impact);
                              } else {
                                _impacts.add(impact);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: ExperienceSpacing.md),
            Text(
              _provenanceHint,
              style: ExperienceType.caption(ExperienceColors.careInkSoft),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: ExperienceType.caption(ExperienceColors.emberSoft),
                  ),
                ),
              ),
            const SizedBox(height: ExperienceSpacing.md),
            _EmberAction(
              label: _saving ? 'Saving…' : 'Save health note',
              onPressed: _saving ? null : _save,
            ),
            TextButton(
              onPressed: _saving ? null : _cancel,
              child: Text(
                'Cancel — discard this note',
                style: ExperienceType.caption(ExperienceColors.careInkSoft),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Something else" and "I do not remember" are complete answers that record
/// nothing further — the Care completion stays fully valid.
class _GracefulSignalNote extends StatelessWidget {
  const _GracefulSignalNote({required this.signal, required this.onClose});

  final RecoveryReceiptSignal signal;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final copy = switch (signal) {
      RecoveryReceiptSignal.iDoNotRemember =>
        'Not remembering is a complete answer. Nothing more will be '
            'recorded.',
      _ =>
        'This check-back keeps to the signals listed here, so it stays '
            'light. If the moment was something else, you can record it in '
            'full from Cycle whenever you like.',
    };
    return Container(
      padding: const EdgeInsets.all(ExperienceSpacing.md),
      decoration: BoxDecoration(
        color: ExperienceColors.careGlass,
        borderRadius: ExperienceRadius.cardRadius,
        border: Border.all(color: ExperienceColors.careGlassBorder),
      ),
      child: Column(
        children: <Widget>[
          Text(
            copy,
            style: ExperienceType.body(ExperienceColors.careInk),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          TextButton(
            onPressed: onClose,
            child: Text(
              'Close — nothing more to add',
              style: ExperienceType.label(ExperienceColors.emberSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityRow extends StatelessWidget {
  const _SeverityRow({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final SymptomSeverity severity;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: DegreeGraphics.severitySemanticsLabel(severity),
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: ExperienceSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x29FFFFFF)
                : ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected
                  ? ExperienceColors.emberSoft
                  : ExperienceColors.careGlassBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ExcludeSemantics(
            child: DegreeGraphics.severity(
              severity,
              selected: selected,
              careWorld: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _CareChoiceChip extends StatelessWidget {
  const _CareChoiceChip({
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: ExperienceMotion.chipSelect,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x29FFFFFF)
                : ExperienceColors.careGlass,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected
                  ? ExperienceColors.emberSoft
                  : ExperienceColors.careGlassBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: ExperienceType.label(ExperienceColors.careInk),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reflection sheet — a few words for future you, 280 characters per field.
// ---------------------------------------------------------------------------

class _ReflectionSheet extends StatefulWidget {
  const _ReflectionSheet({
    required this.recordId,
    required this.careMemoryRepository,
    required this.observationController,
    required this.whatHelpedController,
    required this.futureSelfController,
    required this.initialNeed,
    required this.onNeedChanged,
  });

  final String recordId;
  final CareMemoryRepository careMemoryRepository;

  /// Controllers are owned by the landing so an interrupted sheet keeps its
  /// draft.
  final TextEditingController observationController;
  final TextEditingController whatHelpedController;
  final TextEditingController futureSelfController;
  final ReflectionNeed? initialNeed;
  final ValueChanged<ReflectionNeed?> onNeedChanged;

  @override
  State<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends State<_ReflectionSheet> {
  late ReflectionNeed? _need = widget.initialNeed;
  bool _saving = false;
  String? _error;

  static String _needLabel(ReflectionNeed need) {
    return switch (need) {
      ReflectionNeed.boundaries => 'Boundaries',
      ReflectionNeed.connection => 'Connection',
      ReflectionNeed.autonomy => 'Autonomy',
      ReflectionNeed.restOrPhysicalCapacity => 'Rest or physical capacity',
      ReflectionNeed.somethingElse => 'Something else',
      ReflectionNeed.notSure => 'Not sure',
    };
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final draft = validateCareReflection(
        CareReflectionDraft(
          observation: widget.observationController.text,
          need: _need,
          whatHelped: widget.whatHelpedController.text,
          futureSelfNote: widget.futureSelfController.text,
        ),
      );
      await widget.careMemoryRepository.saveReflection(widget.recordId, draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CareMemoryException catch (error) {
      // Verbatim, ready-made copy: the 280-character limit and the
      // one-thought minimum speak in the repository's own words.
      setState(() => _error = error.userMessage);
    } catch (_) {
      setState(
        () => _error = const CareMemoryException(
          CareMemoryFailure.storageUnavailable,
        ).userMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: ExperienceType.bodyStrong(ExperienceColors.careInk)),
        const SizedBox(height: ExperienceSpacing.xs),
        TextField(
          controller: controller,
          enabled: !_saving,
          maxLength: careMemoryTextMaximumCharacters,
          maxLines: 3,
          minLines: 1,
          style: ExperienceType.body(ExperienceColors.careInk),
          cursorColor: ExperienceColors.emberSoft,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ExperienceType.bodySmall(ExperienceColors.careInkFaint),
            filled: true,
            fillColor: ExperienceColors.careGlass,
            contentPadding: const EdgeInsets.all(ExperienceSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: const BorderSide(
                color: ExperienceColors.careGlassBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: const BorderSide(
                color: ExperienceColors.careGlassBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: ExperienceRadius.chipRadius,
              borderSide: const BorderSide(color: ExperienceColors.emberSoft),
            ),
            counterStyle: ExperienceType.caption(ExperienceColors.careInkFaint),
          ),
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) {
                return Text(
                  '$currentLength / $maxLength',
                  style: ExperienceType.data(
                    ExperienceColors.careInkFaint,
                    size: 12,
                    weight: FontWeight.w400,
                  ),
                );
              },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              'A few words for future you',
              style: ExperienceType.title(ExperienceColors.careInk),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'One thought is enough. Up to 280 characters each.',
            style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          _field(
            label: 'What was this moment like?',
            controller: widget.observationController,
            hint: 'As honest or as brief as you like.',
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'What did this moment need?',
            style: ExperienceType.bodyStrong(ExperienceColors.careInk),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              for (final need in ReflectionNeed.values)
                _CareChoiceChip(
                  label: _needLabel(need),
                  semanticsLabel: 'Need: ${_needLabel(need)}',
                  selected: _need == need,
                  onTap: _saving
                      ? null
                      : () {
                          ExperienceHaptics.pick();
                          setState(() => _need = _need == need ? null : need);
                          widget.onNeedChanged(_need);
                        },
                ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.md),
          _field(
            label: 'What helped, even a little?',
            controller: widget.whatHelpedController,
            hint: 'Warmth, quiet, a message sent…',
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          _field(
            label: 'A note to future you',
            controller: widget.futureSelfController,
            hint: 'Something the next hard moment should hear.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: ExperienceType.caption(ExperienceColors.emberSoft),
                ),
              ),
            ),
          const SizedBox(height: ExperienceSpacing.md),
          _EmberAction(
            label: _saving ? 'Saving…' : 'Keep this reflection',
            onPressed: _saving ? null : _save,
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(
              'Not now — keep my draft',
              style: ExperienceType.caption(ExperienceColors.careInkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
