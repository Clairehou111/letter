import 'package:flutter_test/flutter_test.dart';
import 'package:letter_mobile/features/analytics/domain/analytics_service.dart';
import 'package:letter_mobile/features/analytics/domain/care_usage_aggregate.dart';

void main() {
  test('holds only a 30-day count and uploads a coarse bucket', () async {
    var now = DateTime.utc(2026, 1, 1);
    final service = _RecordingAnalyticsService()..enabled = true;
    final store = InMemoryCareUsageAggregateStore(delayHours: () => 24);
    final analytics = CareUsageAnalytics(
      analytics: service,
      store: store,
      now: () => now,
    );

    await analytics.recordCareUse();
    await analytics.recordCareUse();
    await analytics.recordCareUse();
    expect(service.payloads, isEmpty);

    now = DateTime.utc(2026, 2, 1, 1);
    await analytics.flushIfReady();

    final record = service.payloads.single.toRecord();
    expect(record, {
      'event_name': 'care_usage_30d',
      'schema_version': 1,
      'usage_bucket': '2-5',
    });
    expect(
      record.keys,
      isNot(contains(anyOf('timestamp', 'mode', 'outcome', 'duration'))),
    );
    expect(store.value, isNull);
  });

  test(
    'does not count without consent and clears pending on opt-out',
    () async {
      final service = _RecordingAnalyticsService();
      final store = InMemoryCareUsageAggregateStore();
      final analytics = CareUsageAnalytics(analytics: service, store: store);

      await analytics.recordCareUse();
      expect(store.value, isNull);

      service.enabled = true;
      await analytics.recordCareUse();
      expect(store.value?.count, 1);
      service.enabled = false;
      await analytics.clearPending();
      expect(store.value, isNull);
    },
  );
}

final class _RecordingAnalyticsService implements AnalyticsService {
  bool enabled = false;
  final List<AnalyticsPayload> payloads = [];

  @override
  bool get isEnabled => enabled;

  @override
  Future<void> disable() async => enabled = false;

  @override
  Future<void> dispose() async => enabled = false;

  @override
  Future<void> enable() async => enabled = true;

  @override
  Future<void> track(AnalyticsPayload payload) async {
    if (enabled) payloads.add(payload);
  }
}
