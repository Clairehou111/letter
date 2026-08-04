import 'package:flutter/material.dart';

import '../../../design_system/letter_theme.dart';
import '../../cycle/domain/local_date.dart';
import '../../cycle/domain/period_record.dart';
import '../../cycle/domain/period_repository.dart';
import '../domain/health_record.dart';
import '../domain/health_record_repository.dart';
import 'health_record_form_screen.dart';

export 'health_record_form_screen.dart';

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
      if (mounted) {
        _showError('Health record deleted.');
      }
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
      if (record.functionalImpacts.isNotEmpty)
        '${record.functionalImpacts.length} impact '
            '${record.functionalImpacts.length == 1 ? 'area' : 'areas'}',
      record.provenance.label,
      if (record.provenance == HealthRecordProvenance.laterRecall)
        'Recorded ${_formatDateTime(context, record.recordedAt)}',
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

String _formatDate(BuildContext context, LocalDate date) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(date.asLocalDateTime);
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date at $time';
}
