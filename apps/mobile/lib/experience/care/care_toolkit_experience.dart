import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/care/domain/care_memory.dart';
import '../../features/care/domain/care_mode.dart';
import '../../features/patterns/domain/personal_pattern.dart';
import '../../features/preparation/domain/preparation_loop_state.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';
import 'care_editorial_art.dart';
import 'care_scene_foundation.dart';

/// Everyday-care practices for stable users.
final class CareToolkitExperience extends StatefulWidget {
  const CareToolkitExperience({
    super.key,
    required this.onRitualCompleted,
    this.onExit,
    this.onSafety,
    this.loopKind,
    this.memoryEvidence = const <SupportActionPattern>[],
    this.now,
    this.companionName,
    this.onCompanionNameSaved,
  });

  final Future<void> Function(CareActionCompletion completion)
  onRitualCompleted;
  final VoidCallback? onExit;
  final VoidCallback? onSafety;
  final PreparationLoopKind? loopKind;
  final List<SupportActionPattern> memoryEvidence;
  final DateTime Function()? now;

  /// The saved device-local name. Naming and editing belong to Settings.
  final String? companionName;

  /// Retained for assembly compatibility; this scene never edits the name.
  final Future<void> Function(String name)? onCompanionNameSaved;

  @override
  State<CareToolkitExperience> createState() => _CareToolkitExperienceState();
}

class _CareToolkitExperienceState extends State<CareToolkitExperience> {
  _ToolkitRitual? _active;
  late DateTime _chooserStartedAt;
  DateTime? _ritualStartedAt;
  bool _memoryProposalDismissed = false;
  bool _completing = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _chooserStartedAt = _now();
  }

  void _open(_ToolkitRitual ritual) {
    ExperienceHaptics.pick();
    setState(() {
      _active = ritual;
      _ritualStartedAt = _now();
    });
  }

  void _leaveRitual() {
    setState(() {
      _active = null;
      _chooserStartedAt = _now();
      _ritualStartedAt = null;
    });
  }

  Future<void> _complete(_ToolkitRitual ritual) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await widget.onRitualCompleted(
        CareActionCompletion(
          mode: CareMode.physical,
          actionId: ritual.id,
          actionLabel: ritual.title,
          occurredAt: _now(),
        ),
      );
      if (!mounted) return;
      ExperienceHaptics.careStepCompleted();
      setState(() {
        _active = null;
        _chooserStartedAt = _now();
        _ritualStartedAt = null;
        _memoryProposalDismissed = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'That completion could not be saved just now. Try again when you are ready.',
            style: ExperienceType.bodySmall(CareEditorialPalette.paper),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = ExperienceFoundation.motionPreference(context);
    final active = _active;
    final page = active == null
        ? _ToolkitChooser(
            motion: motion,
            companionName: widget.companionName,
            startedAt: _chooserStartedAt,
            now: _now,
            loopKind: widget.loopKind,
            memoryEvidence: widget.memoryEvidence,
            proposalDismissed: _memoryProposalDismissed,
            onDismissProposal: () {
              setState(() => _memoryProposalDismissed = true);
            },
            onOpen: _open,
            onExit: widget.onExit,
            onSafety: widget.onSafety,
          )
        : _PracticePage(
            key: ValueKey<String>('toolkit-${active.id}'),
            ritual: active,
            motion: motion,
            companionName: widget.companionName,
            startedAt: _ritualStartedAt!,
            now: _now,
            completing: _completing,
            onBack: _leaveRitual,
            onSafety: widget.onSafety,
            onComplete: () => _complete(active),
          );

    final body = Theme(
      data: ExperienceFoundation.careTheme(),
      child: Scaffold(
        backgroundColor: CareEditorialPalette.paper,
        body: AnimatedSwitcher(
          duration: motion == CareSceneMotionPreference.full
              ? const Duration(milliseconds: 300)
              : Duration.zero,
          child: page,
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_active != null) {
          _leaveRitual();
        } else {
          widget.onExit?.call();
        }
      },
      child: body,
    );
  }
}

class _ToolkitChooser extends StatelessWidget {
  const _ToolkitChooser({
    required this.motion,
    required this.companionName,
    required this.startedAt,
    required this.now,
    required this.loopKind,
    required this.memoryEvidence,
    required this.proposalDismissed,
    required this.onDismissProposal,
    required this.onOpen,
    required this.onExit,
    required this.onSafety,
  });

  final CareSceneMotionPreference motion;
  final String? companionName;
  final DateTime startedAt;
  final DateTime Function() now;
  final PreparationLoopKind? loopKind;
  final List<SupportActionPattern> memoryEvidence;
  final bool proposalDismissed;
  final VoidCallback onDismissProposal;
  final ValueChanged<_ToolkitRitual> onOpen;
  final VoidCallback? onExit;
  final VoidCallback? onSafety;

  @override
  Widget build(BuildContext context) {
    final memory = _resolveMemory();
    final menuChildren = <Widget>[];
    for (final group in _RitualEnergy.values) {
      final rituals =
          _ToolkitRitual.catalog
              .where((ritual) => ritual.energy == group)
              .toList()
            ..sort((a, b) => a.menuOrder.compareTo(b.menuOrder));
      menuChildren
        ..add(
          _RitualGroupHeader(
            group: group,
            first: group == _RitualEnergy.values.first,
          ),
        )
        ..addAll(
          rituals.map(
            (ritual) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: _RitualRow(
                ritual: ritual,
                index: ritual.menuOrder,
                onTap: () => onOpen(ritual),
              ),
            ),
          ),
        );
    }
    return CareEditorialPaper(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: _ChooserHeader(
                        memory: memory,
                        motion: motion,
                        companionName: companionName,
                        startedAt: startedAt,
                        now: now,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(menuChildren),
                    ),
                  ),
                ],
              ),
            ),
            _ChooserBottomBar(onSafety: onSafety, onExit: onExit),
          ],
        ),
      ),
    );
  }

  Widget? _resolveMemory() {
    final verdict = ExperienceFoundation.gateMemoryEvidence(
      loopKind: loopKind,
      evidence: memoryEvidence,
    );
    String? line;
    var dismissible = false;
    switch (verdict) {
      case MemoryEvidenceVerdict.remembered:
        line = ExperienceMemoryGate.rememberedLine(memoryEvidence);
        break;
      case MemoryEvidenceVerdict.accumulating:
        line = ExperienceMemoryGate.accumulatingLine(memoryEvidence);
        break;
      case MemoryEvidenceVerdict.proposal:
        if (!proposalDismissed) {
          line = ExperienceMemoryGate.rememberedLine(memoryEvidence);
          dismissible = line != null;
        }
        break;
      case MemoryEvidenceVerdict.silent:
        line = null;
        break;
    }
    if (line == null) return null;
    return _MemoryNote(
      line: line,
      dismissible: dismissible,
      onDismiss: onDismissProposal,
    );
  }
}

enum _RitualEnergy {
  restHere(
    'REST HERE',
    'Let the room grow quiet enough to hear what your body has been saying.',
  ),
  littleComfort(
    'A LITTLE COMFORT',
    'Listen quietly. Your body may answer with warmth, a deeper breath, or the wish to pause.',
  ),
  moveALittle(
    'MOVE A LITTLE',
    'Choose a small movement only when changing position feels welcome.',
  );

  const _RitualEnergy(this.label, this.invitation);

  final String label;
  final String invitation;
}

class _RitualGroupHeader extends StatelessWidget {
  const _RitualGroupHeader({required this.group, this.first = false});

  final _RitualEnergy group;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, first ? 8 : 18, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              group.label,
              style: ExperienceType.eyebrow(CareEditorialPalette.coralText),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            group.invitation,
            style: ExperienceType.bodySmall(CareEditorialPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ChooserHeader extends StatelessWidget {
  const _ChooserHeader({
    required this.memory,
    required this.motion,
    required this.companionName,
    required this.startedAt,
    required this.now,
  });

  final Widget? memory;
  final CareSceneMotionPreference motion;
  final String? companionName;
  final DateTime startedAt;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const CareQuietRule(),
            const SizedBox(width: 14),
            Text(
              'EVERYDAY CARE',
              style: ExperienceType.eyebrow(CareEditorialPalette.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            'What would feel kind right now?',
            style: ExperienceType.display(
              CareEditorialPalette.ink,
            ).copyWith(fontSize: 38, height: 1.05),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 315),
          child: Text(
            'Choose one quiet ritual. Every page stays open for as long as '
            'you need, with no pace to keep.',
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
        ),
        const SizedBox(height: 14),
        CareCompanionClock(
          companionName: companionName,
          startedAt: startedAt,
          now: now,
        ),
        const SizedBox(height: 4),
        CareInlineCat(
          motion: motion,
          setting: CareCompanionSetting.room,
          compact: true,
        ),
        if (memory != null) ...<Widget>[const SizedBox(height: 14), memory!],
      ],
    );
  }
}

class _MemoryNote extends StatelessWidget {
  const _MemoryNote({
    required this.line,
    required this.dismissible,
    required this.onDismiss,
  });

  final String line;
  final bool dismissible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: CareEditorialPalette.saffron.withValues(alpha: 0.14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: CareEditorialPalette.saffron,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line,
              style: ExperienceType.bodySmall(CareEditorialPalette.ink),
            ),
          ),
          if (dismissible)
            SizedBox.square(
              dimension: 44,
              child: IconButton(
                tooltip: 'Dismiss remembered help',
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _RitualRow extends StatelessWidget {
  const _RitualRow({
    required this.ritual,
    required this.index,
    required this.onTap,
  });

  final _ToolkitRitual ritual;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${ritual.title}. ${ritual.intention}',
      child: ExcludeSemantics(
        child: Material(
          color: index.isEven
              ? CareEditorialPalette.paperDeep.withValues(alpha: 0.58)
              : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 42,
                      child: CustomPaint(
                        painter: _StepGlyphPainter(ritual.id, 0),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            ritual.title,
                            style: ExperienceType.bodyStrong(
                              CareEditorialPalette.ink,
                            ).copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ritual.intention,
                            style: ExperienceType.bodySmall(
                              CareEditorialPalette.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: CareEditorialPalette.ink,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooserBottomBar extends StatelessWidget {
  const _ChooserBottomBar({required this.onSafety, required this.onExit});

  final VoidCallback? onSafety;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      decoration: const BoxDecoration(
        color: CareEditorialPalette.paper,
        border: Border(top: BorderSide(color: CareEditorialPalette.rule)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _SafetyAction(onPressed: onSafety)),
          if (onExit != null)
            _TextAction(label: 'Leave for now', onPressed: onExit!),
        ],
      ),
    );
  }
}

class _PracticePage extends StatelessWidget {
  const _PracticePage({
    super.key,
    required this.ritual,
    required this.motion,
    required this.companionName,
    required this.startedAt,
    required this.now,
    required this.completing,
    required this.onBack,
    required this.onSafety,
    required this.onComplete,
  });

  final _ToolkitRitual ritual;
  final CareSceneMotionPreference motion;
  final String? companionName;
  final DateTime startedAt;
  final DateTime Function() now;
  final bool completing;
  final VoidCallback onBack;
  final VoidCallback? onSafety;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final bodyRestingCat =
        ritual.id == 'warmth' ||
        ritual.id == 'warm-shower' ||
        ritual.id == 'rest' ||
        ritual.id == 'warm-drink';
    final companionSetting = switch (ritual.id) {
      'warm-drink' => CareCompanionSetting.tableSide,
      'warm-shower' => CareCompanionSetting.bathMat,
      'warmth' || 'rest' => CareCompanionSetting.footSide,
      'lower-back-release' ||
      'knees-to-chest' ||
      'slow-hips' ||
      'massage' => CareCompanionSetting.matEdge,
      _ => CareCompanionSetting.room,
    };
    return CareEditorialPaper(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 24, 0),
              child: Row(
                children: <Widget>[
                  CareEditorialBackButton(onPressed: onBack),
                  const Spacer(),
                  Text(
                    'CARE, AT YOUR PACE',
                    style: ExperienceType.eyebrow(CareEditorialPalette.inkSoft),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 44),
                children: <Widget>[
                  _PracticeIntro(
                    ritual: ritual,
                    companionName: companionName,
                    startedAt: startedAt,
                    now: now,
                  ),
                  const SizedBox(height: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _HeroIllustration(ritualId: ritual.id),
                      if (!bodyRestingCat)
                        Transform.translate(
                          offset: const Offset(0, -14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 180,
                              child: CareInlineCat(
                                motion: motion,
                                setting: companionSetting,
                                compact: true,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'A GENTLE FLOW',
                    style: ExperienceType.eyebrow(CareEditorialPalette.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  for (
                    var index = 0;
                    index < ritual.steps.length;
                    index++
                  ) ...<Widget>[
                    _StepSection(
                      spec: ritual.steps[index],
                      index: index,
                      ritualId: ritual.id,
                    ),
                    if (ritual.id == 'warm-drink' && index == 0)
                      const _DrinkPresentations(),
                  ],
                  if (bodyRestingCat || ritual.id == 'massage') ...<Widget>[
                    const SizedBox(height: 8),
                    CareInlineCat(motion: motion, setting: companionSetting),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Stay as long as this feels good. Nothing ends '
                    'automatically.',
                    style: ExperienceType.body(CareEditorialPalette.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  CareCoralButton(
                    label: "I'm done for now",
                    loading: completing,
                    onPressed: completing ? null : onComplete,
                  ),
                  const SizedBox(height: 8),
                  _TextAction(
                    label: 'Back to everyday care',
                    onPressed: onBack,
                  ),
                  const SizedBox(height: 8),
                  _SafetyAction(onPressed: onSafety),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeIntro extends StatelessWidget {
  const _PracticeIntro({
    required this.ritual,
    required this.companionName,
    required this.startedAt,
    required this.now,
  });

  final _ToolkitRitual ritual;
  final String? companionName;
  final DateTime startedAt;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const CareQuietRule(),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                ritual.eyebrow,
                style: ExperienceType.eyebrow(CareEditorialPalette.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            ritual.title,
            style: ExperienceType.display(
              CareEditorialPalette.ink,
            ).copyWith(fontSize: 42, height: 1.01),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          ritual.intention,
          style: ExperienceType.body(CareEditorialPalette.inkSoft),
        ),
        const SizedBox(height: 10),
        Text(
          ritual.encouragement,
          style: ExperienceType.body(
            CareEditorialPalette.ink,
          ).copyWith(fontStyle: FontStyle.italic, height: 1.45),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: CareEditorialPalette.coral.withValues(alpha: 0.08),
            border: const Border(
              left: BorderSide(color: CareEditorialPalette.coral, width: 3),
            ),
          ),
          child: CareCompanionClock(
            companionName: companionName,
            startedAt: startedAt,
            now: now,
          ),
        ),
      ],
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.ritualId});

  final String ritualId;

  @override
  Widget build(BuildContext context) {
    final label = switch (ritualId) {
      'warmth' =>
        'A warm pack over the lower belly with a cloth layer between heat and skin.',
      'warm-shower' =>
        'A person tests the shower water on the inside of their wrist while a cat stretches on a dry bath mat nearby.',
      'massage' =>
        'Two warm hands using broad, gentle strokes over a tense place.',
      'warm-drink' =>
        'A yellow ceramic cup of warm herbal tea steaming on a small wooden '
            'table beside chamomile, rose petals, and ginger.',
      'lower-back-release' =>
        'A neutral body supported for a small lower-back release.',
      'knees-to-chest' =>
        'A neutral body holding the knees loosely toward the chest.',
      'slow-hips' =>
        'A neutral body using support for small, slow hip circles.',
      _ =>
        'A person resting on their back with support under the knees and a cat curled warmly across their thighs.',
    };
    final atlas = switch (ritualId) {
      'warmth' => const _AtlasPanelSpec(
        asset: CareEditorialAssets.guideWarmth,
        columns: 2,
        rows: 3,
        atlasIndex: 2,
        panelAspectRatio: 9 / 4,
      ),
      'lower-back-release' => const _AtlasPanelSpec(
        asset: CareEditorialAssets.guideLowerBackRelease,
        columns: 2,
        rows: 2,
        atlasIndex: 3,
        panelAspectRatio: 1,
      ),
      'knees-to-chest' => const _AtlasPanelSpec(
        asset: CareEditorialAssets.guideKneesToChest,
        columns: 2,
        rows: 2,
        atlasIndex: 1,
        panelAspectRatio: 3 / 2,
      ),
      'slow-hips' => const _AtlasPanelSpec(
        asset: CareEditorialAssets.guideSlowHips,
        columns: 2,
        rows: 2,
        atlasIndex: 0,
        panelAspectRatio: 1,
      ),
      'massage' => const _AtlasPanelSpec(
        asset: CareEditorialAssets.guideMassage,
        columns: 5,
        rows: 2,
        atlasIndex: 0,
        panelAspectRatio: 27 / 32,
      ),
      'rest' => const _AtlasPanelSpec(
        asset: CareEditorialAssets.guideRest,
        columns: 2,
        rows: 2,
        atlasIndex: 2,
        panelAspectRatio: 1,
      ),
      _ => null,
    };
    if (atlas != null) {
      return CareAtlasPanel(
        atlas.asset,
        label,
        atlas.columns,
        atlas.rows,
        atlas.atlasIndex,
        atlas.panelAspectRatio,
      );
    }
    final asset = switch (ritualId) {
      'warm-shower' => CareEditorialAssets.bodyWarmShowerWide,
      'warm-drink' => CareEditorialAssets.warmDrinkStillLife,
      _ => null,
    };
    if (asset != null) {
      return CareIllustration(asset: asset, semanticsLabel: label, height: 224);
    }
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: 196,
          child: CustomPaint(painter: _RitualObjectPainter(ritualId)),
        ),
      ),
    );
  }
}

class _StepSection extends StatelessWidget {
  const _StepSection({
    required this.spec,
    required this.index,
    required this.ritualId,
  });

  final _ToolkitStepSpec spec;
  final int index;
  final String ritualId;

  @override
  Widget build(BuildContext context) {
    final title = spec.title ?? 'Pause here';
    final atlas = _atlasForStep();
    final massagePair = _massageAtlasPairForStep();
    final hasAtlas = atlas != null || massagePair != null;
    final caution = _caution(spec);
    final spokenDetail = spec.semanticsLabel ?? spec.text;
    final spokenCaution = caution == null ? '' : ' Caution: $caution';
    return Semantics(
      container: true,
      label: 'Step ${index + 1}. $title. $spokenDetail$spokenCaution',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 44,
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${index + 1}',
                          style: ExperienceType.headline(
                            CareEditorialPalette.coralText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 1,
                          height: 52,
                          color: CareEditorialPalette.rule,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                title,
                                style: ExperienceType.headline(
                                  CareEditorialPalette.ink,
                                ).copyWith(fontSize: 22),
                              ),
                            ),
                            if (!hasAtlas)
                              SizedBox.square(
                                dimension: 50,
                                child: CustomPaint(
                                  painter: _StepGlyphPainter(ritualId, index),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          spec.text,
                          style: ExperienceType.body(
                            CareEditorialPalette.inkSoft,
                          ),
                        ),
                        if (caution != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(9),
                            color: CareEditorialPalette.saffron.withValues(
                              alpha: 0.16,
                            ),
                            child: Text(
                              caution,
                              style: ExperienceType.bodySmall(
                                CareEditorialPalette.ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (atlas != null) ...<Widget>[
                const SizedBox(height: 14),
                CareAtlasPanel(
                  atlas.asset,
                  '$title. ${spec.semanticsLabel ?? spec.text}',
                  atlas.columns,
                  atlas.rows,
                  atlas.atlasIndex,
                  atlas.panelAspectRatio,
                ),
              ] else if (massagePair != null) ...<Widget>[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (
                      var pairIndex = 0;
                      pairIndex < massagePair.length;
                      pairIndex++
                    ) ...<Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              pairIndex == 0 ? 'LOWER BELLY' : 'LOWER BACK',
                              style: ExperienceType.eyebrow(
                                CareEditorialPalette.coralText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            CareAtlasPanel(
                              CareEditorialAssets.guideMassage,
                              '${pairIndex == 0 ? 'Lower-belly route' : 'Lower-back route'}. $title.',
                              5,
                              2,
                              massagePair[pairIndex],
                              27 / 32,
                            ),
                          ],
                        ),
                      ),
                      if (pairIndex == 0) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _AtlasPanelSpec? _atlasForStep() {
    if (ritualId == 'warmth' && index < 4) {
      const atlasIndices = <int>[0, 1, 2, 4];
      return _AtlasPanelSpec(
        asset: CareEditorialAssets.guideWarmth,
        columns: 2,
        rows: 3,
        atlasIndex: atlasIndices[index],
        panelAspectRatio: 9 / 4,
      );
    }
    if (ritualId == 'lower-back-release' && index < 4) {
      return _AtlasPanelSpec(
        asset: CareEditorialAssets.guideLowerBackRelease,
        columns: 2,
        rows: 2,
        atlasIndex: index,
        panelAspectRatio: 1,
      );
    }
    if (ritualId == 'knees-to-chest' && index < 4) {
      return _AtlasPanelSpec(
        asset: CareEditorialAssets.guideKneesToChest,
        columns: 2,
        rows: 2,
        atlasIndex: index,
        panelAspectRatio: 3 / 2,
      );
    }
    if (ritualId == 'slow-hips' && index < 4) {
      return _AtlasPanelSpec(
        asset: CareEditorialAssets.guideSlowHips,
        columns: 2,
        rows: 2,
        atlasIndex: index,
        panelAspectRatio: 1,
      );
    }
    if (ritualId == 'massage' && index == 0) {
      return _AtlasPanelSpec(
        asset: CareEditorialAssets.guideMassage,
        columns: 5,
        rows: 2,
        atlasIndex: 0,
        panelAspectRatio: 27 / 32,
      );
    }
    if (ritualId == 'rest' && index < 4) {
      return _AtlasPanelSpec(
        asset: CareEditorialAssets.guideRest,
        columns: 2,
        rows: 2,
        atlasIndex: index,
        panelAspectRatio: 1,
      );
    }
    return null;
  }

  List<int>? _massageAtlasPairForStep() {
    if (ritualId != 'massage' || index == 0) return null;
    return switch (index) {
      1 => const <int>[1, 2],
      2 => const <int>[3, 4],
      3 => const <int>[5, 6],
      _ => const <int>[7, 8],
    };
  }

  String? _caution(_ToolkitStepSpec step) {
    if (ritualId == 'warmth' && step.id == 'warm-not-hot') {
      return 'Warm, never hot. Remove it if skin feels numb or uncomfortable.';
    }
    if (ritualId == 'warm-shower' && step.id == 'temperature') {
      return 'If you feel lightheaded, sit down or step out and cool the water.';
    }
    if (ritualId == 'massage' && step.id == 'press-and-breathe') {
      return 'Stop before any sharp pain.';
    }
    return null;
  }
}

class _AtlasPanelSpec {
  const _AtlasPanelSpec({
    required this.asset,
    required this.columns,
    required this.rows,
    required this.atlasIndex,
    required this.panelAspectRatio,
  });

  final String asset;
  final int columns;
  final int rows;
  final int atlasIndex;
  final double panelAspectRatio;
}

class _DrinkPresentations extends StatefulWidget {
  const _DrinkPresentations();

  @override
  State<_DrinkPresentations> createState() => _DrinkPresentationsState();
}

class _DrinkPresentationsState extends State<_DrinkPresentations> {
  String _selected = 'golden';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(54, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'CHOOSE A CUP',
            style: ExperienceType.eyebrow(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: 8),
          _DrinkChoice(
            title: 'Ginger-Turmeric / Golden Milk',
            body: 'Warm ginger and turmeric with the milk you already enjoy.',
            selected: _selected == 'golden',
            color: CareEditorialPalette.saffron,
            onTap: () => setState(() => _selected = 'golden'),
          ),
          const SizedBox(height: 8),
          _DrinkChoice(
            title: 'Rose-Chamomile',
            body: 'A soft floral steep for a slower evening ritual.',
            selected: _selected == 'rose',
            color: CareEditorialPalette.coral,
            onTap: () => setState(() => _selected = 'rose'),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose familiar ingredients that already suit you. This is a '
            'comfort ritual, not a treatment or a promise about hormones.',
            style: ExperienceType.caption(CareEditorialPalette.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _DrinkChoice extends StatelessWidget {
  const _DrinkChoice({
    required this.title,
    required this.body,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String body;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $body',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? color : Colors.transparent,
                        border: Border.all(color: color, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: ExperienceType.bodyStrong(
                              CareEditorialPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: ExperienceType.bodySmall(
                              CareEditorialPalette.inkSoft,
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
        ),
      ),
    );
  }
}

class _SafetyAction extends StatelessWidget {
  const _SafetyAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = CareSceneFoundation.defaultSafetyLine;
    if (onPressed == null) {
      return Text(
        label,
        style: ExperienceType.caption(CareEditorialPalette.inkSoft),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.favorite_border_rounded, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: CareEditorialPalette.inkSoft,
        textStyle: ExperienceType.caption(CareEditorialPalette.inkSoft),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: CareEditorialPalette.ink,
        textStyle: ExperienceType.bodyStrong(CareEditorialPalette.ink),
      ),
      child: Text(label),
    );
  }
}

class _RitualObjectPainter extends CustomPainter {
  const _RitualObjectPainter(this.id);

  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 340, size.height / 196);
    canvas.save();
    canvas.translate((size.width - 340 * scale) / 2, 0);
    canvas.scale(scale);
    final line = Paint()
      ..color = CareEditorialPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final saffron = Paint()
      ..color = CareEditorialPalette.saffron.withValues(alpha: 0.72);
    final coral = Paint()
      ..color = CareEditorialPalette.coral.withValues(alpha: 0.76);
    final cyan = Paint()
      ..color = CareEditorialPalette.cyan.withValues(alpha: 0.62);

    canvas.drawPath(
      Path()
        ..moveTo(18, 174)
        ..quadraticBezierTo(166, 166, 322, 175),
      line..color = CareEditorialPalette.rule,
    );
    line.color = CareEditorialPalette.ink;

    if (id == 'warmth') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(38, 95, 225, 63),
          const Radius.circular(31),
        ),
        cyan,
      );
      canvas.drawOval(const Rect.fromLTWH(46, 72, 53, 61), saffron);
      canvas.drawOval(const Rect.fromLTWH(46, 72, 53, 61), line);
      final body = Path()
        ..moveTo(94, 101)
        ..quadraticBezierTo(159, 80, 255, 120)
        ..quadraticBezierTo(203, 159, 106, 146)
        ..close();
      canvas.drawPath(body, saffron);
      canvas.drawPath(body, line);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(148, 112, 61, 34),
          const Radius.circular(8),
        ),
        coral,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(148, 112, 61, 34),
          const Radius.circular(8),
        ),
        line,
      );
    } else if (id == 'warm-shower') {
      canvas.drawArc(
        const Rect.fromLTWH(90, 28, 124, 95),
        math.pi,
        math.pi / 2,
        false,
        line..strokeWidth = 7,
      );
      line.strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(185, 58, 58, 24),
          const Radius.circular(12),
        ),
        saffron,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(185, 58, 58, 24),
          const Radius.circular(12),
        ),
        line,
      );
      for (var i = 0; i < 7; i++) {
        final x = 190.0 + i * 7;
        canvas.drawLine(
          Offset(x, 89),
          Offset(x - 13, 151),
          line..color = CareEditorialPalette.cyan,
        );
      }
    } else if (id == 'massage') {
      canvas.drawOval(const Rect.fromLTWH(62, 51, 82, 117), saffron);
      canvas.drawOval(const Rect.fromLTWH(62, 51, 82, 117), line);
      canvas.drawOval(const Rect.fromLTWH(194, 51, 82, 117), saffron);
      canvas.drawOval(const Rect.fromLTWH(194, 51, 82, 117), line);
      canvas.drawArc(
        const Rect.fromLTWH(125, 79, 90, 63),
        math.pi * 0.25,
        math.pi * 1.5,
        false,
        line..color = CareEditorialPalette.coral,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(103, 72, 112, 90),
          const Radius.circular(20),
        ),
        saffron,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(103, 72, 112, 90),
          const Radius.circular(20),
        ),
        line,
      );
      canvas.drawArc(
        const Rect.fromLTWH(197, 90, 68, 55),
        -math.pi / 2,
        math.pi,
        false,
        line..strokeWidth = 5,
      );
      line.strokeWidth = 2;
      for (var i = 0; i < 3; i++) {
        final x = 130.0 + i * 29;
        canvas.drawPath(
          Path()
            ..moveTo(x, 62)
            ..quadraticBezierTo(x - 8, 48, x + 2, 33),
          line..color = CareEditorialPalette.cyan,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RitualObjectPainter oldDelegate) => oldDelegate.id != id;
}

class _StepGlyphPainter extends CustomPainter {
  const _StepGlyphPainter(this.ritualId, this.index);

  final String ritualId;
  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final line = Paint()
      ..color = CareEditorialPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color =
            (index.isEven
                    ? CareEditorialPalette.cyan
                    : CareEditorialPalette.saffron)
                .withValues(alpha: 0.42),
    );
    if (ritualId == 'warm-drink') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 22, height: 19),
          const Radius.circular(4),
        ),
        line,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: center + const Offset(12, 0),
          width: 10,
          height: 11,
        ),
        -math.pi / 2,
        math.pi,
        false,
        line,
      );
    } else if (ritualId == 'warm-shower') {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(center.dx - 8 + i * 8, center.dy - 12),
          Offset(center.dx - 12 + i * 8, center.dy + 12),
          line,
        );
      }
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 27, height: 27),
        -math.pi / 2,
        math.pi * 1.5,
        false,
        line,
      );
      final tip = center + const Offset(-13, -5);
      canvas.drawLine(tip, tip + const Offset(7, 0), line);
      canvas.drawLine(tip, tip + const Offset(4, 7), line);
    }
  }

  @override
  bool shouldRepaint(_StepGlyphPainter oldDelegate) =>
      oldDelegate.ritualId != ritualId || oldDelegate.index != index;
}

class _ToolkitStepSpec {
  const _ToolkitStepSpec({
    required this.id,
    required this.text,
    this.title,
    this.semanticsLabel,
    this.isFinal = false,
  });

  final String id;
  final String? title;
  final String text;
  final String? semanticsLabel;
  final bool isFinal;
}

class _ToolkitRitual {
  const _ToolkitRitual({
    required this.id,
    required this.title,
    required this.intention,
    required this.encouragement,
    required this.energy,
    required this.menuOrder,
    required this.eyebrow,
    required this.steps,
  });

  final String id;
  final String title;
  final String intention;
  final String encouragement;
  final _RitualEnergy energy;
  final int menuOrder;
  final String eyebrow;
  final List<_ToolkitStepSpec> steps;

  /// The everyday toolkit. Copy is presentation-authored inside existing mode
  /// contracts; every ritual is a guided sequence, not static advice.
  static const List<_ToolkitRitual> catalog = <_ToolkitRitual>[
    _ToolkitRitual(
      id: 'warmth',
      title: "Warmth where you're cramping",
      intention: 'A heating pad or warm pack, placed with care.',
      encouragement:
          'Let the warmth arrive gently. Your body can receive care without explaining anything.',
      energy: _RitualEnergy.restHere,
      menuOrder: 2,
      eyebrow: 'EVERYDAY CARE · WARMTH',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'settle',
          title: 'Settle first',
          text:
              'Find a position your body can keep for a few minutes. Loosen '
              'anything tight around your waist. Let your shoulders drop.',
        ),
        _ToolkitStepSpec(
          id: 'warm-not-hot',
          title: 'Warm, not hot',
          text:
              'Use warmth you can keep a hand on comfortably. Put a thin '
              'cloth between heat and skin, and never use heat on numb skin '
              'or while you might fall asleep.',
          semanticsLabel:
              'Burn safety: warm, not hot. Use a cloth layer. Never on numb '
              'skin or while asleep.',
        ),
        _ToolkitStepSpec(
          id: 'place',
          title: 'Place it where it speaks',
          text:
              'Rest the warmth over your lower belly or lower back — '
              'whichever is asking louder. Let the weight be gentle.',
        ),
        _ToolkitStepSpec(
          id: 'stay',
          title: 'Stay for three slow breaths',
          text:
              'Breathe out a little longer than you breathe in. Notice one '
              'small place that softens, even by a fraction.',
        ),
        _ToolkitStepSpec(
          id: 'complete',
          title: 'Leave the warmth nearby',
          text:
              'When you are ready, set the heat somewhere safe and off. '
              'Completing this ritual is optional and only happens if you '
              'choose it now.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'warm-shower',
      title: 'A warm shower',
      intention: 'Let water carry some of the tension for a while.',
      encouragement:
          'Let the water carry the noise away for a moment. Stay with the places that welcome its warmth.',
      energy: _RitualEnergy.littleComfort,
      menuOrder: 1,
      eyebrow: 'EVERYDAY CARE · WARMTH',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'temperature',
          title: 'Warm, not scalding',
          text:
              'Choose water that feels kind on the inside of your wrist. If '
              'you feel lightheaded, sit down or step out and cool the water.',
          semanticsLabel:
              'Burn safety: warm, not scalding. Sit down or step out if '
              'lightheaded.',
        ),
        _ToolkitStepSpec(
          id: 'aim',
          title: 'Aim it at the loud places',
          text:
              'Let the water run over your lower back, neck, or shoulders. '
              'No need to scrub anything away — just let it land.',
        ),
        _ToolkitStepSpec(
          id: 'hands',
          title: 'Add one steady hand',
          text:
              'Place a hand where the ache is strongest. Keep it still. '
              'Count four slow breaths, or as many as feel possible.',
        ),
        _ToolkitStepSpec(
          id: 'after',
          title: 'After the water',
          text:
              'Dry off before you get chilled. Put on the softest layer '
              'within reach. Completing is your choice.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'lower-back-release',
      title: 'Lower-back release',
      intention: 'Small supported movement for a tense or aching lower back.',
      encouragement:
          'Move slowly enough to hear the first quiet answer from your back.',
      energy: _RitualEnergy.moveALittle,
      menuOrder: 1,
      eyebrow: 'EVERYDAY CARE · BODY',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'support',
          title: 'Give your back a floor',
          text:
              'Lie on your back on a bed or mat, knees bent, feet down. If '
              'the floor is too much today, stay seated and lean back into '
              'a cushion instead.',
        ),
        _ToolkitStepSpec(
          id: 'tilt',
          title: 'A tiny pelvic tilt',
          text:
              'Gently flatten your lower back toward the surface, then let '
              'it go. Slow enough that it almost is not movement.',
        ),
        _ToolkitStepSpec(
          id: 'release-neutral',
          title: 'Release back to neutral',
          text:
              'Let the effort go and allow the small natural space beneath '
              'your lower back to return. If helpful, rest a palm under one '
              'side of your waist to notice the space. Do not push the arch.',
        ),
        _ToolkitStepSpec(
          id: 'knees-side',
          title: 'A small side-to-side option',
          text:
              'With feet planted, let both knees drift only a few inches to '
              'one side, return to center, then try the other side. Skip this '
              'if your back prefers stillness.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'knees-to-chest',
      title: 'Knees-to-chest rest',
      intention: 'A curled, supported position for cramps or body tension.',
      encouragement:
          'Hold only as close as your body welcomes, then let stillness do the rest.',
      energy: _RitualEnergy.moveALittle,
      menuOrder: 2,
      eyebrow: 'EVERYDAY CARE · BODY',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'arrive',
          title: 'Arrive on your back',
          text:
              'Lie somewhere comfortable. Bring one knee toward your chest, '
              'then the other if it is welcome. One knee is enough.',
        ),
        _ToolkitStepSpec(
          id: 'hold-loosely',
          title: 'Hold loosely',
          text:
              'Rest your hands on your shins or behind your thighs. No '
              'pulling. Let your belly stay soft under your hands.',
        ),
        _ToolkitStepSpec(
          id: 'rock',
          title: 'A barely-there rock',
          text:
              'If it feels good, rock an inch side to side. If stillness '
              'feels better, be still. Both count.',
        ),
        _ToolkitStepSpec(
          id: 'release',
          title: 'Release slowly',
          text:
              'Lower one foot, then the other. Notice what changed and what '
              'did not. Completing the ritual is a choice, not a duty.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'slow-hips',
      title: 'Slow hip and pelvic movement',
      intention: 'Gentle circles that remind the pelvis it can move.',
      encouragement:
          'Let the circle stay small enough that breathing remains easy.',
      energy: _RitualEnergy.moveALittle,
      menuOrder: 3,
      eyebrow: 'EVERYDAY CARE · BODY',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'stance',
          title: 'Find a steady stance',
          text:
              'Stand with one hand resting lightly on a stable chair or wall. '
              'Let both knees stay soft.',
        ),
        _ToolkitStepSpec(
          id: 'shift-right-front',
          title: 'Shift right, then slightly forward',
          text:
              'Keep both feet down. Move your pelvis an inch toward the '
              'supported side, then an inch forward. Let your torso stay quiet.',
        ),
        _ToolkitStepSpec(
          id: 'shift-left-back',
          title: 'Shift left, then slightly back',
          text:
              'Continue the same tiny path toward the other side and back. '
              'Your knees remain soft and your feet stay weighted.',
        ),
        _ToolkitStepSpec(
          id: 'return-center',
          title: 'Close the circle at center',
          text:
              'Join the four small shifts into one slow circle, or simply '
              'return to center. Stop if your knee, hip, or back objects.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'massage',
      title: 'Belly or back massage',
      intention: 'Your own hands, unhurried, over the tense places.',
      encouragement:
          'Your hands already know how to be gentle. Listen for the pressure your body welcomes.',
      energy: _RitualEnergy.littleComfort,
      menuOrder: 2,
      eyebrow: 'EVERYDAY CARE · BODY',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'warm-hands',
          title: 'Warm your hands',
          text:
              'Rub your palms together for a few seconds. Warm hands are '
              'kinder than efficient ones.',
        ),
        _ToolkitStepSpec(
          id: 'choose-place',
          title: 'Choose one route',
          text:
              'For your lower belly, lie on your side or back and rest a hand '
              'below your navel. For your lower back, stay side-lying and '
              'reach one hand behind you. Follow only the route that fits.',
        ),
        _ToolkitStepSpec(
          id: 'slow-strokes',
          title: 'Follow only the route you chose',
          text:
              'On the lower belly, stroke gently from the center outward. '
              'On the lower back, glide across the reachable muscle beside '
              'the spine, never directly over it. Six slow strokes is plenty.',
        ),
        _ToolkitStepSpec(
          id: 'press-and-breathe',
          title: 'Pause with one steady hand',
          text:
              'Rest one hand on the tender place. As you breathe out, let '
              'your hand get heavier. Stop before any sharp pain.',
        ),
        _ToolkitStepSpec(
          id: 'finish',
          title: 'Finish with stillness',
          text:
              'Keep your hand where it is for one more breath. Completing '
              'is optional and only counts if you choose it.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'rest',
      title: 'Deliberate rest',
      intention: 'Doing nothing on purpose, with a beginning and an end.',
      encouragement:
          'There is nothing to perform here. Notice the smallest place in you that is ready to soften.',
      energy: _RitualEnergy.restHere,
      menuOrder: 1,
      eyebrow: 'EVERYDAY CARE · REST',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'permission',
          title: 'Set up a supported place',
          text:
              'Place a thin pillow under your head and a firm pillow or '
              'bolster under your knees or lower legs. Keep a blanket nearby '
              'only if you want warmth.',
        ),
        _ToolkitStepSpec(
          id: 'position',
          title: 'Lie flat and let the legs be held',
          text:
              'Lie on your back and let the support carry the weight of your '
              'legs. Move it until your lower back can soften without effort.',
        ),
        _ToolkitStepSpec(
          id: 'one-anchor',
          title: 'Rest your hands and choose one anchor',
          text:
              'Let your hands rest wherever they are comfortable. Notice the '
              'support under your legs, the cat beside you, or one easy breath.',
        ),
        _ToolkitStepSpec(
          id: 'end-gently',
          title: 'End gently',
          text:
              'Wiggle fingers and toes. Roll to one side before sitting up. '
              'Complete the rest only if you want it remembered.',
          isFinal: true,
        ),
      ],
    ),
    _ToolkitRitual(
      id: 'warm-drink',
      title: 'A warm drink, slowly',
      intention: 'Comfort in a cup — a ritual, not a treatment.',
      encouragement:
          'Let the cup warm your hands first. There is no need to hurry the first sip.',
      energy: _RitualEnergy.restHere,
      menuOrder: 3,
      eyebrow: 'EVERYDAY CARE · COMFORT',
      steps: <_ToolkitStepSpec>[
        _ToolkitStepSpec(
          id: 'comfort-frame',
          title: 'Comfort, not a cure',
          text:
              'This will not fix a cycle and it does not have to. It is '
              'warmth you can hold, offered for comfort rather than treatment.',
          semanticsLabel:
              'Framing: a warm drink is a comfort ritual, not a treatment. '
              'Warm rather than hot.',
        ),
        _ToolkitStepSpec(
          id: 'safe-sip',
          title: 'Let it cool to kind',
          text:
              'Test the drink before the first real sip. Let it cool until '
              'the temperature feels gentle in your mouth.',
        ),
        _ToolkitStepSpec(
          id: 'both-hands',
          title: 'Both hands around the cup',
          text:
              'Wrap both hands around it. Take three slow sips, with a '
              'breath between each one.',
        ),
        _ToolkitStepSpec(
          id: 'finish-cup',
          title: 'Stop where you want',
          text:
              'You do not need to finish the cup. Completing this ritual '
              'is your choice and only happens from here.',
          isFinal: true,
        ),
      ],
    ),
  ];
}
