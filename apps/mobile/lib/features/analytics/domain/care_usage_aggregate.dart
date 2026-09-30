import 'analytics_service.dart';

final class CareUsageAggregate {
  const CareUsageAggregate({
    required this.windowStartedAt,
    required this.uploadAfter,
    required this.count,
  });

  final DateTime windowStartedAt;
  final DateTime uploadAfter;
  final int count;

  CareUsageBucket get bucket => count <= 1
      ? CareUsageBucket.one
      : count <= 5
      ? CareUsageBucket.twoToFive
      : CareUsageBucket.sixOrMore;
}

abstract interface class CareUsageAggregateStore {
  Future<void> increment(DateTime now);
  Future<CareUsageAggregate?> ready(DateTime now);
  Future<void> clear();
}

final class InMemoryCareUsageAggregateStore implements CareUsageAggregateStore {
  InMemoryCareUsageAggregateStore({int Function()? delayHours})
    : _delayHours = delayHours ?? (() => 24);

  final int Function() _delayHours;
  CareUsageAggregate? value;

  @override
  Future<void> increment(DateTime now) async {
    final current = value;
    value = current == null
        ? CareUsageAggregate(
            windowStartedAt: now.toUtc(),
            uploadAfter: now.toUtc().add(
              Duration(days: 30, hours: _delayHours().clamp(24, 72)),
            ),
            count: 1,
          )
        : CareUsageAggregate(
            windowStartedAt: current.windowStartedAt,
            uploadAfter: current.uploadAfter,
            count: current.count + 1,
          );
  }

  @override
  Future<CareUsageAggregate?> ready(DateTime now) async {
    final current = value;
    return current != null && !now.toUtc().isBefore(current.uploadAfter)
        ? current
        : null;
  }

  @override
  Future<void> clear() async => value = null;
}

final class CareUsageAnalytics {
  CareUsageAnalytics({
    required AnalyticsService analytics,
    required CareUsageAggregateStore store,
    DateTime Function()? now,
    // ignore: prefer_initializing_formals
  }) : _analytics = analytics,
       // ignore: prefer_initializing_formals
       _store = store,
       _now = now ?? DateTime.now;

  final AnalyticsService _analytics;
  final CareUsageAggregateStore _store;
  final DateTime Function() _now;
  Future<void> _operationTail = Future<void>.value();

  Future<void> recordCareUse() => _serialized(() async {
    if (!_analytics.isEnabled) return;
    await _flushIfReady();
    // Consent may have changed while storage/network work was in flight.
    if (!_analytics.isEnabled) return;
    await _store.increment(_now().toUtc());
  });

  Future<void> flushIfReady() => _serialized(_flushIfReady);

  Future<void> _flushIfReady() async {
    if (!_analytics.isEnabled) return;
    final aggregate = await _store.ready(_now().toUtc());
    if (aggregate == null) return;
    if (!_analytics.isEnabled) return;
    await _analytics.track(
      AnalyticsPayload(
        event: CareUsageBucketEvent(aggregate.bucket),
        timestamp: _now().toUtc(),
      ),
    );
    await _store.clear();
  }

  Future<void> clearPending() => _serialized(_store.clear);

  Future<void> _serialized(Future<void> Function() action) {
    final operation = _operationTail.then((_) => action());
    _operationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}
