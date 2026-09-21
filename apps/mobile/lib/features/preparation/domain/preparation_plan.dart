import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../care/domain/care_mode.dart';
import 'preparation_snapshot.dart';

enum PreparationPlanStatus { current, privateReference }

/// A user-confirmed memory. It snapshots only the selected, already-recorded
/// Care evidence so later record edits never silently rewrite the user's plan.
final class PreparationPlan {
  const PreparationPlan({
    required this.id,
    required this.status,
    required this.evidenceFingerprint,
    required this.sourceRecordIds,
    required this.includeCare,
    required this.careActionId,
    required this.careActionLabel,
    required this.careMode,
    required this.betterCount,
    required this.sameCount,
    required this.worseCount,
    required this.noteText,
    required this.personalText,
    required this.createdAt,
    required this.updatedAt,
  });

  static const activeId = 'active';

  final String id;
  final PreparationPlanStatus status;
  final String evidenceFingerprint;
  final List<String> sourceRecordIds;
  final bool includeCare;
  final String careActionId;
  final String careActionLabel;
  final CareMode careMode;
  final int betterCount;
  final int sameCount;
  final int worseCount;
  final String? noteText;
  final String? personalText;
  final DateTime createdAt;
  final DateTime updatedAt;

  PreparationPlan copyWith({
    PreparationPlanStatus? status,
    String? evidenceFingerprint,
    List<String>? sourceRecordIds,
    bool? includeCare,
    String? careActionId,
    String? careActionLabel,
    CareMode? careMode,
    int? betterCount,
    int? sameCount,
    int? worseCount,
    String? noteText,
    bool removeNote = false,
    String? personalText,
    bool removePersonalText = false,
    DateTime? updatedAt,
  }) => PreparationPlan(
    id: id,
    status: status ?? this.status,
    evidenceFingerprint: evidenceFingerprint ?? this.evidenceFingerprint,
    sourceRecordIds: sourceRecordIds ?? this.sourceRecordIds,
    includeCare: includeCare ?? this.includeCare,
    careActionId: careActionId ?? this.careActionId,
    careActionLabel: careActionLabel ?? this.careActionLabel,
    careMode: careMode ?? this.careMode,
    betterCount: betterCount ?? this.betterCount,
    sameCount: sameCount ?? this.sameCount,
    worseCount: worseCount ?? this.worseCount,
    noteText: removeNote ? null : noteText ?? this.noteText,
    personalText: removePersonalText ? null : personalText ?? this.personalText,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

final class PreparationDismissal {
  const PreparationDismissal({
    required this.fingerprint,
    required this.evidenceLine,
    required this.dismissedAt,
  });

  final String fingerprint;
  final String evidenceLine;
  final DateTime dismissedAt;
}

abstract interface class PreparationRepository {
  Future<PreparationPlan?> getActivePlan();
  Future<void> savePlan(PreparationPlan plan);
  Future<void> removeActivePlan();
  Future<List<PreparationDismissal>> getDismissals();
  Future<void> dismiss(PreparationDismissal dismissal);
  Future<void> restoreDismissal(String fingerprint);
}

/// Stable fingerprints are persisted across launches. Dart's runtime hashCode
/// is intentionally not used because it is not a storage format.
final class PreparationFingerprint {
  const PreparationFingerprint._();

  static Future<String> forSnapshot(PreparationSnapshot snapshot) async {
    final observation = snapshot.observation;
    final care = snapshot.care;
    final note = snapshot.futureNote;
    final canonical = jsonEncode({
      'v': 1,
      'observation': observation == null
          ? null
          : {
              'symptom': observation.symptom.name,
              'count': observation.recordCount,
              'cycles': observation.distinctCompletedCycles,
              'totalCycles': observation.totalCompletedCycles,
              'sources': _sortedIds(observation.sources.map((item) => item.id)),
            },
      'care': care == null
          ? null
          : {
              'actionId': care.actionId,
              'mode': care.mode.name,
              'count': care.recordCount,
              'better': care.betterCount,
              'same': care.sameCount,
              'worse': care.worseCount,
              'pinned': care.pinned,
              'sources': _sortedIds(care.sources.map((item) => item.id)),
            },
      'note': care != null && note != null && note.mode == care.mode
          ? {'careRecordId': note.careRecordId, 'text': note.text}
          : null,
    });
    return _digest(canonical);
  }

  static Future<String> forSelection(
    PreparationSnapshot snapshot, {
    required bool includeCare,
    required bool includeNote,
  }) async {
    final care = snapshot.care;
    if (care == null && (includeCare || includeNote)) {
      throw StateError('Selected Care evidence is no longer available.');
    }
    final note = snapshot.futureNote;
    final canonical = jsonEncode({
      'v': 1,
      'care': includeCare && care != null
          ? {
              'actionId': care.actionId,
              'mode': care.mode.name,
              'count': care.recordCount,
              'better': care.betterCount,
              'same': care.sameCount,
              'worse': care.worseCount,
              'pinned': care.pinned,
              'sources': _sortedIds(care.sources.map((item) => item.id)),
            }
          : null,
      'note':
          includeNote && care != null && note != null && note.mode == care.mode
          ? {'careRecordId': note.careRecordId, 'text': note.text}
          : null,
    });
    return _digest(canonical);
  }

  static List<String> sourceIds(PreparationSnapshot snapshot) => _sortedIds([
    ...?snapshot.observation?.sources.map((item) => item.id),
    ...?snapshot.care?.sources.map((item) => item.id),
    if (snapshot.futureNote case final note?) note.careRecordId,
  ]);

  static List<String> selectionSourceIds(
    PreparationSnapshot snapshot, {
    required bool includeCare,
    required bool includeNote,
  }) => _sortedIds([
    if (includeCare) ...?snapshot.care?.sources.map((item) => item.id),
    if (includeNote && snapshot.futureNote != null)
      snapshot.futureNote!.careRecordId,
  ]);

  static List<String> _sortedIds(Iterable<String> ids) =>
      ids.toSet().toList(growable: false)..sort();

  static Future<String> _digest(String canonical) async {
    final hash = await Sha256().hash(utf8.encode(canonical));
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
