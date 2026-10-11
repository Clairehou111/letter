import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../experience/theme/experience_foundation.dart';
import '../../../experience/components/record_option_scale.dart';
import '../../../experience/components/record_temperature_picker.dart';
import '../../cycle/domain/local_date.dart';
import '../domain/record_hub_facts.dart';
import '../domain/record_hub_repository.dart';

enum RecordContextType {
  sleep('Sleep'),
  activity('Activity/rest'),
  appetite('Appetite/cravings'),
  event('Significant event'),
  temperature('Basal body temperature');

  const RecordContextType(this.label);
  final String label;
}

Future<bool?> showRecordContextEditor(
  BuildContext context, {
  required RecordContextType type,
  required LocalDate date,
  required RecordHubRepository repository,
  VoidCallback? onChanged,
  DatedRecordDraft? initialDraft,
  String? id,
  DateTime Function()? clock,
}) {
  Widget builder(BuildContext context) => RecordContextEditor(
    type: type,
    date: date,
    repository: repository,
    onChanged: onChanged,
    initialDraft: initialDraft,
    id: id,
    clock: clock,
  );
  final platform = Theme.of(context).platform;
  return Navigator.of(context).push<bool>(
    platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? CupertinoPageRoute<bool>(builder: builder, fullscreenDialog: true)
        : MaterialPageRoute<bool>(builder: builder, fullscreenDialog: true),
  );
}

/// Every field inherits Record's date. No child date picker or implicit fact.
class RecordContextEditor extends StatefulWidget {
  const RecordContextEditor({
    required this.type,
    required this.date,
    required this.repository,
    this.onChanged,
    this.initialDraft,
    this.id,
    this.clock,
    super.key,
  });

  final RecordContextType type;
  final LocalDate date;
  final RecordHubRepository repository;
  final VoidCallback? onChanged;
  final DatedRecordDraft? initialDraft;
  final String? id;
  final DateTime Function()? clock;

  @override
  State<RecordContextEditor> createState() => _RecordContextEditorState();
}

class _RecordContextEditorState extends State<RecordContextEditor> {
  final _exactMinutes = TextEditingController();
  final _customName = TextEditingController();
  final _note = TextEditingController();
  final _temperatureValue = TextEditingController();
  final _sleepSignals = <SleepSignal>{};
  final _temperatureFlags = <TemperatureQualityFlag>{};
  DurationBucket? _durationBucket;
  bool _exactDuration = false;
  SleepQuality? _sleepQuality;
  ActivityType? _activityType;
  ActivityIntensity? _activityIntensity;
  AppetiteLevel? _appetite;
  int? _cravingScore;
  CravingType? _cravingType;
  ContextEventType? _eventType;
  ContextEventIntensity? _eventIntensity;
  TemperatureUnit? _temperatureUnit;
  TemperatureMethod? _temperatureMethod;
  LocalMeasurementTime? _measuredAt;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _askingToClose = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDraft;
    if (initial != null && initial.experiencedDate != widget.date) {
      throw const RecordHubException(RecordHubFailure.invalidValue);
    }
    switch (initial) {
      case SleepDraft():
        _loadDuration(initial.duration);
        _sleepQuality = initial.quality;
        _sleepSignals.addAll(initial.signals);
      case ActivityDraft():
        _loadDuration(initial.duration);
        _activityType = initial.type;
        _activityIntensity = initial.intensity;
        _customName.text = initial.customName ?? '';
      case AppetiteDraft():
        _appetite = initial.appetite;
        _cravingScore = initial.cravingScore;
        _cravingType = initial.cravingType;
        _customName.text = initial.customCraving ?? '';
      case ContextEventDraft():
        _eventType = initial.type;
        _eventIntensity = initial.intensity;
        _customName.text = initial.customName ?? '';
        _note.text = initial.note ?? '';
      case TemperatureDraft():
        _temperatureValue.text = initial.enteredValue.toString();
        _temperatureUnit = initial.unit;
        _temperatureMethod = initial.method;
        _measuredAt = initial.measuredAt;
        _temperatureFlags.addAll(initial.flags);
      case null:
        break;
      default:
        throw const RecordHubException(RecordHubFailure.invalidValue);
    }
  }

  void _loadDuration(RecordedDuration? duration) {
    _durationBucket = duration?.bucket;
    _exactDuration = duration?.exactMinutes != null;
    _exactMinutes.text = duration?.exactMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _exactMinutes.dispose();
    _customName.dispose();
    _note.dispose();
    _temperatureValue.dispose();
    super.dispose();
  }

  void _change(VoidCallback update) {
    if (_saving) return;
    setState(() {
      update();
      _dirty = true;
      _error = null;
    });
  }

  RecordedDuration? _duration() {
    if (_exactDuration) {
      final minutes = int.tryParse(_exactMinutes.text.trim());
      if (minutes == null || minutes <= 0) {
        throw const _EditorValidation(
          'Enter an exact duration in positive minutes.',
        );
      }
      return RecordedDuration.exact(minutes);
    }
    return _durationBucket == null
        ? null
        : RecordedDuration.bucket(_durationBucket);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final today = LocalDate.fromDateTime(
        (widget.clock ?? DateTime.now)().toLocal(),
      );
      if (widget.date.isAfter(today)) {
        throw const RecordHubException(RecordHubFailure.futureDate);
      }
      switch (widget.type) {
        case RecordContextType.sleep:
          if (_durationBucket == null &&
              !_exactDuration &&
              _sleepQuality == null &&
              _sleepSignals.isEmpty) {
            throw const _EditorValidation('Choose a sleep detail to save.');
          }
          await widget.repository.upsertSleep(
            SleepDraft(
              experiencedDate: widget.date,
              duration: _duration(),
              quality: _sleepQuality,
              signals: _sleepSignals,
            ),
          );
        case RecordContextType.activity:
          if (_activityType == null) {
            throw const _EditorValidation('Choose an activity or rest.');
          }
          if (_activityType == ActivityType.other &&
              _customName.text.trim().isEmpty) {
            throw const _EditorValidation(
              'Name the activity in your own words.',
            );
          }
          await widget.repository.saveActivity(
            ActivityDraft(
              experiencedDate: widget.date,
              type: _activityType!,
              duration: _duration(),
              intensity: _activityIntensity,
              customName: _activityType == ActivityType.other
                  ? _customName.text
                  : null,
            ),
            id: widget.id,
          );
        case RecordContextType.appetite:
          if (_appetite == null && _cravingScore == null) {
            throw const _EditorValidation(
              'Choose appetite or craving intensity.',
            );
          }
          if (_cravingType == CravingType.other &&
              _customName.text.trim().isEmpty) {
            throw const _EditorValidation(
              'Describe the craving in your own words.',
            );
          }
          await widget.repository.upsertAppetite(
            AppetiteDraft(
              experiencedDate: widget.date,
              appetite: _appetite,
              cravingScore: _cravingScore,
              cravingType: _cravingType,
              customCraving: _cravingType == CravingType.other
                  ? _customName.text
                  : null,
            ),
          );
        case RecordContextType.event:
          if (_eventType == null) {
            throw const _EditorValidation(
              'Choose the event you want to record.',
            );
          }
          if (_eventType == ContextEventType.other &&
              _customName.text.trim().isEmpty) {
            throw const _EditorValidation('Name the event in your own words.');
          }
          await widget.repository.saveEvent(
            ContextEventDraft(
              experiencedDate: widget.date,
              type: _eventType!,
              intensity: _eventIntensity,
              customName: _eventType == ContextEventType.other
                  ? _customName.text
                  : null,
              note: _note.text.trim().isEmpty ? null : _note.text,
            ),
            id: widget.id,
          );
        case RecordContextType.temperature:
          final enteredValue = double.tryParse(_temperatureValue.text.trim());
          if (enteredValue == null ||
              !enteredValue.isFinite ||
              enteredValue <= 0) {
            throw const _EditorValidation(
              'Enter a positive temperature reading.',
            );
          }
          if (_temperatureUnit == null || _temperatureMethod == null) {
            throw const _EditorValidation(
              'Choose a temperature unit and manual method.',
            );
          }
          await widget.repository.saveTemperature(
            TemperatureDraft(
              experiencedDate: widget.date,
              enteredValue: enteredValue,
              unit: _temperatureUnit!,
              method: _temperatureMethod!,
              measuredAt: _measuredAt,
              flags: _temperatureFlags,
            ),
            id: widget.id,
          );
      }
      if (!mounted) return;
      widget.onChanged?.call();
      unawaited(ExperienceHaptics.saved());
      await _close(true);
    } on _EditorValidation catch (error) {
      _failed(error.message);
    } on RecordHubException catch (error) {
      _failed(error.userMessage);
    } catch (_) {
      _failed('Your private record could not be saved. Try again.');
    }
  }

  void _failed(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  Future<void> _close(bool saved) async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(saved);
  }

  Future<void> _requestClose() async {
    if (_saving || _askingToClose) return;
    if (!_dirty) {
      await _close(false);
      return;
    }
    _askingToClose = true;
    final discard = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Leave without saving?'),
        content: const Text('Your changes have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard changes'),
          ),
        ],
      ),
    );
    _askingToClose = false;
    if (discard == true && mounted) await _close(false);
  }

  Future<void> _chooseTime() async {
    final initial = _measuredAt == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: _measuredAt!.hour, minute: _measuredAt!.minute);
    final platform = Theme.of(context).platform;
    TimeOfDay? chosen;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      var selected = initial;
      chosen = await showCupertinoModalPopup<TimeOfDay>(
        context: context,
        builder: (context) => Container(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(selected),
                      child: const Text('Done'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                    initialDateTime: DateTime(
                      2000,
                      1,
                      1,
                      initial.hour,
                      initial.minute,
                    ),
                    onDateTimeChanged: (date) => selected = TimeOfDay(
                      hour: date.hour,
                      minute: date.minute,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      chosen = await showTimePicker(context: context, initialTime: initial);
    }
    if (chosen != null && mounted) {
      final time = chosen;
      _change(() => _measuredAt = LocalMeasurementTime(time.hour, time.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(widget.date.asLocalDateTime);
    return PopScope<bool>(
      canPop: _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: textScaler.scale(20) > 26
              ? textScaler.scale(64)
              : kToolbarHeight,
          title: Text(
            widget.type.label,
            maxLines: 2,
            style: theme.textTheme.titleLarge,
          ),
          leading: IconButton(
            onPressed: _saving ? null : _requestClose,
            tooltip: 'Close editor',
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AbsorbPointer(
                absorbing: _saving,
                child: ListView(
                  padding: const EdgeInsets.all(ExperienceSpacing.screenMargin),
                  children: [
                    Text(dateLabel, style: theme.textTheme.titleMedium),
                    const SizedBox(height: ExperienceSpacing.sm),
                    Text(
                      _description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.lg),
                    ..._fields(context),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: ExperienceSpacing.md,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: ExperienceSpacing.lg),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ExperienceRadius.cardRadius,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: ExperienceSpacing.sm,
                        ),
                        child: Text(
                          _saving
                              ? 'Saving on this device…'
                              : 'Save ${widget.type.label.toLowerCase()}',
                        ),
                      ),
                    ),
                    const SizedBox(height: ExperienceSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _description => switch (widget.type) {
    RecordContextType.sleep =>
      'The night ending on this date. Add only what you want to remember.',
    RecordContextType.activity =>
      'Record an activity or intentional rest on this date.',
    RecordContextType.appetite =>
      'Appetite and craving intensity are separate, optional details.',
    RecordContextType.event =>
      'Record context alongside your symptoms in your own words.',
    RecordContextType.temperature =>
      'Your manual reading. It does not change cycle estimates or reminders.',
  };

  List<Widget> _fields(BuildContext context) => switch (widget.type) {
    RecordContextType.sleep => [
      _durationFields(DurationFamily.sleep),
      _section(
        'Sleep quality (optional)',
        _ordinalChoices(
          SleepQuality.values,
          keyPrefix: 'sleep-quality',
          label: (value) => '${value.score} ${value.label}',
          selected: _sleepQuality,
          onSelected: (value) => _change(() => _sleepQuality = value),
        ),
      ),
      _section(
        'What happened? (optional)',
        _multiChoices(
          SleepSignal.values,
          label: (value) => value.label,
          selected: _sleepSignals,
        ),
      ),
    ],
    RecordContextType.activity => [
      _section(
        'Activity or rest',
        _choices(
          ActivityType.values,
          label: (value) => value.label,
          selected: _activityType,
          onSelected: (value) => _change(() => _activityType = value),
        ),
      ),
      if (_activityType == ActivityType.other)
        _customField('Activity in your words'),
      _durationFields(DurationFamily.activity),
      _section(
        'Intensity (optional)',
        _ordinalChoices(
          ActivityIntensity.values,
          keyPrefix: 'activity-intensity',
          label: (value) => value.label,
          selected: _activityIntensity,
          onSelected: (value) => _change(() => _activityIntensity = value),
        ),
      ),
    ],
    RecordContextType.appetite => [
      _section(
        'Appetite',
        _choices(
          AppetiteLevel.values,
          label: (value) => value.label,
          selected: _appetite,
          onSelected: (value) => _change(() => _appetite = value),
        ),
      ),
      _section(
        'Craving intensity',
        _ordinalChoices(
          const [0, 1, 2, 3, 4, 5],
          keyPrefix: 'craving-intensity',
          label: (value) =>
              '$value ${const ['None', 'Minimal', 'Mild', 'Moderate', 'Strong', 'Extreme'][value]}',
          selected: _cravingScore,
          onSelected: (value) => _change(() => _cravingScore = value),
        ),
      ),
      _section(
        'Craving type (optional)',
        _choices(
          CravingType.values,
          label: (value) => value.label,
          selected: _cravingType,
          onSelected: (value) => _change(() => _cravingType = value),
        ),
      ),
      if (_cravingType == CravingType.other)
        _customField('Craving in your words'),
    ],
    RecordContextType.event => [
      _section(
        'Event',
        _choices(
          ContextEventType.values,
          label: (value) => value.label,
          selected: _eventType,
          onSelected: (value) => _change(() => _eventType = value),
        ),
      ),
      if (_eventType == ContextEventType.other)
        _customField('Event in your words'),
      _section(
        'How intense did it feel? (optional)',
        _ordinalChoices(
          ContextEventIntensity.values,
          keyPrefix: 'event-intensity',
          label: (value) => value.label,
          selected: _eventIntensity,
          onSelected: (value) => _change(() => _eventIntensity = value),
        ),
      ),
      _section(
        'Note (optional)',
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          decoration: _decoration('In your words'),
          onChanged: (_) => _change(() {}),
        ),
      ),
    ],
    RecordContextType.temperature => [
      _section(
        'Unit',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _choices(
              TemperatureUnit.values,
              label: (value) => value.label,
              selected: _temperatureUnit,
              onSelected: (value) => _change(() {
                if (_temperatureUnit != null && _temperatureUnit != value) {
                  _temperatureValue.clear();
                }
                _temperatureUnit = value;
              }),
            ),
            const SizedBox(height: 6),
            Text(
              'Changing unit clears the reading.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      _section(
        'Temperature',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_temperatureUnit != null) ...[
              RecordTemperaturePicker(
                key: ValueKey(_temperatureUnit),
                unitLabel: _temperatureUnit!.label,
                anchorWhole: _temperatureUnit == TemperatureUnit.celsius
                    ? 37
                    : 97,
                value: double.tryParse(_temperatureValue.text.trim()),
                onChanged: _saving
                    ? null
                    : (value) => _change(() {
                        _temperatureValue.text =
                            value?.toStringAsFixed(2) ?? '';
                      }),
              ),
              const SizedBox(height: ExperienceSpacing.md),
            ],
            TextField(
              key: const Key('record-temperature-exact'),
              controller: _temperatureValue,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _decoration('Temperature reading'),
              onChanged: (_) => _change(() {}),
            ),
          ],
        ),
      ),
      _section(
        'Method',
        _choices(
          TemperatureMethod.values,
          label: (value) => value.label,
          selected: _temperatureMethod,
          onSelected: (value) => _change(() => _temperatureMethod = value),
        ),
      ),
      _section(
        'Measured at (optional)',
        Wrap(
          spacing: ExperienceSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _chooseTime,
              icon: const Icon(Icons.access_time),
              label: Text(
                _measuredAt == null
                    ? 'Add measured time'
                    : TimeOfDay(
                        hour: _measuredAt!.hour,
                        minute: _measuredAt!.minute,
                      ).format(context),
              ),
            ),
            if (_measuredAt != null)
              TextButton(
                onPressed: () => _change(() => _measuredAt = null),
                child: const Text('Clear time'),
              ),
          ],
        ),
      ),
      _section(
        'Anything that may affect this reading? (optional)',
        _multiChoices(
          TemperatureQualityFlag.values,
          label: (value) => value.label,
          selected: _temperatureFlags,
        ),
      ),
    ],
  };

  Widget _durationFields(DurationFamily family) => _section(
    'Duration (optional)',
    RecordDurationPicker<DurationBucket>(
      options: [
        for (final bucket in DurationBucket.values.where(
          (value) => value.family == family,
        ))
          RecordScaleOption(
            value: bucket,
            label: bucket.label,
            key: Key('record-duration-${bucket.name}'),
          ),
      ],
      selected: _durationBucket,
      exact: _exactDuration,
      onSelected: _saving
          ? null
          : (bucket) => _change(() {
              _durationBucket = !_exactDuration && _durationBucket == bucket
                  ? null
                  : bucket;
              _exactDuration = false;
            }),
      onExactChanged: _saving
          ? null
          : (exact) => _change(() {
              _exactDuration = exact;
              _durationBucket = null;
            }),
      exactInput: TextField(
        key: const Key('record-duration-exact-minutes'),
        controller: _exactMinutes,
        keyboardType: TextInputType.number,
        decoration: _decoration('Exact minutes'),
        onChanged: (_) => _change(() {}),
      ),
    ),
  );

  Widget _ordinalChoices<T>(
    Iterable<T> values, {
    required String keyPrefix,
    required String Function(T) label,
    required T? selected,
    required ValueChanged<T?> onSelected,
  }) => RecordOptionScale<T>(
    options: [
      for (final (index, value) in values.indexed)
        RecordScaleOption(
          value: value,
          label: label(value),
          key: Key('$keyPrefix-$index'),
        ),
    ],
    selected: selected,
    onSelected: _saving
        ? null
        : (value) => onSelected(selected == value ? null : value),
  );

  Widget _customField(String label) => _section(
    label,
    TextField(
      controller: _customName,
      decoration: _decoration(label),
      onChanged: (_) => _change(() {}),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    border: const OutlineInputBorder(borderRadius: ExperienceRadius.cardRadius),
  );

  Widget _section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: ExperienceSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: ExperienceSpacing.sm),
        child,
      ],
    ),
  );

  Widget _choices<T>(
    Iterable<T> values, {
    required String Function(T) label,
    required T? selected,
    required ValueChanged<T?> onSelected,
  }) => Wrap(
    spacing: ExperienceSpacing.sm,
    runSpacing: ExperienceSpacing.sm,
    children: [
      for (final value in values)
        _choice(
          label(value),
          selected: selected == value,
          onPressed: () => onSelected(selected == value ? null : value),
        ),
    ],
  );

  Widget _multiChoices<T>(
    Iterable<T> values, {
    required String Function(T) label,
    required Set<T> selected,
  }) => Wrap(
    spacing: ExperienceSpacing.sm,
    runSpacing: ExperienceSpacing.sm,
    children: [
      for (final value in values)
        _choice(
          label(value),
          selected: selected.contains(value),
          onPressed: () => _change(() {
            if (!selected.add(value)) selected.remove(value);
          }),
        ),
    ],
  );

  Widget _choice(
    String label, {
    required bool selected,
    required VoidCallback onPressed,
  }) => ChoiceChip(
    checkmarkColor: Theme.of(context).colorScheme.onSurface,
    label: Text(label),
    selected: selected,
    showCheckmark: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    onSelected: (_) => onPressed(),
  );
}

final class _EditorValidation implements Exception {
  const _EditorValidation(this.message);
  final String message;
}

/// Real manual sources, split by their entered unit and method. Missing days
/// remain gaps; no synthetic readings or temperature-shift interpretation.
class RecordTemperatureTrend extends StatelessWidget {
  const RecordTemperatureTrend({required this.records, super.key});
  final List<TemperatureRecord> records;

  @override
  Widget build(BuildContext context) {
    final groups =
        <(TemperatureMethod, TemperatureUnit), List<TemperatureRecord>>{};
    for (final record in records) {
      final key = (record.value.method, record.value.unit);
      (groups[key] ??= []).add(record);
    }
    if (groups.isEmpty) {
      return const Text('No manual temperature readings yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in groups.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: ExperienceSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${key.$1.label} · ${key.$2.label}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: ExperienceSpacing.sm),
                for (final record
                    in (groups[key]!..sort(
                      (a, b) => a.experiencedDate.compareTo(b.experiencedDate),
                    )))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ExperienceSpacing.xs,
                    ),
                    child: Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(record.experiencedDate.asLocalDateTime)}'
                      ' · ${record.value.enteredValue} ${record.value.unit.label}'
                      '${record.value.measuredAt == null ? '' : ' · ${TimeOfDay(hour: record.value.measuredAt!.hour, minute: record.value.measuredAt!.minute).format(context)}'}'
                      '${record.value.flags.isEmpty ? '' : ' · ${record.value.flags.map((value) => value.label).join(', ')}'}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
