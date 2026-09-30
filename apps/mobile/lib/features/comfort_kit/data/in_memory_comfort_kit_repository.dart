import '../domain/comfort_kit.dart';
import '../domain/comfort_kit_repository.dart';

final class InMemoryComfortKitRepository implements ComfortKitRepository {
  final Map<String, ComfortKitItemOverride> _overrides = {};

  @override
  Future<List<ComfortKitItemOverride>> getOverrides() async =>
      List.unmodifiable(_overrides.values);

  @override
  Future<void> removeUntilChanged({
    required ComfortKitItem item,
    required DateTime updatedAt,
  }) async {
    _overrides[item.sourceId] = ComfortKitItemOverride(
      sourceId: item.sourceId,
      action: ComfortKitOverrideAction.removeUntilChanged,
      sourceVersion: item.sourceVersion,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> dontShowAgain({
    required String sourceId,
    required DateTime updatedAt,
  }) async {
    _overrides[sourceId] = ComfortKitItemOverride(
      sourceId: sourceId,
      action: ComfortKitOverrideAction.dontShowAgain,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> restore(String sourceId) async {
    _overrides.remove(sourceId);
  }
}
