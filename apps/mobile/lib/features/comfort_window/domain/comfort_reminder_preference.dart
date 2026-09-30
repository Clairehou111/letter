final class ComfortReminderPreference {
  const ComfortReminderPreference({
    this.enabled = false,
    this.leadDays = 2,
    this.hour = 9,
    this.minute = 0,
    this.updatedAt,
  }) : assert(leadDays >= 0 && leadDays <= 2),
       assert(hour >= 0 && hour <= 23),
       assert(minute >= 0 && minute <= 59);

  static const activeId = 'active';

  final bool enabled;
  final int leadDays;
  final int hour;
  final int minute;
  final DateTime? updatedAt;

  ComfortReminderPreference copyWith({
    bool? enabled,
    int? leadDays,
    int? hour,
    int? minute,
    DateTime? updatedAt,
  }) => ComfortReminderPreference(
    enabled: enabled ?? this.enabled,
    leadDays: leadDays ?? this.leadDays,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

abstract interface class ComfortReminderPreferenceRepository {
  Future<ComfortReminderPreference> load();
  Future<void> save(ComfortReminderPreference preference);
}
