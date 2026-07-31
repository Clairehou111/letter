import 'dart:math';

import '../domain/moment_check_in.dart';
import '../domain/moment_check_in_repository.dart';

final class InMemoryMomentCheckInRepository implements MomentCheckInRepository {
  InMemoryMomentCheckInRepository({
    Iterable<MomentCheckIn> seed = const [],
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _records = [...seed],
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final List<MomentCheckIn> _records;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  @override
  Future<List<MomentCheckIn>> getAll() async {
    return [..._records]
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  }

  @override
  Future<MomentCheckIn> create(
    MomentCheckInState state, {
    required DateTime occurredAt,
  }) async {
    final record = MomentCheckIn(
      id: _idGenerator(),
      state: state,
      occurredAt: occurredAt.toUtc(),
      createdAt: _clock().toUtc(),
    );
    _records.add(record);
    return record;
  }

  @override
  Future<void> delete(String id) async {
    final removed = _records.where((record) => record.id == id).length;
    if (removed == 0) {
      throw const MomentCheckInException(MomentCheckInFailure.notFound);
    }
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<void> close() async {}

  static String _randomId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      12,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
  }
}
