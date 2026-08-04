import 'package:flutter/material.dart';

import '../../../design_system/letter_bottom_navigation.dart';
import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_memory_repository.dart';
import '../domain/care_mode.dart';
import '../domain/impulse_buffer_repository.dart';
import '../../entitlement/domain/entitlement.dart';
import '../../entitlement/presentation/entitlement_scope.dart';
import '../../entitlement/presentation/locked_premium_surface.dart';
import '../../health_records/domain/health_record_repository.dart';
import '../../recovery_receipt/application/recovery_receipt_controller.dart';
import '../../recovery_receipt/presentation/recovery_receipt_flow.dart';
import 'angry_impulse_flow.dart';
import 'care_checkback_flow.dart';
import 'care_safety_boundary_sheet.dart';
import 'heavy_presence_flow.dart';
import 'need_space_flow.dart';
import 'personal_care_kit_view.dart';
import 'physical_pain_flow.dart';
import 'racing_thoughts_flow.dart';
import 'breath_flow.dart';
import 'low_energy_flow.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({
    required this.onNavigationSelected,
    required this.impulseBufferRepository,
    required this.careMemoryRepository,
    required this.healthRecordRepository,
    super.key,
    this.now,
  });

  final ValueChanged<int> onNavigationSelected;
  final ImpulseBufferRepository impulseBufferRepository;
  final CareMemoryRepository careMemoryRepository;
  final HealthRecordRepository healthRecordRepository;
  final DateTime Function()? now;

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  CareMode? _activeMode;
  CareActionCompletion? _pendingCompletion;
  CareActionCompletion? _pendingPhysicalCompletion;
  CareRecord? _recordedCheckBack;
  List<CareRecord> _records = const [];
  List<CareReflection> _reflections = const [];
  bool _showCareKit = false;
  bool _showRecoveryReceipt = false;
  bool _memoryBusy = false;
  bool _memoryError = false;
  Future<void> Function()? _retryMemoryOperation;

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    try {
      final records = await widget.careMemoryRepository.getRecords();
      final reflections = await widget.careMemoryRepository.getReflections();
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _reflections = reflections;
        _memoryError = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _memoryError = true);
      }
    }
  }

  Future<void> _openBreath() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            BreathFlow(onClose: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _openLowEnergy() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            LowEnergyFlow(onClose: () => Navigator.of(context).pop()),
      ),
    );
  }

  void _openMode(CareMode mode) {
    setState(() => _activeMode = mode);
  }

  void _returnToGate() {
    setState(() {
      _activeMode = null;
      _showCareKit = false;
      _showRecoveryReceipt = false;
      _pendingPhysicalCompletion = null;
    });
  }

  void _openCheckBack(CareActionCompletion completion) {
    setState(() {
      _activeMode = null;
      _showCareKit = false;
      _showRecoveryReceipt = false;
      _pendingCompletion = completion;
      _pendingPhysicalCompletion = null;
      _recordedCheckBack = null;
      _memoryError = false;
      _retryMemoryOperation = null;
    });
  }

  void _capturePhysicalAction(PhysicalPainAction action) {
    _pendingPhysicalCompletion = CareActionCompletion(
      mode: CareMode.physical,
      actionId: 'physical.${action.actionId.replaceAll('_', '-')}',
      actionLabel: action.actionLabel,
      occurredAt: (widget.now ?? DateTime.now)(),
    );
  }

  void _returnFromPhysical() {
    final completion = _pendingPhysicalCompletion;
    if (completion == null) {
      _returnToGate();
      return;
    }
    _openCheckBack(completion);
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
      final records = await widget.careMemoryRepository.getRecords();
      if (!mounted) {
        return;
      }
      setState(() {
        _recordedCheckBack = record;
        _records = records;
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

  Future<void> _keepCurrentInKit() async {
    final record = _recordedCheckBack;
    if (record == null || _memoryBusy) {
      return;
    }
    setState(() {
      _memoryBusy = true;
      _memoryError = false;
      _retryMemoryOperation = null;
    });
    try {
      for (final existing in _records.where(
        (item) =>
            item.pinned &&
            item.actionId == record.actionId &&
            item.id != record.id,
      )) {
        await widget.careMemoryRepository.setPinned(existing.id, pinned: false);
      }
      final pinned = await widget.careMemoryRepository.setPinned(
        record.id,
        pinned: true,
      );
      final records = await widget.careMemoryRepository.getRecords();
      if (!mounted) {
        return;
      }
      setState(() {
        _recordedCheckBack = pinned;
        _records = records;
        _memoryBusy = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _memoryBusy = false;
        _memoryError = true;
        _retryMemoryOperation = _keepCurrentInKit;
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

  void _closeRecoveryReceipt() {
    if (mounted) {
      setState(() => _showRecoveryReceipt = false);
    }
  }

  Future<void> _setKitPinned(String recordId, bool pinned) async {
    if (_memoryBusy) {
      return;
    }
    setState(() {
      _memoryBusy = true;
      _memoryError = false;
    });
    try {
      await widget.careMemoryRepository.setPinned(recordId, pinned: pinned);
      await _loadMemory();
    } on Object {
      if (mounted) {
        setState(() => _memoryError = true);
      }
    } finally {
      if (mounted) {
        setState(() => _memoryBusy = false);
      }
    }
  }

  Future<void> _deleteKitRecord(String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this Care record?'),
        content: const Text(
          'This removes its check-back and reflection from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-care-record'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: LetterColors.ink),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _memoryBusy = true);
    try {
      await widget.careMemoryRepository.deleteRecord(recordId);
      await _loadMemory();
    } on Object {
      if (mounted) {
        setState(() => _memoryError = true);
      }
    } finally {
      if (mounted) {
        setState(() => _memoryBusy = false);
      }
    }
  }

  String? _futureNoteFor(CareMode mode) {
    for (final reflection in _reflections) {
      final note = reflection.futureSelfNote;
      if (reflection.mode == mode && note != null && note.isNotEmpty) {
        return note;
      }
    }
    return null;
  }

  List<PersonalCareKitItemViewModel> _careKitItems() {
    final pinned = _records.where((record) => record.pinned);
    return [
      for (final record in pinned)
        PersonalCareKitItemViewModel(
          id: record.id,
          actionLabel: record.actionLabel,
          modeLabel: record.mode.label,
          betterCount: _records
              .where(
                (item) =>
                    item.actionId == record.actionId &&
                    item.outcome == CareOutcome.better,
              )
              .length,
          sameCount: _records
              .where(
                (item) =>
                    item.actionId == record.actionId &&
                    item.outcome == CareOutcome.same,
              )
              .length,
          worseCount: _records
              .where(
                (item) =>
                    item.actionId == record.actionId &&
                    item.outcome == CareOutcome.worse,
              )
              .length,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_showCareKit) {
      if (!EntitlementScope.canUse(context, LetterCapability.careKitMemory)) {
        return const LockedPremiumSurface(
          title: 'Your Care Kit remembers what actually helps you.',
          description:
              'With a plan, every Better check-back can be kept here — with '
              'honest counts — so your next hard moment starts with your own '
              'answers, not a generic list.',
        );
      }
      return PersonalCareKitView(
        items: _careKitItems(),
        onBack: _returnToGate,
        onUnpin: (id) => _setKitPinned(id, false),
        onDelete: _deleteKitRecord,
        busyItemIds: _memoryBusy
            ? _careKitItems().map((item) => item.id).toSet()
            : const {},
        hasError: _memoryError,
        onRetry: _loadMemory,
      );
    }
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
        onKeepInKit: _keepCurrentInKit,
        onDone: _finishCheckBack,
        recordedOutcome: _recordedCheckBack?.outcome,
        isPinned: _recordedCheckBack?.pinned ?? false,
        isBusy: _memoryBusy,
        hasError: _memoryError,
        onRetry: _retryMemoryOperation,
        onOpenRecoveryReceipt: _openRecoveryReceipt,
      );
    }
    final activeMode = _activeMode;
    if (activeMode != null) {
      if (activeMode == CareMode.explode) {
        return AngryImpulseFlow(
          repository: widget.impulseBufferRepository,
          onReturnToGate: _returnToGate,
          onExitCare: () => widget.onNavigationSelected(2),
          now: widget.now,
          onActionCompleted: _openCheckBack,
          futureSelfNote: _futureNoteFor(CareMode.explode),
        );
      }
      if (activeMode == CareMode.heavy) {
        return HeavyPresenceFlow(
          onReturnToGate: _returnToGate,
          onExitCare: () => widget.onNavigationSelected(2),
          onActionCompleted: _openCheckBack,
          futureSelfNote: _futureNoteFor(CareMode.heavy),
          now: widget.now,
        );
      }
      if (activeMode == CareMode.racing) {
        return RacingThoughtsFlow(
          onReturnToGate: _returnToGate,
          onExitCare: () => widget.onNavigationSelected(2),
          onActionCompleted: _openCheckBack,
          futureSelfNote: _futureNoteFor(CareMode.racing),
          now: widget.now,
        );
      }
      if (activeMode == CareMode.space) {
        return NeedSpaceFlow(
          onReturnToGate: _returnToGate,
          onExitCare: () => widget.onNavigationSelected(2),
          onActionCompleted: _openCheckBack,
          futureSelfNote: _futureNoteFor(CareMode.space),
          now: widget.now,
        );
      }
      return PhysicalPainFlow(
        onReturnToGate: _returnFromPhysical,
        onExitCare: () => widget.onNavigationSelected(2),
        onActionCompleted: _capturePhysicalAction,
        futureSelfNote: _futureNoteFor(CareMode.physical),
      );
    }

    return Scaffold(
      bottomNavigationBar: LetterBottomNavigation(
        selectedIndex: 2,
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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                  sliver: SliverList.list(
                    children: [
                      const LetterEyebrow('Care / right now'),
                      const SizedBox(height: LetterSpacing.sm),
                      const Text(
                        'What is closest to this moment?',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 31,
                          height: 1.02,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                      const Text(
                        'Choose the nearest feeling, or take one of the two '
                        'entries below when choosing is too much. You can '
                        'leave at any time.',
                        style: TextStyle(
                          color: LetterColors.muted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      _LowEffortEntry(
                        entryKey: const Key('care-nothing-left'),
                        icon: Icons.nightlight_outlined,
                        title: 'I have nothing left',
                        note:
                            'No choices, no gestures. Something quiet stays '
                            'with you and ends on its own.',
                        onPressed: _openLowEnergy,
                      ),
                      const SizedBox(height: LetterSpacing.xs),
                      _LowEffortEntry(
                        entryKey: const Key('care-breathe'),
                        icon: Icons.air_outlined,
                        title: 'I want to breathe with something',
                        note:
                            'A ring to follow, about two minutes. Sound off '
                            'unless you turn it on.',
                        onPressed: _openBreath,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      OutlinedButton.icon(
                        key: const Key('open-personal-care-kit'),
                        onPressed: () => setState(() => _showCareKit = true),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: LetterColors.ink,
                          backgroundColor: LetterColors.surface,
                          side: const BorderSide(color: LetterColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              LetterRadius.control,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.bookmarks_outlined),
                        label: Text(
                          _careKitItems().isEmpty
                              ? 'My Care Kit'
                              : 'My Care Kit (${_careKitItems().length})',
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.md),
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
      label: '${mode.label}. ${mode.gateDescription}',
      child: Material(
        color: mode.softColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(color: mode.color.withValues(alpha: 0.22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('care-mode-${mode.name}'),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(LetterSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: LetterColors.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(LetterRadius.control),
                    ),
                    child: Icon(mode.icon, color: mode.color, size: 24),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.xxs),
                        Text(
                          mode.gateDescription,
                          style: const TextStyle(
                            color: LetterColors.muted,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                  Icon(Icons.chevron_right, color: mode.color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CareModeScene extends StatefulWidget {
  const CareModeScene({
    required this.mode,
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
  });

  final CareMode mode;
  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;

  @override
  State<CareModeScene> createState() => _CareModeSceneState();
}

class _CareModeSceneState extends State<CareModeScene> {
  bool _responded = false;

  void _respond() {
    if (_responded) {
      return;
    }
    setState(() => _responded = true);
  }

  Future<void> _openSafetyBoundary() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.42),
      builder: (context) => CareSafetyBoundarySheet(
        kind: widget.mode.safetyKind,
        onLeaveCare: () {
          Navigator.of(context).pop();
          widget.onExitCare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return Scaffold(
      backgroundColor: _responded
          ? mode.settledBackground
          : mode.sceneBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: Key('care-scene-${mode.name}'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const Key('care-back-to-gate'),
                            tooltip: 'Back to Care choices',
                            onPressed: widget.onReturnToGate,
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Spacer(),
                          IconButton(
                            key: const Key('care-exit'),
                            tooltip: 'Leave Care',
                            onPressed: widget.onExitCare,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      LetterEyebrow(
                        mode.label,
                        color: _responded ? LetterColors.muted : mode.color,
                      ),
                      const SizedBox(height: LetterSpacing.sm),
                      Text(
                        mode.sceneTitle,
                        style: TextStyle(
                          color: LetterColors.ink,
                          fontFamily: 'Newsreader',
                          fontSize: largeText ? 27 : 32,
                          height: 1.02,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.xl),
                      Semantics(
                        liveRegion: true,
                        label: _responded
                            ? mode.transformedLabel
                            : 'Waiting for your first action',
                        child: AnimatedContainer(
                          key: Key('care-focal-${mode.name}'),
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          constraints: BoxConstraints(
                            minHeight: largeText ? 270 : 236,
                          ),
                          decoration: BoxDecoration(
                            color: _responded
                                ? mode.settledColor
                                : mode.activeColor,
                            borderRadius: BorderRadius.circular(
                              LetterRadius.panel,
                            ),
                            border: Border.all(
                              color: _responded
                                  ? mode.color.withValues(alpha: 0.25)
                                  : mode.color.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: Column(
                                key: ValueKey(_responded),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _responded
                                        ? mode.transformedIcon
                                        : mode.icon,
                                    size: _responded ? 62 : 76,
                                    color: mode.color,
                                  ),
                                  const SizedBox(height: LetterSpacing.md),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: LetterSpacing.lg,
                                    ),
                                    child: Text(
                                      _responded
                                          ? mode.transformedLabel
                                          : mode.focalAction,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: mode.color,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: LetterSpacing.lg),
                      if (!_responded)
                        FilledButton.icon(
                          key: Key('care-respond-${mode.name}'),
                          onPressed: _respond,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: mode.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LetterRadius.control,
                              ),
                            ),
                          ),
                          icon: Icon(mode.icon),
                          label: Text(mode.focalAction),
                        )
                      else ...[
                        Container(
                          key: const Key('care-protective-line'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(LetterSpacing.md),
                          decoration: BoxDecoration(
                            color: LetterColors.surface,
                            border: Border.all(color: LetterColors.line),
                            borderRadius: BorderRadius.circular(
                              LetterRadius.panel,
                            ),
                          ),
                          child: Text(
                            mode.protectiveLine,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 20,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.md),
                        FilledButton.icon(
                          key: Key('care-handoff-${mode.name}'),
                          onPressed: widget.onReturnToGate,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: mode.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LetterRadius.control,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.arrow_outward),
                          label: Text(mode.handOff),
                        ),
                        TextButton(
                          key: const Key('care-not-now'),
                          onPressed: widget.onReturnToGate,
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            foregroundColor: LetterColors.muted,
                          ),
                          child: const Text('Not now'),
                        ),
                      ],
                      const SizedBox(height: LetterSpacing.md),
                      OutlinedButton.icon(
                        key: Key('care-safety-${mode.name}'),
                        onPressed: _openSafetyBoundary,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: LetterColors.ink,
                          side: const BorderSide(color: LetterColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              LetterRadius.control,
                            ),
                          ),
                        ),
                        icon: Icon(
                          mode.safetyKind == CareSafetyKind.physical
                              ? Icons.medical_services_outlined
                              : Icons.shield_outlined,
                        ),
                        label: Text(
                          mode.safetyKind == CareSafetyKind.physical
                              ? 'This is new, unusual, or severe'
                              : 'I may not be safe',
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
}

extension CareModePresentation on CareMode {
  String get gateDescription => switch (this) {
    CareMode.explode => 'Anger or an impulse needs somewhere to stop.',
    CareMode.heavy => 'Crying, emptiness, or almost no energy.',
    CareMode.racing => 'Too many thoughts are demanding attention.',
    CareMode.space => 'Being available to anyone feels like too much.',
    CareMode.physical => 'Pain or physical depletion needs less input.',
  };

  IconData get icon => switch (this) {
    CareMode.explode => Icons.bolt_outlined,
    CareMode.heavy => Icons.brightness_3_outlined,
    CareMode.racing => Icons.blur_on_outlined,
    CareMode.space => Icons.door_front_door_outlined,
    CareMode.physical => Icons.healing_outlined,
  };

  IconData get transformedIcon => switch (this) {
    CareMode.explode => Icons.pause_circle_outline,
    CareMode.heavy => Icons.light_mode_outlined,
    CareMode.racing => Icons.adjust,
    CareMode.space => Icons.door_back_door_outlined,
    CareMode.physical => Icons.dark_mode_outlined,
  };

  Color get color => switch (this) {
    CareMode.explode => LetterColors.safetyRed,
    CareMode.heavy => const Color(0xFF4A6482),
    CareMode.racing => LetterColors.violet,
    CareMode.space => LetterColors.teal,
    CareMode.physical => const Color(0xFF9A6416),
  };

  Color get softColor => switch (this) {
    CareMode.explode => LetterColors.coralSoft,
    CareMode.heavy => LetterColors.blueSoft,
    CareMode.racing => LetterColors.violetSoft,
    CareMode.space => LetterColors.tealSoft,
    CareMode.physical => LetterColors.amberSoft,
  };

  Color get sceneBackground => switch (this) {
    CareMode.explode => const Color(0xFFF7E9E7),
    CareMode.heavy => const Color(0xFFE8EDF2),
    CareMode.racing => const Color(0xFFF0ECF4),
    CareMode.space => const Color(0xFFE7F0ED),
    CareMode.physical => const Color(0xFFF4EEE4),
  };

  Color get settledBackground => switch (this) {
    CareMode.explode => const Color(0xFFF4F1EF),
    CareMode.heavy => const Color(0xFFF2F4F3),
    CareMode.racing => const Color(0xFFF5F3F1),
    CareMode.space => const Color(0xFFF0F4F1),
    CareMode.physical => const Color(0xFFF1F1EE),
  };

  Color get activeColor => softColor;

  Color get settledColor => LetterColors.surface.withValues(alpha: 0.75);
}

/// A calm, single-tap entry for the days when picking a feeling is too much.
class _LowEffortEntry extends StatelessWidget {
  const _LowEffortEntry({
    required this.entryKey,
    required this.icon,
    required this.title,
    required this.note,
    required this.onPressed,
  });

  final Key entryKey;
  final IconData icon;
  final String title;
  final String note;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: entryKey,
      color: LetterColors.surface,
      borderRadius: BorderRadius.circular(LetterRadius.panel),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            border: Border.all(color: LetterColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: LetterColors.tealDark),
              const SizedBox(width: LetterSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: LetterColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: LetterSpacing.xxs),
                    Text(
                      note,
                      style: const TextStyle(
                        color: LetterColors.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
