import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_brand_mark.dart';
import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_memory_repository.dart';
import '../domain/care_mode.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../health_records/presentation/health_record_form_screen.dart';
import '../../recovery_receipt/application/recovery_receipt_controller.dart';
import '../../recovery_receipt/presentation/recovery_receipt_flow.dart';
import 'breath_flow.dart';
import 'care_break_flow.dart';
import 'care_checkback_flow.dart';
import 'care_toolkit_screen.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({
    required this.onNavigationSelected,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    super.key,
    this.now,
    this.initialMode,
    this.initialQuickReset = false,
    this.initialToolkit = false,
  });

  final ValueChanged<int> onNavigationSelected;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final DateTime Function()? now;
  final CareMode? initialMode;
  final bool initialQuickReset;
  final bool initialToolkit;

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  CareMode? _careBreakMode;
  CareActionCompletion? _pendingCompletion;
  CareRecord? _recordedCheckBack;
  bool _showRecoveryReceipt = false;
  bool _memoryBusy = false;
  bool _memoryError = false;
  Future<void> Function()? _retryMemoryOperation;

  @override
  void initState() {
    super.initState();
    _careBreakMode = widget.initialToolkit ? null : widget.initialMode;
    if (widget.initialToolkit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openToolkit());
    }
  }

  Future<void> _openToolkit() async {
    List<CareRecord> priorRecords = const [];
    try {
      priorRecords = await widget.careMemoryRepository.getRecords();
    } on Object {
      // The toolkit remains available if private memory cannot be read.
    }
    if (!mounted) return;
    final completion = await Navigator.of(context).push<CareActionCompletion>(
      MaterialPageRoute(
        builder: (context) => CareToolkitScreen(
          now: widget.now ?? DateTime.now,
          priorRecords: priorRecords,
        ),
      ),
    );
    if (completion != null && mounted) _openCheckBack(completion);
  }

  // ── Breathing ────────────────────────────────────────────────────

  Future<void> _openBreath() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            BreathFlow(onClose: () => Navigator.of(context).pop()),
      ),
    );
  }

  // ── Motion scene → practical help ─────────────────────────────────

  void _openMode(CareMode mode) {
    setState(() => _careBreakMode = mode);
  }

  void _returnToGate() {
    setState(() {
      _careBreakMode = null;
      _showRecoveryReceipt = false;
    });
  }

  void _openCheckBack(CareActionCompletion completion) {
    setState(() {
      _careBreakMode = null;
      _showRecoveryReceipt = false;
      _pendingCompletion = completion;
      _recordedCheckBack = null;
      _memoryError = false;
      _retryMemoryOperation = null;
    });
  }

  Future<void> _recordOutcome(CareOutcome outcome) async {
    final completion = _pendingCompletion;
    if (completion == null || _memoryBusy) {
      return;
    }
    setState(() {
      _memoryBusy = true;
      _memoryError = false;
      _retryMemoryOperation = null;
    });
    try {
      final record = await widget.careMemoryRepository.saveOutcome(
        completion,
        outcome,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _recordedCheckBack = record;
        _memoryBusy = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _memoryBusy = false;
        _memoryError = true;
        _retryMemoryOperation = () => _recordOutcome(outcome);
      });
    }
  }

  void _finishCheckBack() {
    setState(() {
      _pendingCompletion = null;
      _recordedCheckBack = null;
      _memoryError = false;
      _retryMemoryOperation = null;
    });
  }

  void _openRecoveryReceipt() {
    if (_recordedCheckBack == null) {
      return;
    }
    setState(() => _showRecoveryReceipt = true);
  }

  Future<void> _recordSymptoms() async {
    if (_recordedCheckBack != null) {
      _openRecoveryReceipt();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HealthRecordFormScreen(
          repository: widget.healthRecordRepository,
          now: widget.now,
        ),
      ),
    );
  }

  void _completeMotionActivity(CareMode mode, {CareOutcome? outcome}) {
    final completion = CareActionCompletion(
      mode: mode,
      actionId: 'motion.${mode.name}',
      actionLabel: switch (mode) {
        CareMode.explode => 'Safe pressure release',
        CareMode.heavy => 'Quiet presence',
        CareMode.racing => 'One-point focus',
        CareMode.space => 'Closed boundary',
        CareMode.physical => 'Warmth and rest',
      },
      occurredAt: (widget.now ?? DateTime.now)(),
    );
    _openCheckBack(completion);
    if (outcome != null) {
      unawaited(_recordOutcome(outcome));
    }
  }

  Future<void> _returnToSettledScene() async {
    final mode = _pendingCompletion?.mode;
    if (mode == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => CareBreakFlow(
          mode: mode,
          initiallySettled: true,
          onBack: () => Navigator.of(routeContext).pop(),
          onDone: () => Navigator.of(routeContext).pop(),
          onCompleted: () => Navigator.of(routeContext).pop(),
          onCheckedIn: (_) => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  void _restartMotionActivity() {
    final mode = _pendingCompletion?.mode;
    if (mode == null) return;
    setState(() {
      _pendingCompletion = null;
      _recordedCheckBack = null;
      _showRecoveryReceipt = false;
      _memoryBusy = false;
      _memoryError = false;
      _retryMemoryOperation = null;
      _careBreakMode = mode;
    });
  }

  void _closeRecoveryReceipt() {
    if (mounted) {
      setState(() => _showRecoveryReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCompletion != null) {
      if (_showRecoveryReceipt && _recordedCheckBack != null) {
        return RecoveryReceiptFlow(
          careRecord: _recordedCheckBack!,
          controller: RecoveryReceiptController(
            careMemoryRepository: widget.careMemoryRepository,
            healthRecordRepository: widget.healthRecordRepository,
            now: widget.now,
          ),
          onComplete: (_) => _closeRecoveryReceipt(),
          onSkipped: _closeRecoveryReceipt,
        );
      }
      return CareCheckBackFlow(
        onOutcome: _recordOutcome,
        onSkip: _finishCheckBack,
        onRecordSymptoms: _recordSymptoms,
        onDone: _finishCheckBack,
        recordedOutcome: _recordedCheckBack?.outcome,
        rememberedActionLabel: _recordedCheckBack?.actionLabel,
        isBusy: _memoryBusy,
        hasError: _memoryError,
        onRetry: _retryMemoryOperation,
        onReturnToScene: _canReturnToMotion ? _returnToSettledScene : null,
        onRestart: _canReturnToMotion ? _restartMotionActivity : null,
      );
    }
    final careBreakMode = _careBreakMode;
    if (careBreakMode != null) {
      return CareBreakFlow(
        mode: careBreakMode,
        sceneSeconds: widget.initialQuickReset ? 30 : 90,
        onBack: _returnToGate,
        onCompleted: () => _completeMotionActivity(careBreakMode),
        onCheckedIn: (outcome) =>
            _completeMotionActivity(careBreakMode, outcome: outcome),
        onDone: _returnToGate,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EB),
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 1,
        onSelected: widget.onNavigationSelected,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: const Key('care-gate-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                  sliver: SliverList.list(
                    children: [
                      const LetterBrandLockup(),
                      const SizedBox(height: LetterSpacing.md),
                      _CareGateHero(),
                      const SizedBox(height: LetterSpacing.lg),
                      const LetterEyebrow('Choose what should change'),
                      const SizedBox(height: LetterSpacing.sm),
                      _BreathEntry(onPressed: _openBreath),
                      const SizedBox(height: LetterSpacing.xs),
                      _ToolkitEntry(onPressed: _openToolkit),
                      const SizedBox(height: LetterSpacing.xs),
                      ...CareMode.values.map(
                        (mode) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: LetterSpacing.xs,
                          ),
                          child: CareModeEntrance(
                            mode: mode,
                            onPressed: () => _openMode(mode),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canReturnToMotion =>
      _recordedCheckBack != null &&
      (_pendingCompletion?.actionId.startsWith('motion.') ?? false);
}

class _ToolkitEntry extends StatelessWidget {
  const _ToolkitEntry({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFEAD7),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFEBC49A)),
    ),
    child: InkWell(
      key: const Key('open-care-toolkit'),
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: const Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFFFD6AE),
              child: Icon(Icons.spa_outlined, color: Color(0xFF9B642E)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Body comfort toolkit',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Warmth, movement, shower, massage, rest, or a warm drink.',
                    style: TextStyle(color: LetterColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Color(0xFF9B642E)),
          ],
        ),
      ),
    ),
  );
}

/// A quieter entry below the five care modes — no motion scene,
/// no check-back, just a breathing ring with pattern picker.
class _BreathEntry extends StatelessWidget {
  const _BreathEntry({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'I want to breathe with something. Opens a guided breathing ring.',
      child: Material(
        color: LetterColors.surface.withValues(alpha: 0.74),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: LetterColors.ink.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('care-breathe-entry'),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: LetterColors.moonMetal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(LetterRadius.control),
                    ),
                    child: const Icon(
                      Icons.air_outlined,
                      color: LetterColors.moonMetal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'I want to breathe with something',
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 16,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          'One ring, one pace — nothing to count.',
                          style: TextStyle(
                            color: LetterColors.muted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                  Icon(
                    Icons.arrow_forward,
                    color: LetterColors.ink.withValues(alpha: 0.4),
                    size: 18,
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

class CareModeEntrance extends StatelessWidget {
  const CareModeEntrance({
    required this.mode,
    required this.onPressed,
    super.key,
  });

  final CareMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${mode.label}. ${mode.gateDescription}. Opens a finite motion scene.',
      child: Material(
        color: LetterColors.surface.withValues(alpha: 0.74),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: LetterColors.ink.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('care-mode-${mode.name}'),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  Hero(
                    tag: 'care-mark-${mode.name}',
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: CareBreakPainter(
                          mode: mode,
                          progress: 0.72,
                          touchPoint: null,
                          visuals: CareBreakVisuals.forMode(mode),
                        ),
                        child: const SizedBox(width: 74, height: 74),
                      ),
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mode.label,
                          style: const TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 17,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          mode.gateDescription,
                          style: const TextStyle(
                            color: LetterColors.muted,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                  Icon(
                    Icons.arrow_forward,
                    color: LetterColors.ink.withValues(alpha: 0.5),
                    size: 19,
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

class _CareGateHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF17191A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: LetterShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -38,
            child: ExcludeSemantics(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC4A66A).withValues(alpha: 0.22),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC4A66A).withValues(alpha: 0.09),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CARE / RIGHT NOW',
                style: TextStyle(
                  color: const Color(0xFFEFCB72).withValues(alpha: 0.88),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: LetterSpacing.md),
              Text(
                'Change the next minute.',
                style: TextStyle(
                  color: const Color(0xFFF3F1EB),
                  fontFamily: 'Newsreader',
                  fontSize: largeText ? 29 : 36,
                  height: 0.96,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: LetterSpacing.sm),
              SizedBox(
                width: 270,
                child: Text(
                  'No lesson. No typing. Touch once and the screen changes with you.',
                  style: TextStyle(
                    color: const Color(0xFFF3F1EB).withValues(alpha: 0.68),
                    fontSize: 13,
                    height: 1.42,
                  ),
                ),
              ),
              const SizedBox(height: LetterSpacing.md),
              Wrap(
                spacing: largeText ? 4 : 0,
                runSpacing: 8,
                children: [
                  _HeroFact(label: 'SILENT'),
                  _HeroFact(label: '1 MIN'),
                  _HeroFact(label: 'PRIVATE'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Padding(
      padding: EdgeInsets.only(right: largeText ? 5 : 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFEFCB72),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            textScaler: largeText ? TextScaler.noScaling : null,
            style: TextStyle(
              color: const Color(0xFFF3F1EB).withValues(alpha: 0.58),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

extension CareModePresentation on CareMode {
  String get gateDescription => switch (this) {
    CareMode.explode => 'Anger or an impulse needs somewhere to stop.',
    CareMode.heavy => 'Crying, emptiness, or almost no energy.',
    CareMode.racing => 'Anxiety, panic, or too many thoughts need less input.',
    CareMode.space => 'Being available to anyone feels like too much.',
    CareMode.physical =>
      'Pain, fatigue, or physical discomfort needs less input.',
  };
}
