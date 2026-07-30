/// Contract for uploading/downloading encrypted backup packages to cloud
/// storage. Builds on the existing LocalBackupService encryption layer.
/// This is the transport layer; encryption/decryption remains in
/// LocalBackupService.
abstract interface class CloudBackupTransport {
  /// Uploads encrypted bytes under the user's backup path.
  /// Returns a reference identifier for later download.
  Future<String> uploadBackup({
    required String userId,
    required List<int> encryptedBytes,
  });

  /// Downloads encrypted bytes for a given backup reference.
  Future<List<int>> downloadBackup({
    required String userId,
    required String backupId,
  });

  /// Lists available backups for the user.
  Future<List<CloudBackupReference>> listBackups(String userId);

  /// Deletes a backup from cloud storage.
  Future<void> deleteBackup({
    required String userId,
    required String backupId,
  });

  Future<void> dispose();
}

/// Metadata for a stored cloud backup. Never contains health data.
final class CloudBackupReference {
  const CloudBackupReference({
    required this.id,
    required this.createdAt,
    this.sizeBytes,
  });

  final String id;
  final DateTime createdAt;
  final int? sizeBytes;
}
