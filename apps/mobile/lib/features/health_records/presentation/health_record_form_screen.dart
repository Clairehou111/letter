import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
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
        LocalDate.fromDateTime((widget.now ?? DateTime.now)());
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
    final today = LocalDate.fromDateTime((widget.now ?? DateTime.now)());
    return date == today
        ? HealthRecordProvenance.sameDay
        : HealthRecordProvenance.laterRecall;
  }

  Future<void> _chooseSymptom(SymptomType symptom) async {
    final severity = await showModalBottomSheet<SymptomSeverity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.38),
      builder: (context) => _SymptomIntensitySheet(
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: LetterColors.ink.withValues(alpha: 0.45),
      builder: (sheetContext) => CareSafetyBoundarySheet(
        kind: signal.physical
            ? CareSafetyKind.physical
            : CareSafetyKind.emotional,
        onLeaveCare: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pop();
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
          painRating: widget.initialRecord?.painRating,
          painLocations: widget.initialRecord?.painLocations ?? const {},
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final title = _editing ? 'Edit symptom detail' : 'Add symptom details';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _step == 0 ? 'Close' : 'Back to symptoms',
          onPressed: _saving ? null : _goBack,
          icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _CaptureProgress(step: _step),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: AnimatedSwitcher(
                    duration: disableAnimations
                        ? Duration.zero
                        : LetterMotion.responsive,
                    switchInCurve: LetterMotion.standard,
                    switchOutCurve: LetterMotion.standard,
                    child: _step == 0
                        ? _SymptomStep(
                            key: const ValueKey('symptom-step'),
                            category: _category,
                            ratings: _ratings,
                            editing: _editing,
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
              ),
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: LetterColors.safetyRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            _BottomActionBar(
              step: _step,
              selectionCount: _ratings.length,
              editing: _editing,
              saving: _saving,
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

class _CaptureProgress extends StatelessWidget {
  const _CaptureProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: _ProgressItem(
              label: 'Symptoms',
              number: 1,
              active: step == 0,
              complete: step > 0,
            ),
          ),
          Container(width: 28, height: 1, color: LetterColors.line),
          Expanded(
            child: _ProgressItem(
              label: 'Context',
              number: 2,
              active: step == 1,
              complete: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.label,
    required this.number,
    required this.active,
    required this.complete,
  });

  final String label;
  final int number;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final emphasized = active || complete;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: emphasized ? LetterColors.teal : LetterColors.mist,
            shape: BoxShape.circle,
          ),
          child: complete
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: active ? Colors.white : LetterColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
        const SizedBox(width: LetterSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasized ? LetterColors.ink : LetterColors.muted,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SymptomStep extends StatelessWidget {
  const _SymptomStep({
    required super.key,
    required this.category,
    required this.ratings,
    required this.editing,
    required this.onCategoryChanged,
    required this.onChoose,
    required this.onRemove,
    required this.onSafety,
  });

  final SymptomCategory category;
  final Map<SymptomType, SymptomSeverity> ratings;
  final bool editing;
  final ValueChanged<SymptomCategory> onCategoryChanged;
  final ValueChanged<SymptomType> onChoose;
  final ValueChanged<SymptomType> onRemove;
  final ValueChanged<SafetySignal> onSafety;

  @override
  Widget build(BuildContext context) {
    final symptoms = SymptomType.values
        .where(
          (symptom) =>
              symptom.availableForNewRecords && symptom.category == category,
        )
        .toList();
    final safetySignals = switch (category) {
      SymptomCategory.mood =>
        SafetySignal.values.where((signal) => !signal.physical).toList(),
      SymptomCategory.physical =>
        SafetySignal.values.where((signal) => signal.physical).toList(),
      _ => const <SafetySignal>[],
    };
    return ListView(
      // Leave room for the fixed action bar when the final safety route is
      // scrolled into view on a short screen.
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        Text(
          editing ? 'What changed?' : 'What are you noticing?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontFamily: 'Newsreader',
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Text(
          editing
              ? 'Choose the symptom and confirm its intensity.'
              : 'Choose one symptom at a time. You can add more.',
          style: const TextStyle(color: LetterColors.muted),
        ),
        if (ratings.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.md),
          _SelectedRatings(
            ratings: ratings,
            onEdit: onChoose,
            onRemove: editing ? null : onRemove,
          ),
        ],
        const SizedBox(height: LetterSpacing.lg),
        _CategorySelector(selected: category, onChanged: onCategoryChanged),
        if (category != SymptomCategory.physical &&
            safetySignals.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.md),
          _SafetySignalPanel(signals: safetySignals, onSelected: onSafety),
        ],
        const SizedBox(height: LetterSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = constraints.maxWidth >= 480 && textScale <= 1.3
                ? 3
                : 2;
            final gap = LetterSpacing.xs;
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final symptom in symptoms)
                  SizedBox(
                    width: tileWidth,
                    child: _SymptomTile(
                      symptom: symptom,
                      severity: ratings[symptom],
                      onTap: () => onChoose(symptom),
                    ),
                  ),
              ],
            );
          },
        ),
        if (category == SymptomCategory.physical &&
            safetySignals.isNotEmpty) ...[
          const SizedBox(height: LetterSpacing.md),
          _SafetySignalPanel(signals: safetySignals, onSelected: onSafety),
        ],
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onChanged});

  final SymptomCategory selected;
  final ValueChanged<SymptomCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final compact = constraints.maxWidth < 340 || textScale > 1.35;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: compact ? 2 : 4,
          mainAxisSpacing: LetterSpacing.xs,
          crossAxisSpacing: LetterSpacing.xs,
          childAspectRatio: compact ? 3.3 : 1.6,
          children: [
            for (final category in SymptomCategory.values)
              _CategoryButton(
                category: category,
                selected: category == selected,
                onTap: () => onChanged(category),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final SymptomCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LetterColors.tealSoft : LetterColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LetterRadius.control),
        side: BorderSide(
          color: selected ? LetterColors.teal : LetterColors.line,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LetterRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _categoryIcon(category),
                size: 17,
                color: selected ? LetterColors.tealDark : LetterColors.muted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _categoryLabel(category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? LetterColors.tealDark
                        : LetterColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomTile extends StatelessWidget {
  const _SymptomTile({
    required this.symptom,
    required this.severity,
    required this.onTap,
  });

  final SymptomType symptom;
  final SymptomSeverity? severity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = severity != null;
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${symptom.label}, ${severity!.label}. Edit intensity.'
          : '${symptom.label}. Choose intensity.',
      child: Material(
        color: selected ? LetterColors.tealSoft : LetterColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          side: BorderSide(
            color: selected ? LetterColors.teal : LetterColors.line,
          ),
        ),
        child: InkWell(
          key: Key('symptom-${symptom.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _categoryIcon(symptom.category),
                    size: 19,
                    color: selected ? LetterColors.teal : LetterColors.muted,
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          symptom.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (severity != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            severity!.label,
                            style: const TextStyle(
                              color: LetterColors.tealDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.edit_outlined : Icons.chevron_right,
                    size: 18,
                    color: selected ? LetterColors.teal : LetterColors.muted,
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

class _SafetySignalPanel extends StatelessWidget {
  const _SafetySignalPanel({required this.signals, required this.onSelected});

  final List<SafetySignal> signals;
  final ValueChanged<SafetySignal> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LetterSpacing.sm),
      decoration: BoxDecoration(
        color: LetterColors.coralSoft,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(
          color: LetterColors.safetyRed.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: LetterColors.safetyRed,
                size: 20,
              ),
              SizedBox(width: LetterSpacing.xs),
              Expanded(
                child: Text(
                  'Immediate safety',
                  style: TextStyle(
                    color: LetterColors.safetyRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: LetterSpacing.xs),
          for (final signal in signals)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                key: Key('safety-signal-${signal.name}'),
                onPressed: () => onSelected(signal),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(signal.label),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                  foregroundColor: LetterColors.safetyRed,
                  side: const BorderSide(color: LetterColors.safetyRed),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
      decoration: BoxDecoration(
        color: LetterColors.surface,
        borderRadius: BorderRadius.circular(LetterRadius.panel),
        border: Border.all(color: LetterColors.line),
      ),
      child: Column(
        children: [
          for (var index = 0; index < ratings.length; index++) ...[
            if (index > 0) const Divider(height: 1),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symptom.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${severity.score} · ${severity.label}',
                  style: const TextStyle(
                    color: LetterColors.tealDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('edit-rating-${symptom.name}'),
            tooltip: 'Edit ${symptom.label} intensity',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          if (onRemove != null)
            IconButton(
              key: Key('remove-rating-${symptom.name}'),
              tooltip: 'Remove ${symptom.label}',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 19),
            ),
        ],
      ),
    );
  }
}

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
    return Container(
      decoration: const BoxDecoration(
        color: LetterColors.canvas,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LetterRadius.panel),
        ),
      ),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.94,
          minChildSize: 0.7,
          maxChildSize: 0.94,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: LetterColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LetterEyebrow('Intensity'),
                          const SizedBox(height: 3),
                          Text(
                            widget.symptom.label,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontFamily: 'Newsreader',
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close intensity',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: SymptomSeverity.values.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final severity = SymptomSeverity.values[index];
                    final selected = severity == _selected;
                    return Material(
                      color: selected
                          ? LetterColors.tealSoft
                          : LetterColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          LetterRadius.control,
                        ),
                        side: BorderSide(
                          color: selected
                              ? LetterColors.teal
                              : LetterColors.line,
                        ),
                      ),
                      child: InkWell(
                        key: Key('severity-${severity.name}'),
                        onTap: () => setState(() => _selected = severity),
                        borderRadius: BorderRadius.circular(
                          LetterRadius.control,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 50),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? LetterColors.teal
                                        : LetterColors.mist,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${severity.score}',
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : LetterColors.muted,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: LetterSpacing.sm),
                                Expanded(
                                  child: Text(
                                    severity.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? LetterColors.tealDark
                                          : LetterColors.ink,
                                    ),
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: selected
                                      ? LetterColors.teal
                                      : LetterColors.line,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  key: const Key('confirm-symptom-intensity'),
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: LetterColors.teal,
                    disabledBackgroundColor: LetterColors.line,
                  ),
                  child: const Text('Add symptom'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  });

  final Map<SymptomType, SymptomSeverity> ratings;
  final LocalDate experiencedDate;
  final HealthRecordProvenance provenance;
  final Set<FunctionalImpact> functionalImpacts;
  final ValueChanged<SymptomType> onEdit;
  final ValueChanged<SymptomType>? onRemove;
  final VoidCallback onPickDate;
  final ValueChanged<FunctionalImpact> onImpactChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          'Add context',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontFamily: 'Newsreader',
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.md),
        _SelectedRatings(ratings: ratings, onEdit: onEdit, onRemove: onRemove),
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('When'),
        const SizedBox(height: LetterSpacing.xs),
        OutlinedButton.icon(
          key: const Key('health-record-date'),
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(_formatDate(context, experiencedDate)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.centerLeft,
            foregroundColor: LetterColors.ink,
            side: const BorderSide(color: LetterColors.line),
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Record timing',
            helperText: 'Set automatically from the experienced date.',
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Icon(
                provenance == HealthRecordProvenance.sameDay
                    ? Icons.today_outlined
                    : Icons.history,
                size: 18,
              ),
              const SizedBox(width: LetterSpacing.xs),
              Text(
                provenance.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: LetterSpacing.lg),
        const LetterEyebrow('Impact'),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'What did these symptoms interfere with?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: [
            for (final impact in FunctionalImpact.values)
              FilterChip(
                key: Key('functional-impact-${impact.name}'),
                selected: functionalImpacts.contains(impact),
                onSelected: (selected) => onImpactChanged(impact),
                label: Text(impact.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.step,
    required this.selectionCount,
    required this.editing,
    required this.saving,
    required this.onPressed,
  });

  final int step;
  final int selectionCount;
  final bool editing;
  final bool saving;
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
    return Material(
      color: LetterColors.canvas,
      elevation: 5,
      shadowColor: LetterColors.ink.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton.icon(
            key: const Key('health-record-save'),
            onPressed: saving ? null : onPressed,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(step == 0 ? Icons.arrow_forward : Icons.check),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: LetterColors.teal,
              disabledBackgroundColor: LetterColors.line,
              disabledForegroundColor: LetterColors.muted,
            ),
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
