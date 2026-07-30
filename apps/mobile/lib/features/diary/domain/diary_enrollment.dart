import '../../cycle/domain/local_date.dart';

/// Status of a prospective diary enrollment (spec: 2026-07-28-doctor-mode-prospective-diary).
///
/// An enrollment is the user's explicit opt-in to record daily symptom ratings
/// for at least two consecutive cycles. The enrollment itself carries no health
/// values and is not a diagnosis.
enum DiaryEnrollmentStatus {
  /// Actively collecting daily entries.
  active,

  /// User-initiated pause; daily prompts stop but existing data stays.
  paused,

  /// User stopped the diary. Past data remains available for reports.
  stopped,
}

/// An explicit daily reminder preference. The app never guesses a time.
final class DiaryReminder {
  const DiaryReminder({required this.hour, required this.minute});

  /// 0–23 in the user's local timezone.
  final int hour;

  /// 0–59.
  final int minute;

  bool get isValid => hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

/// A user's opt-in enrollment in prospective daily diary recording.
///
/// Enrollments are local, unencrypted (no health data), and allow one active
/// enrollment at a time. The object is never sent off-device.
final class DiaryEnrollment {
  const DiaryEnrollment({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.reminder,
    this.stoppedAt,
    this.stoppedReason,
  });

  final String id;

  final DiaryEnrollmentStatus status;

  /// When the user first opted in.
  final DateTime startedAt;

  /// Optional daily reminder preference; null means no reminder.
  final DiaryReminder? reminder;

  /// When the enrollment was stopped (null while active or paused).
  final DateTime? stoppedAt;

  /// Free-text reason the user gave for stopping (optional).
  final String? stoppedReason;

  bool get isActive => status == DiaryEnrollmentStatus.active;

  DiaryEnrollment copyWith({
    DiaryEnrollmentStatus? status,
    DiaryReminder? reminder,
    DateTime? stoppedAt,
    String? stoppedReason,
  }) {
    return DiaryEnrollment(
      id: id,
      status: status ?? this.status,
      startedAt: startedAt,
      reminder: reminder ?? this.reminder,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      stoppedReason: stoppedReason ?? this.stoppedReason,
    );
  }
}

/// Provenance for a daily diary entry (REQ-005).
enum DiaryEntryProvenance {
  /// Recorded on the experienced date.
  prospective,

  /// Recorded after the experienced date (user explicitly chose this).
  laterRecall,
}

/// A single day's diary entry — one set of explicit ratings for the reviewed
/// symptom and functional-impact items (REQ-003, REQ-004).
///
/// Entries are always user-entered. The app never derives ratings from Care
/// behavior, text, voice, or app absence.
final class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.enrollmentId,
    required this.experiencedDate,
    required this.recordedAt,
    required this.provenance,
    required this.symptoms,
    required this.functionalImpacts,
  });

  final String id;

  /// Links to the enrollment this entry belongs to.
  final String enrollmentId;

  /// The calendar date this entry describes.
  final LocalDate experiencedDate;

  /// When this entry was first saved.
  final DateTime recordedAt;

  /// Whether the entry was recorded on the experienced date or later.
  final DiaryEntryProvenance provenance;

  /// Rated symptoms for this day. Missing symptoms are absent from the map,
  /// never imputed or backfilled (REQ-005).
  final Map<String, int> symptoms;

  /// Rated functional impacts for this day (0 = no impact, 5 = severe impact).
  /// Missing items are absent, never imputed.
  final Map<String, int> functionalImpacts;

  bool get isEmpty => symptoms.isEmpty && functionalImpacts.isEmpty;
}

/// The reviewed symptom item set for the prospective diary.
///
/// Uses six-point anchors (0–5), where 0 = none/not present and 5 = severe.
/// Never labeled DRSP-compatible until clinical review approves (REQ-002).
const diarySymptomItems = [
  _DiaryItem('irritability', 'Irritability or anger'),
  _DiaryItem('depressedMood', 'Depressed mood or hopelessness'),
  _DiaryItem('anxiety', 'Anxiety or tension'),
  _DiaryItem('moodSwings', 'Mood swings or sensitivity'),
  _DiaryItem('lowInterest', 'Decreased interest in activities'),
  _DiaryItem('concentration', 'Difficulty concentrating'),
  _DiaryItem('lowEnergy', 'Low energy or fatigue'),
  _DiaryItem('appetiteChange', 'Appetite changes or cravings'),
  _DiaryItem('sleepChange', 'Sleep changes'),
  _DiaryItem('overwhelm', 'Feeling overwhelmed or out of control'),
  _DiaryItem('physicalSymptoms', 'Physical symptoms (cramps, headache, etc.)'),
];

/// The reviewed functional-impact item set (0–5 anchors).
const diaryFunctionalImpactItems = [
  _DiaryItem('work', 'Work or school'),
  _DiaryItem('home', 'Home responsibilities'),
  _DiaryItem('relationships', 'Relationships'),
  _DiaryItem('social', 'Social activities'),
  _DiaryItem('interests', 'Hobbies or interests'),
];

final class _DiaryItem {
  const _DiaryItem(this.key, this.label);
  final String key;
  final String label;
}

/// Strongly-typed symptom severity anchors (0–5) for diary entry.
enum DiarySeverityAnchor {
  none(0, 'None'),
  minimal(1, 'Minimal'),
  mild(2, 'Mild'),
  moderate(3, 'Moderate'),
  severe(4, 'Severe'),
  extreme(5, 'Extreme');

  const DiarySeverityAnchor(this.value, this.label);

  final int value;
  final String label;

  static DiarySeverityAnchor? fromValue(int value) {
    return switch (value) {
      0 => none,
      1 => minimal,
      2 => mild,
      3 => moderate,
      4 => severe,
      5 => extreme,
      _ => null,
    };
  }
}

/// Strongly-typed functional-impact anchors (0–5) for diary entry.
enum DiaryImpactAnchor {
  none(0, 'No impact'),
  minimal(1, 'Minimal'),
  mild(2, 'Mild'),
  moderate(3, 'Moderate'),
  severe(4, 'Severe'),
  extreme(5, 'Extreme');

  const DiaryImpactAnchor(this.value, this.label);

  final int value;
  final String label;

  static DiaryImpactAnchor? fromValue(int value) {
    return switch (value) {
      0 => none,
      1 => minimal,
      2 => mild,
      3 => moderate,
      4 => severe,
      5 => extreme,
      _ => null,
    };
  }
}
