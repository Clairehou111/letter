import 'moment_check_in.dart';

enum MomentCheckInFailure { notFound, storageUnavailable }

final class MomentCheckInException implements Exception {
  const MomentCheckInException(this.failure);

  final MomentCheckInFailure failure;

  String get userMessage => switch (failure) {
    MomentCheckInFailure.notFound =>
      'This check-in is no longer available. Refresh and try again.',
    MomentCheckInFailure.storageUnavailable =>
      'Letter could not update your private check-in. Try again.',
  };
}

abstract interface class MomentCheckInRepository {
  Future<List<MomentCheckIn>> getAll();

  Future<MomentCheckIn> create(
    MomentCheckInState state, {
    required DateTime occurredAt,
  });

  Future<void> delete(String id);

  Future<void> close();
}
