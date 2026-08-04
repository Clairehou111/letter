/// Stores and retrieves the user's backup passphrase on-device so they
/// don't need to re-enter it on every backup operation.
///
/// The passphrase itself is never sent to Letter servers. It is stored in the
/// platform secure enclave (iOS Keychain / Android EncryptedSharedPreferences)
/// and only used locally for encrypting/decrypting backup packages.
abstract interface class LocalBackupCredentialStore {
  /// Returns the stored passphrase, or null if none has been saved.
  Future<String?> readPassphrase();

  /// Persists a passphrase for future reuse.
  Future<void> savePassphrase(String passphrase);

  /// Removes the stored passphrase. Safe to call even when nothing is stored.
  Future<void> deletePassphrase();

  /// True when a passphrase is currently stored.
  Future<bool> hasPassphrase();
}
