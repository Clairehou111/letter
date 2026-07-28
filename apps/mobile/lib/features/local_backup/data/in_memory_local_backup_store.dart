import '../domain/local_backup_import.dart';
import '../domain/local_backup_models.dart';

/// Reference transactional store for tests and non-persistent development.
/// Production adapters must stage against the local encrypted database.
final class InMemoryLocalBackupStore
    implements LocalBackupSnapshotProvider, LocalBackupImportStager {
  InMemoryLocalBackupStore(this._snapshot);

  LocalBackupSnapshot _snapshot;

  @override
  Future<LocalBackupSnapshot> captureSnapshot() async => _snapshot;

  @override
  Future<StagedLocalBackupImport> stage(LocalBackupImportPlan plan) async {
    return _InMemoryStagedImport(store: this, plan: plan);
  }
}

final class _InMemoryStagedImport implements StagedLocalBackupImport {
  _InMemoryStagedImport({required this.store, required this.plan});

  final InMemoryLocalBackupStore store;
  final LocalBackupImportPlan plan;
  var _finished = false;

  @override
  LocalBackupImportPreview get preview => plan.preview;

  @override
  Future<void> commit() async {
    if (_finished) {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
    store._snapshot = plan.resultingSnapshot;
    _finished = true;
  }

  @override
  Future<void> discard() async {
    _finished = true;
  }
}
