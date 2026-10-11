import 'dart:math';

import '../../cycle/domain/local_date.dart';
import '../../record_hub/domain/record_interventions.dart';
import '../domain/care_memory.dart';
import '../domain/care_memory_repository.dart';

/// Called only by a deliberate final scene/ritual completion. Keeping the
/// original completion object retains its token, date and zone across retries.
final class CareActionRecordingController {
  CareActionRecordingController({
    required this.repository,
    String Function()? completionTokenGenerator,
  }) : _tokenGenerator = completionTokenGenerator ?? _newToken;

  final RecordInterventionsRepository repository;
  final String Function() _tokenGenerator;
  final _drafts = Map<CareActionCompletion, TriedActionDraft>.identity();
  final _pending =
      Map<CareActionCompletion, Future<TriedActionRecord>>.identity();

  Future<TriedActionRecord> recordCompletion(
    CareActionCompletion completion,
  ) async {
    final existing = _pending[completion];
    if (existing != null) return existing;
    final draft = _drafts.putIfAbsent(completion, () {
      final validated = validateCareCompletion(completion);
      final captured = completion.occurredAt.toLocal();
      return TriedActionDraft(
        experiencedDate: LocalDate.fromDateTime(captured),
        actions: [
          TriedActionSelection(
            TriedActionKind.other,
            customName: validated.actionLabel,
          ),
        ],
        bundle: false,
        status: TriedActionStatus.completed,
        source: TriedActionSource.inAppCare,
        completionToken: _tokenGenerator(),
        careSourceId: validated.actionId,
        completionOccurredAt: captured,
        completionUtcOffsetMinutes: captured.timeZoneOffset.inMinutes,
      );
    });
    final operation = repository.saveAction(draft);
    _pending[completion] = operation;
    try {
      return await operation;
    } finally {
      _pending.remove(completion);
    }
  }

  static String _newToken() {
    final random = Random.secure();
    return 'care-completion-${List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join()}';
  }
}
