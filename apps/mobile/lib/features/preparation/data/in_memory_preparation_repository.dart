import '../domain/preparation_plan.dart';

final class InMemoryPreparationRepository implements PreparationRepository {
  PreparationPlan? _active;
  final Map<String, PreparationDismissal> _dismissals = {};

  @override
  Future<PreparationPlan?> getActivePlan() async => _active;

  @override
  Future<void> savePlan(PreparationPlan plan) async {
    _active = plan;
  }

  @override
  Future<void> removeActivePlan() async {
    _active = null;
  }

  @override
  Future<List<PreparationDismissal>> getDismissals() async {
    final values = _dismissals.values.toList(growable: false);
    values.sort((a, b) => b.dismissedAt.compareTo(a.dismissedAt));
    return values;
  }

  @override
  Future<void> dismiss(PreparationDismissal dismissal) async {
    _dismissals[dismissal.fingerprint] = dismissal;
  }

  @override
  Future<void> restoreDismissal(String fingerprint) async {
    _dismissals.remove(fingerprint);
  }
}
