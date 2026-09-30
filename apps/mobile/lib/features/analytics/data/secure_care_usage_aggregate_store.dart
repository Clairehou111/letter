import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/care_usage_aggregate.dart';

final class SecureCareUsageAggregateStore implements CareUsageAggregateStore {
  SecureCareUsageAggregateStore({FlutterSecureStorage? storage, Random? random})
    : _storage = storage ?? const FlutterSecureStorage(),
      _random = random ?? Random.secure();

  static const _storageKey = 'letter.analytics.care-usage.v1';
  final FlutterSecureStorage _storage;
  final Random _random;

  @override
  Future<void> increment(DateTime now) async {
    final current = await _load();
    final next = current == null
        ? CareUsageAggregate(
            windowStartedAt: now.toUtc(),
            uploadAfter: now.toUtc().add(
              Duration(days: 30, hours: 24 + _random.nextInt(49)),
            ),
            count: 1,
          )
        : CareUsageAggregate(
            windowStartedAt: current.windowStartedAt,
            uploadAfter: current.uploadAfter,
            count: current.count + 1,
          );
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({
        'version': 1,
        'window_started_at': next.windowStartedAt.toIso8601String(),
        'upload_after': next.uploadAfter.toIso8601String(),
        'count': next.count,
      }),
    );
  }

  @override
  Future<CareUsageAggregate?> ready(DateTime now) async {
    final current = await _load();
    return current != null && !now.toUtc().isBefore(current.uploadAfter)
        ? current
        : null;
  }

  @override
  Future<void> clear() => _storage.delete(key: _storageKey);

  Future<CareUsageAggregate?> _load() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        throw const FormatException();
      }
      final start = DateTime.parse(value['window_started_at'] as String);
      final uploadAfter = DateTime.parse(value['upload_after'] as String);
      final count = value['count'] as int;
      if (!start.isUtc || !uploadAfter.isUtc || count < 1) {
        throw const FormatException();
      }
      return CareUsageAggregate(
        windowStartedAt: start,
        uploadAfter: uploadAfter,
        count: count,
      );
    } on Object {
      await clear();
      return null;
    }
  }
}
