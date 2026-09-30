import 'comfort_kit.dart';

abstract interface class ComfortKitRepository {
  Future<List<ComfortKitItemOverride>> getOverrides();

  Future<void> removeUntilChanged({
    required ComfortKitItem item,
    required DateTime updatedAt,
  });

  Future<void> dontShowAgain({
    required String sourceId,
    required DateTime updatedAt,
  });

  Future<void> restore(String sourceId);
}
