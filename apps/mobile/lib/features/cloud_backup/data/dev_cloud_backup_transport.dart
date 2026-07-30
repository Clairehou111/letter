import 'dart:async';

import '../domain/cloud_backup_transport.dart';

/// Dev adapter that stores backups in memory. No network calls.
/// In production this is replaced by a Supabase Storage adapter.
final class DevCloudBackupTransport implements CloudBackupTransport {
  final Map<String, Map<String, List<int>>> _store = {};
  int _nextId = 1;

  @override
  Future<String> uploadBackup({
    required String userId,
    required List<int> encryptedBytes,
  }) async {
    final backupId = 'backup-${_nextId++}';
    _store.putIfAbsent(userId, () => {});
    _store[userId]![backupId] = encryptedBytes;
    return backupId;
  }

  @override
  Future<List<int>> downloadBackup({
    required String userId,
    required String backupId,
  }) async {
    final userStore = _store[userId];
    if (userStore == null || !userStore.containsKey(backupId)) {
      throw CloudBackupException('Backup not found');
    }
    return List.unmodifiable(userStore[backupId]!);
  }

  @override
  Future<List<CloudBackupReference>> listBackups(String userId) async {
    final userStore = _store[userId];
    if (userStore == null) {
      return [];
    }
    return userStore.entries.map((entry) {
      return CloudBackupReference(
        id: entry.key,
        createdAt: DateTime.now(),
        sizeBytes: entry.value.length,
      );
    }).toList();
  }

  @override
  Future<void> deleteBackup({
    required String userId,
    required String backupId,
  }) async {
    _store[userId]?.remove(backupId);
  }

  @override
  Future<void> dispose() async => _store.clear();
}

final class CloudBackupException implements Exception {
  const CloudBackupException(this.message);
  final String message;

  @override
  String toString() => 'CloudBackupException($message)';
}
