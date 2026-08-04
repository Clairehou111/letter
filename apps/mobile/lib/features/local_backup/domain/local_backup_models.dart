import 'dart:convert';

const localBackupFormat = 'letter.local-backup';
const localBackupFormatVersion = 1;
const localBackupPayloadSchema = 'letter.local-backup.payload';
const localBackupPayloadSchemaVersion = 1;
const localBackupMaximumPayloadBytes = 5 * 1024 * 1024;

enum LocalBackupFailure {
  emptyPassphrase,
  invalidPackage,
  unsupportedFormat,
  incompatibleCrypto,
  integrityCheckFailed,
  malformedPayload,
  payloadTooLarge,
  stagingFailed,
}

final class LocalBackupException implements Exception {
  const LocalBackupException(this.failure);

  final LocalBackupFailure failure;

  String get userMessage => switch (failure) {
    LocalBackupFailure.emptyPassphrase =>
      'Use a non-empty password to protect this backup.',
    LocalBackupFailure.invalidPackage =>
      'This backup package could not be read.',
    LocalBackupFailure.unsupportedFormat =>
      'This backup was created by an unsupported version of Letter.',
    LocalBackupFailure.incompatibleCrypto =>
      'This backup uses security settings this version of Letter cannot open.',
    LocalBackupFailure.integrityCheckFailed =>
      'The password is incorrect or this backup has been changed.',
    LocalBackupFailure.malformedPayload =>
      'This backup does not contain a valid Letter data package.',
    LocalBackupFailure.payloadTooLarge =>
      'This backup is too large for Letter to open safely.',
    LocalBackupFailure.stagingFailed =>
      'Letter could not safely prepare this import. Your data is unchanged.',
  };

  @override
  String toString() => 'LocalBackupException($failure)';
}

final class LocalBackupRecord {
  LocalBackupRecord({
    required this.id,
    required DateTime updatedAt,
    required Map<String, Object?> data,
  }) : updatedAt = updatedAt.toUtc(),
       data = Map.unmodifiable(_copyJsonObject(data)) {
    if (!_recordIdPattern.hasMatch(id)) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    _requireJsonValue(data);
  }

  static final _recordIdPattern = RegExp(r'^[A-Za-z0-9._:-]{1,160}$');

  final String id;
  final DateTime updatedAt;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'data': data,
  };

  static LocalBackupRecord fromJson(Object? value) {
    final map = _requireObject(value);
    _requireExactKeys(map, {'id', 'updatedAt', 'data'});
    final id = map['id'];
    final updatedAt = map['updatedAt'];
    final data = map['data'];
    if (id is! String || updatedAt is! String || data is! Map) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    final parsedDate = DateTime.tryParse(updatedAt);
    if (parsedDate == null || !parsedDate.isUtc) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    return LocalBackupRecord(
      id: id,
      updatedAt: parsedDate,
      data: _objectMap(data),
    );
  }
}

final class LocalBackupCollection {
  LocalBackupCollection({
    required this.name,
    required this.schemaVersion,
    required Iterable<LocalBackupRecord> records,
  }) : records = List.unmodifiable(records) {
    if (!_collectionNamePattern.hasMatch(name) || schemaVersion < 1) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    final recordIds = this.records.map((record) => record.id).toSet();
    if (recordIds.length != this.records.length) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
  }

  static final _collectionNamePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  final String name;
  final int schemaVersion;
  final List<LocalBackupRecord> records;

  Map<String, Object?> toJson() => {
    'name': name,
    'schemaVersion': schemaVersion,
    'records': records.map((record) => record.toJson()).toList(growable: false),
  };

  static LocalBackupCollection fromJson(Object? value) {
    final map = _requireObject(value);
    _requireExactKeys(map, {'name', 'schemaVersion', 'records'});
    final name = map['name'];
    final schemaVersion = map['schemaVersion'];
    final records = map['records'];
    if (name is! String || schemaVersion is! int || records is! List) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    return LocalBackupCollection(
      name: name,
      schemaVersion: schemaVersion,
      records: records.map(LocalBackupRecord.fromJson),
    );
  }
}

final class LocalBackupSnapshot {
  LocalBackupSnapshot({
    required DateTime createdAt,
    required Iterable<LocalBackupCollection> collections,
  }) : createdAt = createdAt.toUtc(),
       collections = List.unmodifiable(collections) {
    final names = this.collections.map((collection) => collection.name).toSet();
    if (names.length != this.collections.length) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
  }

  final DateTime createdAt;
  final List<LocalBackupCollection> collections;

  Map<String, Object?> toJson() => {
    'schema': localBackupPayloadSchema,
    'schemaVersion': localBackupPayloadSchemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'collections': collections
        .map((collection) => collection.toJson())
        .toList(growable: false),
  };

  static LocalBackupSnapshot fromJson(Object? value) {
    final map = _requireObject(value);
    _requireExactKeys(map, {
      'schema',
      'schemaVersion',
      'createdAt',
      'collections',
    });
    final schema = map['schema'];
    final schemaVersion = map['schemaVersion'];
    final createdAt = map['createdAt'];
    final collections = map['collections'];
    if (schema != localBackupPayloadSchema ||
        schemaVersion != localBackupPayloadSchemaVersion ||
        createdAt is! String ||
        collections is! List) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    final parsedDate = DateTime.tryParse(createdAt);
    if (parsedDate == null || !parsedDate.isUtc) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    return LocalBackupSnapshot(
      createdAt: parsedDate,
      collections: collections.map(LocalBackupCollection.fromJson),
    );
  }
}

enum LocalBackupImportPolicy { replace, merge }

/// Describes what will happen to one specific record during import.
enum LocalBackupRecordChangeKind { add, replace, keep, remove }

final class LocalBackupRecordChange {
  const LocalBackupRecordChange({
    required this.recordId,
    required this.label,
    required this.kind,
    this.reason,
  });

  /// Stable record identifier (e.g. the Drift row id).
  final String recordId;

  /// One-line human-readable description derived from structured fields.
  /// Never contains free-text notes or impulse-draft content.
  final String label;

  final LocalBackupRecordChangeKind kind;

  /// Optional short explanation (e.g. "local is newer", "only in backup").
  final String? reason;

  String get actionLabel => switch (kind) {
    LocalBackupRecordChangeKind.add => 'Added',
    LocalBackupRecordChangeKind.replace => 'Replaced',
    LocalBackupRecordChangeKind.keep => 'Kept',
    LocalBackupRecordChangeKind.remove => 'Removed',
  };
}

final class LocalBackupCollectionPreview {
  const LocalBackupCollectionPreview({
    required this.name,
    required this.incomingRecords,
    required this.destinationRecords,
    required this.wouldAdd,
    required this.wouldReplace,
    required this.wouldKeepDestination,
    required this.wouldRemove,
    this.changes = const [],
  });

  final String name;
  final int incomingRecords;
  final int destinationRecords;
  final int wouldAdd;
  final int wouldReplace;
  final int wouldKeepDestination;
  final int wouldRemove;

  /// Per-record change detail, one entry per affected record.
  /// Empty when the collection has no changes or the list was not computed.
  final List<LocalBackupRecordChange> changes;
}

final class LocalBackupImportPreview {
  const LocalBackupImportPreview({
    required this.policy,
    required this.collections,
  });

  final LocalBackupImportPolicy policy;
  final List<LocalBackupCollectionPreview> collections;
}

Map<String, Object?> _requireObject(Object? value) {
  if (value is! Map) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return _objectMap(value);
}

Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const LocalBackupException(LocalBackupFailure.malformedPayload);
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _requireExactKeys(Map<String, Object?> map, Set<String> expected) {
  if (map.length != expected.length ||
      !map.keys.toSet().containsAll(expected)) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
}

Map<String, Object?> _copyJsonObject(Map<String, Object?> value) {
  final encoded = jsonEncode(value);
  final decoded = jsonDecode(encoded);
  if (decoded is! Map) {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
  return _objectMap(decoded);
}

void _requireJsonValue(Object? value) {
  try {
    jsonEncode(value);
  } on JsonUnsupportedObjectError {
    throw const LocalBackupException(LocalBackupFailure.malformedPayload);
  }
}
