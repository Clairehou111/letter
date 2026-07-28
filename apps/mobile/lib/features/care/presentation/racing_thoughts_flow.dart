import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_memory.dart';
import '../domain/care_mode.dart';
import 'care_safety_boundary_sheet.dart';
import 'future_self_note_card.dart';

enum RacingThoughtsStage { scattered, converged, naming, setDown, handoff }

class RacingThoughtsFlow extends StatefulWidget {
  const RacingThoughtsFlow({
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
    this.onActionCompleted,
    this.futureSelfNote,
    this.now,
  });

  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;
  final ValueChanged<CareActionCompletion>? onActionCompleted;
  final String? futureSelfNote;
  final DateTime Function()? now;

  @override
  State<RacingThoughtsFlow> createState() => _RacingThoughtsFlowState();
}

class _RacingThoughtsFlowState extends State<RacingThoughtsFlow> {
  final TextEditingController _thoughtController = TextEditingController();

  RacingThoughtsStage _stage = RacingThoughtsStage.scattered;
  _SetDownKind _setDownKind = _SetDownKind.named;
  _HandoffKind _handoffKind = _HandoffKind.standard;
  String? _operationError;

  @override
  void dispose() {
    _clearThought();
    _thoughtController.dispose();
    super.dispose();
  }

  void _converge() {
    if (_stage != RacingThoughtsStage.scattered) {
      return;
    }
    setState(() => _stage = RacingThoughtsStage.converged);
  }

  void _openNaming() {
    setState(() {
      _operationError = null;
      _stage = RacingThoughtsStage.naming;
    });
  }

  void _setDownNamedThought() {
    final thought = _thoughtController.text.trim();
    if (thought.isEmpty || thought.length > 280) {
      setState(() {
        _operationError = thought.isEmpty
            ? 'Enter one thought, or choose Discard.'
            : 'Keep this thought to 280 characters or fewer.';
      });
      return;
    }

    _clearThought();
    setState(() {
      _operationError = null;
      _setDownKind = _SetDownKind.named;
      _stage = RacingThoughtsStage.setDown;
    });
  }

  void _setDownUnnamedThought() {
    _clearThought();
    setState(() {
      _operationError = null;
      _setDownKind = _SetDownKind.unnamed;
      _stage = RacingThoughtsStage.setDown;
    });
  }

  void _discardThought() {
    _clearThought();
    setState(() {
      _operationError = null;
      _handoffKind = _HandoffKind.discarded;
      _stage = RacingThoughtsStage.handoff;
    });
  }

  void _finishWithoutThought() {
    _clearThought();
    setState(() {
      _operationError = null;
      _handoffKind = _HandoffKind.nothingNow;
      _stage = RacingThoughtsStage.handoff;
    });
  }

  void _continueToHandoff() {
    _clearThought();
    setState(() {
      _handoffKind = _HandoffKind.standard;
      _stage = RacingThoughtsStage.handoff;
    });
  }

  void _returnToGate() {
    _clearThought();
    final callback = widget.onActionCompleted;
    if (_stage == RacingThoughtsStage.handoff && callback != null) {
      callback(
        CareActionCompletion(
          mode: CareMode.racing,
          actionId: 'racing.one-calm-point',
          actionLabel: 'Bring thoughts to one calm point',
          occurredAt: (widget.now ?? DateTime.now)(),
        ),
      );
      return;
    }
    widget.onReturnToGate();
  }

  void _exitCare() {
    _clearThought();
    widget.onExitCare();
  }

  void _clearThought() {
    _thoughtController.clear();
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
          _clearThought();
          Navigator.of(context).pop();
          widget.onExitCare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F4),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: OutlinedButton.icon(
            key: const Key('racing-safety'),
            onPressed: _openSafetyBoundary,
            style: _secondaryButtonStyle(),
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
              key: const Key('racing-thoughts-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  sliver: SliverList.list(
                    children: [
                      _RacingHeader(onBack: _returnToGate, onExit: _exitCare),
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
      RacingThoughtsStage.scattered => _buildConvergence(context),
      RacingThoughtsStage.converged => _buildConvergence(context),
      RacingThoughtsStage.naming => _buildNaming(),
      RacingThoughtsStage.setDown => _buildSetDown(),
      RacingThoughtsStage.handoff => _buildHandoff(),
    };
  }

  List<Widget> _buildConvergence(BuildContext context) {
    final converged = _stage == RacingThoughtsStage.converged;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.45;

    return [
      const LetterEyebrow('Everything at once'),
      const SizedBox(height: LetterSpacing.xs),
      Text(
        converged ? 'One point is enough.' : 'Touch anywhere to gather it.',
        style: TextStyle(
          color: LetterColors.ink,
          fontFamily: 'Newsreader',
          fontSize: largeText ? 23 : 27,
          height: 1.08,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: largeText ? LetterSpacing.md : LetterSpacing.xl),
      Semantics(
        button: !converged,
        label: converged
            ? 'Many thoughts gathered into one calm point'
            : 'Gather racing thoughts into one calm point',
        child: GestureDetector(
          key: const Key('racing-convergence-surface'),
          behavior: HitTestBehavior.opaque,
          onTap: converged ? null : _converge,
          child: SizedBox(
            height: largeText ? 190 : 260,
            width: double.infinity,
            child: _ConvergenceField(
              converged: converged,
              reduceMotion: reduceMotion,
            ),
          ),
        ),
      ),
      if (!converged) ...[
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'One tap. No holding or repeating.',
          textAlign: TextAlign.center,
          style: TextStyle(color: LetterColors.muted, height: 1.4),
        ),
      ] else ...[
        const SizedBox(height: LetterSpacing.md),
        Semantics(
          liveRegion: true,
          child: const Text(
            'Your mind opened every tab at once. We only need one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LetterColors.ink,
              fontFamily: 'Newsreader',
              fontSize: 22,
              height: 1.18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
        FilledButton.icon(
          key: const Key('racing-name-one'),
          onPressed: _openNaming,
          style: _primaryButtonStyle(),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Name one thought'),
        ),
        const SizedBox(height: LetterSpacing.sm),
        OutlinedButton(
          key: const Key('racing-unnamed'),
          onPressed: _setDownUnnamedThought,
          style: _secondaryButtonStyle(),
          child: const Text("I don't want to name it"),
        ),
        const SizedBox(height: LetterSpacing.xs),
        TextButton(
          key: const Key('racing-nothing-now'),
          onPressed: _finishWithoutThought,
          style: _textButtonStyle(),
          child: const Text('Nothing now'),
        ),
      ],
    ];
  }

  List<Widget> _buildNaming() {
    return [
      const _RacingTitle(
        eyebrow: 'Only one',
        title: 'Name one thought, without solving it.',
      ),
      const SizedBox(height: LetterSpacing.sm),
      const Text(
        'This text stays only on this screen. Letter will not save it or '
        'bring it back tomorrow.',
        style: TextStyle(color: LetterColors.muted, height: 1.45),
      ),
      const SizedBox(height: LetterSpacing.md),
      TextField(
        key: const Key('racing-thought-field'),
        controller: _thoughtController,
        minLines: 4,
        maxLines: 7,
        maxLength: 280,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) {
          if (_operationError != null) {
            setState(() => _operationError = null);
          }
        },
        decoration: InputDecoration(
          hintText: 'One thought, in your own words.',
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
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(LetterRadius.panel),
            borderSide: const BorderSide(color: LetterColors.teal, width: 2),
          ),
        ),
      ),
      if (_operationError case final error?) ...[
        const SizedBox(height: LetterSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Container(
            key: const Key('racing-operation-error'),
            padding: const EdgeInsets.all(LetterSpacing.sm),
            decoration: BoxDecoration(
              color: LetterColors.coralSoft,
              border: Border.all(color: LetterColors.coral),
              borderRadius: BorderRadius.circular(LetterRadius.panel),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Color(0xFF8E413B),
                ),
                const SizedBox(width: LetterSpacing.xs),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Color(0xFF713732),
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: LetterSpacing.md),
      FilledButton.icon(
        key: const Key('racing-set-down'),
        onPressed: _setDownNamedThought,
        style: _primaryButtonStyle(),
        icon: const Icon(Icons.south_outlined),
        label: const Text('Set it down for now'),
      ),
      const SizedBox(height: LetterSpacing.xs),
      TextButton(
        key: const Key('racing-discard'),
        onPressed: _discardThought,
        style: _textButtonStyle(),
        child: const Text('Discard'),
      ),
    ];
  }

  List<Widget> _buildSetDown() {
    final named = _setDownKind == _SetDownKind.named;
    return [
      const SizedBox(height: LetterSpacing.xl),
      const _CalmPoint(size: 118),
      const SizedBox(height: LetterSpacing.xl),
      Text(
        named
            ? 'It is set down for now. Letter will not bring it back tomorrow.'
            : 'You do not have to name it for it to stop owning this minute.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: LetterColors.ink,
          fontFamily: 'Newsreader',
          fontSize: 25,
          height: 1.15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: LetterSpacing.xl),
      FilledButton(
        key: const Key('racing-set-down-continue'),
        onPressed: _continueToHandoff,
        style: _primaryButtonStyle(),
        child: const Text('Continue'),
      ),
    ];
  }

  List<Widget> _buildHandoff() {
    final message = switch (_handoffKind) {
      _HandoffKind.nothingNow => 'Nothing else is required from this screen.',
      _HandoffKind.discarded =>
        'The words are gone from this screen. Nothing was marked solved.',
      _HandoffKind.standard => 'You can leave this moment here.',
    };

    return [
      const SizedBox(height: LetterSpacing.xl),
      const _CalmPoint(size: 96),
      const SizedBox(height: LetterSpacing.xl),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: LetterColors.ink,
          fontFamily: 'Newsreader',
          fontSize: 25,
          height: 1.15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: LetterSpacing.xl),
      if (widget.futureSelfNote case final note?) ...[
        FutureSelfNoteCard(note: note),
        const SizedBox(height: LetterSpacing.lg),
      ],
      FilledButton(
        key: const Key('racing-handoff-return'),
        onPressed: _returnToGate,
        style: _primaryButtonStyle(),
        child: const Text('Return to Care choices'),
      ),
      const SizedBox(height: LetterSpacing.sm),
      OutlinedButton(
        key: const Key('racing-handoff-exit'),
        onPressed: _exitCare,
        style: _secondaryButtonStyle(),
        child: const Text('Leave Care'),
      ),
    ];
  }

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

  static ButtonStyle _textButtonStyle() {
    return TextButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      foregroundColor: LetterColors.muted,
    );
  }
}

enum _SetDownKind { named, unnamed }

enum _HandoffKind { standard, discarded, nothingNow }

class _RacingHeader extends StatelessWidget {
  const _RacingHeader({required this.onBack, required this.onExit});

  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('racing-back-to-care'),
          tooltip: 'Return to Care choices',
          onPressed: onBack,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.arrow_back),
        ),
        const Expanded(
          child: Text(
            'Racing thoughts',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: const Key('racing-exit-care'),
          tooltip: 'Leave Care',
          onPressed: onExit,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _RacingTitle extends StatelessWidget {
  const _RacingTitle({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterEyebrow(eyebrow),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          title,
          style: const TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: 27,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ConvergenceField extends StatelessWidget {
  const _ConvergenceField({
    required this.converged,
    required this.reduceMotion,
  });

  final bool converged;
  final bool reduceMotion;

  static const _fragmentData = [
    (Offset(0.12, 0.14), 42.0, Color(0xFF746390)),
    (Offset(0.66, 0.08), 54.0, Color(0xFF537A83)),
    (Offset(0.82, 0.37), 34.0, Color(0xFF8A7B91)),
    (Offset(0.69, 0.74), 46.0, Color(0xFF648B84)),
    (Offset(0.18, 0.76), 52.0, Color(0xFF657388)),
    (Offset(0.04, 0.43), 32.0, Color(0xFF8B787F)),
    (Offset(0.43, 0.02), 28.0, Color(0xFF6F817C)),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        return TweenAnimationBuilder<double>(
          tween: Tween(end: converged ? 1 : 0),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final fragment in _fragmentData)
                  _positionedFragment(
                    bounds: constraints,
                    center: center,
                    origin: fragment.$1,
                    size: fragment.$2,
                    color: fragment.$3,
                    progress: progress,
                  ),
                Positioned(
                  left: center.dx - 39,
                  top: center.dy - 39,
                  child: Transform.scale(
                    scale: 1 + (progress * 0.16),
                    child: const _CalmPoint(size: 78),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _positionedFragment({
    required BoxConstraints bounds,
    required Offset center,
    required Offset origin,
    required double size,
    required Color color,
    required double progress,
  }) {
    final start = Offset(
      origin.dx * (bounds.maxWidth - size),
      origin.dy * (bounds.maxHeight - size),
    );
    final destination = Offset(center.dx - size / 2, center.dy - size / 2);
    final position = Offset.lerp(start, destination, progress)!;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Opacity(
        opacity: 1 - progress,
        child: Transform.rotate(
          angle: (origin.dx - origin.dy) * 0.55,
          child: Container(
            width: size,
            height: size * 0.38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.17),
              border: Border.all(color: color.withValues(alpha: 0.58)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalmPoint extends StatelessWidget {
  const _CalmPoint({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'One calm point',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LetterColors.tealSoft,
          border: Border.all(color: LetterColors.teal, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x247BC2BA),
              blurRadius: 22,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.24,
            height: size * 0.24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LetterColors.teal,
            ),
          ),
        ),
      ),
    );
  }
}
