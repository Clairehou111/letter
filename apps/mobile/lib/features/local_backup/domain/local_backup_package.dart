import 'dart:convert';
import 'dart:typed_data';

import 'local_backup_models.dart';

const localBackupKdfAlgorithm = 'argon2id-v19';
const localBackupCipherAlgorithm = 'aes-256-gcm';

final class LocalBackupKdfParameters {
  const LocalBackupKdfParameters({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  static const supported = LocalBackupKdfParameters(
    memoryKiB: 19456,
    iterations: 2,
    parallelism: 1,
    hashLength: 32,
  );

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;

  Map<String, Object?> toJson() => {
    'algorithm': localBackupKdfAlgorithm,
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'hashLength': hashLength,
  };

  static LocalBackupKdfParameters fromJson(Object? value) {
    final map = _packageMap(value);
    if (!_hasExactKeys(map, {
      'algorithm',
      'memoryKiB',
      'iterations',
      'parallelism',
      'hashLength',
    })) {
      throw const LocalBackupException(LocalBackupFailure.invalidPackage);
    }
    if (map['algorithm'] != localBackupKdfAlgorithm ||
        map['memoryKiB'] is! int ||
        map['iterations'] is! int ||
        map['parallelism'] is! int ||
        map['hashLength'] is! int) {
      throw const LocalBackupException(LocalBackupFailure.incompatibleCrypto);
    }
    return LocalBackupKdfParameters(
      memoryKiB: map['memoryKiB']! as int,
      iterations: map['iterations']! as int,
      parallelism: map['parallelism']! as int,
      hashLength: map['hashLength']! as int,
    );
  }

  bool get isSupported =>
      memoryKiB == supported.memoryKiB &&
      iterations == supported.iterations &&
      parallelism == supported.parallelism &&
      hashLength == supported.hashLength;
}

final class LocalEncryptedBackupPackage {
  LocalEncryptedBackupPackage({
    required this.kdf,
    required List<int> salt,
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> mac,
  }) : salt = Uint8List.fromList(salt),
       nonce = Uint8List.fromList(nonce),
       ciphertext = Uint8List.fromList(ciphertext),
       mac = Uint8List.fromList(mac) {
    if (this.salt.length != 16 ||
        this.nonce.length != 12 ||
        this.mac.length != 16 ||
        this.ciphertext.isEmpty) {
      throw const LocalBackupException(LocalBackupFailure.invalidPackage);
    }
  }

  final LocalBackupKdfParameters kdf;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  List<int> get associatedData => utf8.encode(
    jsonEncode({
      'format': localBackupFormat,
      'formatVersion': localBackupFormatVersion,
      'kdf': kdf.toJson(),
      'cipher': localBackupCipherAlgorithm,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
    }),
  );

  List<int> toBytes() => utf8.encode(
    jsonEncode({
      'format': localBackupFormat,
      'formatVersion': localBackupFormatVersion,
      'kdf': kdf.toJson(),
      'cipher': localBackupCipherAlgorithm,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
    }),
  );

  static LocalEncryptedBackupPackage fromBytes(List<int> bytes) {
    if (bytes.length > localBackupMaximumPayloadBytes * 2) {
      throw const LocalBackupException(LocalBackupFailure.payloadTooLarge);
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      final map = _packageMap(decoded);
      if (!_hasExactKeys(map, {
        'format',
        'formatVersion',
        'kdf',
        'cipher',
        'salt',
        'nonce',
        'ciphertext',
        'mac',
      })) {
        throw const LocalBackupException(LocalBackupFailure.invalidPackage);
      }
      if (map['format'] != localBackupFormat || map['formatVersion'] is! int) {
        throw const LocalBackupException(LocalBackupFailure.unsupportedFormat);
      }
      if (map['formatVersion'] != localBackupFormatVersion) {
        throw const LocalBackupException(LocalBackupFailure.unsupportedFormat);
      }
      if (map['cipher'] != localBackupCipherAlgorithm ||
          map['salt'] is! String ||
          map['nonce'] is! String ||
          map['ciphertext'] is! String ||
          map['mac'] is! String) {
        throw const LocalBackupException(LocalBackupFailure.incompatibleCrypto);
      }
      return LocalEncryptedBackupPackage(
        kdf: LocalBackupKdfParameters.fromJson(map['kdf']),
        salt: base64Decode(map['salt']! as String),
        nonce: base64Decode(map['nonce']! as String),
        ciphertext: base64Decode(map['ciphertext']! as String),
        mac: base64Decode(map['mac']! as String),
      );
    } on LocalBackupException {
      rethrow;
    } on FormatException {
      throw const LocalBackupException(LocalBackupFailure.invalidPackage);
    } on ArgumentError {
      throw const LocalBackupException(LocalBackupFailure.invalidPackage);
    }
  }

  @override
  String toString() =>
      'LocalEncryptedBackupPackage(formatVersion: $localBackupFormatVersion, bytes: ${ciphertext.length})';
}

Map<String, Object?> _packageMap(Object? value) {
  if (value is! Map) {
    throw const LocalBackupException(LocalBackupFailure.invalidPackage);
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const LocalBackupException(LocalBackupFailure.invalidPackage);
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

bool _hasExactKeys(Map<String, Object?> map, Set<String> expected) =>
    map.length == expected.length && map.keys.toSet().containsAll(expected);
