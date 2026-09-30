import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/plus_preview.dart';

final class SecurePlusPreviewGrantRepository
    implements PlusPreviewGrantRepository {
  SecurePlusPreviewGrantRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'letter.plus.preview-grant.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<PlusPreviewGrant?> load() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, Object?>;
      return PlusPreviewGrant(
        startedAt: DateTime.parse(json['started_at']! as String).toUtc(),
        expiresAt: DateTime.parse(json['expires_at']! as String).toUtc(),
        anchorPeriodId: json['anchor_period_id']! as String,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(PlusPreviewGrant grant) => _storage.write(
    key: _key,
    value: jsonEncode({
      'started_at': grant.startedAt.toUtc().toIso8601String(),
      'expires_at': grant.expiresAt.toUtc().toIso8601String(),
      'anchor_period_id': grant.anchorPeriodId,
    }),
  );
}

final class InMemoryPlusPreviewGrantRepository
    implements PlusPreviewGrantRepository {
  InMemoryPlusPreviewGrantRepository([this.value]);

  PlusPreviewGrant? value;

  @override
  Future<PlusPreviewGrant?> load() async => value;

  @override
  Future<void> save(PlusPreviewGrant grant) async => value = grant;
}
