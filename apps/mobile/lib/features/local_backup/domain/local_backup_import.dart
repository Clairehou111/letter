import 'local_backup_models.dart';

final class LocalBackupImportPlan {
  const LocalBackupImportPlan({
    required this.preview,
    required this.resultingSnapshot,
  });

  final LocalBackupImportPreview preview;
  final LocalBackupSnapshot resultingSnapshot;
}

LocalBackupImportPlan planLocalBackupImport({
  required LocalBackupSnapshot incoming,
  required LocalBackupSnapshot destination,
  required LocalBackupImportPolicy policy,
}) {
  final incomingByName = {
    for (final collection in incoming.collections) collection.name: collection,
  };
  final destinationByName = {
    for (final collection in destination.collections)
      collection.name: collection,
  };
  final names = {...incomingByName.keys, ...destinationByName.keys}.toList()
    ..sort();
  final previews = <LocalBackupCollectionPreview>[];
  final result = <LocalBackupCollection>[];

  for (final name in names) {
    final source = incomingByName[name];
    final existing = destinationByName[name];
    if (policy == LocalBackupImportPolicy.replace) {
      if (source != null) {
        result.add(source);
      }
      previews.add(_replacePreview(name, source, existing));
      continue;
    }
    final merge = _mergeCollection(name, source, existing);
    if (merge.collection != null) {
      result.add(merge.collection!);
    }
    previews.add(merge.preview);
  }
  return LocalBackupImportPlan(
    preview: LocalBackupImportPreview(policy: policy, collections: previews),
    resultingSnapshot: LocalBackupSnapshot(
      createdAt: incoming.createdAt,
      collections: result,
    ),
  );
}

LocalBackupCollectionPreview _replacePreview(
  String name,
  LocalBackupCollection? source,
  LocalBackupCollection? destination,
) {
  final sourceRecords = source?.records ?? const <LocalBackupRecord>[];
  final destinationRecords =
      destination?.records ?? const <LocalBackupRecord>[];
  final destinationIds = destinationRecords.map((record) => record.id).toSet();
  final sourceIds = sourceRecords.map((record) => record.id).toSet();

  final changes = <LocalBackupRecordChange>[];
  // Records added from backup (not on device).
  for (final record in sourceRecords) {
    if (!destinationIds.contains(record.id)) {
      changes.add(LocalBackupRecordChange(
        recordId: record.id,
        label: _recordLabel(name, record),
        kind: LocalBackupRecordChangeKind.add,
        reason: 'Only in backup',
      ));
    }
  }
  // Records replaced (in both, backup wins unconditionally for replace).
  for (final record in sourceRecords) {
    if (destinationIds.contains(record.id)) {
      changes.add(LocalBackupRecordChange(
        recordId: record.id,
        label: _recordLabel(name, record),
        kind: LocalBackupRecordChangeKind.replace,
        reason: 'Backup overwrites device',
      ));
    }
  }
  // Records removed (on device but not in backup).
  for (final id in destinationIds.difference(sourceIds)) {
    changes.add(LocalBackupRecordChange(
      recordId: id,
      label: _recordIdOnlyLabel(name, id),
      kind: LocalBackupRecordChangeKind.remove,
      reason: 'Not in backup',
    ));
  }

  return LocalBackupCollectionPreview(
    name: name,
    incomingRecords: sourceRecords.length,
    destinationRecords: destinationRecords.length,
    wouldAdd: sourceRecords
        .where((record) => !destinationIds.contains(record.id))
        .length,
    wouldReplace: sourceRecords
        .where((record) => destinationIds.contains(record.id))
        .length,
    wouldKeepDestination: 0,
    wouldRemove: destinationIds.where((id) => !sourceIds.contains(id)).length,
    changes: changes,
  );
}

_MergeResult _mergeCollection(
  String name,
  LocalBackupCollection? source,
  LocalBackupCollection? destination,
) {
  if (source == null && destination == null) {
    throw StateError('A backup collection must have a source or destination.');
  }
  if (source == null) {
    final destRecords = destination!.records;
    final changes = destRecords
        .map((r) => LocalBackupRecordChange(
              recordId: r.id,
              label: _recordLabel(name, r),
              kind: LocalBackupRecordChangeKind.keep,
              reason: 'Only on device',
            ))
        .toList(growable: false);
    return _MergeResult(
      collection: destination,
      preview: LocalBackupCollectionPreview(
        name: name,
        incomingRecords: 0,
        destinationRecords: destRecords.length,
        wouldAdd: 0,
        wouldReplace: 0,
        wouldKeepDestination: destRecords.length,
        wouldRemove: 0,
        changes: changes,
      ),
    );
  }
  if (destination == null) {
    final changes = source.records
        .map((r) => LocalBackupRecordChange(
              recordId: r.id,
              label: _recordLabel(name, r),
              kind: LocalBackupRecordChangeKind.add,
              reason: 'Only in backup',
            ))
        .toList(growable: false);
    return _MergeResult(
      collection: source,
      preview: LocalBackupCollectionPreview(
        name: name,
        incomingRecords: source.records.length,
        destinationRecords: 0,
        wouldAdd: source.records.length,
        wouldReplace: 0,
        wouldKeepDestination: 0,
        wouldRemove: 0,
        changes: changes,
      ),
    );
  }
  if (source.schemaVersion != destination.schemaVersion) {
    throw const LocalBackupException(LocalBackupFailure.unsupportedFormat);
  }
  final sourceById = {for (final record in source.records) record.id: record};
  final target = <LocalBackupRecord>[];
  final changes = <LocalBackupRecordChange>[];
  var add = 0;
  var replace = 0;
  var keep = 0;
  for (final existing in destination.records) {
    final incoming = sourceById.remove(existing.id);
    if (incoming == null) {
      target.add(existing);
      keep++;
      changes.add(LocalBackupRecordChange(
        recordId: existing.id,
        label: _recordLabel(name, existing),
        kind: LocalBackupRecordChangeKind.keep,
        reason: 'Only on device',
      ));
    } else if (incoming.updatedAt.isAfter(existing.updatedAt)) {
      target.add(incoming);
      replace++;
      changes.add(LocalBackupRecordChange(
        recordId: incoming.id,
        label: _recordLabel(name, incoming),
        kind: LocalBackupRecordChangeKind.replace,
        reason: 'Backup is newer',
      ));
    } else {
      target.add(existing);
      keep++;
      changes.add(LocalBackupRecordChange(
        recordId: existing.id,
        label: _recordLabel(name, existing),
        kind: LocalBackupRecordChangeKind.keep,
        reason: existing.updatedAt == incoming.updatedAt
            ? 'Same timestamp'
            : 'Device is newer',
      ));
    }
  }
  for (final incoming in sourceById.values) {
    target.add(incoming);
    add++;
    changes.add(LocalBackupRecordChange(
      recordId: incoming.id,
      label: _recordLabel(name, incoming),
      kind: LocalBackupRecordChangeKind.add,
      reason: 'Only in backup',
    ));
  }
  return _MergeResult(
    collection: LocalBackupCollection(
      name: name,
      schemaVersion: source.schemaVersion,
      records: target,
    ),
    preview: LocalBackupCollectionPreview(
      name: name,
      incomingRecords: source.records.length,
      destinationRecords: destination.records.length,
      wouldAdd: add,
      wouldReplace: replace,
      wouldKeepDestination: keep,
      wouldRemove: 0,
      changes: changes,
    ),
  );
}

final class _MergeResult {
  const _MergeResult({required this.collection, required this.preview});

  final LocalBackupCollection? collection;
  final LocalBackupCollectionPreview preview;
}

abstract interface class LocalBackupSnapshotProvider {
  Future<LocalBackupSnapshot> captureSnapshot();
}

abstract interface class LocalBackupImportStager {
  /// Must not alter persisted data until [StagedLocalBackupImport.commit].
  Future<StagedLocalBackupImport> stage(LocalBackupImportPlan plan);
}

/// A production local store can both capture its current records and stage an
/// atomic import. It never sends a snapshot or passphrase to a server.
abstract interface class LocalBackupStore
    implements LocalBackupSnapshotProvider, LocalBackupImportStager {}

abstract interface class StagedLocalBackupImport {
  LocalBackupImportPreview get preview;

  /// Must commit all collections atomically or leave persisted data unchanged.
  Future<void> commit();

  Future<void> discard();
}

// ── Record labelling for preview ──────────────────────────────────────
//
// These produce short, privacy-safe labels from structured record fields.
// Free-text note content and impulse drafts are never included.

/// Derives a one-line label from a [record]'s structured fields based on its
/// [collectionName]. Returns a fallback using the record id when data is
/// insufficient.
String _recordLabel(String collectionName, LocalBackupRecord record) {
  final data = record.data;
  return switch (collectionName) {
    'periods' => _periodLabel(data),
    'care_records' => _careRecordLabel(data),
    'care_reflections' => _careReflectionLabel(data),
    'cycle_reflections' => _cycleReflectionLabel(data),
    'health_records' => _healthRecordLabel(data),
    'capture_notes' => _captureNoteLabel(data),
    'moment_check_ins' => _momentCheckInLabel(data),
    _ => _recordIdOnlyLabel(collectionName, record.id),
  };
}

/// Label used when we only have the record id (e.g. a removed record whose
/// data isn't available from the backup).
String _recordIdOnlyLabel(String collectionName, String id) {
  final shortId = id.length > 12 ? '${id.substring(0, 10)}…' : id;
  return '${_collectionDisplayName(collectionName)} · $shortId';
}

String _periodLabel(Map<String, Object?> data) {
  final start = _maybeInt(data, 'startDay');
  final end = _maybeInt(data, 'endDay');
  final startStr = _dayString(start);
  if (startStr.isEmpty) return 'Period record';
  final endStr = _dayString(end);
  if (endStr.isNotEmpty && endStr != startStr) {
    return '$startStr – $endStr';
  }
  return startStr;
}

String _careRecordLabel(Map<String, Object?> data) {
  final mode = _maybeString(data, 'mode');
  final action = _maybeString(data, 'actionLabel');
  final occurredStr = _dayString(_maybeInt(data, 'occurredAtMillis'));
  final parts = <String>[];
  if (mode != null && mode.isNotEmpty) parts.add(_capitalize(mode));
  if (action != null && action.isNotEmpty) parts.add(action);
  if (occurredStr.isNotEmpty) parts.add(occurredStr);
  return parts.isEmpty ? 'Care action' : parts.join(' · ');
}

String _careReflectionLabel(Map<String, Object?> data) {
  final mode = _maybeString(data, 'mode');
  final createdStr = _dayString(_maybeInt(data, 'createdAtMillis'));
  final parts = <String>[];
  if (mode != null && mode.isNotEmpty) parts.add('Reflection · ${_capitalize(mode)}');
  if (createdStr.isNotEmpty) parts.add(createdStr);
  return parts.isEmpty ? 'Care reflection' : parts.join(' · ');
}

String _cycleReflectionLabel(Map<String, Object?> data) {
  final cycleStartStr = _dayString(_maybeInt(data, 'cycleStartDay'));
  final createdStr = _dayString(_maybeInt(data, 'createdAtMillis'));
  final parts = <String>['Cycle reflection'];
  if (cycleStartStr.isNotEmpty) parts.add(cycleStartStr);
  if (createdStr.isNotEmpty) parts.add(createdStr);
  return parts.join(' · ');
}

String _healthRecordLabel(Map<String, Object?> data) {
  final symptom = _maybeString(data, 'symptom');
  final severity = _maybeString(data, 'severity');
  final experiencedStr = _dayString(_maybeInt(data, 'experiencedDay'));
  final parts = <String>[];
  if (symptom != null && symptom.isNotEmpty) parts.add(_capitalize(symptom));
  if (severity != null && severity.isNotEmpty) parts.add(severity);
  if (experiencedStr.isNotEmpty) parts.add(experiencedStr);
  return parts.isEmpty ? 'Health record' : parts.join(' · ');
}

String _captureNoteLabel(Map<String, Object?> data) {
  final source = _maybeString(data, 'source');
  final createdStr = _dayString(_maybeInt(data, 'createdAtMillis'));
  final parts = <String>['Note'];
  if (source != null && source.isNotEmpty) parts.add(source);
  if (createdStr.isNotEmpty) parts.add(createdStr);
  return parts.join(' · ');
}

String _momentCheckInLabel(Map<String, Object?> data) {
  final state = _maybeString(data, 'state');
  final occurredStr = _dayString(_maybeInt(data, 'occurredAtMillis'));
  final parts = <String>[];
  if (state != null && state.isNotEmpty) parts.add(_capitalize(state));
  if (occurredStr.isNotEmpty) parts.add(occurredStr);
  return parts.isEmpty ? 'Check-in' : parts.join(' · ');
}

String _collectionDisplayName(String name) => switch (name) {
  'periods' => 'Period',
  'care_records' => 'Care',
  'care_reflections' => 'Reflection',
  'cycle_reflections' => 'Cycle',
  'health_records' => 'Health',
  'capture_notes' => 'Note',
  'moment_check_ins' => 'Check-in',
  _ => name,
};

/// Parses a millis-since-epoch integer (stored as int or num) into a short
/// date string like "Jul 28". Returns empty string when unparseable.
String _dayString(int? millis) {
  if (millis == null || millis <= 0) return '';
  try {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  } catch (_) {
    return '';
  }
}

int? _maybeInt(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String? _maybeString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String) return value;
  return null;
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
