import 'dart:async';

import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../care/domain/care_mode.dart';
import '../../care/presentation/care_safety_boundary_sheet.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';

class HealthRecordFormScreen extends StatefulWidget {
  const HealthRecordFormScreen({
    required this.repository,
    super.key,
    this.initialRecord,
    this.now,
    this.initialCategory,
  });

  final HealthRecordRepository repository;
  final HealthRecord? initialRecord;
  final DateTime Function()? now;
  final SymptomCategory? initialCategory;

  @override
  State<HealthRecordFormScreen> createState() => _HealthRecordFormScreenState();
}

class _HealthRecordFormScreenState extends State<HealthRecordFormScreen> {
  late final Map<SymptomType, SymptomSeverity> _ratings;
  late LocalDate _experiencedDate;
  late HealthRecordProvenance _provenance;
  late SymptomCategory _category;
  final Set<FunctionalImpact> _functionalImpacts = {};
  var _step = 0;
  var _saving = false;
  String? _error;

  bool get _editing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    _ratings = {if (initial != null) initial.symptom: initial.severity};
    _experiencedDate =
        initial?.experiencedDate ??
        LocalDate.fromDateTime((widget.now ?? DateTime.now)().toLocal());
    _provenance = _provenanceForDate(_experiencedDate);
    _category =
        initial?.symptom.category ??
        widget.initialCategory ??
        SymptomCategory.physical;
    if (initial != null) {
      _functionalImpacts.addAll(initial.functionalImpacts);
    }
  }

  HealthRecordProvenance _provenanceForDate(LocalDate date) {
    final today = LocalDate.fromDateTime(
      (widget.now ?? DateTime.now)().toLocal(),
    );
    return date == today
        ? HealthRecordProvenance.sameDay
        : HealthRecordProvenance.laterRecall;
  }

  Future<void> _chooseSymptom(SymptomType symptom) async {
    final severity = await showExperienceSheet<SymptomSeverity>(
      context,
      child: _SymptomIntensitySheet(
        symptom: symptom,
        initialSeverity: _ratings[symptom],
      ),
    );
    if (severity == null || !mounted) {
      return;
    }
    setState(() {
      if (_editing) {
        _ratings.clear();
      }
      _ratings[symptom] = severity;
      _error = null;
    });
  }

  Future<void> _openSafetyBoundary(SafetySignal signal) async {
    final screenContext = context;
    await showExperienceSheet<void>(
      context,
      child: CareSafetyBoundarySheet(
        kind: signal.physical
            ? CareSafetyKind.physical
            : CareSafetyKind.emotional,
        onLeaveCare: () {
          Navigator.of(context).pop();
          Navigator.of(screenContext).pop();
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _experiencedDate.asLocalDateTime,
      firstDate: DateTime(2000),
      lastDate: (widget.now ?? DateTime.now)().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      final date = LocalDate.fromDateTime(picked);
      setState(() {
        _experiencedDate = date;
        _provenance = _provenanceForDate(date);
      });
    }
  }

  Future<void> _save() async {
    if (_ratings.isEmpty) {
      setState(() {
        _step = 0;
        _error = 'Choose and rate at least one symptom.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entries = _ratings.entries.toList()
        ..sort((left, right) => left.key.index.compareTo(right.key.index));
      for (final entry in entries) {
        final draft = HealthRecordDraft(
          symptom: entry.key,
          severity: entry.value,
          // Preserve legacy values when editing. Routine capture no longer
          // asks for a second pain scale or a location field.
          functionalImpacts: _functionalImpacts,
          experiencedDate: _experiencedDate,
          provenance: _provenance,
        );
        if (_editing) {
          await widget.repository.update(widget.initialRecord!.id, draft);
        } else {
          await widget.repository.create(draft);
        }
      }
      if (mounted) {
        unawaited(ExperienceHaptics.saved());
        Navigator.of(context).pop();
      }
    } on HealthRecordException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.userMessage;
        });
      }
    }
  }

  void _goBack() {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Edit symptom detail' : 'Add symptom details';
    final reduced = ExperienceMotion.reducedMotion(context);
    return Scaffold(
      backgroundColor: ExperienceColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              label: title,
              header: true,
              child: const SizedBox.shrink(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ExperienceSpacing.screenMargin,
                  ExperienceSpacing.sm,
                  ExperienceSpacing.screenMargin,
                  0,
                ),
                child: _ErrorBanner(text: _error!),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                child: _step == 0
                    ? _SymptomStep(
                        key: const ValueKey('symptom-step'),
                        category: _category,
                        ratings: _ratings,
                        editing: _editing,
                        onBack: _goBack,
                        onCategoryChanged: (value) =>
                            setState(() => _category = value),
                        onChoose: _chooseSymptom,
                        onRemove: (symptom) =>
                            setState(() => _ratings.remove(symptom)),
                        onSafety: _openSafetyBoundary,
                      )
                    : _ContextStep(
                        key: const ValueKey('context-step'),
                        ratings: _ratings,
                        experiencedDate: _experiencedDate,
                        provenance: _provenance,
                        functionalImpacts: _functionalImpacts,
                        editing: _editing,
                        onBack: _goBack,
                        onEdit: _chooseSymptom,
                        onRemove: _editing
                            ? null
                            : (symptom) =>
                                  setState(() => _ratings.remove(symptom)),
                        onPickDate: _pickDate,
                        onImpactChanged: (impact) => setState(() {
                          if (!_functionalImpacts.add(impact)) {
                            _functionalImpacts.remove(impact);
                          }
                        }),
                      ),
              ),
            ),
            _BottomActionBar(
              step: _step,
              selectionCount: _ratings.length,
              editing: _editing,
              saving: _saving,
              onCancel: () => Navigator.of(context).maybePop(),
              onPressed: _step == 0
                  ? (_ratings.isEmpty
                        ? null
                        : () => setState(() {
                            _step = 1;
                            _error = null;
                          }))
                  : _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared primitives
// ---------------------------------------------------------------------------

Duration _motion(BuildContext context, Duration duration) {
  return ExperienceMotion.reducedMotion(context) ? Duration.zero : duration;
}

bool _isCompactLayout(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return width <= 340 || textScale > 1.35;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ExperienceColors.surface,
          borderRadius: ExperienceRadius.chipRadius,
          border: Border.all(color: ExperienceColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.error_outline,
                size: 18,
                color: ExperienceColors.error,
              ),
            ),
            const SizedBox(width: ExperienceSpacing.xs + 4),
            Expanded(
              child: Text(
                text,
                style: ExperienceType.bodySmall(ExperienceColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.backLabel,
  });

  final int step;
  final int total;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final reduced = ExperienceMotion.reducedMotion(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.sm,
        ExperienceSpacing.screenMargin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: backLabel,
                child: InkWell(
                  onTap: onBack,
                  borderRadius: ExperienceRadius.chipRadius,
                  child: const SizedBox(
                    width: ExperienceSpacing.minTouchTarget,
                    height: ExperienceSpacing.minTouchTarget,
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: ExperienceColors.inkSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs + 4),
              Expanded(
                child: Semantics(
                  label: 'Step $step of $total',
                  child: _EmberProgressTrack(
                    fraction: step / total,
                    reduced: reduced,
                  ),
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs + 4),
              Text(
                '$step of $total',
                style: ExperienceType.data(
                  ExperienceColors.inkSoft,
                  size: 13,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.sm),
          Text(title, style: ExperienceType.title(ExperienceColors.ink)),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            subtitle,
            style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// The ember-filled stage track — one warm fill on a hairline track.
class _EmberProgressTrack extends StatelessWidget {
  const _EmberProgressTrack({required this.fraction, required this.reduced});

  final double fraction;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 6,
          decoration: const BoxDecoration(
            color: ExperienceColors.hairline,
            borderRadius: ExperienceRadius.cardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : ExperienceMotion.sheetUp,
              curve: Curves.easeOut,
              width: constraints.maxWidth * fraction.clamp(0.0, 1.0).toDouble(),
              height: 6,
              decoration: const BoxDecoration(
                gradient: ExperienceColors.emberGradient,
                borderRadius: ExperienceRadius.cardRadius,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.support});

  final String title;
  final String? support;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.lg,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.xs + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ExperienceType.headline(ExperienceColors.ink)),
          if (support != null) ...[
            const SizedBox(height: ExperienceSpacing.xs),
            Text(
              support!,
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: ExperienceColors.surface,
    borderRadius: ExperienceRadius.cardRadius,
    border: Border.all(color: ExperienceColors.hairline),
    boxShadow: ExperienceShadows.card,
  );
}

/// The single filled ember action of a surface. Disabled state renders
/// surfaceWarm with an inkSoft label at reduced opacity.
class _EmberPrimaryButton extends StatelessWidget {
  const _EmberPrimaryButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
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
          child: InkWell(
            key: buttonKey,
            borderRadius: ExperienceRadius.chipRadius,
            onTap: onPressed,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(
                label,
                style: enabled
                    ? ExperienceType.label(Colors.white)
                    : ExperienceType.label(
                        ExperienceColors.inkSoft.withValues(alpha: 0.7),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary quiet action — hairline outline in ink.
class _QuietButton extends StatelessWidget {
  const _QuietButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        key: buttonKey,
        onTap: onPressed,
        borderRadius: ExperienceRadius.chipRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: ExperienceColors.hairline),
          ),
          child: Text(
            label,
            style: ExperienceType.bodySmall(
              ExperienceColors.ink,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — symptoms
// ---------------------------------------------------------------------------

class _SymptomStep extends StatefulWidget {
  const _SymptomStep({
    required super.key,
    required this.category,
    required this.ratings,
    required this.editing,
    required this.onCategoryChanged,
    required this.onChoose,
    required this.onRemove,
    required this.onSafety,
    required this.onBack,
  });

  final SymptomCategory category;
  final Map<SymptomType, SymptomSeverity> ratings;
  final bool editing;
  final ValueChanged<SymptomCategory> onCategoryChanged;
  final ValueChanged<SymptomType> onChoose;
  final ValueChanged<SymptomType> onRemove;
  final ValueChanged<SafetySignal> onSafety;
  final VoidCallback onBack;

  @override
  State<_SymptomStep> createState() => _SymptomStepState();
}

class _SymptomStepState extends State<_SymptomStep> {
  static const _routinePreviewCount = 6;

  late final TextEditingController _searchController;
  String _query = '';
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SymptomStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _query = '';
      _showAll = false;
      _searchController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final symptoms = SymptomType.values
        .where(
          (symptom) =>
              symptom.availableForNewRecords &&
              symptom.category == widget.category,
        )
        .toList();
    final safetySignals = switch (widget.category) {
      SymptomCategory.mood =>
        SafetySignal.values.where((signal) => !signal.physical).toList(),
      SymptomCategory.physical =>
        SafetySignal.values.where((signal) => signal.physical).toList(),
      _ => const <SafetySignal>[],
    };
    final searchable = symptoms.length >= 10;
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredSymptoms = normalizedQuery.isEmpty
        ? symptoms
        : symptoms
              .where(
                (symptom) =>
                    symptom.label.toLowerCase().contains(normalizedQuery),
              )
              .toList();
    final previewing =
        !_showAll && normalizedQuery.isEmpty && symptoms.length > 6;
    final visibleSymptoms = previewing
        ? filteredSymptoms.take(_routinePreviewCount).toList()
        : filteredSymptoms;
    final compactLayout = _isCompactLayout(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.only(bottom: ExperienceSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ExperienceSpacing.screenMargin,
                ExperienceSpacing.xs + 4,
                ExperienceSpacing.screenMargin,
                0,
              ),
              child: Text(
                widget.editing ? 'Edit symptom detail' : 'Add symptom details',
                style: ExperienceType.eyebrow(ExperienceColors.inkSoft),
              ),
            ),
            _StageHeader(
              step: 1,
              total: 2,
              title: widget.editing
                  ? 'What changed?'
                  : 'What are you noticing?',
              subtitle: widget.editing
                  ? 'Choose the symptom and confirm its intensity.'
                  : 'Choose one symptom at a time. You can add more.',
              onBack: widget.onBack,
              backLabel: 'Close',
            ),
            if (widget.ratings.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Chosen so far',
                support: 'Each one becomes its own record when you save.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceSpacing.screenMargin,
                ),
                child: _SelectedRatings(
                  ratings: widget.ratings,
                  onEdit: widget.onChoose,
                  onRemove: widget.editing ? null : widget.onRemove,
                ),
              ),
            ],
            const _SectionHeader(
              title: 'Choose a symptom',
              support: 'Only symptoms you explicitly rate become records.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.screenMargin,
              ),
              child: _CategoryGroup(
                selected: widget.category,
                compact: compactLayout,
                onChanged: (value) {
                  unawaited(ExperienceHaptics.pick());
                  widget.onCategoryChanged(value);
                },
              ),
            ),
            if (safetySignals.isNotEmpty) ...[
              const SizedBox(height: ExperienceSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExperienceSpacing.screenMargin,
                ),
                child: _SafetySignalPanel(
                  signals: safetySignals,
                  onSelected: widget.onSafety,
                ),
              ),
            ],
            const SizedBox(height: ExperienceSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.screenMargin,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (searchable) ...[
                    _SymptomSearchField(
                      key: const Key('symptom-search'),
                      controller: _searchController,
                      hintText:
                          'Search ${_categoryLabel(widget.category).toLowerCase()} choices',
                      resultLine: normalizedQuery.isEmpty
                          ? null
                          : visibleSymptoms.isEmpty
                          ? 'No choices match “$_query”.'
                          : '${visibleSymptoms.length} of ${symptoms.length} choices match “$_query”.',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: ExperienceSpacing.xs + 4),
                  ],
                  if (visibleSymptoms.isEmpty)
                    Text(
                      'No symptoms match “$_query”.',
                      style: ExperienceType.caption(ExperienceColors.inkSoft),
                    )
                  else if (compactLayout)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final symptom in visibleSymptoms)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ExperienceSpacing.unit,
                            ),
                            child: _RoutineSymptomChip(
                              key: Key('symptom-${symptom.name}'),
                              label: symptom.label,
                              selected: widget.ratings.containsKey(symptom),
                              fullWidth: true,
                              onTap: () => widget.onChoose(symptom),
                            ),
                          ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: ExperienceSpacing.unit,
                      runSpacing: ExperienceSpacing.unit,
                      children: [
                        for (final symptom in visibleSymptoms)
                          _RoutineSymptomChip(
                            key: Key('symptom-${symptom.name}'),
                            label: symptom.label,
                            selected: widget.ratings.containsKey(symptom),
                            fullWidth: symptom.label.length > 22,
                            onTap: () => widget.onChoose(symptom),
                          ),
                      ],
                    ),
                  if (normalizedQuery.isEmpty && symptoms.length > 6)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: ExperienceSpacing.xs,
                        bottom: ExperienceSpacing.unit,
                      ),
                      child: _ShowAllSymptomsToggle(
                        key: const Key('symptom-toggle-more'),
                        expanded: _showAll,
                        total: symptoms.length,
                        onToggle: () => setState(() => _showAll = !_showAll),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.selected,
    required this.compact,
    required this.onChanged,
  });

  final SymptomCategory selected;
  final bool compact;
  final ValueChanged<SymptomCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final category in SymptomCategory.values)
        _CategoryChip(
          category: category,
          selected: category == selected,
          onTap: () => onChanged(category),
        ),
    ];
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: chips[0]),
              const SizedBox(width: ExperienceSpacing.unit),
              Expanded(child: chips[1]),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.unit),
          Row(
            children: [
              Expanded(child: chips[2]),
              const SizedBox(width: ExperienceSpacing.unit),
              Expanded(child: chips[3]),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        for (var index = 0; index < chips.length; index++) ...[
          if (index > 0) const SizedBox(width: ExperienceSpacing.unit),
          Expanded(child: chips[index]),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SymptomCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _categoryLabel(category);
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label category, selected' : '$label category',
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: _motion(context, ExperienceMotion.chipSelect),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ExperienceColors.surfaceWarm
                : ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected
                  ? ExperienceColors.ember
                  : ExperienceColors.hairline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _categoryIcon(category),
                size: 16,
                color: selected
                    ? ExperienceColors.ember
                    : ExperienceColors.inkSoft,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceType.caption(
                    selected ? ExperienceColors.ink : ExperienceColors.inkSoft,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineSymptomChip extends StatelessWidget {
  const _RoutineSymptomChip({
    required super.key,
    required this.label,
    required this.selected,
    required this.fullWidth,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool fullWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = InkWell(
      onTap: onTap,
      borderRadius: ExperienceRadius.chipRadius,
      child: AnimatedContainer(
        duration: _motion(context, ExperienceMotion.chipSelect),
        curve: Curves.easeOut,
        width: fullWidth ? double.infinity : null,
        constraints: const BoxConstraints(
          minHeight: ExperienceSpacing.minTouchTarget,
          minWidth: 88,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? ExperienceColors.surfaceWarm
              : ExperienceColors.surface,
          borderRadius: ExperienceRadius.chipRadius,
          border: Border.all(
            color: selected
                ? ExperienceColors.ember
                : ExperienceColors.hairline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check : Icons.add,
              size: 16,
              color: selected
                  ? ExperienceColors.ember
                  : ExperienceColors.inkSoft,
            ),
            const SizedBox(width: ExperienceSpacing.unit),
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style:
                    ExperienceType.bodySmall(
                      selected
                          ? ExperienceColors.ink
                          : ExperienceColors.inkSoft,
                    ).copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, selected' : label,
      hint: selected
          ? 'Selected. Activate to change intensity.'
          : 'Activate to confirm how strong it was.',
      child: fullWidth
          ? SizedBox(width: double.infinity, child: surface)
          : surface,
    );
  }
}

class _ShowAllSymptomsToggle extends StatelessWidget {
  const _ShowAllSymptomsToggle({
    required super.key,
    required this.expanded,
    required this.total,
    required this.onToggle,
  });

  final bool expanded;
  final int total;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onToggle,
        borderRadius: ExperienceRadius.chipRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: ExperienceSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Icon(
                Icons.expand_more,
                size: 18,
                color: ExperienceColors.ember,
              ),
              if (expanded)
                const Icon(
                  Icons.expand_less,
                  size: 18,
                  color: ExperienceColors.ember,
                ),
              const SizedBox(width: ExperienceSpacing.xs),
              Expanded(
                child: Text(
                  expanded ? 'Show fewer' : 'Show all ($total)',
                  softWrap: true,
                  style: ExperienceType.caption(
                    ExperienceColors.ember,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomSearchField extends StatelessWidget {
  const _SymptomSearchField({
    required super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.resultLine,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final String? resultLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: ExperienceColors.surface,
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(color: ExperienceColors.hairline),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: 18,
                color: ExperienceColors.inkSoft,
              ),
              const SizedBox(width: ExperienceSpacing.unit),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: ExperienceType.bodySmall(ExperienceColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: ExperienceType.caption(
                      ExperienceColors.inkFaint,
                    ),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                Semantics(
                  button: true,
                  label: 'Clear search',
                  child: InkWell(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    borderRadius: ExperienceRadius.chipRadius,
                    child: const SizedBox(
                      width: ExperienceSpacing.minTouchTarget,
                      height: ExperienceSpacing.minTouchTarget,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: ExperienceColors.inkSoft,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (resultLine != null) ...[
          const SizedBox(height: ExperienceSpacing.unit),
          Semantics(
            liveRegion: true,
            child: Text(
              resultLine!,
              style: ExperienceType.caption(ExperienceColors.inkSoft),
            ),
          ),
        ],
      ],
    );
  }
}

class _SafetySignalPanel extends StatelessWidget {
  const _SafetySignalPanel({required this.signals, required this.onSelected});

  final List<SafetySignal> signals;
  final ValueChanged<SafetySignal> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(ExperienceSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                size: 20,
                color: ExperienceColors.accentSafety,
              ),
              const SizedBox(width: ExperienceSpacing.unit),
              Expanded(
                child: Text(
                  'Immediate safety',
                  style: ExperienceType.label(ExperienceColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: ExperienceSpacing.xs),
          Text(
            'These open support information before anything is selected or recorded.',
            style: ExperienceType.caption(ExperienceColors.inkSoft),
          ),
          const SizedBox(height: ExperienceSpacing.xs + 4),
          for (final signal in signals)
            Padding(
              padding: const EdgeInsets.only(bottom: ExperienceSpacing.unit),
              child: _SafetySignalTile(
                key: Key('safety-signal-${signal.name}'),
                signal: signal,
                onTap: () => onSelected(signal),
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetySignalTile extends StatelessWidget {
  const _SafetySignalTile({
    required super.key,
    required this.signal,
    required this.onTap,
  });

  final SafetySignal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: signal.label,
      hint: 'Opens support information. This is not recorded.',
      child: Material(
        color: ExperienceColors.surface,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: ExperienceColors.hairline),
          borderRadius: ExperienceRadius.chipRadius,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: ExperienceRadius.chipRadius,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: ExperienceSpacing.degreeTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: ExperienceColors.accentSafety,
                ),
                const SizedBox(width: ExperienceSpacing.xs + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.label,
                        style: ExperienceType.bodyStrong(ExperienceColors.ink),
                      ),
                      Text(
                        'Opens support information. This is not recorded.',
                        style: ExperienceType.caption(ExperienceColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: ExperienceColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected ratings (shared by both steps)
// ---------------------------------------------------------------------------

class _SelectedRatings extends StatelessWidget {
  const _SelectedRatings({
    required this.ratings,
    required this.onEdit,
    required this.onRemove,
  });

  final Map<SymptomType, SymptomSeverity> ratings;
  final ValueChanged<SymptomType> onEdit;
  final ValueChanged<SymptomType>? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var index = 0; index < ratings.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, color: ExperienceColors.hairline),
            _SelectedRatingRow(
              symptom: ratings.keys.elementAt(index),
              severity: ratings.values.elementAt(index),
              onEdit: () => onEdit(ratings.keys.elementAt(index)),
              onRemove: onRemove == null
                  ? null
                  : () => onRemove!(ratings.keys.elementAt(index)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedRatingRow extends StatelessWidget {
  const _SelectedRatingRow({
    required this.symptom,
    required this.severity,
    required this.onEdit,
    required this.onRemove,
  });

  final SymptomType symptom;
  final SymptomSeverity severity;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ExperienceSpacing.sm,
        vertical: ExperienceSpacing.xs + 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symptom.label,
            style: ExperienceType.bodyStrong(ExperienceColors.ink),
          ),
          const SizedBox(height: ExperienceSpacing.unit),
          _SeverityBadge(severity: severity),
          const SizedBox(height: ExperienceSpacing.unit),
          Wrap(
            spacing: ExperienceSpacing.unit,
            runSpacing: ExperienceSpacing.unit,
            children: [
              _QuietButton(
                buttonKey: Key('edit-rating-${symptom.name}'),
                label: 'Change strength',
                onPressed: onEdit,
              ),
              if (onRemove != null)
                _QuietButton(
                  buttonKey: Key('remove-rating-${symptom.name}'),
                  label: 'Remove',
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Severity badge — word and score are the primary encoding; the ramp color
/// is reinforcement only (never error red, never ember).
class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final SymptomSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = ExperienceSeverityRamp.forScore(severity.score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ExperienceSeverityRamp.softFill(severity.score),
        borderRadius: const BorderRadius.all(
          Radius.circular(ExperienceRadius.full),
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${severity.score}',
            style: ExperienceType.data(color, size: 13),
          ),
          const SizedBox(width: 6),
          Text(
            severity.label,
            style: ExperienceType.caption(
              ExperienceColors.ink,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Intensity sheet
// ---------------------------------------------------------------------------

class _SymptomIntensitySheet extends StatefulWidget {
  const _SymptomIntensitySheet({
    required this.symptom,
    required this.initialSeverity,
  });

  final SymptomType symptom;
  final SymptomSeverity? initialSeverity;

  @override
  State<_SymptomIntensitySheet> createState() => _SymptomIntensitySheetState();
}

class _SymptomIntensitySheetState extends State<_SymptomIntensitySheet> {
  SymptomSeverity? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSeverity;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              horizontal: ExperienceSpacing.screenMargin,
            ),
            children: [
              Text(
                widget.symptom.label,
                style: ExperienceType.title(ExperienceColors.ink),
              ),
              const SizedBox(height: ExperienceSpacing.unit),
              Text(
                'How strongly did you experience this? Your answer is the record. Nothing is assumed for you.',
                style: ExperienceType.bodySmall(ExperienceColors.inkSoft),
              ),
              const SizedBox(height: ExperienceSpacing.sm),
              for (final severity in SymptomSeverity.values)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: ExperienceSpacing.unit,
                  ),
                  child: _IntensityChoiceCard(
                    key: Key('severity-${severity.name}'),
                    symptom: widget.symptom,
                    severity: severity,
                    selected: _selected == severity,
                    onTap: () {
                      unawaited(ExperienceHaptics.pick());
                      setState(() => _selected = severity);
                    },
                  ),
                ),
              const SizedBox(height: ExperienceSpacing.unit),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: ExperienceColors.surface,
            border: Border(top: BorderSide(color: ExperienceColors.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.xs + 4,
            ExperienceSpacing.screenMargin,
            ExperienceSpacing.xs + 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EmberPrimaryButton(
                buttonKey: const Key('confirm-symptom-intensity'),
                label: 'Add symptom',
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_selected),
              ),
              if (_selected == null)
                Padding(
                  padding: const EdgeInsets.only(top: ExperienceSpacing.unit),
                  child: Text(
                    'Choose how strongly you experienced this to continue.',
                    textAlign: TextAlign.center,
                    style: ExperienceType.caption(ExperienceColors.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntensityChoiceCard extends StatelessWidget {
  const _IntensityChoiceCard({
    required this.symptom,
    required this.severity,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final SymptomType symptom;
  final SymptomSeverity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = ExperienceSeverityRamp.forScore(severity.score);
    final cramps = symptom == SymptomType.cramps;
    return Semantics(
      button: true,
      selected: selected,
      label: '${severity.label} ${symptom.label.toLowerCase()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: ExperienceRadius.chipRadius,
        child: AnimatedContainer(
          duration: _motion(context, ExperienceMotion.chipSelect),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? .16 : .06),
            borderRadius: ExperienceRadius.chipRadius,
            border: Border.all(
              color: selected ? color : color.withValues(alpha: .26),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Center(
                  child: cramps
                      ? _CrampIntensityGlyph(severity: severity, color: color)
                      : _SeverityDots(score: severity.score, color: color),
                ),
              ),
              const SizedBox(width: ExperienceSpacing.xs + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      severity.label,
                      style: ExperienceType.label(ExperienceColors.ink)
                          .copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.2,
                          ),
                    ),
                    if (cramps) ...[
                      const SizedBox(height: 2),
                      Text(
                        _crampDescription(severity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceType.caption(ExperienceColors.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Countable score glyph — five dots, filled up to the score.
class _SeverityDots extends StatelessWidget {
  const _SeverityDots({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < ExperienceSeverityRamp.maxScore; index++)
          Container(
            width: 6,
            height: 6,
            margin: EdgeInsets.only(
              right: index < ExperienceSeverityRamp.maxScore - 1 ? 3 : 0,
            ),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < score ? color : ExperienceColors.hairline,
            ),
          ),
      ],
    );
  }
}

String _crampDescription(SymptomSeverity severity) => switch (severity) {
  SymptomSeverity.minimal => 'Present, but easy to overlook.',
  SymptomSeverity.mild => 'Noticeable without taking over.',
  SymptomSeverity.moderate => 'Keeps drawing some attention.',
  SymptomSeverity.severe => 'Hard to move past or ignore.',
  SymptomSeverity.extreme => 'Overwhelming in this moment.',
};

class _CrampIntensityGlyph extends StatelessWidget {
  const _CrampIntensityGlyph({required this.severity, required this.color});

  final SymptomSeverity severity;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CrampPainter(level: severity.score, color: color),
    child: const SizedBox(width: 42, height: 36),
  );
}

class _CrampPainter extends CustomPainter {
  const _CrampPainter({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = color.withValues(alpha: .2)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final torso = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .18, 2, size.width * .64, size.height - 4),
      const Radius.circular(18),
    );
    canvas.drawRRect(torso, body);
    canvas.drawRRect(torso, line..color = color.withValues(alpha: .42));
    final rings = ((level + 1) / 2).ceil();
    for (var index = 0; index < rings; index++) {
      final width = size.width * (.15 + index * .12);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * .59),
          width: width,
          height: width * .55,
        ),
        0,
        6.2,
        false,
        line
          ..color = color.withValues(alpha: .52 + index * .14)
          ..strokeWidth = 1.6 + level * .16,
      );
    }
    if (level >= 4) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height * .59),
        3.2 + level,
        Paint()..color = color.withValues(alpha: .24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CrampPainter oldDelegate) =>
      level != oldDelegate.level || color != oldDelegate.color;
}

// ---------------------------------------------------------------------------
// Step 2 — context
// ---------------------------------------------------------------------------

class _ContextStep extends StatelessWidget {
  const _ContextStep({
    required super.key,
    required this.ratings,
    required this.experiencedDate,
    required this.provenance,
    required this.functionalImpacts,
    required this.onEdit,
    required this.onRemove,
    required this.onPickDate,
    required this.onImpactChanged,
    required this.onBack,
    required this.editing,
  });

  final Map<SymptomType, SymptomSeverity> ratings;
  final LocalDate experiencedDate;
  final HealthRecordProvenance provenance;
  final Set<FunctionalImpact> functionalImpacts;
  final ValueChanged<SymptomType> onEdit;
  final ValueChanged<SymptomType>? onRemove;
  final VoidCallback onPickDate;
  final ValueChanged<FunctionalImpact> onImpactChanged;
  final VoidCallback onBack;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.only(bottom: ExperienceSpacing.xl),
          children: [
            _StageHeader(
              step: 2,
              total: 2,
              title: editing ? 'What changed?' : 'Add context',
              subtitle:
                  'Say when you experienced this and what it affected. Only what you confirm is stored.',
              onBack: onBack,
              backLabel: 'Back to symptoms',
            ),
            const SizedBox(height: ExperienceSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.screenMargin,
              ),
              child: _SelectedRatings(
                ratings: ratings,
                onEdit: onEdit,
                onRemove: onRemove,
              ),
            ),
            const _SectionHeader(
              title: 'When you experienced it',
              support:
                  'The date you experienced this, not the date you are recording it.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.screenMargin,
              ),
              child: Container(
                decoration: _cardDecoration(),
                padding: const EdgeInsets.all(ExperienceSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(context, experiencedDate),
                      style: ExperienceType.bodyStrong(ExperienceColors.ink),
                    ),
                    const SizedBox(height: ExperienceSpacing.xs + 4),
                    _QuietButton(
                      buttonKey: const Key('health-record-date'),
                      label: 'Choose date',
                      onPressed: onPickDate,
                    ),
                    const SizedBox(height: ExperienceSpacing.xs + 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _ProvenanceTag(),
                        const SizedBox(width: ExperienceSpacing.unit),
                        Expanded(
                          child: Text(
                            '${provenance.label}. Set automatically from the experienced date.',
                            style: ExperienceType.caption(
                              ExperienceColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const _SectionHeader(
              title: 'What it affected',
              support: 'Optional. Choose only what you are sure of.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExperienceSpacing.screenMargin,
              ),
              child: Container(
                decoration: _cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < FunctionalImpact.values.length;
                      index++
                    )
                      _ImpactRow(
                        key: Key(
                          'functional-impact-${FunctionalImpact.values[index].name}',
                        ),
                        label: FunctionalImpact.values[index].label,
                        checked: functionalImpacts.contains(
                          FunctionalImpact.values[index],
                        ),
                        last: index == FunctionalImpact.values.length - 1,
                        onToggle: () =>
                            onImpactChanged(FunctionalImpact.values[index]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvenanceTag extends StatelessWidget {
  const _ProvenanceTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: ExperienceColors.surfaceWarm,
        borderRadius: BorderRadius.all(Radius.circular(ExperienceRadius.full)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 13, color: ExperienceColors.inkSoft),
          const SizedBox(width: 4),
          Text(
            'Observed',
            style: ExperienceType.caption(
              ExperienceColors.inkSoft,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required super.key,
    required this.label,
    required this.checked,
    required this.last,
    required this.onToggle,
  });

  final String label;
  final bool checked;
  final bool last;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: checked,
      label: label,
      child: InkWell(
        onTap: () {
          unawaited(ExperienceHaptics.pick());
          onToggle();
        },
        child: Container(
          constraints: const BoxConstraints(
            minHeight: ExperienceSpacing.degreeTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ExperienceSpacing.sm,
            vertical: ExperienceSpacing.xs + 4,
          ),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(
                    bottom: BorderSide(color: ExperienceColors.hairline),
                  ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: _motion(context, ExperienceMotion.chipSelect),
                curve: Curves.easeOut,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked
                      ? ExperienceColors.surfaceWarm
                      : ExperienceColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: checked
                        ? ExperienceColors.ember
                        : ExperienceColors.hairline,
                    width: checked ? 1.6 : 1,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check,
                        size: 15,
                        color: ExperienceColors.ember,
                      )
                    : null,
              ),
              const SizedBox(width: ExperienceSpacing.xs + 4),
              Expanded(
                child: Text(
                  label,
                  style: ExperienceType.bodySmall(ExperienceColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky action bar
// ---------------------------------------------------------------------------

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.step,
    required this.selectionCount,
    required this.editing,
    required this.saving,
    required this.onCancel,
    required this.onPressed,
  });

  final int step;
  final int selectionCount;
  final bool editing;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = step == 0
        ? selectionCount == 0
              ? 'Choose a symptom'
              : 'Continue with $selectionCount'
        : editing
        ? 'Save changes'
        : 'Save $selectionCount ${selectionCount == 1 ? 'symptom' : 'symptoms'}';
    return Container(
      decoration: const BoxDecoration(
        color: ExperienceColors.canvas,
        border: Border(top: BorderSide(color: ExperienceColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.xs + 4,
        ExperienceSpacing.screenMargin,
        ExperienceSpacing.xs + 4,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EmberPrimaryButton(
                buttonKey: const Key('health-record-save'),
                label: saving ? 'Saving…' : label,
                onPressed: saving ? null : onPressed,
              ),
              TextButton(
                key: const Key('health-record-cancel'),
                onPressed: saving ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: ExperienceColors.inkSoft,
                  textStyle: ExperienceType.label(ExperienceColors.inkSoft),
                  minimumSize: const Size(64, ExperienceSpacing.minTouchTarget),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(SymptomCategory category) => switch (category) {
  SymptomCategory.physical => 'Physical',
  SymptomCategory.mood => 'Mood',
  SymptomCategory.energy => 'Energy',
  SymptomCategory.sleep => 'Sleep',
};

IconData _categoryIcon(SymptomCategory category) => switch (category) {
  SymptomCategory.physical => Icons.accessibility_new_outlined,
  SymptomCategory.mood => Icons.psychology_alt_outlined,
  SymptomCategory.energy => Icons.battery_3_bar_outlined,
  SymptomCategory.sleep => Icons.bedtime_outlined,
};

String _formatDate(BuildContext context, LocalDate date) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(date.asLocalDateTime);
}
