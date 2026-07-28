import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_mode.dart';
import 'care_safety_boundary_sheet.dart';
import 'future_self_note_card.dart';

enum HeavyPresenceStage { dim, awake, message2, message3, presence, handoff }

class HeavyPresenceFlow extends StatefulWidget {
  const HeavyPresenceFlow({
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
    this.onActionCompleted,
    this.futureSelfNote,
    this.now,
    this.elapsedNow,
  });

  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;
  final ValueChanged<CareActionCompletion>? onActionCompleted;
  final String? futureSelfNote;
  final DateTime Function()? now;

  /// Monotonic elapsed time used to make the finite presence interval testable.
  final Duration Function()? elapsedNow;

  @override
  State<HeavyPresenceFlow> createState() => _HeavyPresenceFlowState();
}

class _HeavyPresenceFlowState extends State<HeavyPresenceFlow>
    with WidgetsBindingObserver {
  static const _presenceDuration = Duration(minutes: 2);
  static const _timerInterval = Duration(milliseconds: 100);
  static const _messages = [
    'You do not have to become okay all at once.',
    'Nothing needs to be solved from this minute.',
    'One small input was enough. You can stop here.',
  ];

  final Stopwatch _stopwatch = Stopwatch();
  HeavyPresenceStage _stage = HeavyPresenceStage.dim;
  Timer? _timer;
  Duration _presenceAccumulated = Duration.zero;
  Duration? _foregroundStartedAt;
  bool _safetyBoundaryOpen = false;
  bool _leavingFlow = false;

  Duration get _elapsedNow => widget.elapsedNow?.call() ?? _stopwatch.elapsed;

  Duration get _presenceElapsed {
    final foregroundStartedAt = _foregroundStartedAt;
    final currentSegment = foregroundStartedAt == null
        ? Duration.zero
        : _nonNegative(_elapsedNow - foregroundStartedAt);
    final elapsed = _presenceAccumulated + currentSegment;
    return elapsed > _presenceDuration ? _presenceDuration : elapsed;
  }

  Duration get _presenceRemaining => _presenceDuration - _presenceElapsed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopwatch.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stage != HeavyPresenceStage.presence) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_safetyBoundaryOpen && !_leavingFlow) {
          _foregroundStartedAt ??= _elapsedNow;
          _startPresenceTicker();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pausePresenceClock();
    }
  }

  void _wakeLight() {
    if (_stage != HeavyPresenceStage.dim) {
      return;
    }
    setState(() => _stage = HeavyPresenceStage.awake);
  }

  void _showNextMessage() {
    setState(() {
      _stage = switch (_stage) {
        HeavyPresenceStage.awake => HeavyPresenceStage.message2,
        HeavyPresenceStage.message2 => HeavyPresenceStage.message3,
        _ => _stage,
      };
    });
  }

  void _startPresence() {
    if (_stage != HeavyPresenceStage.awake &&
        _stage != HeavyPresenceStage.message2 &&
        _stage != HeavyPresenceStage.message3) {
      return;
    }
    _presenceAccumulated = Duration.zero;
    _foregroundStartedAt = _elapsedNow;
    setState(() => _stage = HeavyPresenceStage.presence);
    _startPresenceTicker();
  }

  void _startPresenceTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(_timerInterval, (_) {
      if (!mounted || _stage != HeavyPresenceStage.presence) {
        _timer?.cancel();
        return;
      }
      if (_presenceElapsed >= _presenceDuration) {
        _finishPresence();
      } else {
        setState(() {});
      }
    });
  }

  void _pausePresenceClock() {
    final foregroundStartedAt = _foregroundStartedAt;
    if (foregroundStartedAt != null) {
      _presenceAccumulated += _nonNegative(_elapsedNow - foregroundStartedAt);
      if (_presenceAccumulated > _presenceDuration) {
        _presenceAccumulated = _presenceDuration;
      }
      _foregroundStartedAt = null;
    }
    _timer?.cancel();
  }

  void _finishPresence() {
    _timer?.cancel();
    _foregroundStartedAt = null;
    _presenceAccumulated = _presenceDuration;
    if (mounted) {
      setState(() => _stage = HeavyPresenceStage.handoff);
    }
  }

  void _showHandoff() {
    _pausePresenceClock();
    setState(() => _stage = HeavyPresenceStage.handoff);
  }

  Future<void> _openSafetyBoundary() {
    _pausePresenceClock();
    _safetyBoundaryOpen = true;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.42),
      builder: (context) => CareSafetyBoundarySheet(
        kind: CareSafetyKind.emotional,
        onLeaveCare: () {
          Navigator.of(context).pop();
          _leaveCare();
        },
      ),
    ).whenComplete(() {
      _safetyBoundaryOpen = false;
      if (!mounted || _leavingFlow || _stage != HeavyPresenceStage.presence) {
        return;
      }
      _foregroundStartedAt = _elapsedNow;
      _startPresenceTicker();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F4),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: OutlinedButton.icon(
            key: const Key('heavy-safety'),
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
              key: const Key('heavy-presence-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      _HeavyHeader(onBack: _leaveForGate, onExit: _leaveCare),
                      const SizedBox(height: LetterSpacing.lg),
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
      HeavyPresenceStage.dim => _buildDim(context),
      HeavyPresenceStage.awake => _buildMessage(0),
      HeavyPresenceStage.message2 => _buildMessage(1),
      HeavyPresenceStage.message3 => _buildMessage(2),
      HeavyPresenceStage.presence => _buildPresence(),
      HeavyPresenceStage.handoff => _buildHandoff(),
    };
  }

  List<Widget> _buildDim(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;
    final lightSize = largeText ? 128.0 : 176.0;
    return [
      const LetterEyebrow('One small response'),
      const SizedBox(height: LetterSpacing.xs),
      Text(
        'One small response is enough.',
        style: TextStyle(
          color: LetterColors.ink,
          fontFamily: 'Newsreader',
          fontSize: largeText ? 23 : 27,
          height: 1.08,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: largeText ? 16 : 44),
      Center(
        child: Semantics(
          button: true,
          label: 'Wake one light',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('heavy-light'),
              onTap: _wakeLight,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                width: lightSize,
                height: lightSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD9E3E5),
                  border: Border.all(color: const Color(0xFFBACBCD)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14252626),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.light_mode_outlined,
                  size: largeText ? 34 : 42,
                  color: Color(0xFF4E696C),
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: largeText ? LetterSpacing.xs : LetterSpacing.lg),
      const Center(
        child: Text(
          'Wake one light',
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildMessage(int index) {
    final hasNext = index < _messages.length - 1;
    return [
      const SizedBox(height: 24),
      const _AwakeLight(),
      const SizedBox(height: 36),
      Semantics(
        liveRegion: true,
        child: Text(
          _messages[index],
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: 27,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 36),
      if (hasNext)
        OutlinedButton(
          key: const Key('heavy-next-message'),
          onPressed: _showNextMessage,
          style: _secondaryButtonStyle(),
          child: const Text('Read one more line'),
        ),
      if (hasNext) const SizedBox(height: LetterSpacing.sm),
      FilledButton(
        key: const Key('heavy-start-presence'),
        onPressed: _startPresence,
        style: _primaryButtonStyle(),
        child: const Text('Stay with me for 2 minutes'),
      ),
      const SizedBox(height: LetterSpacing.xs),
      TextButton(
        key: const Key('heavy-stop-here'),
        onPressed: _showHandoff,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: LetterColors.muted,
        ),
        child: const Text('Stop here'),
      ),
    ];
  }

  List<Widget> _buildPresence() {
    final remaining = _presenceRemaining;
    final totalSeconds = remaining.inMilliseconds <= 0
        ? 0
        : (remaining.inMilliseconds / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final formatted = '$minutes:${seconds.toString().padLeft(2, '0')}';
    return [
      const SizedBox(height: 44),
      const _AwakeLight(),
      const SizedBox(height: 40),
      Semantics(
        liveRegion: true,
        label: '$formatted remaining',
        child: Text(
          formatted,
          key: const Key('heavy-presence-remaining'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LetterColors.blue,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: LetterSpacing.sm),
      const Text(
        'No input needed.',
        textAlign: TextAlign.center,
        style: TextStyle(color: LetterColors.muted),
      ),
      const SizedBox(height: 40),
      OutlinedButton(
        key: const Key('heavy-end-early'),
        onPressed: _showHandoff,
        style: _secondaryButtonStyle(),
        child: const Text('End early'),
      ),
    ];
  }

  List<Widget> _buildHandoff() {
    return [
      const SizedBox(height: 64),
      const _AwakeLight(),
      const SizedBox(height: 40),
      const Text(
        'Put the phone down for a moment.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: LetterColors.ink,
          fontFamily: 'Newsreader',
          fontSize: 27,
          height: 1.12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 44),
      if (widget.futureSelfNote case final note?) ...[
        FutureSelfNoteCard(note: note),
        const SizedBox(height: LetterSpacing.lg),
      ],
      FilledButton(
        key: const Key('heavy-handoff-return'),
        onPressed: _leaveForGate,
        style: _primaryButtonStyle(),
        child: const Text('Return to Care choices'),
      ),
      const SizedBox(height: LetterSpacing.sm),
      OutlinedButton(
        key: const Key('heavy-handoff-exit'),
        onPressed: _leaveCare,
        style: _secondaryButtonStyle(),
        child: const Text('Leave Care'),
      ),
    ];
  }

  void _leaveForGate() {
    _leavingFlow = true;
    _pausePresenceClock();
    final callback = widget.onActionCompleted;
    if (_stage == HeavyPresenceStage.handoff && callback != null) {
      callback(
        CareActionCompletion(
          mode: CareMode.heavy,
          actionId: 'heavy.quiet-presence',
          actionLabel: 'Quiet presence',
          occurredAt: (widget.now ?? DateTime.now)(),
        ),
      );
      return;
    }
    widget.onReturnToGate();
  }

  void _leaveCare() {
    _leavingFlow = true;
    _pausePresenceClock();
    widget.onExitCare();
  }

  static Duration _nonNegative(Duration duration) =>
      duration.isNegative ? Duration.zero : duration;

  static ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      backgroundColor: LetterColors.teal,
      foregroundColor: LetterColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
    );
  }

  static ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      foregroundColor: LetterColors.ink,
      backgroundColor: LetterColors.surface,
      side: const BorderSide(color: LetterColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetterRadius.control),
      ),
    );
  }
}

class _HeavyHeader extends StatelessWidget {
  const _HeavyHeader({required this.onBack, required this.onExit});

  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('heavy-back-to-care'),
          tooltip: 'Return to Care choices',
          onPressed: onBack,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.arrow_back),
        ),
        const Expanded(
          child: Text(
            'Heavy / low',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: const Key('heavy-exit-care'),
          tooltip: 'Leave Care',
          onPressed: onExit,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _AwakeLight extends StatelessWidget {
  const _AwakeLight();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        image: true,
        label: 'One light is awake',
        child: Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE9F3F1),
            border: Border.all(color: const Color(0xFF85B6B1), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x337BC2BA),
                blurRadius: 28,
                spreadRadius: 7,
              ),
            ],
          ),
          child: const Icon(
            Icons.light_mode,
            size: 36,
            color: LetterColors.teal,
          ),
        ),
      ),
    );
  }
}
