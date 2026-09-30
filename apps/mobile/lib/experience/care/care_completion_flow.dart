import 'dart:math' as math;

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

/// The Settled Page — the soft-landing check-back that follows every Care
/// scene.
///
/// One rule governs this file: **completion is the default state; work is
/// opt-in; the page never asks twice.**
///
/// Contracts honored here (design authority):
///  * A completion is a **deliberate** [CareActionCompletion] supplied by the
///    scene the person actually performed. Reading a suggestion never counts;
///    nothing persists until the person deliberately saves an outcome.
///  * The page asks exactly one display-size question — *"How does this
///    moment feel now?"* — and accepts exactly one optional answer. The
///    acknowledgement (*"You stayed with the moment."*) is a supporting
///    line, never a headline. There is no luminous object at rest: the held
///    orb and the eyebrow ember dot are retired; the eyebrow stands alone in
///    ink. Ember appears at most once per viewport, always attached to an
///    action.
///  * The outcome is optional. Better / Same / Worse are absolutely neutral
///    before selection: all three arcs and words render in the exact same
///    soft ink through a private neutral glyph, so no honest answer is
///    pre-warmed. Selection alone warms — the chosen option composes the
///    shared [DegreeGraphics] outcome glyph in its selected treatment.
///    Shape + word carry the meaning, never color alone. Skipping records
///    nothing and loses nothing.
///  * Skip (`Skip — nothing needs saving`) and Android/system back from the
///    unsaved stage persist nothing and delegate to [onSkip]. The saved
///    stage has exactly one exit, labeled exactly `Return to daylight`,
///    rendered in flow (never pinned), and saved-stage system back is
///    intercepted here and routed to [onLeaveCare]. `Leave for now` never
///    renders in this flow.
///  * Saving settles; it does not celebrate. The question crossfades into
///    the settled outcome unit — no pulse, no halo, no breathing element.
///  * After completion, optional work lives below the exit as quiet
///    postscript rows — a health note (when [saveReceipt] is wired) and a
///    reflection — each collapsing to a one-line confirmation once saved or
///    declined. Declining never invalidates the saved check-back.
///  * The RecoveryReceipt is offered **separately**, per use, as a stepped
///    sheet: signal → severity → a deliberate `More` disclosure for
///    additional physical signals (physical-category-only, deduped against
///    the main signal, inheriting the main severity with a disclosed
///    `Change` override written through
///    [RecoveryReceiptDraft.additionalPhysicalSignalSeverities]) and
///    functional impact. When the mode maps to a suggested signal, the
///    signal step opens with only that suggestion and a deliberate
///    `Change signal` action — the full [RecoveryReceiptSignal] list
///    (including the complete record-nothing answers "Something else" and
///    "I do not remember") appears only after that action; for
///    [CareMode.space] the list is available from the start. The full
///    symptom catalog is never exposed for the main signal. Pain-kind
///    signals ask degree through the shared pain card in the same five
///    named [SymptomSeverity] levels — never a numeric score; cancelling
///    discards the unfinished degree. Provenance derives from
///    [recoveryReceiptProvenance] and is surfaced honestly before and after
///    save.
///  * Both sheets pin their header — title plus a persistent 44pt
///    `Not now` — outside the scrolling body, so the exit never scrolls
///    away and stays reachable at 200% text with the keyboard open.
///  * The reflection sheet is the Letter Desk: the whole sheet body is one
///    [ExperiencePaper] inset ringed by dusk. It opens with a single paper
///    field and the save action — one thought is enough — and
///    `Add another thought` progressively discloses the need chips and the
///    remaining fields. Writing is intentionally unconstrained, controllers
///    are owned by this landing so an interrupted sheet keeps its draft,
///    and [CareMemoryException.userMessage] surfaces verbatim on failure.
///  * Primary-action labels sit on a lightened ember treatment in dark
///    plum ink — the complete label area meets the 4.5:1 body floor; no
///    outer glow is restored.
///  * Errors are live-region text in the error color — visual + textual
///    only, never haptic, never ember.
class CareCompletionFlow extends StatefulWidget {
  const CareCompletionFlow({
    super.key,
    required this.mode,
    required this.completion,
    required this.careMemoryRepository,
    required this.onLeaveCare,
    this.saveReceipt,
    this.onDataChanged,
    this.onResumeScene,
    this.resumeHint,
    required this.onSkip,
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
  /// postscript is not offered at all.
  final Future<RecoveryReceiptResult> Function(RecoveryReceiptDraft draft)?
  saveReceipt;

  /// Reconciles local forecasts, reminders, Kit presence, and report reads
  /// after a successful Care-side write. Failure here never rolls back the
  /// record the person deliberately saved.
  final Future<void> Function()? onDataChanged;

  /// Leave the Care world back to daylight. This is the saved page's single
  /// exit, labeled exactly `Return to daylight`.
  final VoidCallback onLeaveCare;

  /// Skip the unsaved check-back: persists nothing and returns to the Care
  /// landing. Android/system back from the unsaved stage routes here too.
  final VoidCallback onSkip;

  /// Continue an interrupted scene (interruption recovery).
  final VoidCallback? onResumeScene;

  /// Named recovery copy for an interrupted scene, e.g. "You were in the
  /// middle of Release. Continue, check in, or leave it here."
  final String? resumeHint;

  /// Routes to the deterministic safety surface.
  final VoidCallback? onOpenSafety;

  final CareSceneMotionPreference motionPreference;

  /// Testable clock.
  final DateTime Function()? now;

  @override
  State<CareCompletionFlow> createState() => _CareCompletionFlowState();
}

enum _LandingStage { checkIn, checkedIn }

/// Dark-plum on-ember ink, matching the theme's `onEmber` token. Over the
/// lightened ember treatment in [_EmberAction], the complete label area
/// holds ≥4.5:1 — no glow, no white-on-coral.
const Color _onEmberInk = Color(0xFF241019);

class _CareCompletionFlowState extends State<CareCompletionFlow> {
  _LandingStage _stage = _LandingStage.checkIn;

  CareOutcome? _selectedOutcome;
  bool _savingOutcome = false;
  String? _outcomeError;

  CareRecord? _record;
  String? _ackLine;

  bool _receiptDismissed = false;
  RecoveryReceiptResult? _receiptResult;

  bool _reflectionSaved = false;

  // Reflection draft lives here so an interrupted sheet keeps its words.
  final TextEditingController _observationController = TextEditingController();
  final TextEditingController _whatHelpedController = TextEditingController();
  final TextEditingController _futureSelfController = TextEditingController();
  ReflectionNeed? _reflectionNeed;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  Future<void> _notifyDataChanged() async {
    try {
      await widget.onDataChanged?.call();
    } on Object {
      // The source write already succeeded. Derived surfaces can refresh on
      // the next lifecycle/read boundary without turning this into an error.
    }
  }

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
      await _notifyDataChanged();
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
    // While a save is in flight there is nothing to skip and retry must not
    // duplicate records; the unsaved stage simply stays put.
    if (_savingOutcome) return;
    ExperienceHaptics.pick();
    widget.onSkip();
  }

  Future<void> _openReceipt() async {
    final record = _record;
    final saveReceipt = widget.saveReceipt;
    if (record == null || saveReceipt == null) return;
    ExperienceHaptics.pick();
    final result = await showExperienceSheet<RecoveryReceiptResult>(
      context,
      careWorld: true,
      dominant: true,
      child: _RecoveryReceiptSheet(
        record: record,
        completion: widget.completion,
        saveReceipt: saveReceipt,
        motionPreference: widget.motionPreference,
        now: widget.now,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      // Declining or cancelling the note leaves the saved check-back fully
      // valid; the page never asks twice, so the doorway settles into its
      // one-line confirmation.
      setState(() => _receiptDismissed = true);
      return;
    }
    await _notifyDataChanged();
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

  Future<void> _openReflection() async {
    final record = _record;
    if (record == null) return;
    ExperienceHaptics.pick();
    final saved = await showExperienceSheet<bool>(
      context,
      careWorld: true,
      dominant: true,
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
    await _notifyDataChanged();
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
    final body = Semantics(
      container: true,
      label: 'Care check-back after ${widget.mode.label}',
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: ExperienceColors.careBackdrop,
          ),
          child: SafeArea(
            // One scrollable column; nothing floats over content. The exit
            // renders in flow, so large text pushes content instead of
            // colliding with a pinned footer.
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                ExperienceSpacing.screenMargin,
                ExperienceSpacing.sm,
                ExperienceSpacing.screenMargin,
                ExperienceSpacing.scrollBottomPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: _Eyebrow(label: widget.mode.label),
                      ),
                      const SizedBox(height: ExperienceSpacing.lg),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        // The threshold: the question crossfades into the
                        // settled unit — one motion, one moment, resolved
                        // from the threaded motion preference.
                        child: AnimatedSwitcher(
                          duration: CareSceneFoundation.stepTransition(
                            widget.motionPreference,
                          ),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeOut,
                          child: _stage == _LandingStage.checkIn
                              ? _buildCheckInContent()
                              : _buildSettledContent(),
                        ),
                      ),
                      const SizedBox(height: ExperienceSpacing.md),
                      // The quiet safety line persists in both page stages,
                      // at the end of the scroll content, never inside the
                      // sheets.
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(4),
                        child: _QuietSafetyLine(onTap: widget.onOpenSafety),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Unsaved back is Skip (zero persistence); saved-stage back mirrors the
    // sanctioned exit — the invariant is guaranteed by the flow itself.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_stage == _LandingStage.checkIn) {
          _skipOutcome();
        } else {
          widget.onLeaveCare();
        }
      },
      child: body,
    );
  }

  Widget _buildCheckInContent() {
    return Column(
      key: const ValueKey<String>('check-in'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.resumeHint != null) ...<Widget>[
          _ResumeLine(
            hint: widget.resumeHint!,
            onContinue: widget.onResumeScene,
          ),
          const SizedBox(height: ExperienceSpacing.md),
        ],
        // The one display thought on the unsaved page.
        Text(
          'How does this moment feel now?',
          style: ExperienceType.title(ExperienceColors.careInk),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ExperienceSpacing.md),
        Row(
          children: <Widget>[
            for (final outcome in DegreeGraphics.outcomes)
              Expanded(
                child: _OutcomeOption(
                  outcome: outcome,
                  selected: _selectedOutcome == outcome,
                  onTap: _savingOutcome
                      ? null
                      : () {
                          ExperienceHaptics.pick();
                          setState(() => _selectedOutcome = outcome);
                        },
                ),
              ),
          ],
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'Choose what fits — or skip. Nothing is recorded until you save.',
          style: ExperienceType.caption(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ExperienceSpacing.lg),
        _EmberAction(
          label: _savingOutcome ? 'Saving…' : 'Save this check-back',
          onPressed: _selectedOutcome == null || _savingOutcome
              ? null
              : _saveOutcome,
        ),
        if (_outcomeError != null)
          Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _outcomeError!,
                style: ExperienceType.caption(ExperienceColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const SizedBox(height: ExperienceSpacing.sm),
        // Skip is a first-class, fully visible exit from the question —
        // its own quiet row, never tucked under the primary action.
        _QuietExitRow(
          label: 'Skip — nothing needs saving',
          strong: true,
          onPressed: _savingOutcome ? null : _skipOutcome,
        ),
        const SizedBox(height: ExperienceSpacing.xl),
        // The acknowledgement validates; it never headlines.
        Text(
          'You stayed with the moment.',
          style: ExperienceType.caption(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'However it went, showing up was the whole of '
          'it. Nothing needs fixing now.',
          style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSettledContent() {
    final record = _record;
    final receiptResult = _receiptResult;
    return Column(
      key: const ValueKey<String>('settled'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The settled unit: arc + word + record line. Static; the page
        // settles, nothing celebrates.
        if (record != null) _SettledUnit(record: record),
        const SizedBox(height: ExperienceSpacing.sm),
        Center(child: SavedRhythmAckLine(line: _ackLine, careWorld: true)),
        const SizedBox(height: ExperienceSpacing.lg),
        // The single exit, in flow — the settled page's one coral element.
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: _EmberAction(
            label: 'Return to daylight',
            onPressed: widget.onLeaveCare,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xl),
        // Postscripts: optional work, deliberately after the point of
        // completion — quiet hairline rows, visually subordinate to the
        // exit, ink only.
        if (widget.saveReceipt != null &&
            receiptResult == null &&
            !_receiptDismissed)
          _PostscriptRow(
            label: 'Add a health note — optional',
            semanticsLabel: 'Add a health note. Optional.',
            onTap: _openReceipt,
          ),
        if (_receiptDismissed && receiptResult == null)
          const _PostscriptConfirmation(
            line: 'Nothing else was added — your check-back stands.',
          ),
        if (receiptResult != null)
          _PostscriptConfirmation(
            line: receiptResult.provenance == HealthRecordProvenance.sameDay
                ? 'Health note saved — same-day record.'
                : 'Health note saved — later recall, and it still counts.',
          ),
        if (!_reflectionSaved)
          _PostscriptRow(
            label: 'A few words for future you — optional',
            semanticsLabel: 'Write a few words for future you. Optional.',
            onTap: _openReflection,
          )
        else
          const _PostscriptConfirmation(
            line: 'Reflection kept for future you.',
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Landing pieces
// ---------------------------------------------------------------------------

/// The mode eyebrow. It stands alone in ink — the former coral dot read as
/// a recording indicator and broke the one-coral rule in selected states,
/// so no luminous object accompanies it.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: ExperienceType.eyebrow(ExperienceColors.careInkSoft),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Interruption recovery as the first quiet line inside the content region —
/// a continuation sentence with a 44pt `Continue` action, never a card, and
/// never competing with the question.
class _ResumeLine extends StatelessWidget {
  const _ResumeLine({required this.hint, required this.onContinue});

  final String hint;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          hint,
          style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
        if (onContinue != null)
          Semantics(
            button: true,
            label: 'Continue where you left off',
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  ExperienceSpacing.minTouchTarget,
                  ExperienceSpacing.minTouchTarget,
                ),
              ),
              onPressed: onContinue,
              child: Text(
                'Continue',
                style: ExperienceType.label(ExperienceColors.careInk),
              ),
            ),
          ),
      ],
    );
  }
}

/// One of the three honest answers. Borderless at rest — ink glyph and word
/// on bare dusk, identical container for all three so no card bias and no
/// valence smuggling. **Absolute neutrality before selection:** all three
/// arcs and words render in the exact same soft ink through the private
/// [_NeutralOutcomeGlyph]; the shared [DegreeGraphics] glyph — whose Better
/// arc is ember by its own vocabulary — composes only after selection, so
/// coral appears exclusively on the answer the person chose.
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
          duration: _selectionDuration(context),
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.xs,
            vertical: ExperienceSpacing.xs * 2,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0x29FFFFFF) : Colors.transparent,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected ? ExperienceColors.emberSoft : Colors.transparent,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ExcludeSemantics(
            child: Center(
              child: selected
                  ? DegreeGraphics.outcome(
                      outcome,
                      selected: true,
                      careWorld: true,
                    )
                  : _NeutralOutcomeGlyph(outcome: outcome),
            ),
          ),
        ),
      ),
    );
  }
}

/// The resting outcome glyph: the three shared arc shapes (up-arc, level
/// line, softened down-arc) redrawn privately in one neutral soft ink with
/// the word beneath in the same ink. Shape and word carry the meaning;
/// before selection no answer is warmer than another. The shared
/// [DegreeGraphics] outcome glyph owns the selected appearance.
class _NeutralOutcomeGlyph extends StatelessWidget {
  const _NeutralOutcomeGlyph({required this.outcome});

  final CareOutcome outcome;

  @override
  Widget build(BuildContext context) {
    const ink = ExperienceColors.careInkSoft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 36 * 1.6,
          height: 36,
          child: CustomPaint(
            painter: _NeutralOutcomeArcPainter(outcome: outcome, color: ink),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          DegreeGraphics.outcomeLabel(outcome),
          style: ExperienceType.caption(ink),
        ),
      ],
    );
  }
}

/// The three outcome arc shapes, verbatim in geometry, in a single caller-
/// supplied ink. Kept private to this file so the shared vocabulary in
/// [DegreeGraphics] is never modified.
final class _NeutralOutcomeArcPainter extends CustomPainter {
  const _NeutralOutcomeArcPainter({required this.outcome, required this.color});

  final CareOutcome outcome;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, h * 0.12)
      ..strokeCap = StrokeCap.round;

    switch (outcome) {
      case CareOutcome.better:
        // Up-arc: rises and ends high.
        final path = Path()
          ..moveTo(w * 0.06, h * 0.72)
          ..quadraticBezierTo(w * 0.5, -h * 0.22, w * 0.94, h * 0.3);
        canvas.drawPath(path, paint);
      case CareOutcome.same:
        // Level line.
        canvas.drawLine(
          Offset(w * 0.08, h * 0.5),
          Offset(w * 0.92, h * 0.5),
          paint,
        );
      case CareOutcome.worse:
        // Softened down-arc: sags and ends lower than it began.
        final path = Path()
          ..moveTo(w * 0.06, h * 0.28)
          ..quadraticBezierTo(w * 0.5, h * 1.18, w * 0.94, h * 0.66);
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_NeutralOutcomeArcPainter oldDelegate) {
    return oldDelegate.outcome != outcome || oldDelegate.color != color;
  }
}

/// The settled outcome: the chosen arc in its selected treatment with its
/// word, and the quiet record line beneath. The record line informs; it does
/// not perform.
class _SettledUnit extends StatelessWidget {
  const _SettledUnit({required this.record});

  final CareRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: DegreeGraphics.outcome(
            record.outcome,
            selected: true,
            careWorld: true,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'You recorded “${record.actionLabel}”.',
          style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// An optional doorway after completion: a full-width, 48pt-minimum text row
/// with a hairline top border, a sans label in ink, and a trailing quiet ›.
/// Never a filled card, never a serif headline, never ember text.
class _PostscriptRow extends StatelessWidget {
  const _PostscriptRow({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: ExperienceColors.careGlassBorder),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: ExperienceType.label(ExperienceColors.careInk),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  '›',
                  style: ExperienceType.label(ExperienceColors.careInkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-line confirmation a postscript row collapses into once its work
/// is saved or declined — caption weight, hairline-divided like the row it
/// replaces.
class _PostscriptConfirmation extends StatelessWidget {
  const _PostscriptConfirmation({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: ExperienceSpacing.minTouchTarget,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: ExperienceColors.careGlassBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          line,
          style: ExperienceType.caption(ExperienceColors.careInkSoft),
        ),
      ),
    );
  }
}

/// The quiet safety line. Quiet in weight, never in reach: the full
/// interactive route holds an explicit 44pt minimum height while the visual
/// treatment stays a soft caption with a small heart mark.
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
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: ExperienceSpacing.xs),
            child: text,
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: CareSceneFoundation.defaultSafetyLine,
      child: InkWell(
        borderRadius: ExperienceRadius.chipRadius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          child: Center(
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
        ),
      ),
    );
  }
}

/// The one primary-action treatment: full-width ember pill, no outer glow
/// shadow. The enabled treatment carries a constant soft light wash over
/// the ember gradient so the dark-plum label holds ≥4.5:1 across the
/// complete label area; the disabled state is a quiet hairline-outline
/// treatment — glass fill, soft-ink label — obviously unavailable, never
/// glowing, never error-colored, never dimmed-bright.
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
        child: DecoratedBox(
          decoration: enabled
              ? const BoxDecoration(
                  gradient: ExperienceColors.emberGradient,
                  borderRadius: ExperienceRadius.heroRadius,
                )
              : BoxDecoration(
                  color: ExperienceColors.careGlass,
                  borderRadius: ExperienceRadius.heroRadius,
                  border: Border.all(color: ExperienceColors.careGlassBorder),
                ),
          child: DecoratedBox(
            // The wash lifts every gradient stop uniformly, so the label's
            // contrast floor is met at the brightest and the deepest point
            // alike — measured, not claimed. No glow is restored.
            decoration: enabled
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: ExperienceRadius.heroRadius,
                  )
                : const BoxDecoration(),
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
                    style: ExperienceType.label(
                      enabled ? _onEmberInk : ExperienceColors.careInkSoft,
                    ),
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

/// A quiet exit: leave without consequence. Enforces the 44pt minimum and
/// the soft-ink label everywhere — skip rows, header "Not now" actions,
/// bottom cancels, and the graceful-note close.
class _QuietExitRow extends StatelessWidget {
  const _QuietExitRow({
    required this.label,
    required this.onPressed,
    this.strong = false,
    this.color = ExperienceColors.careInkSoft,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Label weight instead of caption — for first-class exits like Skip and
  /// header "Not now" actions.
  final bool strong;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? ExperienceType.label(color)
        : ExperienceType.caption(color);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            ExperienceSpacing.minTouchTarget,
            ExperienceSpacing.minTouchTarget,
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: style, textAlign: TextAlign.center),
      ),
    );
  }
}

/// A sheet header: the title plus a persistent right-aligned 44pt "Not now"
/// text action, so the sheet is always exitable from the top — even at 200%
/// text with the keyboard covering the bottom actions. The title takes the
/// full remaining width and wraps cleanly beneath itself; the exit keeps
/// its own unambiguous, never-squeezed space.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.onNotNow,
    this.serifTitle = false,
  });

  final String title;
  final VoidCallback? onNotNow;

  /// Georgia is retained for the Letter Desk title only; every other sheet
  /// title is sans.
  final bool serifTitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = serifTitle
        ? ExperienceType.title(ExperienceColors.careInk)
        : ExperienceType.bodyStrong(
            ExperienceColors.careInk,
          ).copyWith(fontSize: 19, height: 28 / 19);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(title, style: titleStyle),
            ),
          ),
        ),
        const SizedBox(width: ExperienceSpacing.xs),
        Semantics(
          button: true,
          label: 'Not now',
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(
                ExperienceSpacing.minTouchTarget,
                ExperienceSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.xs * 2,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onNotNow,
            child: Text(
              'Not now',
              style: ExperienceType.label(ExperienceColors.careInkSoft),
            ),
          ),
        ),
      ],
    );
  }
}

/// A deliberate disclosure row — `More`, `Add another thought` — that
/// expands optional vocabulary in place. Count-free label, 44pt target,
/// expansion survives scroll, and the motion collapses to instant when the
/// platform asks for reduced motion.
class _Disclosure extends StatefulWidget {
  const _Disclosure({
    required this.label,
    required this.child,
    this.onPaper = false,
  });

  final String label;
  final Widget child;

  /// Paper-material variant for the Letter Desk.
  final bool onPaper;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ink = widget.onPaper ? ExperiencePaper.ink : ExperienceColors.careInk;
    final inkSoft = widget.onPaper
        ? ExperiencePaper.inkSoft
        : ExperienceColors.careInkSoft;
    final duration = ExperienceMotion.reducedMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _open,
          label: widget.label,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: ExperienceRadius.chipRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: ExperienceSpacing.minTouchTarget,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(widget.label, style: ExperienceType.label(ink)),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      _open
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: ExperienceSpacing.sm),
            child: widget.child,
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: duration,
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

Duration _selectionDuration(BuildContext context) {
  if (ExperienceMotion.reducedMotion(context)) {
    return Duration.zero;
  }
  return ExperienceMotion.chipSelect;
}

// ---------------------------------------------------------------------------
// RecoveryReceipt sheet — the stepped, per-use health note on dusk glass.
// The header (title + persistent 44pt "Not now") is pinned outside the
// scrolling body, so the exit never scrolls away — at any text scale, with
// or without the keyboard.
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
  final Map<SymptomType, SymptomSeverity> _severityOverrides =
      <SymptomType, SymptomSeverity>{};
  final Set<FunctionalImpact> _impacts = <FunctionalImpact>{};

  /// The additional signal whose per-signal degree editor is open, if any.
  SymptomType? _editingSignal;

  /// The contextual suggestion for this mode, when one exists.
  RecoveryReceiptSignal? _suggested;

  /// Whether the person has deliberately opened the full receipt-signal
  /// list. When a suggestion exists, the sheet opens with only that
  /// suggestion and a `Change signal` action — never the option wall.
  bool _signalListExpanded = false;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Modes with a suggested signal start there; space starts with the free
    // signal list and nothing preselected.
    _suggested = _suggestedSignal();
    _signal = _suggested;
  }

  RecoveryReceiptSignal? _suggestedSignal() {
    final symptom = suggestedSymptomForCare(widget.record);
    if (symptom == null) return null;
    for (final signal in RecoveryReceiptSignal.values) {
      if (signal.symptom == symptom) return signal;
    }
    return null;
  }

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

  void _selectSignal(RecoveryReceiptSignal option) {
    ExperienceHaptics.pick();
    setState(() {
      _signal = option;
      _error = null;
      // Changing the main signal can never leave it duplicated in the
      // additional physical step — nor keep a stale override for it.
      final main = option.symptom;
      if (main != null) {
        _additionalSignals.remove(main);
        _severityOverrides.remove(main);
        if (_editingSignal == main) _editingSignal = null;
      }
    });
  }

  void _toggleAdditionalSignal(SymptomType type) {
    ExperienceHaptics.pick();
    setState(() {
      if (_additionalSignals.contains(type)) {
        _additionalSignals.remove(type);
        // Removing the signal also removes its override — reverting to
        // inherit removes the key.
        _severityOverrides.remove(type);
        if (_editingSignal == type) _editingSignal = null;
      } else {
        _additionalSignals.add(type);
      }
    });
  }

  void _setOverride(SymptomType type, SymptomSeverity degree) {
    ExperienceHaptics.pick();
    setState(() {
      if (_severity != null && degree == _severity) {
        // Choosing the main severity reverts to inheritance.
        _severityOverrides.remove(type);
      } else {
        _severityOverrides[type] = degree;
      }
      _editingSignal = null;
    });
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
          additionalPhysicalSignalSeverities:
              Map<SymptomType, SymptomSeverity>.of(_severityOverrides),
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

  /// Step 1's decision surface. With a contextual suggestion, the sheet
  /// opens with only that suggestion plus a deliberate 44pt `Change signal`
  /// action; the full [RecoveryReceiptSignal] list (never the full symptom
  /// catalog) appears only after it. Without a suggestion — CareMode.space —
  /// the receipt-signal list is available from the start.
  Widget _buildSignalChoices() {
    final suggested = _suggested;
    if (suggested != null && !_signalListExpanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: ExperienceSpacing.xs * 2,
            runSpacing: ExperienceSpacing.xs * 2,
            children: <Widget>[
              _CareChoiceChip(
                label: suggested.label,
                semanticsLabel: 'Signal: ${suggested.label}',
                selected: _signal == suggested,
                onTap: _saving ? null : () => _selectSignal(suggested),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Change signal — show every signal for this note',
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    ExperienceSpacing.minTouchTarget,
                    ExperienceSpacing.minTouchTarget,
                  ),
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() => _signalListExpanded = true),
                child: Text(
                  'Change signal',
                  style: ExperienceType.label(ExperienceColors.careInk),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: ExperienceSpacing.xs * 2,
      runSpacing: ExperienceSpacing.xs * 2,
      children: <Widget>[
        for (final option in RecoveryReceiptSignal.values)
          _CareChoiceChip(
            label: option.label,
            semanticsLabel: 'Signal: ${option.label}',
            selected: _signal == option,
            onTap: _saving ? null : () => _selectSignal(option),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final signal = _signal;
    final symptom = signal?.symptom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Persistent header: the top exit never scrolls away.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.screenMargin,
          ),
          child: _SheetHeader(
            title: 'What was this moment?',
            onNotNow: _saving ? null : _cancel,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Flexible(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              ExperienceSpacing.screenMargin,
              0,
              ExperienceSpacing.screenMargin,
              ExperienceSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Kept light on purpose — a signal, its intensity, and pain '
                  'only if it was present.',
                  style: ExperienceType.bodySmall(ExperienceColors.careInkSoft),
                ),
                const SizedBox(height: ExperienceSpacing.lg),

                // --- Step 1, signal: the contextual suggestion alone when
                // the mode maps to one; the full receipt signal list (never
                // the full catalog) only after a deliberate `Change signal`,
                // or from the start for space. -----------------------------
                Text(
                  'The signal',
                  style: ExperienceType.bodyStrong(ExperienceColors.careInk),
                ),
                if (_suggested != null)
                  Padding(
                    padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
                    child: Text(
                      'Suggested from this moment — change it if another fits '
                      'better.',
                      style: ExperienceType.caption(
                        ExperienceColors.careInkSoft,
                      ),
                    ),
                  ),
                const SizedBox(height: ExperienceSpacing.sm),
                _buildSignalChoices(),
                const SizedBox(height: ExperienceSpacing.md),

                if (signal == null)
                  Text(
                    'Choose a signal above to continue — or “I do not '
                    'remember” if none fit.',
                    style: ExperienceType.caption(ExperienceColors.careInkSoft),
                  )
                else if (symptom == null)
                  _GracefulSignalNote(signal: signal, onClose: _cancel)
                else ...<Widget>[
                  // --- Step 2, degree: exactly five named degrees, never
                  // "not at all". For a pain-kind signal the shared pain
                  // card asks the same question — pain is a severity
                  // degree, never a score. ---------------------------------
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
                      style: ExperienceType.bodyStrong(
                        ExperienceColors.careInk,
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.sm),
                    for (final severity in SymptomSeverity.values)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: ExperienceSpacing.xs,
                        ),
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

                  // --- Step 3, `More`: a deliberate disclosure keeps the
                  // option wall out of the first viewport. Additional
                  // physical signals (physical-category-only, deduped
                  // against main) and what the moment affected live behind
                  // it. -----------------------------------------------------
                  _Disclosure(
                    label: 'Add more — other signals, what it affected',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Any other physical signals? (optional)',
                          style: ExperienceType.bodyStrong(
                            ExperienceColors.careInk,
                          ),
                        ),
                        const SizedBox(height: ExperienceSpacing.sm),
                        Wrap(
                          spacing: ExperienceSpacing.xs * 2,
                          runSpacing: ExperienceSpacing.xs * 2,
                          children: <Widget>[
                            for (final type in _physicalOptions)
                              _CareChoiceChip(
                                label: type.label,
                                semanticsLabel:
                                    'Additional physical signal: ${type.label}',
                                selected: _additionalSignals.contains(type),
                                onTap: _saving
                                    ? null
                                    : () => _toggleAdditionalSignal(type),
                              ),
                          ],
                        ),
                        if (_additionalSignals.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: ExperienceSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (final type in _additionalSignals)
                                  _AdditionalSignalRow(
                                    key: ValueKey<SymptomType>(type),
                                    signal: type,
                                    mainSeverity: _severity,
                                    degreeOverride: _severityOverrides[type],
                                    editing: _editingSignal == type,
                                    enabled: !_saving,
                                    onToggleEdit: () {
                                      setState(
                                        () => _editingSignal =
                                            _editingSignal == type
                                            ? null
                                            : type,
                                      );
                                    },
                                    onDegreeChosen: (degree) =>
                                        _setOverride(type, degree),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: ExperienceSpacing.md),
                        Text(
                          'Did it get in the way of anything? (optional)',
                          style: ExperienceType.bodyStrong(
                            ExperienceColors.careInk,
                          ),
                        ),
                        const SizedBox(height: ExperienceSpacing.sm),
                        Wrap(
                          spacing: ExperienceSpacing.xs * 2,
                          runSpacing: ExperienceSpacing.xs * 2,
                          children: <Widget>[
                            for (final impact in FunctionalImpact.values)
                              _CareChoiceChip(
                                label: impact.label,
                                semanticsLabel:
                                    'Functional impact: ${impact.label}',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: ExperienceSpacing.md),

                  // Provenance is shown honestly before save — and echoed
                  // after.
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
                          style: ExperienceType.caption(ExperienceColors.error),
                        ),
                      ),
                    ),
                  const SizedBox(height: ExperienceSpacing.md),
                  _EmberAction(
                    label: _saving ? 'Saving…' : 'Save health note',
                    // Severity is part of the health claim, not an optional
                    // embellishment. Keep the action visually quiet and
                    // inert until the person has named it.
                    onPressed: _saving || _severity == null ? null : _save,
                  ),
                  _QuietExitRow(
                    label: 'Cancel — discard this note',
                    onPressed: _saving ? null : _cancel,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One additional physical signal with its inheritance line and `Change`
/// action. Additional signals inherit the main severity unless the person
/// deliberately overrides the degree; the override is written through
/// `additionalPhysicalSignalSeverities`, and reverting to the main degree
/// removes the key.
class _AdditionalSignalRow extends StatelessWidget {
  const _AdditionalSignalRow({
    super.key,
    required this.signal,
    required this.mainSeverity,
    required this.degreeOverride,
    required this.editing,
    required this.enabled,
    required this.onToggleEdit,
    required this.onDegreeChosen,
  });

  final SymptomType signal;
  final SymptomSeverity? mainSeverity;
  final SymptomSeverity? degreeOverride;
  final bool editing;
  final bool enabled;
  final VoidCallback onToggleEdit;
  final ValueChanged<SymptomSeverity> onDegreeChosen;

  @override
  Widget build(BuildContext context) {
    final override = degreeOverride;
    final main = mainSeverity;
    final inheritance = override != null
        ? 'Its own degree: ${override.label}'
        : main != null
        ? 'Same as main: ${main.label}'
        : 'Inherits the main intensity';
    return Padding(
      padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            signal.label,
            style: ExperienceType.label(ExperienceColors.careInk),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  inheritance,
                  style: ExperienceType.caption(ExperienceColors.careInkSoft),
                ),
              ),
              Semantics(
                button: true,
                label: 'Change the degree for ${signal.label}',
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      ExperienceSpacing.minTouchTarget,
                      ExperienceSpacing.minTouchTarget,
                    ),
                  ),
                  onPressed: enabled ? onToggleEdit : null,
                  child: Text(
                    editing ? 'Done' : 'Change',
                    style: ExperienceType.label(ExperienceColors.careInk),
                  ),
                ),
              ),
            ],
          ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: ExperienceSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final severity in SymptomSeverity.values)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: ExperienceSpacing.xs,
                      ),
                      child: _SeverityRow(
                        severity: severity,
                        selected: (override ?? main) == severity,
                        onTap: () => onDegreeChosen(severity),
                      ),
                    ),
                  Text(
                    'Choosing the main degree returns this signal to '
                    'inheriting it.',
                    style: ExperienceType.caption(ExperienceColors.careInkSoft),
                  ),
                ],
              ),
            ),
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
          _QuietExitRow(
            label: 'Close — nothing more to add',
            strong: true,
            color: ExperienceColors.careInk,
            onPressed: onClose,
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
          duration: _selectionDuration(context),
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
    this.onPaper = false,
  });

  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback? onTap;

  /// Paper-material variant for the Letter Desk need chips: paper fill,
  /// paper hairline, ember selection border, paper ink label.
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final Color text;
    if (onPaper) {
      fill = selected
          ? ExperienceColors.emberSoft.withValues(alpha: 0.16)
          : ExperiencePaper.surface;
      border = selected ? ExperienceColors.ember : ExperiencePaper.hairline;
      text = ExperiencePaper.ink;
    } else {
      fill = selected ? const Color(0x29FFFFFF) : ExperienceColors.careGlass;
      border = selected
          ? ExperienceColors.emberSoft
          : ExperienceColors.careGlassBorder;
      text = ExperienceColors.careInk;
    }
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: _selectionDuration(context),
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Text(label, style: ExperienceType.label(text)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reflection sheet — the Letter Desk: one coherent paper inset ringed by
// dusk. One inviting writing action opens it; `Add another thought`
// progressively discloses the rest. Writing has no character counter or
// artificial brevity constraint. The header (serif title + persistent 44pt
// "Not now") is pinned outside the scrolling
// body, so the exit stays reachable when the keyboard covers the bottom
// actions.
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
      // Ready-made validation copy from the repository keeps storage errors
      // and the one-thought minimum consistent.
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

  void _leave() {
    // Both exits keep the draft: the controllers live on the landing, so an
    // interrupted sheet keeps its words while this check-back is open.
    Navigator.of(context).pop(false);
  }

  /// One writing surface on the desk: paper fill, paper ink text, a
  /// readable hint and counter in paper soft ink, and an ember focus border.
  Widget _paperField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Text(
            label,
            style: ExperienceType.bodyStrong(ExperiencePaper.ink),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.xs),
        Semantics(
          label: label,
          textField: true,
          child: TextField(
            controller: controller,
            enabled: !_saving,
            maxLines: 8,
            minLines: 4,
            style: ExperienceType.body(ExperiencePaper.ink),
            cursorColor: ExperienceColors.ember,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: ExperienceType.bodySmall(ExperiencePaper.inkSoft),
              filled: true,
              fillColor: ExperiencePaper.surface,
              contentPadding: const EdgeInsets.all(ExperienceSpacing.sm),
              border: OutlineInputBorder(
                borderRadius: ExperienceRadius.chipRadius,
                borderSide: const BorderSide(color: ExperiencePaper.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ExperienceRadius.chipRadius,
                borderSide: const BorderSide(color: ExperiencePaper.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ExperienceRadius.chipRadius,
                borderSide: const BorderSide(color: ExperienceColors.ember),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The desk header stays pinned on the dusk ring — its "Not now" is
        // the guaranteed exit when the keyboard covers the bottom actions.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.screenMargin,
          ),
          child: _SheetHeader(
            title: 'A few words for future you',
            serifTitle: true,
            onNotNow: _saving ? null : _leave,
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Flexible(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              ExperienceSpacing.screenMargin,
              0,
              ExperienceSpacing.screenMargin,
              ExperienceSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The Letter Desk: one coherent paper material holding every
                // field, chip, counter, and the save action — paper you
                // hold, ringed by the dusk you live in.
                Container(
                  decoration: BoxDecoration(
                    color: ExperiencePaper.canvas,
                    borderRadius: ExperienceRadius.cardRadius,
                    border: Border.all(color: ExperiencePaper.hairline),
                    boxShadow: ExperienceShadows.card,
                  ),
                  padding: const EdgeInsets.all(ExperienceSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Write as much as you need. It stays on this device.',
                        style: ExperienceType.bodySmall(
                          ExperiencePaper.inkSoft,
                        ),
                      ),
                      const SizedBox(height: ExperienceSpacing.md),
                      _paperField(
                        label: 'What was this moment like?',
                        controller: widget.observationController,
                        hint: 'Say what you need to say.',
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: ExperienceSpacing.sm,
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: ExperienceType.caption(
                                ExperiencePaper.error,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: ExperienceSpacing.md),
                      // Save is available from the opening state — one
                      // thought is enough.
                      _EmberAction(
                        label: _saving ? 'Saving…' : 'Keep this reflection',
                        onPressed: _saving ? null : _save,
                      ),
                      const SizedBox(height: ExperienceSpacing.sm),
                      _Disclosure(
                        label: 'Add another thought',
                        onPaper: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'What did this moment need?',
                              style: ExperienceType.bodyStrong(
                                ExperiencePaper.ink,
                              ),
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
                                    onPaper: true,
                                    onTap: _saving
                                        ? null
                                        : () {
                                            ExperienceHaptics.pick();
                                            setState(
                                              () => _need = _need == need
                                                  ? null
                                                  : need,
                                            );
                                            widget.onNeedChanged(_need);
                                          },
                                  ),
                              ],
                            ),
                            const SizedBox(height: ExperienceSpacing.md),
                            _paperField(
                              label: 'What helped, even a little?',
                              controller: widget.whatHelpedController,
                              hint: 'Warmth, quiet, a message sent…',
                            ),
                            const SizedBox(height: ExperienceSpacing.sm),
                            _paperField(
                              label: 'A note to future you',
                              controller: widget.futureSelfController,
                              hint:
                                  'Something the next hard moment should '
                                  'hear.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ExperienceSpacing.sm),
                      Text(
                        'Your draft stays here while this check-back is open.',
                        style: ExperienceType.caption(ExperiencePaper.inkSoft),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ExperienceSpacing.sm),
                _QuietExitRow(
                  label: 'Not now — keep my draft',
                  onPressed: _saving ? null : _leave,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
