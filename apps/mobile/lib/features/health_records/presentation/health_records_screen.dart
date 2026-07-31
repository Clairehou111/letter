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
      backgroundColor: LetterColors.canvas,
      appBar: AppBar(
        title: Text(editing ? 'Edit record' : 'Record a symptom'),
        actions: [
          if (editing)
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverList.list(
                children: [
                  // ── Symptom cards (horizontal scrollable row) ──
                  const Text(
                    "what's happening?",
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.sm),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: SymptomType.values.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: LetterSpacing.xs),
                      itemBuilder: (context, index) {
                        final symptom = SymptomType.values[index];
                        final selected =
                            _selectedSymptoms.contains(symptom);
                        return _SymptomCard(
                          symptom: symptom,
                          selected: selected,
                          onTap: () => _toggleSymptom(symptom),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.lg),

                  // ── Intensity for selected symptoms ──
                  if (_selectedSymptoms.isNotEmpty) ...[
                    const Text(
                      'intensity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: LetterColors.muted,
                      ),
                    ),
                    const SizedBox(height: LetterSpacing.sm),
                    ..._selectedSymptoms.map(_modernSeverityPills),
                    const SizedBox(height: LetterSpacing.lg),
                  ],

                  // ── Collapsible: when ──
                  _CollapsibleSection(
                    title: 'when?',
                    subtitle: _formatDate(context, _experiencedDate),
                    initiallyExpanded: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: LetterSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 18),
                          label: Text(_formatDate(context, _experiencedDate)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LetterColors.ink,
                            side: const BorderSide(color: LetterColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  LetterRadius.control),
                            ),
                          ),
                        ),
                        const SizedBox(height: LetterSpacing.sm),
                        SegmentedButton<HealthRecordProvenance>(
                          segments: HealthRecordProvenance.values
                              .map((v) => ButtonSegment(
                                    value: v,
                                    label: Text(v.label,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                          selected: {_provenance},
                          onSelectionChanged: (values) =>
                              setState(() => _provenance = values.single),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.md),

                  // ── Collapsible: pain ──
                  _CollapsibleSection(
                    title:
                        'pain ${_includePain ? "· ${_painLocations.length} location${_painLocations.length == 1 ? "" : "s"}" : ""}',
                    initiallyExpanded: _includePain,
                    onToggle: () =>
                        setState(() => _includePain = !_includePain),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: LetterSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('health-record-pain-rating'),
                                controller: _painController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '0–10 rating',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: LetterSpacing.sm),
                        Wrap(
                          spacing: LetterSpacing.xs,
                          runSpacing: LetterSpacing.xs,
                          children: PainLocation.values.map((location) {
                            final active =
                                _painLocations.contains(location);
                            return _MiniChip(
                              label: location.label,
                              active: active,
                              activeColor: LetterColors.coral,
                              onTap: () => setState(() {
                                if (active) {
                                  _painLocations.remove(location);
                                } else {
                                  _painLocations.add(location);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LetterSpacing.md),

                  // ── Collapsible: impact ──
                  _CollapsibleSection(
                    title:
                        'daily impact ${_functionalImpacts.isNotEmpty ? "· ${_functionalImpacts.length} area${_functionalImpacts.length == 1 ? "" : "s"}" : ""}',
                    initiallyExpanded: false,
                    child: Wrap(
                      spacing: LetterSpacing.xs,
                      runSpacing: LetterSpacing.xs,
                      children: [
                        const SizedBox(height: LetterSpacing.sm),
                        ...FunctionalImpact.values.map((impact) {
                          final active =
                              _functionalImpacts.contains(impact);
                          return _MiniChip(
                            label: impact.label,
                            active: active,
                            activeColor: LetterColors.amber,
                            onTap: () => setState(() {
                              if (active) {
                                _functionalImpacts.remove(impact);
                              } else {
                                _functionalImpacts.add(impact);
                              }
                            }),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Floating save bar
      bottomNavigationBar: _selectedSymptoms.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: LetterColors.safetyRed, fontSize: 13),
                        ),
                      ),
                    FilledButton.icon(
                      key: const Key('health-record-save'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outlined, size: 20),
                      label: Text(
                        editing
                            ? 'save changes'
                            : 'save ${_selectedSymptoms.length} symptom${_selectedSymptoms.length == 1 ? "" : "s"}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: LetterColors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(LetterRadius.control),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _modernSeverityPills(SymptomType symptom) {
    final current = _severities[symptom] ?? SymptomSeverity.moderate;
    final severities = SymptomSeverity.values;
    return Padding(
      padding: const EdgeInsets.only(bottom: LetterSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                symptom.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _toggleSymptom(symptom),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: LetterColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Interactive severity pill bar
          ClipRRect(
            borderRadius: BorderRadius.circular(LetterRadius.control),
            child: SizedBox(
              height: 48,
              child: Row(
                children: severities.map((severity) {
                  final active = severity == current;
                  final scoreRatio =
                      (severity.score - 1) / 5.0; // 0.0 to 1.0
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _severities[symptom] = severity),
                      child: AnimatedContainer(
                        duration: LetterMotion.responsive,
                        curve: LetterMotion.standard,
                        decoration: BoxDecoration(
                          color: active
                              ? Color.lerp(
                                  LetterColors.violetSoft,
                                  LetterColors.violet,
                                  scoreRatio,
                                )
                              : LetterColors.violetSoft.withValues(alpha: 0.4),
                          border: active
                              ? Border.all(
                                  color: LetterColors.violet, width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          severity.score.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: active
                                ? Colors.white
                                : LetterColors.muted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Label for current severity
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              current.label,
              style: const TextStyle(
                color: LetterColors.violet,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modern symptom card ──
class _SymptomCard extends StatelessWidget {
  const _SymptomCard({
    required this.symptom,
    required this.selected,
    required this.onTap,
  });

  final SymptomType symptom;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (symptom.category) {
    SymptomCategory.physical => Icons.accessibility_new_outlined,
    SymptomCategory.mood => Icons.psychology_outlined,
    SymptomCategory.energy => Icons.battery_2_bar_outlined,
    SymptomCategory.sleep => Icons.bedtime_outlined,
  };

  Color get _iconColor => switch (symptom.category) {
    SymptomCategory.physical => LetterColors.coral,
    SymptomCategory.mood => LetterColors.violet,
    SymptomCategory.energy => LetterColors.amber,
    SymptomCategory.sleep => LetterColors.blue,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: LetterMotion.responsive,
        curve: LetterMotion.standard,
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? _iconColor.withValues(alpha: 0.15) : LetterColors.surface,
          borderRadius: BorderRadius.circular(LetterRadius.panel),
          border: Border.all(
            color: selected ? _iconColor.withValues(alpha: 0.5) : LetterColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 22, color: selected ? _iconColor : LetterColors.muted),
            const SizedBox(height: 4),
            Text(
              symptom.label.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: selected ? LetterColors.ink : LetterColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini toggle chip ──
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: LetterMotion.responsive,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.15) : LetterColors.surface,
          borderRadius: BorderRadius.circular(LetterRadius.control),
          border: Border.all(
            color: active ? activeColor : LetterColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 14, color: activeColor),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : LetterColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Collapsible section ──
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.onToggle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;
  final VoidCallback? onToggle;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _expanded = !_expanded);
            widget.onToggle?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _expanded ? LetterColors.line : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: LetterColors.muted,
                    ),
                  ),
                ),
                if (widget.subtitle != null) ...[
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LetterColors.ink,
                    ),
                  ),
                  const SizedBox(width: LetterSpacing.xs),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: LetterMotion.responsive,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: LetterColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: widget.child,
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: LetterMotion.responsive,
        ),
      ],
    );
  }
}

String _formatDate(BuildContext context, LocalDate date) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(date.asLocalDateTime);
}
