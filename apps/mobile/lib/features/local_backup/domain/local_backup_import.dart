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
    return _MergeResult(
      collection: destination,
      preview: LocalBackupCollectionPreview(
        name: name,
        incomingRecords: 0,
        destinationRecords: destination!.records.length,
        wouldAdd: 0,
        wouldReplace: 0,
        wouldKeepDestination: destination.records.length,
        wouldRemove: 0,
      ),
    );
  }
  if (destination == null) {
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
      ),
    );
  }
  if (source.schemaVersion != destination.schemaVersion) {
    throw const LocalBackupException(LocalBackupFailure.unsupportedFormat);
  }
  final sourceById = {for (final record in source.records) record.id: record};
  final target = <LocalBackupRecord>[];
  var add = 0;
  var replace = 0;
  var keep = 0;
  for (final existing in destination.records) {
    final incoming = sourceById.remove(existing.id);
    if (incoming == null) {
      target.add(existing);
      keep++;
    } else if (incoming.updatedAt.isAfter(existing.updatedAt)) {
      target.add(incoming);
      replace++;
    } else {
      target.add(existing);
      keep++;
    }
  }
  for (final incoming in sourceById.values) {
    target.add(incoming);
    add++;
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
