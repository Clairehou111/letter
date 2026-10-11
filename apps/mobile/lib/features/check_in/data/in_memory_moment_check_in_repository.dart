import 'dart:math';

import '../domain/moment_check_in.dart';
import '../domain/moment_check_in_repository.dart';

final class InMemoryMomentCheckInRepository
    implements CorrectableMomentRepository {
  InMemoryMomentCheckInRepository({
    Iterable<MomentCheckIn> seed = const [],
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _records = [...seed],
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _randomId;

  final List<MomentCheckIn> _records;
  final Map<String, MomentCheckIn> _deletedSources = {};
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
    final record = createMomentCheckIn(
      id: _idGenerator(),
      state: state,
      occurredAt: occurredAt,
      savedAt: _clock(),
    );
    _records.add(record);
    return record;
  }

  @override
  Future<MomentCheckIn> update(
    String id,
    MomentCheckInState state, {
    MomentCheckIn? expected,
  }) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) {
      throw const MomentCheckInException(MomentCheckInFailure.notFound);
    }
    final previous = _records[index];
    if (expected != null && !momentCheckInsMatch(previous, expected)) {
      throw const MomentCheckInException(MomentCheckInFailure.staleWrite);
    }
    if (previous.state == state) return previous;
    final corrected = correctMomentCheckIn(
      previous: previous,
      state: state,
      savedAt: _clock(),
    );
    _records[index] = corrected;
    return corrected;
  }

  @override
  Future<bool> deleteIfUnchanged(MomentCheckIn expected) async {
    final index = _records.indexWhere((record) => record.id == expected.id);
    if (index < 0 || !momentCheckInsMatch(_records[index], expected)) {
      return false;
    }
    final deleted = _records.removeAt(index);
    _deletedSources[deleted.id] = deleted;
    return true;
  }

  @override
  Future<MomentCheckIn> restoreDeleted(MomentCheckIn deleted) async {
    final trusted = _deletedSources[deleted.id];
    if (trusted == null ||
        !momentCheckInsMatch(trusted, deleted) ||
        _records.any((record) => record.id == deleted.id)) {
      throw const MomentCheckInException(MomentCheckInFailure.staleWrite);
    }
    _records.add(trusted);
    _deletedSources.remove(deleted.id);
    return trusted;
  }

  @override
  Future<void> delete(String id) async {
    final removed = _records.where((record) => record.id == id).length;
    if (removed == 0) {
      throw const MomentCheckInException(MomentCheckInFailure.notFound);
    }
    _records.removeWhere((record) => record.id == id);
    _deletedSources.remove(id);
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
