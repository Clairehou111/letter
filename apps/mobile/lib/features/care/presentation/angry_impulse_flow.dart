import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_mode.dart';
import '../domain/impulse_buffer_repository.dart';
import '../domain/impulse_draft_record.dart';
import 'care_safety_boundary_sheet.dart';
import 'future_self_note_card.dart';

enum AngryImpulseStage {
  loading,
  loadFailed,
  shatter,
  quiet,
  draft,
  review,
  locked,
  ready,
  opened,
}

class AngryImpulseFlow extends StatefulWidget {
  const AngryImpulseFlow({
    required this.repository,
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
    this.now,
    this.onActionCompleted,
    this.futureSelfNote,
  });

  final ImpulseBufferRepository repository;
  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;
  final DateTime Function()? now;
  final ValueChanged<CareActionCompletion>? onActionCompleted;
  final String? futureSelfNote;

  @override
  State<AngryImpulseFlow> createState() => _AngryImpulseFlowState();
}

class _AngryImpulseFlowState extends State<AngryImpulseFlow> {
  static const _shatterDuration = Duration(seconds: 20);
  static const _shatterTick = Duration(milliseconds: 100);
  static const _requiredTaps = 20;

  final TextEditingController _draftController = TextEditingController();
  final List<Offset> _impacts = [];
  AngryImpulseStage _stage = AngryImpulseStage.loading;
  ImpulseDraftRecord? _active;
  Timer? _timer;
  Duration _shatterElapsed = Duration.zero;
  String? _error;
  bool _busy = false;

  DateTime get _now => (widget.now ?? DateTime.now)().toUtc();

  void _completeQuietAction() {
    final callback = widget.onActionCompleted;
    if (callback == null) {
      widget.onReturnToGate();
      return;
    }
    callback(
      CareActionCompletion(
        mode: CareMode.explode,
        actionId: 'explode.shatter-and-pause',
        actionLabel: 'Shatter and pause',
        occurredAt: _now,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _draftController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    setState(() {
      _stage = AngryImpulseStage.loading;
      _error = null;
    });
    try {
      final active = await widget.repository.getActive();
      if (!mounted) {
        return;
      }
      _active = active;
      if (active == null) {
        _startShatter();
        return;
      }
      switch (active.stateAt(_now)) {
        case ImpulseDraftState.draft:
          _draftController.text = active.content;
          setState(() => _stage = AngryImpulseStage.draft);
        case ImpulseDraftState.locked:
          setState(() => _stage = AngryImpulseStage.locked);
          _startLockedTicker();
        case ImpulseDraftState.ready:
          setState(() => _stage = AngryImpulseStage.ready);
      }
    } on Object {
      if (mounted) {
        setState(() => _stage = AngryImpulseStage.loadFailed);
      }
    }
  }

  void _startShatter() {
    _timer?.cancel();
    _impacts.clear();
    _shatterElapsed = Duration.zero;
    setState(() {
      _stage = AngryImpulseStage.shatter;
      _error = null;
    });
    _timer = Timer.periodic(_shatterTick, (_) {
      if (!mounted || _stage != AngryImpulseStage.shatter) {
        return;
      }
      _shatterElapsed += _shatterTick;
      if (_shatterElapsed >= _shatterDuration) {
        _finishShatter();
      } else {
        setState(() {});
      }
    });
  }

  void _recordImpact(TapDownDetails details) {
    if (_stage != AngryImpulseStage.shatter) {
      return;
    }
    setState(() => _impacts.add(details.localPosition));
    if (_impacts.length >= _requiredTaps) {
      _finishShatter();
    }
  }

  void _finishShatter() {
    _timer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = AngryImpulseStage.quiet;
      _error = null;
    });
  }

  void _startLockedTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _stage != AngryImpulseStage.locked) {
        return;
      }
      final active = _active;
      if (active != null && active.stateAt(_now) == ImpulseDraftState.ready) {
        _timer?.cancel();
        setState(() => _stage = AngryImpulseStage.ready);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _saveAndReview() async {
    await _runOperation(() async {
      final record = await widget.repository.saveDraft(_draftController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _active = record;
        _stage = AngryImpulseStage.review;
      });
    });
  }

  Future<void> _saveAndLeave() async {
    await _runOperation(() async {
      final record = await widget.repository.saveDraft(_draftController.text);
      if (!mounted) {
        return;
      }
      _active = record;
      widget.onReturnToGate();
    });
  }

  Future<void> _sealDraft() async {
    final active = _active;
    if (active == null) {
      return;
    }
    await _runOperation(() async {
      final record = await widget.repository.sealDraft(active.id, now: _now);
      if (!mounted) {
        return;
      }
      setState(() {
        _active = record;
        _draftController.clear();
        _stage = AngryImpulseStage.locked;
      });
      _startLockedTicker();
    });
  }

  Future<void> _keepSealed() async {
    final active = _active;
    if (active == null) {
      return;
    }
    await _runOperation(() async {
      final record = await widget.repository.keepReadySealed(
        active.id,
        now: _now,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _active = record;
        _stage = AngryImpulseStage.locked;
      });
      _startLockedTicker();
    });
  }

  void _openPrivately() {
    final active = _active;
    if (active == null || active.stateAt(_now) != ImpulseDraftState.ready) {
      return;
    }
    _draftController.text = active.content;
    setState(() {
      _stage = AngryImpulseStage.opened;
      _error = null;
    });
  }

  Future<void> _resealRewrite() async {
    final active = _active;
    if (active == null) {
      return;
    }
    await _runOperation(() async {
      final record = await widget.repository.resealReady(
        active.id,
        _draftController.text,
        now: _now,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _active = record;
        _draftController.clear();
        _stage = AngryImpulseStage.locked;
      });
      _startLockedTicker();
    });
  }

  Future<void> _confirmDelete({required bool sealedUnopened}) async {
    final active = _active;
    if (active == null || _busy) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          sealedUnopened ? 'Delete without opening?' : 'Delete this draft?',
        ),
        content: Text(
          sealedUnopened
              ? 'The sealed text will be permanently deleted. It will not be '
                    'opened first.'
              : 'This private text will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-impulse'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFAD4E46),
            ),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runOperation(() async {
      await widget.repository.delete(active.id);
      if (!mounted) {
        return;
      }
      _timer?.cancel();
      setState(() {
        _active = null;
        _draftController.clear();
        _stage = AngryImpulseStage.loading;
      });
      widget.onReturnToGate();
    });
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on ImpulseBufferException catch (error) {
      if (mounted) {
        setState(() => _error = error.userMessage);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = const ImpulseBufferException(
            ImpulseBufferFailure.storageUnavailable,
          ).userMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openSafetyBoundary() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.42),
      builder: (context) => CareSafetyBoundarySheet(
        kind: CareSafetyKind.emotional,
        onLeaveCare: () {
          Navigator.of(context).pop();
          widget.onExitCare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiet =
        _stage != AngryImpulseStage.shatter &&
        _stage != AngryImpulseStage.loading &&
        _stage != AngryImpulseStage.loadFailed;
    return Scaffold(
      backgroundColor: quiet
          ? const Color(0xFFEEEDEA)
          : const Color(0xFFF7E9E7),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: OutlinedButton.icon(
            key: const Key('angry-safety'),
            onPressed: _openSafetyBoundary,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: LetterColors.ink,
              backgroundColor: LetterColors.surface,
              side: const BorderSide(color: LetterColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            ),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('I may not be safe'),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              key: const Key('angry-impulse-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      _AngryHeader(
                        onBack: widget.onReturnToGate,
                        onExit: widget.onExitCare,
                      ),
                      const SizedBox(height: LetterSpacing.md),
                      ..._buildStage(context),
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

  List<Widget> _buildStage(BuildContext context) {
    return switch (_stage) {
      AngryImpulseStage.loading => [
        const SizedBox(height: 180),
        const Center(
          child: CircularProgressIndicator(color: Color(0xFFAD4E46)),
        ),
      ],
      AngryImpulseStage.loadFailed => [
        const _AngryTitle(
          eyebrow: 'Private storage',
          title: 'Letter could not open this private envelope.',
        ),
        const SizedBox(height: LetterSpacing.lg),
        FilledButton.icon(
          key: const Key('retry-impulse-load'),
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
      AngryImpulseStage.shatter => _buildShatter(context),
      AngryImpulseStage.quiet => _buildQuiet(),
      AngryImpulseStage.draft => _buildDraft(opened: false),
      AngryImpulseStage.review => _buildReview(),
      AngryImpulseStage.locked => _buildLocked(context),
      AngryImpulseStage.ready => _buildReady(),
      AngryImpulseStage.opened => _buildDraft(opened: true),
    };
  }

  List<Widget> _buildShatter(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final remaining = _shatterDuration - _shatterElapsed;
    final seconds = math.max(0, (remaining.inMilliseconds / 1000).ceil());
    return [
      const _AngryTitle(
        eyebrow: 'Put the force here',
        title: 'This screen cannot send, post, buy, quit, or end anything.',
      ),
      const SizedBox(height: LetterSpacing.md),
      Text(
        'Quiet in $seconds seconds, or when the crystal breaks.',
        key: const Key('shatter-remaining'),
        style: const TextStyle(color: LetterColors.muted),
      ),
      const SizedBox(height: LetterSpacing.md),
      LayoutBuilder(
        builder: (context, constraints) {
          return Semantics(
            button: true,
            label:
                'Shatter crystal. ${_impacts.length} of $_requiredTaps impacts.',
            child: GestureDetector(
              key: const Key('shatter-crystal'),
              behavior: HitTestBehavior.opaque,
              onTapDown: _recordImpact,
              child: AnimatedScale(
                scale: reduceMotion || _impacts.isEmpty
                    ? 1
                    : 1 + (_impacts.length.isOdd ? 0.012 : 0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 90),
                child: SizedBox(
                  height: 310,
                  width: constraints.maxWidth,
                  child: CustomPaint(
                    painter: ShatterCrystalPainter(
                      impacts: List.unmodifiable(_impacts),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: LetterSpacing.md),
      OutlinedButton(
        key: const Key('skip-shatter'),
        onPressed: _finishShatter,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: LetterColors.ink,
          side: const BorderSide(color: Color(0xFFD7BAB6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LetterRadius.control),
          ),
        ),
        child: const Text('Skip to quiet'),
      ),
    ];
  }

  List<Widget> _buildQuiet() {
    return [
      const _AngryTitle(
        eyebrow: 'Quiet now',
        title: 'Done. Nothing has to leave this screen.',
      ),
      const SizedBox(height: LetterSpacing.lg),
      const Icon(
        Icons.pause_circle_outline,
        size: 96,
        color: Color(0xFF6D7473),
      ),
      const SizedBox(height: LetterSpacing.lg),
      const Text(
        "Don't send it. Don't post it. Don't quit tonight.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 22,
          height: 1.15,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: LetterSpacing.xl),
      if (widget.futureSelfNote case final note?) ...[
        FutureSelfNoteCard(note: note),
        const SizedBox(height: LetterSpacing.lg),
      ],
      FilledButton.icon(
        key: const Key('open-private-draft'),
        onPressed: () => setState(() => _stage = AngryImpulseStage.draft),
        style: _primaryStyle(),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Write it here, with no recipient'),
      ),
      TextButton(
        key: const Key('leave-after-quiet'),
        onPressed: _completeQuietAction,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: LetterColors.muted,
        ),
        child: const Text('Leave it here for now'),
      ),
    ];
  }

  List<Widget> _buildDraft({required bool opened}) {
    return [
      _AngryTitle(
        eyebrow: opened ? 'Opened privately' : 'No recipient',
        title: opened
            ? 'Rewrite it only if that helps.'
            : 'Write it exactly as it came.',
      ),
      const SizedBox(height: LetterSpacing.sm),
      Text(
        opened
            ? 'The cooldown ended. This text is visible because you chose to '
                  'open it.'
            : 'Nothing is sent from here. Saving keeps it only in Letter.',
        style: const TextStyle(color: LetterColors.muted, height: 1.45),
      ),
      const SizedBox(height: LetterSpacing.md),
      TextField(
        key: Key(opened ? 'opened-draft-field' : 'private-draft-field'),
        controller: _draftController,
        minLines: 7,
        maxLines: 12,
        maxLength: impulseDraftMaximumCharacters,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: 'Put every word here.',
          filled: true,
          fillColor: LetterColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            borderSide: const BorderSide(color: LetterColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            borderSide: const BorderSide(color: LetterColors.line),
          ),
        ),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: LetterSpacing.xs),
        _OperationError(error),
      ],
      const SizedBox(height: LetterSpacing.sm),
      FilledButton.icon(
        key: Key(opened ? 'reseal-rewrite' : 'review-private-draft'),
        onPressed: _busy ? null : (opened ? _resealRewrite : _saveAndReview),
        style: _primaryStyle(),
        icon: Icon(opened ? Icons.lock_clock_outlined : Icons.lock_outline),
        label: Text(
          opened ? 'Reseal rewrite for 24 hours' : 'Review before sealing',
        ),
      ),
      if (!opened)
        OutlinedButton(
          key: const Key('save-draft-and-leave'),
          onPressed: _busy ? null : _saveAndLeave,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: LetterColors.ink,
            side: const BorderSide(color: LetterColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          child: const Text('Save draft and leave'),
        ),
      if (_active != null)
        TextButton(
          key: const Key('delete-active-draft'),
          onPressed: _busy ? null : () => _confirmDelete(sealedUnopened: false),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: const Color(0xFFAD4E46),
          ),
          child: const Text('Delete permanently'),
        ),
    ];
  }

  List<Widget> _buildReview() {
    return [
      const _AngryTitle(
        eyebrow: 'Before sealing',
        title: 'This is an app-enforced 24-hour cooldown.',
      ),
      const SizedBox(height: LetterSpacing.lg),
      const _ConsequenceLine(
        icon: Icons.visibility_off_outlined,
        text: 'Letter hides the text inside the app for 24 hours.',
      ),
      const _ConsequenceLine(
        icon: Icons.phone_android_outlined,
        text: 'It cannot stop you from acting somewhere else.',
      ),
      const _ConsequenceLine(
        icon: Icons.delete_outline,
        text: 'You can permanently delete the unopened envelope at any time.',
      ),
      const _ConsequenceLine(
        icon: Icons.schedule_outlined,
        text: 'Your device clock determines when the envelope becomes ready.',
      ),
      if (_error case final error?) ...[
        const SizedBox(height: LetterSpacing.sm),
        _OperationError(error),
      ],
      const SizedBox(height: LetterSpacing.lg),
      FilledButton.icon(
        key: const Key('seal-for-24-hours'),
        onPressed: _busy ? null : _sealDraft,
        style: _primaryStyle(),
        icon: const Icon(Icons.lock_clock_outlined),
        label: const Text('Seal for 24 hours'),
      ),
      TextButton(
        key: const Key('back-to-draft'),
        onPressed: _busy
            ? null
            : () => setState(() => _stage = AngryImpulseStage.draft),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: LetterColors.muted,
        ),
        child: const Text('Back to edit'),
      ),
    ];
  }

  List<Widget> _buildLocked(BuildContext context) {
    final active = _active!;
    final remaining = active.remainingAt(_now);
    return [
      const _AngryTitle(
        eyebrow: 'Sealed envelope',
        title: 'The words are hidden inside Letter.',
      ),
      const SizedBox(height: LetterSpacing.xl),
      const Center(
        child: Icon(
          Icons.mark_email_unread_outlined,
          size: 112,
          color: Color(0xFF6D7473),
        ),
      ),
      const SizedBox(height: LetterSpacing.lg),
      Text(
        _formatRemaining(remaining),
        key: const Key('locked-remaining'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Newsreader',
          fontSize: 27,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: LetterSpacing.xs),
      Text(
        'Ready ${_formatUnlock(context, active.unlockAt!)}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: LetterColors.muted),
      ),
      const SizedBox(height: LetterSpacing.lg),
      const Text(
        'Letter is hiding the text here. This does not prevent action outside '
        'the app.',
        textAlign: TextAlign.center,
        style: TextStyle(color: LetterColors.muted, height: 1.45),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: LetterSpacing.sm),
        _OperationError(error),
      ],
      const SizedBox(height: LetterSpacing.lg),
      OutlinedButton.icon(
        key: const Key('delete-locked-unopened'),
        onPressed: _busy ? null : () => _confirmDelete(sealedUnopened: true),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: const Color(0xFFAD4E46),
          side: const BorderSide(color: Color(0xFFD7BAB6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LetterRadius.control),
          ),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete unopened'),
      ),
    ];
  }

  List<Widget> _buildReady() {
    return [
      const _AngryTitle(
        eyebrow: 'Cooldown complete',
        title: 'A sealed note is ready when you are.',
      ),
      const SizedBox(height: LetterSpacing.xl),
      const Center(
        child: Icon(Icons.drafts_outlined, size: 112, color: Color(0xFF176D67)),
      ),
      const SizedBox(height: LetterSpacing.lg),
      const Text(
        'Its contents are still hidden. Nothing opens until you choose.',
        textAlign: TextAlign.center,
        style: TextStyle(color: LetterColors.muted, height: 1.45),
      ),
      if (_error case final error?) ...[
        const SizedBox(height: LetterSpacing.sm),
        _OperationError(error),
      ],
      const SizedBox(height: LetterSpacing.lg),
      FilledButton.icon(
        key: const Key('open-ready-privately'),
        onPressed: _busy ? null : _openPrivately,
        style: _primaryStyle(background: LetterColors.teal),
        icon: const Icon(Icons.lock_open_outlined),
        label: const Text('Open privately'),
      ),
      OutlinedButton.icon(
        key: const Key('keep-sealed-24-hours'),
        onPressed: _busy ? null : _keepSealed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: LetterColors.ink,
          side: const BorderSide(color: LetterColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LetterRadius.control),
          ),
        ),
        icon: const Icon(Icons.lock_clock_outlined),
        label: const Text('Keep sealed another 24 hours'),
      ),
      TextButton.icon(
        key: const Key('delete-ready-unopened'),
        onPressed: _busy ? null : () => _confirmDelete(sealedUnopened: true),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: const Color(0xFFAD4E46),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Delete unopened'),
      ),
    ];
  }

  ButtonStyle _primaryStyle({Color background = const Color(0xFFAD4E46)}) {
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      backgroundColor: background,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
    );
  }
}

class _AngryHeader extends StatelessWidget {
  const _AngryHeader({required this.onBack, required this.onExit});

  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('angry-back-to-care'),
          tooltip: 'Back to Care choices',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const Spacer(),
        IconButton(
          key: const Key('angry-exit-care'),
          tooltip: 'Leave Care',
          onPressed: onExit,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _AngryTitle extends StatelessWidget {
  const _AngryTitle({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterEyebrow(eyebrow, color: const Color(0xFFAD4E46)),
        const SizedBox(height: LetterSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: largeText ? 26 : 31,
            height: 1.03,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ConsequenceLine extends StatelessWidget {
  const _ConsequenceLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LetterSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6D7473), size: 22),
          const SizedBox(width: LetterSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationError extends StatelessWidget {
  const _OperationError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('impulse-operation-error'),
      width: double.infinity,
      padding: const EdgeInsets.all(LetterSpacing.sm),
      decoration: BoxDecoration(
        color: LetterColors.coralSoft,
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF8F3F39),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ShatterCrystalPainter extends CustomPainter {
  const ShatterCrystalPainter({required this.impacts});

  final List<Offset> impacts;

  @override
  void paint(Canvas canvas, Size size) {
    final crystal = Path()
      ..moveTo(size.width * 0.5, 8)
      ..lineTo(size.width * 0.82, size.height * 0.22)
      ..lineTo(size.width * 0.76, size.height * 0.78)
      ..lineTo(size.width * 0.5, size.height - 8)
      ..lineTo(size.width * 0.22, size.height * 0.76)
      ..lineTo(size.width * 0.16, size.height * 0.24)
      ..close();
    canvas.drawPath(
      crystal,
      Paint()
        ..color = const Color(0xFFE5B6B0)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      crystal,
      Paint()
        ..color = const Color(0xFFAD4E46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.save();
    canvas.clipPath(crystal);
    final crackPaint = Paint()
      ..color = const Color(0xFF713833)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var index = 0; index < impacts.length; index++) {
      final impact = impacts[index];
      final length = 34.0 + (index % 4) * 8;
      for (var branch = 0; branch < 4; branch++) {
        final angle = (index * 0.77) + branch * math.pi / 2;
        final end = Offset(
          impact.dx + math.cos(angle) * length,
          impact.dy + math.sin(angle) * length,
        );
        final middle = Offset.lerp(impact, end, 0.55)!;
        final bend = Offset(
          middle.dx + math.sin(angle) * 7,
          middle.dy - math.cos(angle) * 7,
        );
        canvas.drawPath(
          Path()
            ..moveTo(impact.dx, impact.dy)
            ..lineTo(bend.dx, bend.dy)
            ..lineTo(end.dx, end.dy),
          crackPaint,
        );
      }
      canvas.drawCircle(
        impact,
        4,
        Paint()
          ..color = const Color(0xFF713833)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShatterCrystalPainter oldDelegate) {
    return oldDelegate.impacts.length != impacts.length;
  }
}

String _formatRemaining(Duration duration) {
  if (duration <= Duration.zero) {
    return 'Ready now';
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m remaining';
  }
  final seconds = duration.inSeconds.remainder(60);
  return '${minutes}m ${seconds}s remaining';
}

String _formatUnlock(BuildContext context, DateTime unlockAt) {
  final local = unlockAt.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)}, '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
