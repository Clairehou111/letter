import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../domain/local_backup_import.dart';
import '../domain/local_backup_models.dart';
import '../domain/local_backup_package.dart';

final class LocalBackupService {
  LocalBackupService({Cipher? cipher, LocalBackupKdfParameters? kdfParameters})
    : _cipher = cipher ?? AesGcm.with256bits(),
      _kdfParameters = kdfParameters ?? LocalBackupKdfParameters.supported {
    if (!_kdfParameters.isSupported) {
      throw ArgumentError.value(
        kdfParameters,
        'kdfParameters',
        'Only the supported local-backup KDF profile can be written.',
      );
    }
  }

  final Cipher _cipher;
  final LocalBackupKdfParameters _kdfParameters;

  Future<List<int>> encryptSnapshot({
    required LocalBackupSnapshot snapshot,
    required String passphrase,
  }) async {
    _requirePassphrase(passphrase);
    final cleartext = utf8.encode(jsonEncode(snapshot.toJson()));
    if (cleartext.length > localBackupMaximumPayloadBytes) {
      throw const LocalBackupException(LocalBackupFailure.payloadTooLarge);
    }
    final salt = List<int>.generate(
      16,
      (_) => SecureRandom.system.nextInt(256),
      growable: false,
    );
    final nonce = _cipher.newNonce();
    final package = LocalEncryptedBackupPackage(
      kdf: _kdfParameters,
      salt: salt,
      nonce: nonce,
      ciphertext: const <int>[0],
      mac: List<int>.filled(16, 0),
    );
    final key = await _deriveKey(passphrase, package);
    final secretBox = await _cipher.encrypt(
      cleartext,
      secretKey: key,
      nonce: nonce,
      aad: package.associatedData,
    );
    return LocalEncryptedBackupPackage(
      kdf: package.kdf,
      salt: package.salt,
      nonce: secretBox.nonce,
      ciphertext: secretBox.cipherText,
      mac: secretBox.mac.bytes,
    ).toBytes();
  }

  Future<LocalBackupSnapshot> decryptSnapshot({
    required List<int> packageBytes,
    required String passphrase,
  }) async {
    _requirePassphrase(passphrase);
    final package = LocalEncryptedBackupPackage.fromBytes(packageBytes);
    if (!package.kdf.isSupported) {
      throw const LocalBackupException(LocalBackupFailure.incompatibleCrypto);
    }
    final key = await _deriveKey(passphrase, package);
    try {
      final cleartext = await _cipher.decrypt(
        SecretBox(
          package.ciphertext,
          nonce: package.nonce,
          mac: Mac(package.mac),
        ),
        secretKey: key,
        aad: package.associatedData,
      );
      if (cleartext.length > localBackupMaximumPayloadBytes) {
        throw const LocalBackupException(LocalBackupFailure.payloadTooLarge);
      }
      try {
        return LocalBackupSnapshot.fromJson(
          jsonDecode(utf8.decode(cleartext, allowMalformed: false)),
        );
      } on LocalBackupException {
        rethrow;
      } on FormatException {
        throw const LocalBackupException(LocalBackupFailure.malformedPayload);
      }
    } on SecretBoxAuthenticationError {
      throw const LocalBackupException(LocalBackupFailure.integrityCheckFailed);
    }
  }

  Future<StagedLocalBackupImport> prepareImport({
    required List<int> packageBytes,
    required String passphrase,
    required LocalBackupImportPolicy policy,
    required LocalBackupSnapshotProvider destination,
    required LocalBackupImportStager stager,
  }) async {
    final incoming = await decryptSnapshot(
      packageBytes: packageBytes,
      passphrase: passphrase,
    );
    final existing = await destination.captureSnapshot();
    final plan = planLocalBackupImport(
      incoming: incoming,
      destination: existing,
      policy: policy,
    );
    try {
      return await stager.stage(plan);
    } on LocalBackupException {
      rethrow;
    } catch (_) {
      throw const LocalBackupException(LocalBackupFailure.stagingFailed);
    }
  }

  Future<SecretKey> _deriveKey(
    String passphrase,
    LocalEncryptedBackupPackage package,
  ) {
    final kdf = Argon2id(
      parallelism: package.kdf.parallelism,
      memory: package.kdf.memoryKiB,
      iterations: package.kdf.iterations,
      hashLength: package.kdf.hashLength,
    );
    return kdf.deriveKeyFromPassword(password: passphrase, nonce: package.salt);
  }

  void _requirePassphrase(String passphrase) {
    if (passphrase.trim().isEmpty) {
      throw const LocalBackupException(LocalBackupFailure.emptyPassphrase);
    }
  }
}
