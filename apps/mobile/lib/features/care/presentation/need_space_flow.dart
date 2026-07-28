import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../domain/care_mode.dart';
import 'care_safety_boundary_sheet.dart';
import 'need_space_boundary_card.dart';
import 'safe_cocoon_stage.dart';

enum NeedSpaceStage { cocoon, boundaryCard, handoff }

class NeedSpaceFlow extends StatefulWidget {
  const NeedSpaceFlow({
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
  });

  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;

  @override
  State<NeedSpaceFlow> createState() => _NeedSpaceFlowState();
}

class _NeedSpaceFlowState extends State<NeedSpaceFlow> {
  final TextEditingController _boundaryController = TextEditingController();

  NeedSpaceStage _stage = NeedSpaceStage.cocoon;
  bool _isCurtainClosed = false;

  @override
  void dispose() {
    _clearBoundaryText();
    _boundaryController.dispose();
    super.dispose();
  }

  void _closeCurtain() {
    if (_isCurtainClosed) {
      return;
    }
    setState(() => _isCurtainClosed = true);
  }

  void _openBoundaryCard() {
    setState(() => _stage = NeedSpaceStage.boundaryCard);
  }

  void _returnToCocoon() {
    setState(() => _stage = NeedSpaceStage.cocoon);
  }

  void _finishWithoutWords() {
    _clearBoundaryText();
    setState(() => _stage = NeedSpaceStage.handoff);
  }

  void _finishBoundaryCard() {
    _clearBoundaryText();
    setState(() => _stage = NeedSpaceStage.handoff);
  }

  void _returnToGate() {
    _clearBoundaryText();
    widget.onReturnToGate();
  }

  void _exitCare() {
    _clearBoundaryText();
    widget.onExitCare();
  }

  void _clearBoundaryText() {
    _boundaryController.clear();
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
          _clearBoundaryText();
          Navigator.of(context).pop();
          widget.onExitCare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F3),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
          child: OutlinedButton.icon(
            key: const Key('need-space-safety'),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: _NeedSpaceHeader(
                    onBack: _returnToGate,
                    onExit: _exitCare,
                  ),
                ),
                const SizedBox(height: LetterSpacing.md),
                Expanded(
                  child: CustomScrollView(
                    key: const Key('need-space-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                        sliver: SliverList.list(
                          children: [
                            AnimatedSwitcher(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: switch (_stage) {
                                NeedSpaceStage.cocoon => SafeCocoonStage(
                                  key: const ValueKey('need-space-cocoon'),
                                  isClosed: _isCurtainClosed,
                                  onClose: _closeCurtain,
                                  onPrepareWords: _openBoundaryCard,
                                  onNothingNow: _finishWithoutWords,
                                ),
                                NeedSpaceStage.boundaryCard =>
                                  NeedSpaceBoundaryCard(
                                    key: const ValueKey(
                                      'need-space-boundary-card',
                                    ),
                                    controller: _boundaryController,
                                    onBack: _returnToCocoon,
                                    onFinish: _finishBoundaryCard,
                                  ),
                                NeedSpaceStage.handoff => _NeedSpaceHandoff(
                                  key: const ValueKey('need-space-handoff'),
                                  onReturnToGate: _returnToGate,
                                  onExitCare: _exitCare,
                                ),
                              },
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
        ),
      ),
    );
  }
}

class _NeedSpaceHeader extends StatelessWidget {
  const _NeedSpaceHeader({required this.onBack, required this.onExit});

  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('need-space-back-to-care'),
          tooltip: 'Back to Care choices',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const Expanded(
          child: Text(
            'Need space',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LetterColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          key: const Key('need-space-exit-care'),
          tooltip: 'Leave Care',
          onPressed: onExit,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _NeedSpaceHandoff extends StatelessWidget {
  const _NeedSpaceHandoff({
    required this.onReturnToGate,
    required this.onExitCare,
    super.key,
  });

  final VoidCallback onReturnToGate;
  final VoidCallback onExitCare;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('need-space-handoff-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LetterSpacing.xl),
        const Icon(
          Icons.door_back_door_outlined,
          size: 72,
          color: LetterColors.teal,
        ),
        const SizedBox(height: LetterSpacing.xl),
        const Center(
          child: LetterEyebrow('QUIET HAND-OFF', color: LetterColors.teal),
        ),
        const SizedBox(height: LetterSpacing.sm),
        const Text(
          'You can leave without explaining.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LetterColors.ink,
            fontFamily: 'Newsreader',
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        const Text(
          'Letter has not contacted anyone or changed your phone settings.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: LetterColors.muted,
            fontSize: 15,
            height: 1.35,
          ),
        ),
        const SizedBox(height: LetterSpacing.xl),
        FilledButton.icon(
          key: const Key('need-space-handoff-return'),
          onPressed: onReturnToGate,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: LetterColors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.grid_view_outlined),
          label: const Text('Return to Care choices'),
        ),
        const SizedBox(height: LetterSpacing.sm),
        OutlinedButton.icon(
          key: const Key('need-space-handoff-exit'),
          onPressed: onExitCare,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: LetterColors.ink,
            backgroundColor: LetterColors.surface,
            side: const BorderSide(color: LetterColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
          icon: const Icon(Icons.close),
          label: const Text('Leave Care'),
        ),
      ],
    );
  }
}
