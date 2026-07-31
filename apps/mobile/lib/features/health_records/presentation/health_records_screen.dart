import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';
import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({
    required this.repository,
    super.key,
    this.periodRepository,
    this.now,
  });

  final HealthRecordRepository repository;
  final PeriodRepository? periodRepository;
  final DateTime Function()? now;

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  List<HealthRecord> _records = const [];
  List<PeriodRecord> _periods = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final records = await widget.repository.getAll();
      final periods =
          await widget.periodRepository?.getAll() ?? const <PeriodRecord>[];
      if (!mounted) {
        return;
      }
      setState(() {
        _records = records;
        _periods = periods;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _openEditor([HealthRecord? record]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => HealthRecordFormScreen(
          repository: widget.repository,
          initialRecord: record,
          now: widget.now,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _delete(HealthRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text(
          'This permanently removes the selected health record from this '
          'device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('health-record-confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: LetterColors.safetyRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.repository.delete(record.id);
      await _load();
    } on HealthRecordException catch (error) {
      if (mounted) {
        _showError(error.userMessage);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health record'),
        actions: [
          IconButton(
            key: const Key('health-record-add'),
            tooltip: 'Add health record',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? _HealthRecordLoadError(onRetry: _load)
                : _records.isEmpty
                ? _HealthRecordEmpty(onAdd: () => _openEditor())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      const _HealthRecordIntro(),
                      const SizedBox(height: LetterSpacing.lg),
                      for (final group in _dayGroups()) ...[
                        _HealthRecordDayGroup(
                          date: group.date,
                          cycleLabel: _cycleLabel(group.date),
                          records: group.records,
                          onEdit: _openEditor,
                          onDelete: _delete,
                        ),
                        const SizedBox(height: LetterSpacing.lg),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  List<_HealthRecordDay> _dayGroups() {
    final grouped = <LocalDate, List<HealthRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.experiencedDate, () => []).add(record);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final date in dates)
        _HealthRecordDay(date: date, records: grouped[date]!),
    ];
  }

  String _cycleLabel(LocalDate date) {
    final starts =
        _periods
            .where((period) => !period.startDate.isAfter(date))
            .map((period) => period.startDate)
            .toList()
          ..sort();
    if (starts.isEmpty) return 'Outside recorded cycle history';
    final start = starts.last;
    return 'Cycle day ${date.epochDay - start.epochDay + 1}';
  }
}

final class _HealthRecordDay {
  const _HealthRecordDay({required this.date, required this.records});

  final LocalDate date;
  final List<HealthRecord> records;
}

class _HealthRecordDayGroup extends StatelessWidget {
  const _HealthRecordDayGroup({
    required this.date,
    required this.cycleLabel,
    required this.records,
    required this.onEdit,
    required this.onDelete,
  });

  final LocalDate date;
  final String cycleLabel;
  final List<HealthRecord> records;
  final ValueChanged<HealthRecord> onEdit;
  final ValueChanged<HealthRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('health-record-day-${date.epochDay}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _formatDate(context, date),
          style: const TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: LetterSpacing.xxs),
        Text(
          cycleLabel,
          style: const TextStyle(
            color: LetterColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: LetterSpacing.sm),
        for (var index = 0; index < records.length; index++) ...[
          _HealthRecordTile(
            record: records[index],
            onEdit: () => onEdit(records[index]),
            onDelete: () => onDelete(records[index]),
          ),
          if (index != records.length - 1)
            const SizedBox(height: LetterSpacing.xs),
        ],
      ],
    );
  }
}

class _HealthRecordIntro extends StatelessWidget {
  const _HealthRecordIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LetterEyebrow('Your words, kept private'),
        SizedBox(height: LetterSpacing.xs),
        Text(
          'A clear record of what you experienced.',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: LetterSpacing.sm),
        Text(
          'Every entry is confirmed by you. Care moments stay separate until '
          'you choose to record what you experienced.',
          style: TextStyle(color: LetterColors.muted, height: 1.45),
        ),
      ],
    );
  }
}

class _HealthRecordEmpty extends StatelessWidget {
  const _HealthRecordEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LetterSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.edit_note_outlined,
            size: 44,
            color: LetterColors.teal,
          ),
          const SizedBox(height: LetterSpacing.md),
          const Text(
            'Nothing recorded yet.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: LetterSpacing.xs),
          const Text(
            'You can add a confirmed symptom whenever you have the room.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LetterColors.muted),
          ),
          const SizedBox(height: LetterSpacing.lg),
          FilledButton.icon(
            key: const Key('health-record-empty-add'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add a record'),
          ),
        ],
      ),
    );
  }
}

class _HealthRecordLoadError extends StatelessWidget {
  const _HealthRecordLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LetterSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 36, color: LetterColors.teal),
            const SizedBox(height: LetterSpacing.md),
            const Text(
              'Your private record could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: LetterSpacing.lg),
            FilledButton.icon(
              key: const Key('health-record-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRecordTile extends StatelessWidget {
  const _HealthRecordTile({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final HealthRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      record.severity.label,
      if (record.painRating case final rating?) 'Pain $rating/10',
      if (record.functionalImpacts.isNotEmpty)
        '${record.functionalImpacts.length} impact '
            '${record.functionalImpacts.length == 1 ? 'area' : 'areas'}',
      record.provenance.label,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: LetterColors.surface,
        border: Border.all(color: LetterColors.line),
        borderRadius: BorderRadius.circular(LetterRadius.panel),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              label: '${record.symptom.label}, ${details.join(', ')}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.symptom.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatDate(context, record.experiencedDate)} · '
                    '${details.join(' · ')}',
                    style: const TextStyle(
                      color: LetterColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            key: Key('health-record-menu-${record.id}'),
            tooltip: 'Record actions',
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class HealthRecordFormScreen extends StatefulWidget {
  const HealthRecordFormScreen({
    required this.repository,
    super.key,
    this.initialRecord,
    this.now,
  });

  final HealthRecordRepository repository;
  final HealthRecord? initialRecord;
  final DateTime Function()? now;

  @override
  State<HealthRecordFormScreen> createState() => _HealthRecordFormScreenState();
}

class _HealthRecordFormScreenState extends State<HealthRecordFormScreen> {
  late final Set<SymptomType> _selectedSymptoms;
  late final Map<SymptomType, SymptomSeverity> _severities;
  late LocalDate _experiencedDate;
  late HealthRecordProvenance _provenance;
  final Set<PainLocation> _painLocations = {};
  final Set<FunctionalImpact> _functionalImpacts = {};
  late final TextEditingController _painController;
  bool _includePain = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRecord;
    _selectedSymptoms = {if (initial != null) initial.symptom};
    _severities = {if (initial != null) initial.symptom: initial.severity};
    _experiencedDate =
        initial?.experiencedDate ??
        LocalDate.fromDateTime((widget.now ?? DateTime.now)());
    _provenance = initial?.provenance ?? HealthRecordProvenance.sameDay;
    if (initial != null) {
      _includePain = initial.painRating != null;
      _painLocations.addAll(initial.painLocations);
      _functionalImpacts.addAll(initial.functionalImpacts);
    }
    _painController = TextEditingController(
      text: initial?.painRating?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _painController.dispose();
    super.dispose();
  }

  void _toggleSymptom(SymptomType symptom) {
    setState(() {
      if (widget.initialRecord != null) {
        _selectedSymptoms
          ..clear()
          ..add(symptom);
        _severities
          ..clear()
          ..[symptom] = SymptomSeverity.moderate;
        return;
      }
      if (_selectedSymptoms.remove(symptom)) {
        _severities.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
        _severities[symptom] = SymptomSeverity.moderate;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _experiencedDate.asLocalDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _experiencedDate = LocalDate.fromDateTime(picked));
    }
  }

  Future<void> _save() async {
    if (_selectedSymptoms.isEmpty) {
      setState(() => _error = 'Choose at least one symptom.');
      return;
    }
    final painRating = int.tryParse(_painController.text.trim());
    if (_includePain &&
        (painRating == null ||
            _painLocations.isEmpty ||
            painRating < 0 ||
            painRating > 10)) {
      setState(() => _error = 'Add a pain location and a 0-10 rating.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final symptoms = _selectedSymptoms.toList()
        ..sort((left, right) => left.index.compareTo(right.index));
      for (final symptom in symptoms) {
        final draft = HealthRecordDraft(
          symptom: symptom,
          severity: _severities[symptom]!,
          painRating: _includePain ? painRating : null,
          painLocations: _includePain ? _painLocations : const {},
          functionalImpacts: _functionalImpacts,
          experiencedDate: _experiencedDate,
          provenance: _provenance,
        );
        if (widget.initialRecord != null) {
          await widget.repository.update(widget.initialRecord!.id, draft);
        } else {
          await widget.repository.create(draft);
        }
      }
      if (mounted) {
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialRecord != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit health record' : 'New health record'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'What did you experience?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'Select one or more symptoms. Each one gets its own intensity.',
              style: TextStyle(color: LetterColors.muted),
            ),
            const SizedBox(height: LetterSpacing.md),
            ...SymptomCategory.values.map(_categorySection),
            const SizedBox(height: LetterSpacing.lg),
            const LetterEyebrow('Intensity for selected symptoms'),
            const SizedBox(height: LetterSpacing.xs),
            ..._selectedSymptoms.map(_severitySection),
            const SizedBox(height: LetterSpacing.lg),
            _dateSection(),
            const SizedBox(height: LetterSpacing.lg),
            _provenanceSection(),
            const SizedBox(height: LetterSpacing.lg),
            _painSection(),
            const SizedBox(height: LetterSpacing.lg),
            _impactSection(),
            if (_error != null) ...[
              const SizedBox(height: LetterSpacing.md),
              Text(
                _error!,
                key: const Key('health-record-error'),
                style: const TextStyle(color: LetterColors.safetyRed),
              ),
            ],
            const SizedBox(height: LetterSpacing.lg),
            FilledButton.icon(
              key: const Key('health-record-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(editing ? 'Save changes' : 'Confirm and save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              ),
            ),
            const SizedBox(height: LetterSpacing.xs),
            const Text(
              'This saves only what you selected and confirmed on this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LetterColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categorySection(SymptomCategory category) {
    final symptoms = SymptomType.values.where(
      (item) => item.category == category,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: LetterSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LetterEyebrow(_categoryLabel(category)),
          const SizedBox(height: LetterSpacing.xs),
          Wrap(
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xs,
            children: symptoms.map((symptom) {
              final selected = _selectedSymptoms.contains(symptom);
              return FilterChip(
                key: Key('health-symptom-${symptom.name}'),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => _toggleSymptom(symptom),
                avatar: Icon(
                  selected ? Icons.check : Icons.add,
                  size: 16,
                  color: selected ? Colors.white : LetterColors.teal,
                ),
                label: Text(symptom.label),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : LetterColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: LetterColors.teal,
                backgroundColor: LetterColors.tealSoft,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _severitySection(SymptomType symptom) {
    final selected = _severities[symptom] ?? SymptomSeverity.moderate;
    return Padding(
      padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symptom.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Wrap(
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xs,
            children: SymptomSeverity.values.map((severity) {
              final active = severity == selected;
              return ChoiceChip(
                key: Key('health-severity-${symptom.name}-${severity.name}'),
                selected: active,
                onSelected: (_) =>
                    setState(() => _severities[symptom] = severity),
                label: Text(severity.label),
                selectedColor: LetterColors.violet,
                backgroundColor: LetterColors.violetSoft,
                labelStyle: TextStyle(
                  color: active ? Colors.white : LetterColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _dateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterEyebrow('When did you experience it?'),
        const SizedBox(height: LetterSpacing.xs),
        OutlinedButton.icon(
          key: const Key('health-record-experienced-date'),
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_formatDate(context, _experiencedDate)),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(48),
            foregroundColor: LetterColors.ink,
            side: const BorderSide(color: LetterColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LetterRadius.control),
            ),
          ),
        ),
      ],
    );
  }

  Widget _provenanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterEyebrow('When are you recording this?'),
        const SizedBox(height: LetterSpacing.xs),
        SegmentedButton<HealthRecordProvenance>(
          key: const Key('health-record-provenance'),
          segments: HealthRecordProvenance.values
              .map(
                (value) => ButtonSegment(
                  value: value,
                  label: Text(value.label),
                  icon: Icon(
                    value == HealthRecordProvenance.sameDay
                        ? Icons.today_outlined
                        : Icons.history_outlined,
                  ),
                ),
              )
              .toList(),
          selected: {_provenance},
          onSelectionChanged: (values) =>
              setState(() => _provenance = values.single),
        ),
      ],
    );
  }

  Widget _painSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterEyebrow('Optional pain detail'),
        const SizedBox(height: LetterSpacing.xs),
        CheckboxListTile(
          key: const Key('health-record-include-pain'),
          value: _includePain,
          onChanged: (value) => setState(() => _includePain = value ?? false),
          contentPadding: EdgeInsets.zero,
          title: const Text('Add a separate 0-10 pain rating'),
          subtitle: const Text('This is separate from symptom intensity.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_includePain) ...[
          TextField(
            key: const Key('health-record-pain-rating'),
            controller: _painController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Pain rating (0-10)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: LetterSpacing.sm),
          const Text(
            'Where did it hurt?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LetterSpacing.xs),
          Wrap(
            spacing: LetterSpacing.xs,
            runSpacing: LetterSpacing.xs,
            children: PainLocation.values.map((location) {
              final selected = _painLocations.contains(location);
              return FilterChip(
                key: Key('health-pain-location-${location.name}'),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  if (selected) {
                    _painLocations.remove(location);
                  } else {
                    _painLocations.add(location);
                  }
                }),
                label: Text(location.label),
                selectedColor: LetterColors.coral,
                backgroundColor: LetterColors.coralSoft,
                labelStyle: TextStyle(
                  color: selected ? LetterColors.ink : LetterColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LetterRadius.control),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _impactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LetterEyebrow('User-reported impact'),
        const SizedBox(height: LetterSpacing.xs),
        const Text(
          'Select any areas this affected. Letter does not calculate an '
          'impairment score.',
          style: TextStyle(color: LetterColors.muted, fontSize: 12),
        ),
        const SizedBox(height: LetterSpacing.xs),
        Wrap(
          spacing: LetterSpacing.xs,
          runSpacing: LetterSpacing.xs,
          children: FunctionalImpact.values.map((impact) {
            final selected = _functionalImpacts.contains(impact);
            return FilterChip(
              key: Key('health-impact-${impact.name}'),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() {
                if (selected) {
                  _functionalImpacts.remove(impact);
                } else {
                  _functionalImpacts.add(impact);
                }
              }),
              label: Text(impact.label),
              selectedColor: LetterColors.amber,
              backgroundColor: LetterColors.amberSoft,
              labelStyle: const TextStyle(
                color: LetterColors.ink,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LetterRadius.control),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

String _categoryLabel(SymptomCategory category) => switch (category) {
  SymptomCategory.physical => 'Physical',
  SymptomCategory.mood => 'Mood',
  SymptomCategory.energy => 'Energy',
  SymptomCategory.sleep => 'Sleep',
};

String _formatDate(BuildContext context, LocalDate date) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(date.asLocalDateTime);
}
