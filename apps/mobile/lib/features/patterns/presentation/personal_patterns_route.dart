import 'package:flutter/material.dart';

import '../../../experience/plus/plus_experience.dart';
import '../../../experience/theme/experience_foundation.dart';
import '../../entitlement/domain/entitlement.dart';
import '../../entitlement/presentation/entitlement_scope.dart';
import '../../entitlement/presentation/locked_premium_surface.dart';
import '../../cycle/domain/local_date.dart';
import '../../health_records/presentation/health_record_form_screen.dart';
import '../../preparation/domain/preparation_plan.dart';
import '../application/personal_patterns_controller.dart';
import '../data/repository_pattern_source.dart';
import '../domain/patterns_experience_data.dart';
import '../data/personal_pattern_preview_repository.dart';
import '../domain/personal_pattern.dart';
import 'patterns_experience_screen.dart';

/// Loads the factual patterns view from the device's existing repositories.
///
/// This route deliberately owns no pattern storage. It rebuilds the view from
/// confirmed health records, saved Care check-backs, and period starts.
class PersonalPatternsRoute extends StatefulWidget {
  const PersonalPatternsRoute({
    required this.source,
    this.preparationRepository,
    this.previewRepository,
    this.now,
    this.showBack = true,
    super.key,
  });

  final RepositoryPatternSource source;
  final PreparationRepository? preparationRepository;
  final PersonalPatternPreviewRepository? previewRepository;
  final DateTime Function()? now;
  final bool showBack;

  @override
  State<PersonalPatternsRoute> createState() => _PersonalPatternsRouteState();
}

class _PersonalPatternsRouteState extends State<PersonalPatternsRoute> {
  late final PersonalPatternsController _controller;
  late final PersonalPatternPreviewRepository _previewRepository;
  bool? _previewViewed;
  bool _markingPreview = false;

  LocalDate get _today =>
      LocalDate.fromDateTime((widget.now ?? DateTime.now)());

  VoidCallback? get _onBack =>
      widget.showBack ? () => Navigator.of(context).maybePop() : null;

  @override
  void initState() {
    super.initState();
    _controller = PersonalPatternsController(
      source: widget.source,
      mutations: widget.source,
    );
    _previewRepository =
        widget.previewRepository ?? SecurePersonalPatternPreviewRepository();
    _loadPreviewState();
    _controller.load();
  }

  Future<void> _loadPreviewState() async {
    try {
      final viewed = await _previewRepository.hasViewedPreview();
      if (mounted) setState(() => _previewViewed = viewed);
    } on Object {
      if (mounted) setState(() => _previewViewed = true);
    }
  }

  Future<void> _markPreviewViewed() async {
    if (_markingPreview || _previewViewed == true) return;
    _markingPreview = true;
    try {
      await _previewRepository.markPreviewViewed();
    } on Object {
      // This flag only prevents repeating the free preview. Keychain access can
      // be unavailable in an unsigned local build, so it must never interrupt
      // Patterns or surface as an unhandled platform exception.
    } finally {
      _markingPreview = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Letter Within could not refresh your observed history.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editHealthRecord(String sourceId) async {
    final matches = _controller.sourceSnapshot.healthRecords.where(
      (record) => record.id == sourceId,
    );
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That source record is no longer here.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HealthRecordFormScreen(
          repository: widget.source.healthRecords,
          initialRecord: matches.first,
        ),
      ),
    );
    if (mounted) {
      await _run(_controller.refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!EntitlementScope.canUse(context, LetterCapability.personalPatterns)) {
      if (_previewViewed == null || _controller.isLoading) {
        return const Scaffold(
          backgroundColor: ExperienceColors.canvas,
          body: Center(
            child: EmberLoadingIndicator(
              semanticLabel: 'Loading your patterns',
            ),
          ),
        );
      }
      final analysis = _controller.analysis;
      final enoughHistory = _controller.sourceSnapshot.periods.length >= 3;
      if (_previewViewed == false && enoughHistory && !analysis.isEmpty) {
        return _PersonalPatternPreview(
          analysis: analysis,
          onViewed: _markPreviewViewed,
          onSeePlans: () {
            final repository = EntitlementScope.repositoryOf(context);
            if (repository != null) {
              PlusExperience.open(context, entitlementRepository: repository);
            }
          },
        );
      }
      return Scaffold(
        backgroundColor: ExperienceColors.canvas,
        appBar: _patternsAppBar(
          _onBack,
          const Key('personal-patterns-locked-back'),
        ),
        body: LockedPremiumSurface(
          title: 'Patterns gather quietly over cycles.',
          description:
              'With a plan, Letter Within keeps comparing what returned and '
              'what you noticed across cycles.',
          onOpenPlans: () {
            final repository = EntitlementScope.repositoryOf(context);
            if (repository != null) {
              PlusExperience.open(context, entitlementRepository: repository);
            }
          },
        ),
      );
    }
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return _PatternsLoading(onBack: _onBack);
        }
        if (_controller.error != null) {
          return _PatternsLoadError(onBack: _onBack, onRetry: _controller.load);
        }
        final data = const PatternsExperienceDataBuilder().build(
          _controller.sourceSnapshot,
          today: _today,
        );
        return PatternsExperienceScreen(
          data: data,
          onBack: _onBack,
          onEditHealthRecord: (sourceId) => _editHealthRecord(sourceId),
        );
      },
    );
  }
}

class _PersonalPatternPreview extends StatefulWidget {
  const _PersonalPatternPreview({
    required this.analysis,
    required this.onViewed,
    required this.onSeePlans,
  });

  final PersonalPatternAnalysis analysis;
  final Future<void> Function() onViewed;
  final VoidCallback onSeePlans;

  @override
  State<_PersonalPatternPreview> createState() =>
      _PersonalPatternPreviewState();
}

class _PersonalPatternPreviewState extends State<_PersonalPatternPreview> {
  @override
  void initState() {
    super.initState();
    if (_hasComparableEvidence) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onViewed());
    }
  }

  bool get _hasComparableEvidence {
    final symptom = widget.analysis.symptomPatterns.firstOrNull;
    if (symptom != null) return symptom.count >= 2;
    final action = widget.analysis.supportActions.firstOrNull;
    return action != null && action.count >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final symptom = widget.analysis.symptomPatterns.firstOrNull;
    final action = widget.analysis.supportActions.firstOrNull;
    final title = symptom != null
        ? _recordedFinding(symptom.symptom.label, symptom.count, 'returned')
        : _recordedFinding(action!.actionLabel, action.count, 'was recorded');
    final detail = !_hasComparableEvidence
        ? 'Save one more check-back and Patterns can start comparing what helped.'
        : symptom != null
        ? 'This comes from ${symptom.coveredDates.length} confirmed days in your local history.'
        : action!.factualOutcomeSummary;
    return Scaffold(
      backgroundColor: ExperienceColors.canvas,
      appBar: _patternsAppBar(
        () => Navigator.of(context).pop(),
        const Key('personal-patterns-preview-back'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
              children: [
                Text(
                  'ONE REAL PREVIEW',
                  style: ExperienceType.eyebrow(ExperienceColors.emberDeep),
                ),
                const SizedBox(height: ExperienceSpacing.unit),
                Text(
                  title,
                  key: const Key('personal-patterns-real-preview'),
                  style: ExperienceType.display(ExperienceColors.ink),
                ),
                const SizedBox(height: ExperienceSpacing.xs + 4),
                Text(
                  detail,
                  style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
                ),
                const SizedBox(height: ExperienceSpacing.lg),
                if (_hasComparableEvidence) ...[
                  Text(
                    'Letter Within Plus keeps comparing future cycles and lets '
                    'you prepare your next window. This preview is descriptive, '
                    'not a diagnosis.',
                    style: ExperienceType.body(ExperienceColors.ink),
                  ),
                  const SizedBox(height: ExperienceSpacing.lg),
                  _EmberPrimaryAction(
                    buttonKey: const Key('personal-patterns-preview-plans'),
                    label: 'See Letter Within Plus',
                    onPressed: widget.onSeePlans,
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: ExperienceColors.inkSoft,
                    textStyle: ExperienceType.label(ExperienceColors.inkSoft),
                    minimumSize: const Size(
                      64,
                      ExperienceSpacing.minTouchTarget,
                    ),
                  ),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _recordedFinding(String label, int count, String verb) {
  if (count == 1) return '$label $verb once.';
  if (count == 2) return '$label $verb twice.';
  return '$label $verb $count times.';
}

PreferredSizeWidget? _patternsAppBar(VoidCallback? onBack, Key backKey) {
  if (onBack == null) return null;
  return AppBar(
    backgroundColor: ExperienceColors.canvas,
    foregroundColor: ExperienceColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: IconButton(
      key: backKey,
      tooltip: 'Back',
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    ),
  );
}

/// The single filled ember action of a surface — ember gradient fill, white
/// label, warm shadow.
class _EmberPrimaryAction extends StatelessWidget {
  const _EmberPrimaryAction({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          borderRadius: ExperienceRadius.chipRadius,
          child: InkWell(
            key: buttonKey,
            borderRadius: ExperienceRadius.chipRadius,
            onTap: onPressed,
            child: Ink(
              decoration: BoxDecoration(
                gradient: enabled ? ExperienceColors.emberGradient : null,
                color: enabled ? null : ExperienceColors.surfaceWarm,
                borderRadius: ExperienceRadius.chipRadius,
                boxShadow: enabled
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: ExperienceColors.emberGlow,
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExperienceSpacing.sm,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: ExperienceSpacing.unit),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: ExperienceType.label(
                            enabled ? Colors.white : ExperienceColors.inkSoft,
                          ),
                        ),
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
  }
}

class _PatternsLoading extends StatelessWidget {
  const _PatternsLoading({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('personal-patterns-loading'),
      backgroundColor: ExperienceColors.canvas,
      appBar: _patternsAppBar(
        onBack,
        const Key('personal-patterns-loading-back'),
      ),
      body: const Center(
        child: EmberLoadingIndicator(
          size: 48,
          semanticLabel: 'Loading your patterns',
        ),
      ),
    );
  }
}

class _PatternsLoadError extends StatelessWidget {
  const _PatternsLoadError({required this.onBack, required this.onRetry});

  final VoidCallback? onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExperienceColors.canvas,
      appBar: _patternsAppBar(
        onBack,
        const Key('personal-patterns-error-back'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ExperienceSpacing.md),
                  decoration: BoxDecoration(
                    color: ExperienceColors.surface,
                    borderRadius: ExperienceRadius.cardRadius,
                    border: Border.all(color: ExperienceColors.hairline),
                    boxShadow: ExperienceShadows.card,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 28,
                          color: ExperienceColors.error,
                        ),
                      ),
                      const SizedBox(height: ExperienceSpacing.sm),
                      Text(
                        'Your observed history could not be opened.',
                        textAlign: TextAlign.center,
                        style: ExperienceType.bodyStrong(ExperienceColors.ink),
                      ),
                      const SizedBox(height: ExperienceSpacing.lg),
                      _EmberPrimaryAction(
                        buttonKey: const Key('personal-patterns-retry'),
                        label: 'Try again',
                        icon: Icons.refresh,
                        onPressed: onRetry,
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
  }
}
