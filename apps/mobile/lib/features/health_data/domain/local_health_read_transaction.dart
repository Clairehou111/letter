/// Runs a multi-repository read against one local database snapshot.
abstract interface class LocalHealthReadTransaction {
  Future<T> run<T>(Future<T> Function() read);
}

/// Used by injected and in-memory repositories that do not share one Drift
/// connection. Production native storage supplies the transactional adapter.
final class PassthroughLocalHealthReadTransaction
    implements LocalHealthReadTransaction {
  const PassthroughLocalHealthReadTransaction();

  @override
  Future<T> run<T>(Future<T> Function() read) => read();
}
