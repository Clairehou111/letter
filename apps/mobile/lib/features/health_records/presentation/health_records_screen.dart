import 'package:flutter/material.dart';

import '../../../design_system/lovable/health_record_kit.dart' as health_kit;
import '../../../design_system/lovable/letter_kit.dart';
import '../../../design_system/lovable/letter_theme.dart';
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
    this.onBack,
    this.from,
    this.through,
  });

  final HealthRecordRepository repository;
  final PeriodRepository? periodRepository;
  final DateTime Function()? now;
  final VoidCallback? onBack;
  final LocalDate? from;
  final LocalDate? through;

  bool get hasCycleFilter => from != null || through != null;

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  List<HealthRecord> _records = const [];
  List<PeriodRecord> _periods = const [];
  bool _loading = true;
  bool _failed = false;

  LocalDate get _today =>
      LocalDate.fromDateTime((widget.now ?? DateTime.now)().toLocal());

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
      if (!mounted) return;
      setState(() {
        _records = _sortRecords(
          records.where((record) {
            if (!widget.hasCycleFilter) return true;
            if (!record.userConfirmed) return false;
            if (widget.from != null &&
                record.experiencedDate.isBefore(widget.from!)) {
              return false;
            }
            if (widget.through != null &&
                record.experiencedDate.isAfter(widget.through!)) {
              return false;
            }
            return true;
          }),
        );
        _periods = periods;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
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
    if (mounted) await _load();
  }

  Future<void> _openArchive() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => AllSymptomRecordsScreen(
          repository: widget.repository,
          periodRepository: widget.periodRepository,
          now: widget.now,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(HealthRecord record) async {
    final confirmed = await _confirmDelete(context);
    if (confirmed != true) return;
    try {
      await widget.repository.delete(record.id);
      await _load();
      if (mounted) _showMessage('Health record deleted.');
    } on HealthRecordException catch (error) {
      if (mounted) _showMessage(error.userMessage);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  List<HealthRecord> get _recentRecords => _records
      .where(
        (record) =>
            !record.experiencedDate.isAfter(_today) &&
            !record.experiencedDate.isBefore(_today.addDays(-29)),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LetterTokens.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _HealthRecordsTopBar(onBack: _goBack),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const health_kit.LoadingBlock(
        label: 'Opening your private record on this device.',
      );
    }
    if (_failed) {
      return health_kit.FailureState(
        title: 'Your private record could not be opened.',
        cause:
            'The record stays on this device and nothing has been lost. Reading it failed just now.',
        action: health_kit.RetryAction(
          key: const Key('health-record-retry'),
          onRetry: _load,
        ),
      );
    }
    if (_records.isEmpty && widget.hasCycleFilter) {
      return _FilteredEmptyState();
    }
    if (_records.isEmpty) {
      return _EmptyRecentState(onAdd: () => _openEditor());
    }
    if (!widget.hasCycleFilter && _recentRecords.isEmpty) {
      return _OlderRecordsState(
        totalCount: _records.length,
        onAdd: () => _openEditor(),
        onViewArchive: _openArchive,
      );
    }
    return _recentContent();
  }

  Widget _recentContent() {
    final groups = _dayGroups(
      widget.hasCycleFilter ? _records : _recentRecords,
    );
    final visibleGroups = groups.take(20).toList();
    final archiveNeeded = _records.isNotEmpty && !widget.hasCycleFilter;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            0,
            0,
            0,
            LetterTokens.s28 + LetterTokens.tapTarget + LetterTokens.s16,
          ),
          children: [
            health_kit.SectionHeader(
              eyebrow: 'ON THIS DEVICE ONLY',
              title: 'Symptoms',
              support: widget.hasCycleFilter
                  ? 'Confirmed symptoms recorded during this cycle. Nothing here is a diagnosis and nothing is inferred.'
                  : 'What you confirmed in the last 30 days, in the order you experienced it. Nothing here is a diagnosis and nothing is inferred.',
            ),
            if (widget.hasCycleFilter)
              _FilteredContext(from: widget.from, through: widget.through),
            if (archiveNeeded)
              _ArchiveLink(count: _records.length, onPressed: _openArchive),
            const SizedBox(height: LetterTokens.s12),
            for (final group in visibleGroups) ...[
              _HealthRecordDayGroup(
                date: group.date,
                cycleLabel: _cycleLabel(group.date, _periods),
                records: group.records,
                onEdit: _openEditor,
                onDelete: _delete,
              ),
              const SizedBox(height: LetterTokens.s16),
            ],
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: LetterTokens.canvas.withValues(alpha: 0.96),
              border: const Border(top: LetterTokens.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LetterTokens.gutter,
                LetterTokens.s12,
                LetterTokens.gutter,
                LetterTokens.s12,
              ),
              child: PrimaryButton(
                key: const Key('health-record-add'),
                label: 'Add symptoms',
                expand: true,
                onPressed: () => _openEditor(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AllSymptomRecordsScreen extends StatefulWidget {
  const AllSymptomRecordsScreen({
    required this.repository,
    super.key,
    this.periodRepository,
    this.now,
    this.onBack,
  });

  final HealthRecordRepository repository;
  final PeriodRepository? periodRepository;
  final DateTime Function()? now;
  final VoidCallback? onBack;

  @override
  State<AllSymptomRecordsScreen> createState() =>
      _AllSymptomRecordsScreenState();
}

typedef HealthRecordsArchiveScreen = AllSymptomRecordsScreen;

class _AllSymptomRecordsScreenState extends State<AllSymptomRecordsScreen> {
  static const _initialGroupCount = 8;
  static const _groupIncrement = 8;

  List<HealthRecord> _records = const [];
  List<PeriodRecord> _periods = const [];
  int? _selectedMonth;
  var _visibleGroupCount = _initialGroupCount;
  var _loading = true;
  var _failed = false;

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
      if (!mounted) return;
      setState(() {
        _records = _sortRecords(records);
        _periods = periods;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
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
    if (mounted) await _load();
  }

  Future<void> _delete(HealthRecord record) async {
    final confirmed = await _confirmDelete(context);
    if (confirmed != true) return;
    try {
      await widget.repository.delete(record.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Health record deleted.')));
      }
    } on HealthRecordException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LetterTokens.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _HealthRecordsTopBar(
                  title: 'All symptom records',
                  onBack: _goBack,
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const health_kit.LoadingBlock(
        label: 'Opening all private symptom records on this device.',
      );
    }
    if (_failed) {
      return health_kit.FailureState(
        title: 'All symptom records could not be opened.',
        cause:
            'The record stays on this device and nothing has been lost. Reading it failed just now.',
        action: health_kit.RetryAction(onRetry: _load),
      );
    }

    final filtered = _selectedMonth == null
        ? _records
        : _records
              .where(
                (record) => _monthKey(record.experiencedDate) == _selectedMonth,
              )
              .toList();
    final groups = _dayGroups(filtered);
    final visibleGroups = groups.take(_visibleGroupCount).toList();
    final visibleDates = visibleGroups.map((group) => group.date).toSet();
    final visibleRecords = filtered
        .where((record) => visibleDates.contains(record.experiencedDate))
        .length;
    final months = _monthKeys(_records);

    return ListView(
      padding: const EdgeInsets.only(bottom: LetterTokens.s28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LetterTokens.gutter,
            LetterTokens.s20,
            LetterTokens.gutter,
            0,
          ),
          child: Text(
            '${_records.length} total records',
            style: letterBody(size: 15, weight: FontWeight.w600),
          ),
        ),
        if (months.isNotEmpty) ...[
          const health_kit.SectionHeader(
            title: 'Jump to a month',
            support:
                'Filter the archive without changing or deleting anything.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LetterTokens.gutter,
            ),
            child: Wrap(
              spacing: LetterTokens.s8,
              runSpacing: LetterTokens.s8,
              children: [
                _MonthFilterChip(
                  key: const Key('archive-month-filter-all'),
                  label: 'All months',
                  selected: _selectedMonth == null,
                  onTap: () => setState(() {
                    _selectedMonth = null;
                    _visibleGroupCount = _initialGroupCount;
                  }),
                ),
                for (final month in months)
                  _MonthFilterChip(
                    key: Key('archive-month-filter-$month'),
                    label: _formatMonth(context, _monthDate(month)),
                    selected: _selectedMonth == month,
                    onTap: () => setState(() {
                      _selectedMonth = month;
                      _visibleGroupCount = _initialGroupCount;
                    }),
                  ),
              ],
            ),
          ),
        ],
        if (filtered.isEmpty)
          const health_kit.EmptyState(
            title: 'No records in this month.',
            body: 'Choose another month to see more of your private record.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LetterTokens.gutter,
              LetterTokens.s20,
              LetterTokens.gutter,
              0,
            ),
            child: Text(
              'Showing $visibleRecords of ${filtered.length} records',
              style: letterHelper(size: 12),
            ),
          ),
          for (final monthGroup in _monthGroups(visibleGroups)) ...[
            health_kit.RecordGroupHeading(
              text: _formatMonth(context, monthGroup.month),
              count: monthGroup.records.length,
            ),
            for (final group in monthGroup.groups)
              _HealthRecordDayGroup(
                date: group.date,
                cycleLabel: _cycleLabel(group.date, _periods),
                records: group.records,
                onEdit: _openEditor,
                onDelete: _delete,
              ),
          ],
          if (visibleGroups.length < groups.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LetterTokens.gutter,
                LetterTokens.s16,
                LetterTokens.gutter,
                0,
              ),
              child: health_kit.QuietButton(
                key: const Key('health-record-archive-load-more'),
                label: 'Show more records',
                expand: true,
                onPressed: () =>
                    setState(() => _visibleGroupCount += _groupIncrement),
              ),
            ),
        ],
      ],
    );
  }
}

class _HealthRecordsTopBar extends StatelessWidget {
  const _HealthRecordsTopBar({
    required this.onBack,
    this.title = 'Health records',
  });

  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.s12,
      LetterTokens.s4,
      LetterTokens.gutter,
      LetterTokens.s4,
    ),
    child: Row(
      children: [
        TextButton.icon(
          key: const Key('health-record-back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back'),
        ),
        const SizedBox(width: LetterTokens.s8),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.end,
            style: letterHelper(size: 12),
          ),
        ),
      ],
    ),
  );
}

class _EmptyRecentState extends StatelessWidget {
  const _EmptyRecentState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: health_kit.EmptyState(
      title: 'Nothing recorded yet.',
      body:
          'When you record a symptom, it appears here with the date you experienced it and the strength you confirmed.',
      action: PrimaryButton(
        key: const Key('health-record-empty-add'),
        label: 'Add symptoms',
        onPressed: onAdd,
      ),
    ),
  );
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    child: health_kit.EmptyState(
      title: 'No confirmed symptoms in this cycle.',
      body: 'This cycle has no symptom records in the selected date range.',
    ),
  );
}

class _FilteredContext extends StatelessWidget {
  const _FilteredContext({this.from, this.through});

  final LocalDate? from;
  final LocalDate? through;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.gutter,
      LetterTokens.s12,
      LetterTokens.gutter,
      0,
    ),
    child: Text(_filterLabel(context), style: letterHelper(size: 12)),
  );

  String _filterLabel(BuildContext context) {
    if (from != null && through != null) {
      return 'Cycle symptoms · ${_formatDate(context, from!)}–${_formatDate(context, through!)}';
    }
    if (from != null) {
      return 'Cycle symptoms · from ${_formatDate(context, from!)}';
    }
    return 'Cycle symptoms · through ${_formatDate(context, through!)}';
  }
}

class _OlderRecordsState extends StatelessWidget {
  const _OlderRecordsState({
    required this.totalCount,
    required this.onAdd,
    required this.onViewArchive,
  });

  final int totalCount;
  final VoidCallback onAdd;
  final VoidCallback onViewArchive;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: health_kit.EmptyState(
      title: 'No symptoms in the last 30 days.',
      body:
          'Your older records are still saved on this device. View the archive to browse them.',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            key: const Key('health-record-empty-add'),
            label: 'Add symptoms',
            onPressed: onAdd,
          ),
          const SizedBox(height: LetterTokens.s8),
          health_kit.QuietButton(
            key: const Key('health-record-view-archive'),
            label: 'View all symptom records ($totalCount)',
            onPressed: onViewArchive,
            expand: true,
          ),
        ],
      ),
    ),
  );
}

class _ArchiveLink extends StatelessWidget {
  const _ArchiveLink({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.gutter,
      LetterTokens.s16,
      LetterTokens.gutter,
      0,
    ),
    child: health_kit.QuietButton(
      key: const Key('health-record-view-archive'),
      label: 'View all symptom records ($count)',
      onPressed: onPressed,
      expand: true,
    ),
  );
}

class _MonthFilterChip extends StatelessWidget {
  const _MonthFilterChip({
    required super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: LetterTokens.brControl,
      child: Container(
        constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: LetterTokens.s12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? LetterTokens.tealSoft : LetterTokens.surface,
          borderRadius: LetterTokens.brControl,
          border: Border.all(
            color: selected ? LetterTokens.teal : LetterTokens.line,
          ),
        ),
        child: Text(
          selected ? '$label ✓' : label,
          style: letterBody(
            size: 13,
            color: selected ? LetterTokens.teal : LetterTokens.muted,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class _HealthRecordDay {
  const _HealthRecordDay({required this.date, required this.records});

  final LocalDate date;
  final List<HealthRecord> records;
}

class _HealthRecordMonth {
  const _HealthRecordMonth({required this.month, required this.groups});

  final LocalDate month;
  final List<_HealthRecordDay> groups;

  List<HealthRecord> get records => [
    for (final group in groups) ...group.records,
  ];
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: LetterTokens.gutter),
    child: Column(
      key: Key('health-record-day-${date.epochDay}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _formatDate(context, date),
          style: letterSerif(size: 20, weight: FontWeight.w700),
        ),
        const SizedBox(height: LetterTokens.s4),
        Text(cycleLabel, style: letterHelper(size: 12)),
        const SizedBox(height: LetterTokens.s8),
        LetterCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < records.length; index++)
                _HealthRecordTile(
                  record: records[index],
                  last: index == records.length - 1,
                  onEdit: () => onEdit(records[index]),
                  onDelete: () => onDelete(records[index]),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HealthRecordTile extends StatelessWidget {
  const _HealthRecordTile({
    required this.record,
    required this.last,
    required this.onEdit,
    required this.onDelete,
  });

  final HealthRecord record;
  final bool last;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: LetterTokens.tapTarget),
    padding: const EdgeInsets.fromLTRB(
      LetterTokens.s16,
      LetterTokens.s12,
      LetterTokens.s8,
      LetterTokens.s12,
    ),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: LetterTokens.hairline),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            label:
                '${record.symptom.label}, ${record.severity.label}, ${record.provenance.label}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        record.symptom.label,
                        style: letterBody(size: 15, weight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: LetterTokens.s8),
                    const ProvenanceTag(observed: true),
                  ],
                ),
                const SizedBox(height: LetterTokens.s8),
                health_kit.SeverityChip(
                  value: record.severity.score,
                  word: record.severity.label,
                ),
                const SizedBox(height: LetterTokens.s8),
                health_kit.RecordProvenanceLine(
                  provenanceLabel: record.provenance.label,
                  recordedAtLabel:
                      '${_formatDate(context, LocalDate.fromDateTime(record.recordedAt))} ${_formatClock(context, record.recordedAt)}',
                  impactCount: record.functionalImpacts.length,
                ),
                if (record.functionalImpacts.isNotEmpty) ...[
                  const SizedBox(height: LetterTokens.s4),
                  Text(
                    record.functionalImpacts
                        .map((impact) => impact.label)
                        .join(', '),
                    style: letterHelper(size: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          key: Key('health-record-menu-${record.id}'),
          tooltip: 'Record actions',
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete this record?'),
    content: const Text(
      'This permanently removes the selected health record from this device.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('health-record-confirm-delete'),
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(backgroundColor: LetterColors.coral),
        child: const Text('Delete'),
      ),
    ],
  ),
);

List<HealthRecord> _sortRecords(Iterable<HealthRecord> records) => [...records]
  ..sort((left, right) {
    final date = right.experiencedDate.compareTo(left.experiencedDate);
    if (date != 0) return date;
    final recorded = right.recordedAt.compareTo(left.recordedAt);
    return recorded == 0 ? right.updatedAt.compareTo(left.updatedAt) : recorded;
  });

List<_HealthRecordDay> _dayGroups(Iterable<HealthRecord> records) {
  final grouped = <LocalDate, List<HealthRecord>>{};
  for (final record in records) {
    grouped.putIfAbsent(record.experiencedDate, () => []).add(record);
  }
  final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates)
      _HealthRecordDay(date: date, records: _sortRecords(grouped[date]!)),
  ];
}

List<_HealthRecordMonth> _monthGroups(Iterable<_HealthRecordDay> groups) {
  final grouped = <int, List<_HealthRecordDay>>{};
  for (final group in groups) {
    grouped.putIfAbsent(_monthKey(group.date), () => []).add(group);
  }
  final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      _HealthRecordMonth(month: _monthDate(key), groups: grouped[key]!),
  ];
}

List<int> _monthKeys(Iterable<HealthRecord> records) {
  final keys =
      records
          .map((record) => _monthKey(record.experiencedDate))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
  return keys;
}

int _monthKey(LocalDate date) => date.year * 12 + date.month;

LocalDate _monthDate(int key) {
  final year = (key - 1) ~/ 12;
  final month = (key - 1) % 12 + 1;
  return LocalDate(year, month, 1);
}

String _cycleLabel(LocalDate date, List<PeriodRecord> periods) {
  final starts =
      periods
          .where((period) => !period.startDate.isAfter(date))
          .map((period) => period.startDate)
          .toList()
        ..sort();
  if (starts.isEmpty) return 'Outside recorded cycle history';
  return 'Cycle day ${date.epochDay - starts.last.epochDay + 1}';
}

String _formatDate(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatMediumDate(date.asLocalDateTime);

String _formatMonth(BuildContext context, LocalDate date) =>
    MaterialLocalizations.of(context).formatMonthYear(date.asLocalDateTime);

String _formatClock(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));
