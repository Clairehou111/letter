import 'dart:typed_data';

import '../../features/local_backup/application/local_backup_service.dart';
import '../../features/local_backup/domain/local_backup_credential_store.dart';
import '../../features/local_backup/domain/local_backup_file_port.dart';
import '../../features/local_backup/domain/local_backup_import.dart';
import '../../features/local_backup/domain/local_backup_models.dart';
import '../experience_release_ports.dart';

/// Production boundary for encrypted local backup and restore.
///
/// A backup is always written to Letter's local folder before the operating
/// system receives it through its share sheet. No cloud provider is contacted
/// by Letter; iCloud Drive, Google Drive, Dropbox, AirDrop, or no destination
/// are all choices made in that native handoff.
final class LetterBackupExperiencePort implements BackupExperiencePort {
  LetterBackupExperiencePort({
    required this.store,
    LocalBackupFilePort? filePort,
    this.credentialStore,
    LocalBackupService? service,
  }) : filePort = filePort ?? SystemLocalBackupFilePort(),
       _service = service ?? LocalBackupService();

  final LocalBackupStore store;
  final LocalBackupFilePort filePort;
  final LocalBackupCredentialStore? credentialStore;
  final LocalBackupService _service;
  StagedLocalBackupImport? _stagedImport;

  @override
  String get localDestinationDescription =>
      'Letter Within’s dedicated letter folder on this device';

  @override
  Future<bool> hasStoredPassphrase() async {
    try {
      return await credentialStore?.hasPassphrase() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<ExperienceFileReceipt> exportEncrypted({
    required String passphrase,
    required bool rememberPassphrase,
  }) async {
    final snapshot = await store.captureSnapshot();
    final bytes = await _service.encryptSnapshot(
      snapshot: snapshot,
      passphrase: passphrase,
    );
    final data = Uint8List.fromList(bytes);
    final savedPath = await filePort.saveEncryptedBackupLocally(data);
    if (rememberPassphrase) {
      try {
        await credentialStore?.savePassphrase(passphrase);
      } on Object {
        // A keychain failure must not turn a completed local backup into a
        // failed backup. The user can still keep the password themselves.
      }
    }
    try {
      await filePort.shareEncryptedBackup(data);
      return ExperienceFileReceipt(
        outcome: ExperienceFileOutcome.shared,
        localPath: savedPath,
        message:
            'Saved in your Letter folder, then opened the system share sheet.',
      );
    } on Object {
      return ExperienceFileReceipt(
        outcome: ExperienceFileOutcome.savedOnly,
        localPath: savedPath,
        message:
            'Saved in your Letter folder. You can share it from there anytime.',
      );
    }
  }

  @override
  Future<LocalBackupImportPreview?> prepareImport({
    required String passphrase,
    required LocalBackupImportPolicy policy,
  }) async {
    await discardPreparedImport();
    final packageBytes = await filePort.pickEncryptedBackup();
    if (packageBytes == null) return null;
    final staged = await _service.prepareImport(
      packageBytes: packageBytes,
      passphrase: passphrase,
      policy: policy,
      destination: store,
      stager: store,
    );
    _stagedImport = staged;
    return staged.preview;
  }

  @override
  Future<void> commitPreparedImport() async {
    final staged = _stagedImport;
    if (staged == null) {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
    await staged.commit();
    _stagedImport = null;
  }

  @override
  Future<void> discardPreparedImport() async {
    final staged = _stagedImport;
    _stagedImport = null;
    await staged?.discard();
  }
}
