import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/local_backup_credential_store.dart';

/// Production credential store backed by iOS Keychain / Android Keystore.
///
/// Uses `flutter_secure_storage` with biometric-optional access control.
/// The stored passphrase is encrypted at rest by the platform and never
/// included in app backups or logs.
final class SecureLocalBackupCredentialStore
    implements LocalBackupCredentialStore {
  SecureLocalBackupCredentialStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _passphraseKey = 'letter.local_backup.passphrase';

  @override
  Future<String?> readPassphrase() => _storage.read(key: _passphraseKey);

  @override
  Future<void> savePassphrase(String passphrase) =>
      _storage.write(key: _passphraseKey, value: passphrase);

  @override
  Future<void> deletePassphrase() => _storage.delete(key: _passphraseKey);

  @override
  Future<bool> hasPassphrase() => _storage.containsKey(key: _passphraseKey);
}
