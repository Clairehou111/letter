import 'package:flutter/material.dart';

import '../../features/care/domain/care_mode.dart';
import '../../features/care/domain/safety_resources.dart';
import '../theme/experience_foundation.dart';
import 'care_animation_port.dart';
import 'care_editorial_art.dart';

/// A self-paced set of illustrated body-care rooms.
///
/// Entry always begins with a choice. Each practice opens as its own static
/// reading room, and only an explicit action changes rooms or finishes care.
/// The five stable section ids preserve the existing interruption contract.
abstract final class CareBodyScene {
  static const CareMode mode = CareMode.physical;
  static const String eyebrow = 'Care for the body';

  static const String arriveStepId = 'body.arrive';
  static const String settleStepId = 'body.settle';
  static const String warmthStepId = 'body.warmth';
  static const String boundaryStepId = 'body.boundary';
  static const String landingStepId = 'body.landing';

  static const List<String> stepIds = <String>[
    arriveStepId,
    settleStepId,
    warmthStepId,
    boundaryStepId,
    landingStepId,
  ];

  static const String defaultResumeHint = 'Picking up where you paused.';

  static int stepIndexFor(String? stepId) {
    if (stepId == null) return 0;
    final index = stepIds.indexOf(stepId);
    return index < 0 ? 0 : index;
  }

  static Widget build({
    Key? key,
    required CareSceneMotionPreference motionPreference,
    required ValueChanged<CareSceneSignal> onSignal,
    VoidCallback? onExit,
    VoidCallback? onSafety,
    VoidCallback? onCompleted,
    String? resumeStepId,
    String resumeHint = defaultResumeHint,
    String? companionName,
    Future<void> Function(String name)? onCompanionNameSaved,
  }) {
    return _CareBodyScenePage(
      key: key,
      motionPreference: motionPreference,
      onSignal: onSignal,
      onExit: onExit,
      onSafety: onSafety,
      onCompleted: onCompleted,
      resumeStepId: resumeStepId,
      resumeHint: resumeHint,
      companionName: companionName,
      // Naming is intentionally handled in Settings. The argument remains in
      // the public API so existing scene assembly stays source compatible.
      onCompanionNameSaved: onCompanionNameSaved,
    );
  }
}

class _CareBodyScenePage extends StatefulWidget {
  const _CareBodyScenePage({
    super.key,
    required this.motionPreference,
    required this.onSignal,
    this.onExit,
    this.onSafety,
    this.onCompleted,
    this.resumeStepId,
    required this.resumeHint,
    this.companionName,
    this.onCompanionNameSaved,
  });

  final CareSceneMotionPreference motionPreference;
  final ValueChanged<CareSceneSignal> onSignal;
  final VoidCallback? onExit;
  final VoidCallback? onSafety;
  final VoidCallback? onCompleted;
  final String? resumeStepId;
  final String resumeHint;
  final String? companionName;

  /// Kept for source compatibility. Companion names are edited in Settings.
  final Future<void> Function(String name)? onCompanionNameSaved;

  @override
  State<_CareBodyScenePage> createState() => _CareBodyScenePageState();
}

class _CareBodyScenePageState extends State<_CareBodyScenePage> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = List<GlobalKey>.generate(
    CareBodyScene.stepIds.length,
    (_) => GlobalKey(),
  );
  final List<FocusNode> _sectionFocusNodes = List<FocusNode>.generate(
    CareBodyScene.stepIds.length,
    (_) => FocusNode(),
  );

  late DateTime _pageStartedAt;
  String? _activeNeed;
  int? _activeSectionIndex;
  bool _showAcupressure = false;
  String? _acupressureMoment;
  bool _acupressureScreeningAccepted = false;
  String _restMoment = 'rest';
  String _movementPractice = 'lower-back';

  int get _resumeIndex => CareBodyScene.stepIndexFor(widget.resumeStepId);

  bool get _reduceMotion =>
      widget.motionPreference != CareSceneMotionPreference.full;

  String? get _companionName {
    final name = widget.companionName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  String get _companionSubject => _companionName ?? 'Your cat';

  @override
  void initState() {
    super.initState();
    _pageStartedAt = DateTime.now();
    _activeSectionIndex = widget.resumeStepId == null ? null : _resumeIndex;
    _activeNeed = switch (_activeSectionIndex) {
      0 => 'rest',
      1 => 'lower-back',
      2 => 'cramps',
      _ => null,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSignal(CareSceneSignal.ready);
      if (_activeSectionIndex != null) _restoreReadingPosition();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _sectionFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreReadingPosition() async {
    final index = _resumeIndex;
    final target = _sectionKeys[index].currentContext;
    if (target == null) return;
    if (widget.resumeStepId != null) {
      await Scrollable.ensureVisible(
        target,
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    }
    if (mounted) _sectionFocusNodes[index].requestFocus();
  }

  void _complete() {
    ExperienceHaptics.careStepCompleted();
    widget.onSignal(CareSceneSignal.primaryInteraction);
    widget.onSignal(CareSceneSignal.stepCompleted);
    widget.onSignal(CareSceneSignal.sceneCompleted);
    widget.onCompleted?.call();
  }

  void _requestExit() {
    widget.onSignal(CareSceneSignal.requestedExit);
    widget.onExit?.call();
  }

  void _requestSafety() {
    widget.onSignal(CareSceneSignal.requestedSafety);
    widget.onSafety?.call();
  }

  String? _resumeHintFor(int index) {
    if (widget.resumeStepId == null || index != _resumeIndex) return null;
    return widget.resumeHint;
  }

  void _openNeed(String need) {
    ExperienceHaptics.pick();
    widget.onSignal(CareSceneSignal.primaryInteraction);
    setState(() {
      _pageStartedAt = DateTime.now();
      _activeNeed = need;
      _activeSectionIndex = null;
      _showAcupressure = false;
      _acupressureMoment = null;
      _acupressureScreeningAccepted = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollController.jumpTo(0);
    });
  }

  void _openSection(
    int index, {
    String? activeNeed,
    bool acupressure = false,
    String? acupressureMoment,
    String? restMoment,
    String? movementPractice,
  }) {
    ExperienceHaptics.pick();
    widget.onSignal(CareSceneSignal.primaryInteraction);
    setState(() {
      _pageStartedAt = DateTime.now();
      if (activeNeed != null) _activeNeed = activeNeed;
      _activeSectionIndex = index;
      _showAcupressure = acupressure;
      _acupressureMoment = acupressureMoment;
      _acupressureScreeningAccepted = false;
      if (restMoment != null) _restMoment = restMoment;
      if (movementPractice != null) _movementPractice = movementPractice;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollController.jumpTo(0);
      _sectionFocusNodes[index].requestFocus();
    });
  }

  void _showChoices() {
    ExperienceHaptics.pick();
    setState(() {
      _pageStartedAt = DateTime.now();
      _activeSectionIndex = null;
      _activeNeed = null;
      _showAcupressure = false;
      _acupressureMoment = null;
      _acupressureScreeningAccepted = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollController.jumpTo(0);
    });
  }

  void _showNeedChoices() {
    ExperienceHaptics.pick();
    setState(() {
      _pageStartedAt = DateTime.now();
      _activeSectionIndex = null;
      _showAcupressure = false;
      _acupressureMoment = null;
      _acupressureScreeningAccepted = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollController.jumpTo(0);
    });
  }

  void _scrollToTopAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeSectionIndex;
    final need = _activeNeed;
    final body = CareEditorialPaper(
      backgroundColor: need == 'head'
          ? CareEditorialPalette.paperDim
          : CareEditorialPalette.paper,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(
              onBack: active != null
                  ? _backFromPractice
                  : need != null
                  ? _showChoices
                  : _requestExit,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  bottom: ExperienceSpacing.scrollBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: active == null
                      ? <Widget>[
                          need == null
                              ? _buildChooser()
                              : _buildNeedChooser(need),
                        ]
                      : <Widget>[
                          _buildActiveSection(active),
                          _buildPracticeFooter(),
                        ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (active != null) {
          _backFromPractice();
        } else if (need != null) {
          _showChoices();
        } else {
          _requestExit();
        }
      },
      child: body,
    );
  }

  void _backFromPractice() {
    if (_activeNeed == 'head' ||
        _activeNeed == 'stomach' ||
        _activeNeed == 'rest' ||
        _activeNeed == 'acupressure') {
      _showChoices();
    } else {
      _showNeedChoices();
    }
  }

  Widget _buildActiveSection(int index) {
    return switch (index) {
      0 => _buildArriveSection(false),
      1 => _buildSettleSection(false),
      2 =>
        _showAcupressure
            ? _buildAcupressureSection(false)
            : _buildWarmthSection(false),
      3 => _buildBoundarySection(false),
      _ => _buildLandingSection(),
    };
  }

  Widget _buildChooser() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CareQuietRule(),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'What does your body need?',
            style: ExperienceType.display(CareEditorialPalette.ink),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'Start with the place or feeling asking for care. You will choose '
            'the practice yourself; this is not a diagnosis.',
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          CareInlineCat(
            motion: widget.motionPreference,
            setting: CareCompanionSetting.room,
            compact: true,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          _BodyCareChoiceRow(
            title: 'Lower-belly cramps',
            when: 'Cramping, heaviness, or an achy lower belly',
            onTap: () => _openNeed('cramps'),
          ),
          _BodyCareChoiceRow(
            title: 'Lower back or hips',
            when: 'Tight, achy, or tired around the lower back and hips',
            onTap: () => _openNeed('lower-back'),
          ),
          _BodyCareChoiceRow(
            title: 'Headache or light sensitivity',
            when: 'Your head hurts, or light and movement feel like too much',
            onTap: () =>
                _openSection(0, activeNeed: 'head', restMoment: 'head'),
          ),
          _BodyCareChoiceRow(
            title: 'Queasy or bloated stomach',
            when: 'Your stomach feels unsettled, full, or uncomfortable',
            onTap: () =>
                _openSection(0, activeNeed: 'stomach', restMoment: 'stomach'),
          ),
          _BodyCareChoiceRow(
            title: 'I need to rest',
            when: 'When choosing a symptom or movement feels like too much',
            onTap: () =>
                _openSection(0, activeNeed: 'rest', restMoment: 'rest'),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          Text(
            'OPTIONAL TOUCH PRACTICE',
            style: ExperienceType.eyebrow(CareEditorialPalette.coralText),
          ),
          _BodyCareChoiceRow(
            title: 'Explore acupressure',
            when: 'Traditional SP6 and LV3 point-location guides',
            onTap: () =>
                _openSection(2, activeNeed: 'acupressure', acupressure: true),
          ),
          _BodyCareChoiceRow(
            title: 'Know when to seek care',
            when: 'When pain feels unusual, severe, or worrying',
            onTap: () => _openSection(3),
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          _QuietAction(
            label: 'If this feels bigger than this moment, support is here',
            onPressed: _requestSafety,
          ),
        ],
      ),
    );
  }

  Widget _buildNeedChooser(String need) {
    final title = switch (need) {
      'cramps' => 'Lower-belly cramps',
      'lower-back' => 'Lower back or hips',
      'head' => 'Headache or light sensitivity',
      'stomach' => 'Queasy or bloated stomach',
      _ => 'I need to rest',
    };
    final invitation = switch (need) {
      'cramps' =>
        'Choose one kind of comfort for cramping, heaviness, or an achy lower belly.',
      'lower-back' =>
        'Choose stillness, warmth, touch, or one small movement. Stop if pain becomes sharp.',
      'head' =>
        'Keep this simple: less light, a supported head, a little water, and stillness.',
      'stomach' =>
        'A quiet position or a slow warm drink may feel kinder than movement right now.',
      _ =>
        'Let the room grow quiet enough to hear what your body has been saying.',
    };

    final choices = switch (need) {
      'cramps' => <Widget>[
        _BodyCareChoiceRow(
          title: 'Use gentle warmth',
          when: 'A warm pack over the lower belly or lower back',
          onTap: () => _openSection(2),
        ),
        _BodyCareChoiceRow(
          title: 'Find a supported rest',
          when: 'A low-effort position with the cat close by',
          onTap: () => _openSection(0, restMoment: 'cramps'),
        ),
      ],
      'lower-back' => <Widget>[
        _BodyCareChoiceRow(
          title: 'Lower-back release',
          when: 'A supported pelvic tilt and an optional small knee drift',
          onTap: () => _openSection(1, movementPractice: 'lower-back'),
        ),
        _BodyCareChoiceRow(
          title: 'Knees-to-chest rest',
          when: 'One knee or both, held loosely without pulling',
          onTap: () => _openSection(1, movementPractice: 'knees-to-chest'),
        ),
        _BodyCareChoiceRow(
          title: 'Slow hip and pelvic movement',
          when: 'Small supported shifts while standing',
          onTap: () => _openSection(1, movementPractice: 'slow-hips'),
        ),
        _BodyCareChoiceRow(
          title: 'Belly or back massage',
          when: 'Broad, gentle pressure that never becomes painful',
          onTap: () => _openSection(1, movementPractice: 'massage'),
        ),
        _BodyCareChoiceRow(
          title: 'Use gentle warmth',
          when: 'A warm pack over the lower back',
          onTap: () => _openSection(2),
        ),
      ],
      'head' => <Widget>[
        _BodyCareChoiceRow(
          title: 'Quiet, dim, and supported',
          when: 'Lower the light, support your head, and stay still',
          onTap: () => _openSection(0, restMoment: 'head'),
        ),
      ],
      'stomach' => <Widget>[
        _BodyCareChoiceRow(
          title: 'Settle without pressure',
          when: 'A supported position that leaves your stomach uncompressed',
          onTap: () => _openSection(0, restMoment: 'stomach'),
        ),
      ],
      _ => <Widget>[
        _BodyCareChoiceRow(
          title: 'Deliberate rest',
          when: 'Lie flat with your legs supported and the cat nearby',
          onTap: () => _openSection(0, restMoment: 'rest'),
        ),
      ],
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CareQuietRule(),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(title, style: ExperienceType.display(CareEditorialPalette.ink)),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            invitation,
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          CareInlineCat(
            motion: widget.motionPreference,
            setting: CareCompanionSetting.quietCorner,
            compact: true,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          ...choices,
          const SizedBox(height: ExperienceSpacing.lg),
          _QuietAction(
            label: 'Choose a different feeling',
            onPressed: _showChoices,
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          _QuietAction(
            label: 'If this feels bigger than this moment, support is here',
            onPressed: _requestSafety,
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        0,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.scrollBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PrimaryButton(
            label: _activeNeed == 'acupressure'
                ? 'Back to body-care choices'
                : 'Back to these care choices',
            onPressed: _backFromPractice,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          _QuietAction(label: "I'm done for now", onPressed: _complete),
          const SizedBox(height: ExperienceSpacing.xs),
          _QuietAction(
            label: 'If this feels bigger than this moment, support is here',
            onPressed: _requestSafety,
          ),
        ],
      ),
    );
  }

  Widget _buildArriveSection(bool leaveRoomForCat) {
    final title = switch (_restMoment) {
      'head' => 'Quiet, dim, and supported',
      'stomach' => 'Settle without pressure',
      'cramps' => 'A supported place for cramps',
      _ => 'Deliberate rest',
    };
    final opening = switch (_restMoment) {
      'head' =>
        'Lower the light if you can. Support your head and let movement become optional.',
      'stomach' =>
        'Choose a position that leaves your stomach uncompressed. Small sips are enough.',
      'cramps' =>
        'Begin with the shape that asks the least of you. There is no pace to keep.',
      _ =>
        'There is nothing to perform here. Notice the smallest place in you that is ready to soften.',
    };
    return _EditorialSection(
      key: _sectionKeys[0],
      focusNode: _sectionFocusNodes[0],
      title: title,
      resumeHint: _resumeHintFor(0),
      trailingClearance: leaveRoomForCat ? 88 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            opening,
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          if (_restMoment == 'rest')
            const CareAtlasPanel(
              CareEditorialAssets.guideRest,
              'A person lies on their back with the lower legs supported and '
              'their cat resting naturally across their lap.',
              2,
              2,
              2,
              1,
            )
          else if (_restMoment == 'stomach')
            const CareIllustration(
              asset: CareEditorialAssets.warmDrinkStillLife,
              semanticsLabel:
                  'A cat sits naturally beside a steaming warm drink on a low wooden table.',
              height: 210,
            )
          else
            const CareIllustration(
              asset: CareEditorialAssets.bodySideRest,
              semanticsLabel:
                  'A person rests on their side with their head supported and '
                  'a bolster between bent knees while their cat curls beside them.',
              height: 188,
            ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(switch (_restMoment) {
            'head' => 'Support your head and soften the room',
            'stomach' => 'Leave room around your stomach',
            'rest' => 'Let the support carry your legs',
            _ => 'Side rest',
          }, style: ExperienceType.headline(CareEditorialPalette.ink)),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(switch (_restMoment) {
            'head' =>
              'Rest your head on a pillow, close the curtains or lower the '
                  'light, and let your eyes close if that feels better. Take '
                  'a few small sips of water when you are ready.',
            'stomach' =>
              'Sit supported or rest on your side without pressing into your '
                  'belly. If a warm drink sounds welcome, test the temperature '
                  'and sip slowly. Comfort is enough.',
            'rest' =>
              'Lie on your back with a firm pillow or bolster under your lower '
                  'legs. Let your hands rest anywhere comfortable while the cat settles in.',
            _ =>
              'Support your head. Let a pillow or folded blanket separate '
                  'your knees. Shift until your belly and lower back can soften.',
          }, style: ExperienceType.body(CareEditorialPalette.ink)),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            _restMoment == 'head'
                ? 'Seek care for a sudden severe headache, new weakness, confusion, fainting, or vision loss.'
                : 'Stay only while this feels easier than your usual position.',
            style: ExperienceType.caption(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          CareInlineCat(
            motion: _restMoment == 'head'
                ? CareSceneMotionPreference.staticFallback
                : widget.motionPreference,
            setting: _restMoment == 'stomach'
                ? CareCompanionSetting.tableSide
                : CareCompanionSetting.footSide,
          ),
        ],
      ),
    );
  }

  Widget _buildSettleSection(bool leaveRoomForCat) {
    final practice = _BodyMovementSpec.forId(_movementPractice);
    return _EditorialSection(
      key: _sectionKeys[1],
      focusNode: _sectionFocusNodes[1],
      title: practice.title,
      resumeHint: _resumeHintFor(1),
      trailingClearance: leaveRoomForCat ? 88 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            practice.introduction,
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          for (
            var index = 0;
            index < practice.steps.length;
            index++
          ) ...<Widget>[
            _BodyAtlasStep(
              practice: practice,
              index: index,
              motion: widget.motionPreference,
            ),
            if (index < practice.steps.length - 1) const _SectionHairline(),
          ],
          const SizedBox(height: ExperienceSpacing.md),
          Text(
            'Stop if pain becomes sharper, travels down a leg, or you feel numb, weak, or dizzy.',
            style: ExperienceType.bodyStrong(CareEditorialPalette.coralText),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmthSection(bool leaveRoomForCat) {
    return _EditorialSection(
      key: _sectionKeys[2],
      focusNode: _sectionFocusNodes[2],
      title: "Warmth where you're cramping",
      resumeHint: _resumeHintFor(2),
      trailingClearance: leaveRoomForCat ? 88 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'A little warmth may help tight muscles relax. Use a heating '
            'pad, a warm bottle, or a warm compress while you rest.',
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          const CareAtlasPanel(
            CareEditorialAssets.guideWarmth,
            'A person reclines with a warm pack placed low over the belly, '
            'a cloth layer between the heat and skin, and their cat settled '
            'against their legs.',
            2,
            3,
            2,
            9 / 4,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          const _InstructionLine(
            marker: '1',
            title: 'Place a cloth layer',
            detail:
                'Put a thin towel or clothing between your skin and the warm pack.',
          ),
          const _InstructionLine(
            marker: '2',
            title: 'Rest it low',
            detail:
                'Try your lower belly or lower back. Settle into the position '
                'that lets your muscles release.',
          ),
          const _InstructionLine(
            marker: '3',
            title: 'Warm, never hot',
            detail:
                'Remove it if the heat feels uncomfortable or your skin '
                'feels numb. You can stop at any time.',
            last: true,
          ),
          const SizedBox(height: ExperienceSpacing.md),
          Container(
            width: double.infinity,
            color: CareEditorialPalette.paperDeep,
            padding: const EdgeInsets.all(ExperienceSpacing.sm),
            child: Text(
              'Take three unhurried breaths if that feels good. Nothing '
              'moves on automatically; stay with the warmth as long as you like.',
              style: ExperienceType.bodyStrong(CareEditorialPalette.ink),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          CareInlineCat(
            motion: widget.motionPreference,
            setting: CareCompanionSetting.footSide,
          ),
        ],
      ),
    );
  }

  Widget _buildAcupressureSection(bool leaveRoomForCat) {
    return _EditorialSection(
      key: _sectionKeys[2],
      focusNode: _sectionFocusNodes[2],
      title: 'Choose a point-location guide',
      resumeHint: _resumeHintFor(2),
      trailingClearance: leaveRoomForCat ? 88 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            color: CareEditorialPalette.ink,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              'OPTIONAL ACUPRESSURE · SELF-CARE',
              style: ExperienceType.caption(
                Colors.white,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.45),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'These diagrams show traditional point locations for optional, '
            'gentle self-touch. This is comfort care, not medical treatment, '
            'and relief is not guaranteed. Skip it if it does not feel right '
            'for your body.',
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          if (_acupressureMoment == null) ...<Widget>[
            const SizedBox(height: ExperienceSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 180,
                child: CareInlineCat(
                  motion: widget.motionPreference,
                  setting: CareCompanionSetting.quietCorner,
                  compact: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: ExperienceSpacing.lg),
          if (_acupressureMoment == null) ...<Widget>[
            _BodyCareChoiceRow(
              title: 'SP6 · Sanyinjiao',
              when: 'Inner lower leg · open the traditional landmark guide',
              onTap: () {
                setState(() {
                  _pageStartedAt = DateTime.now();
                  _acupressureMoment = 'sp6';
                  _acupressureScreeningAccepted = false;
                });
                _scrollToTopAfterBuild();
              },
            ),
            _BodyCareChoiceRow(
              title: 'LV3 (WHO: LR3) · Taichong',
              when: 'Top of the foot · open the traditional landmark guide',
              onTap: () {
                setState(() {
                  _pageStartedAt = DateTime.now();
                  _acupressureMoment = 'lv3';
                  _acupressureScreeningAccepted = false;
                });
                _scrollToTopAfterBuild();
              },
            ),
          ] else if (!_acupressureScreeningAccepted) ...<Widget>[
            Text(
              'Check before opening the locator',
              style: ExperienceType.title(CareEditorialPalette.ink),
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            const _BulletLine(
              text:
                  'Stop and seek urgent medical care if pain is severe, '
                  'unusual, or worsening, or occurs with fainting, fever, '
                  'repeated vomiting, or heavy bleeding.',
              strong: true,
            ),
            if (_acupressureMoment == 'sp6')
              const _BulletLine(
                text:
                    'Do not use SP6 if you are pregnant, could be '
                    'pregnant, or are unsure.',
                strong: true,
              ),
            const _BulletLine(
              text:
                  'Do not press skin that is numb, wounded, infected, or '
                  'severely swollen.',
            ),
            const _BulletLine(
              text:
                  'Do not press a leg or foot with a known or suspected blood '
                  'clot. New one-sided swelling, warmth, redness or '
                  'discoloration, or tenderness needs prompt medical '
                  'assessment.',
            ),
            const _BulletLine(
              text:
                  'Chest pain, trouble breathing, coughing up blood, or '
                  'fainting needs emergency care.',
              strong: true,
            ),
            const _BulletLine(
              text:
                  'If you have a bleeding disorder or take blood-thinning '
                  'medicine, ask a health care professional first.',
            ),
            const _BulletLine(
              text:
                  'If you are unsure about the location or whether this fits, '
                  'leave the locator closed.',
            ),
            const SizedBox(height: ExperienceSpacing.md),
            _PrimaryButton(
              label: 'I checked — show the locator',
              onPressed: () {
                setState(() {
                  _acupressureScreeningAccepted = true;
                });
                _scrollToTopAfterBuild();
              },
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            _QuietAction(
              label: 'Choose a different moment',
              onPressed: () {
                setState(() {
                  _acupressureMoment = null;
                  _acupressureScreeningAccepted = false;
                });
                _scrollToTopAfterBuild();
              },
            ),
          ] else ...<Widget>[
            _AcupressureReviewArea(
              showHeading: false,
              pointId: _acupressureMoment,
              motion: widget.motionPreference,
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            _QuietAction(
              label: 'Choose a different moment',
              onPressed: () {
                setState(() {
                  _acupressureMoment = null;
                  _acupressureScreeningAccepted = false;
                });
                _scrollToTopAfterBuild();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoundarySection(bool leaveRoomForCat) {
    return _EditorialSection(
      key: _sectionKeys[3],
      focusNode: _sectionFocusNodes[3],
      title: 'When the body asks for more',
      resumeHint: _resumeHintFor(3),
      trailingClearance: leaveRoomForCat ? 88 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cycle pain is common, but new, severe, or unusual pain deserves '
            'medical attention. Some signals should not wait.',
            style: ExperienceType.body(CareEditorialPalette.ink),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          Text(
            'Get urgent medical care now if you notice:',
            style: ExperienceType.bodyStrong(CareEditorialPalette.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          for (final item in medicalBoundaryContent.urgent)
            _BulletLine(text: item, strong: true),
          const SizedBox(height: ExperienceSpacing.md),
          Text(
            'Book a medical assessment if you notice:',
            style: ExperienceType.bodyStrong(CareEditorialPalette.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          for (final item in medicalBoundaryContent.nonUrgent)
            _BulletLine(text: item),
          const SizedBox(height: ExperienceSpacing.md),
          Text(
            'This scene is comfort, not medical care. Nothing here '
            'replaces either kind of help.',
            style: ExperienceType.bodySmall(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          CareInlineCat(
            motion: widget.motionPreference,
            setting: CareCompanionSetting.quietCorner,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLandingSection() {
    return _EditorialSection(
      key: _sectionKeys[4],
      focusNode: _sectionFocusNodes[4],
      title: 'Stay for as long as you need',
      resumeHint: _resumeHintFor(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$_companionSubject can keep you company. You can remain here '
            'without doing another thing; this page will not end on its own.',
            style: ExperienceType.body(CareEditorialPalette.ink),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          CareCompanionClock(
            startedAt: _pageStartedAt,
            companionName: _companionName,
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          CareInlineCat(
            motion: widget.motionPreference,
            setting: CareCompanionSetting.quietCorner,
          ),
          const SizedBox(height: ExperienceSpacing.lg),
          _PrimaryButton(label: "I'm done for now", onPressed: _complete),
          const SizedBox(height: ExperienceSpacing.sm),
          _QuietAction(
            label: 'If this feels bigger than this moment, support is here',
            onPressed: _requestSafety,
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          _QuietAction(label: 'Leave for now', onPressed: _requestExit),
        ],
      ),
    );
  }
}

class _BodyMovementSpec {
  const _BodyMovementSpec({
    required this.title,
    required this.introduction,
    required this.asset,
    required this.columns,
    required this.rows,
    required this.panelAspectRatio,
    required this.atlasIndices,
    required this.steps,
  });

  final String title;
  final String introduction;
  final String asset;
  final int columns;
  final int rows;
  final double panelAspectRatio;
  final List<int> atlasIndices;
  final List<_BodyMovementStep> steps;

  static _BodyMovementSpec forId(String id) {
    return switch (id) {
      'knees-to-chest' => const _BodyMovementSpec(
        title: 'Knees-to-chest rest',
        introduction:
            'Bring in one knee first. Both knees are optional, and there is no need to pull.',
        asset: CareEditorialAssets.guideKneesToChest,
        columns: 2,
        rows: 2,
        panelAspectRatio: 3 / 2,
        atlasIndices: <int>[0, 1, 2, 3],
        steps: <_BodyMovementStep>[
          _BodyMovementStep(
            'Begin with one knee',
            'Lie back with your head supported. Keep one foot grounded and bring the other knee toward you.',
          ),
          _BodyMovementStep(
            'Add the second only if welcome',
            'Bring the other knee in without forcing either hip. One knee remains a complete practice.',
          ),
          _BodyMovementStep(
            'Hold loosely or stay still',
            'Rest your hands behind the thighs or over the shins. A barely-there rock is optional.',
          ),
          _BodyMovementStep(
            'Release one foot at a time',
            'Return one foot, then the other, and pause before sitting up.',
          ),
        ],
      ),
      'slow-hips' => const _BodyMovementSpec(
        title: 'Slow hip and pelvic movement',
        introduction:
            'Stand with one hand on a stable chair or wall. The movement stays small enough that your torso remains quiet.',
        asset: CareEditorialAssets.guideSlowHips,
        columns: 2,
        rows: 2,
        panelAspectRatio: 1,
        atlasIndices: <int>[0, 1, 2, 3],
        steps: <_BodyMovementStep>[
          _BodyMovementStep(
            'Find a steady center',
            'Stand with soft knees and one hand resting lightly on a stable chair or wall.',
          ),
          _BodyMovementStep(
            'Shift right, then slightly forward',
            'Keep both feet weighted and move the pelvis only an inch in each direction.',
          ),
          _BodyMovementStep(
            'Shift left, then slightly back',
            'Continue the same small path without twisting the shoulders.',
          ),
          _BodyMovementStep(
            'Return to center',
            'Join the shifts into one slow circle, or stop at center if that feels better.',
          ),
        ],
      ),
      'massage' => const _BodyMovementSpec(
        title: 'Belly or back massage',
        introduction:
            'Your hands already know how to be gentle. Listen for the pressure your body welcomes.',
        asset: CareEditorialAssets.guideMassage,
        columns: 5,
        rows: 2,
        panelAspectRatio: 27 / 32,
        atlasIndices: <int>[0, 1, 3, 5, 7],
        steps: <_BodyMovementStep>[
          _BodyMovementStep(
            'Warm your hands',
            'Rub your palms together for a few seconds, then let them become still.',
          ),
          _BodyMovementStep(
            'Choose one route',
            'For the lower belly, lie on your side or back. For the lower back, stay on your side and reach one hand to the tense area. Follow only the route that fits.',
          ),
          _BodyMovementStep(
            'Follow only the route you chose',
            'For the lower belly, move gently from the center outward. For the lower back, glide across reachable muscle beside the spine, never directly over it.',
          ),
          _BodyMovementStep(
            'Pause with one steady hand',
            'Let one hand become still over the place you chose. Stop before any sharp pain.',
          ),
          _BodyMovementStep(
            'Finish with stillness',
            'Keep your hand there for one easy breath, then let it lift away.',
          ),
        ],
      ),
      _ => const _BodyMovementSpec(
        title: 'Lower-back release',
        introduction:
            'Use a supported surface and keep the movement almost invisible. Small is enough.',
        asset: CareEditorialAssets.guideLowerBackRelease,
        columns: 2,
        rows: 2,
        panelAspectRatio: 1,
        atlasIndices: <int>[0, 1, 2, 3],
        steps: <_BodyMovementStep>[
          _BodyMovementStep(
            'Settle in neutral',
            'Lie on your back with knees bent and feet down. Support your head so your neck stays easy.',
          ),
          _BodyMovementStep(
            'Try one tiny pelvic tilt',
            'Gently let the lower back become a little heavier against the surface.',
          ),
          _BodyMovementStep(
            'Release back to neutral',
            'Let the small natural space return. If helpful, rest a palm under one side of your waist to notice the space without pushing it larger.',
          ),
          _BodyMovementStep(
            'Add a small knee drift only if welcome',
            'Let both knees move a few inches to one side, return to center, then consider the other side.',
          ),
        ],
      ),
    };
  }
}

class _BodyMovementStep {
  const _BodyMovementStep(this.title, this.detail);

  final String title;
  final String detail;
}

class _BodyAtlasStep extends StatelessWidget {
  const _BodyAtlasStep({
    required this.practice,
    required this.index,
    required this.motion,
  });

  final _BodyMovementSpec practice;
  final int index;
  final CareSceneMotionPreference motion;

  @override
  Widget build(BuildContext context) {
    final step = practice.steps[index];
    final massagePair =
        practice.asset == CareEditorialAssets.guideMassage && index > 0
        ? switch (index) {
            1 => const <int>[1, 2],
            2 => const <int>[3, 4],
            3 => const <int>[5, 6],
            _ => const <int>[7, 8],
          }
        : null;
    final art = massagePair == null
        ? CareAtlasPanel(
            practice.asset,
            '${step.title}. ${step.detail}',
            practice.columns,
            practice.rows,
            practice.atlasIndices[index],
            practice.panelAspectRatio,
          )
        : Row(
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
                        practice.asset,
                        '${pairIndex == 0 ? 'Lower-belly route' : 'Lower-back route'}. ${step.title}.',
                        practice.columns,
                        practice.rows,
                        massagePair[pairIndex],
                        practice.panelAspectRatio,
                      ),
                    ],
                  ),
                ),
                if (pairIndex == 0) const SizedBox(width: 8),
              ],
            ],
          );
    return Semantics(
      container: true,
      label: 'Step ${index + 1}. ${step.title}. ${step.detail}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                art,
                if (index == 0)
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 180,
                        child: CareInlineCat(
                          motion: motion,
                          setting: CareCompanionSetting.matEdge,
                          compact: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            Text(
              '${index + 1} · ${step.title}',
              style: ExperienceType.headline(CareEditorialPalette.ink),
            ),
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              step.detail,
              style: ExperienceType.body(CareEditorialPalette.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyCareChoiceRow extends StatelessWidget {
  const _BodyCareChoiceRow({
    required this.title,
    required this.when,
    required this.onTap,
  });

  final String title;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $when',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CareEditorialPalette.rule),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: ExperienceType.headline(
                          CareEditorialPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        when,
                        style: ExperienceType.bodySmall(
                          CareEditorialPalette.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
                  color: CareEditorialPalette.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.sm,
        ExperienceSpacing.xs,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          CareEditorialBackButton(onPressed: onBack),
          const SizedBox(width: ExperienceSpacing.xs),
          Expanded(
            child: Text(
              CareBodyScene.mode.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ExperienceType.label(CareEditorialPalette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialSection extends StatelessWidget {
  const _EditorialSection({
    super.key,
    required this.focusNode,
    required this.title,
    required this.child,
    this.resumeHint,
    this.trailingClearance = 0,
  });

  final FocusNode focusNode;
  final String title;
  final Widget child;
  final String? resumeHint;
  final double trailingClearance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.screenMargin,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: ExperienceSpacing.xl),
          if (resumeHint != null) ...<Widget>[
            Container(
              width: double.infinity,
              color: CareEditorialPalette.paperDeep,
              padding: const EdgeInsets.all(ExperienceSpacing.sm),
              child: Text(
                resumeHint!,
                style: ExperienceType.bodySmall(CareEditorialPalette.ink),
              ),
            ),
            const SizedBox(height: ExperienceSpacing.lg),
          ],
          const CareQuietRule(),
          const SizedBox(height: ExperienceSpacing.sm),
          Padding(
            padding: EdgeInsets.only(right: trailingClearance),
            child: Focus(
              focusNode: focusNode,
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: ExperienceType.display(CareEditorialPalette.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.md),
          Padding(
            padding: EdgeInsets.only(right: trailingClearance),
            child: child,
          ),
          const SizedBox(height: ExperienceSpacing.xl),
          const Divider(
            height: 1,
            thickness: 1,
            color: CareEditorialPalette.rule,
          ),
        ],
      ),
    );
  }
}

class _AcupressureReviewArea extends StatelessWidget {
  const _AcupressureReviewArea({
    required this.motion,
    this.showHeading = true,
    this.pointId,
  });

  final CareSceneMotionPreference motion;
  final bool showHeading;
  final String? pointId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showHeading) ...<Widget>[
          Container(
            color: CareEditorialPalette.ink,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text(
              'OPTIONAL ACUPRESSURE · SELF-CARE',
              style: ExperienceType.caption(
                Colors.white,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.45),
            ),
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(
            'Acupressure point locator',
            style: ExperienceType.title(CareEditorialPalette.ink),
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'These diagrams show traditional point locations for optional, '
            'gentle self-touch. This is comfort care, not medical treatment, '
            'and relief is not guaranteed.',
            style: ExperienceType.body(CareEditorialPalette.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.lg),
        ],
        if (pointId == null || pointId == 'sp6')
          _AcupressurePoint(
            motion: motion,
            title: 'SP6 · Sanyinjiao',
            when:
                'Use this guide only if you want to explore the traditional '
                'SP6 location. You can stop before touching it.',
            location:
                'Find the highest point of your inner ankle bone. Using your '
                'own hand, measure about four finger widths upward. Find the '
                'inner edge of your shin bone; SP6 is in the soft tissue just '
                'behind that edge, not on the bone. Finger widths are an '
                'approximate guide; bodies vary.',
            asset: CareEditorialAssets.acupressureSp6,
            semanticsLabel:
                'SP6 locator diagram. A marked point on the inner lower leg, '
                'approximately four finger widths above the highest point of '
                'the inner ankle bone and just behind the shin edge.',
          ),
        if (pointId == null) const _SectionHairline(),
        if (pointId == null || pointId == 'lv3')
          _AcupressurePoint(
            motion: motion,
            title: 'LV3 (WHO: LR3) · Taichong',
            when:
                'Use this guide only if you want to explore the traditional '
                'LV3 location. You can stop before touching it.',
            location:
                'Start at the web between your big toe and second toe. Follow '
                'the space between the first and second metatarsal bones '
                'toward your ankle. LV3 is the depression just before the '
                'bases of those bones meet, not in the toe web.',
            asset: CareEditorialAssets.acupressureLv3,
            semanticsLabel:
                'LV3 locator diagram. A marked point in the depression on top '
                'of the foot between the first and second metatarsal bones, '
                'back from the toe web.',
          ),
        const SizedBox(height: ExperienceSpacing.md),
        Container(
          width: double.infinity,
          color: CareEditorialPalette.paperDeep,
          padding: const EdgeInsets.all(ExperienceSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Before touching either point',
                style: ExperienceType.bodyStrong(CareEditorialPalette.ink),
              ),
              const SizedBox(height: ExperienceSpacing.xs),
              const _BulletLine(
                text:
                    'Stop and seek urgent medical care if pain is severe, '
                    'unusual, or worsening, or occurs with fainting, fever, '
                    'repeated vomiting, or heavy bleeding.',
                strong: true,
              ),
              const _BulletLine(
                text:
                    'Avoid areas that are numb, wounded, open, peeling, '
                    'blistered, rash-covered, red, warm, severely swollen, '
                    'draining, or infected.',
              ),
              const _BulletLine(
                text:
                    'Do not press a leg or foot with a known or suspected '
                    'blood clot. New one-sided swelling, warmth, redness or '
                    'discoloration, or tenderness needs prompt medical '
                    'assessment.',
              ),
              const _BulletLine(
                text:
                    'Chest pain, trouble breathing, coughing up blood, or '
                    'fainting needs emergency care.',
                strong: true,
              ),
              const _BulletLine(
                text:
                    'Stop immediately if pressure causes discomfort or dizziness.',
              ),
              if (pointId == null || pointId == 'sp6')
                const _BulletLine(
                  text:
                      'Do not use SP6 if you are pregnant, could '
                      'be pregnant, or are unsure.',
                ),
              const _BulletLine(
                text:
                    'If you have a bleeding disorder or take blood-thinning '
                    'medicine, ask a health care professional first.',
              ),
              const _BulletLine(
                text: 'Do not use acupressure to delay medical care.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcupressurePoint extends StatelessWidget {
  const _AcupressurePoint({
    required this.motion,
    required this.title,
    required this.when,
    required this.location,
    required this.asset,
    required this.semanticsLabel,
  });

  final CareSceneMotionPreference motion;
  final String title;
  final String when;
  final String location;
  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ZoomableLocatorIllustration(
          asset: asset,
          semanticsLabel: semanticsLabel,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 180,
            child: CareInlineCat(
              motion: motion,
              setting: CareCompanionSetting.quietCorner,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(title, style: ExperienceType.headline(CareEditorialPalette.ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'ABOUT THIS GUIDE',
          style: ExperienceType.eyebrow(CareEditorialPalette.coralText),
        ),
        const SizedBox(height: 4),
        Text(when, style: ExperienceType.body(CareEditorialPalette.inkSoft)),
        const SizedBox(height: ExperienceSpacing.sm),
        Text(
          'FIND THE LOCATION',
          style: ExperienceType.eyebrow(CareEditorialPalette.inkSoft),
        ),
        const SizedBox(height: 4),
        Text(location, style: ExperienceType.body(CareEditorialPalette.ink)),
        const SizedBox(height: ExperienceSpacing.xs),
        Text(
          'If you want to explore the point, rest one fingertip there and use '
          'gentle, comfortable pressure. It should not hurt. Release at any '
          'time.',
          style: ExperienceType.bodySmall(CareEditorialPalette.inkSoft),
        ),
      ],
    );
  }
}

class _ZoomableLocatorIllustration extends StatelessWidget {
  const _ZoomableLocatorIllustration({
    required this.asset,
    required this.semanticsLabel,
  });

  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: '$semanticsLabel Open a larger, zoomable diagram.',
          child: ExcludeSemantics(
            child: InkWell(
              onTap: () => _showExpanded(context),
              child: CareIllustration(
                asset: asset,
                semanticsLabel: semanticsLabel,
                height: 300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap the diagram to enlarge the landmarks.',
          style: ExperienceType.caption(CareEditorialPalette.inkSoft),
        ),
      ],
    );
  }

  Future<void> _showExpanded(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: CareEditorialPalette.paper,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Point-location diagram',
                        style: ExperienceType.headline(
                          CareEditorialPalette.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close enlarged diagram',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Semantics(
                  image: true,
                  label: semanticsLabel,
                  child: ExcludeSemantics(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: const EdgeInsets.all(48),
                      child: Center(
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Text(
                  'Pinch to zoom and drag to inspect the landmarks.',
                  style: ExperienceType.bodySmall(CareEditorialPalette.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  const _InstructionLine({
    required this.marker,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final String marker;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Column(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: CareEditorialPalette.coral,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    marker,
                    style: ExperienceType.label(Colors.white),
                  ),
                ),
                if (!last)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: CareEditorialPalette.rule,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: ExperienceSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: ExperienceSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: ExperienceType.bodyStrong(CareEditorialPalette.ink),
                  ),
                  const SizedBox(height: ExperienceSpacing.xs),
                  Text(
                    detail,
                    style: ExperienceType.body(CareEditorialPalette.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? ExperienceType.bodyStrong(CareEditorialPalette.ink)
        : ExperienceType.body(CareEditorialPalette.ink);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: ExperienceSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('•  ', style: style),
              Expanded(child: Text(text, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHairline extends StatelessWidget {
  const _SectionHairline();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: ExperienceSpacing.xl),
      child: Divider(height: 1, thickness: 1, color: CareEditorialPalette.rule),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: ExperienceSpacing.degreeTarget,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: CareEditorialPalette.coral,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: ExperienceType.bodyStrong(Colors.white),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _QuietAction extends StatelessWidget {
  const _QuietAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: 48,
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: CareEditorialPalette.inkSoft,
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: 12,
          ),
          textStyle: ExperienceType.bodySmall(CareEditorialPalette.inkSoft),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
